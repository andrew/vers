# frozen_string_literal: true

require "test_helper"

class TestBazelVersion < Minitest::Test
  def test_bcr_versions_follow_the_upstream_release
    assert_operator Vers.compare_with_scheme("0.7.1", "0.7.1.bcr.1", "bazel"), :<, 0
    assert_operator Vers.compare_with_scheme("0.7.1.bcr.2", "0.7.1.bcr.10", "bazel"), :<, 0
  end

  def test_prerelease_release_and_bcr_ordering
    assert_operator Vers.compare_with_scheme("36.0-rc2", "36.0", "bazel"), :<, 0
    assert_operator Vers.compare_with_scheme("36.0", "36.0.bcr.1", "bazel"), :<, 0
  end

  def test_bazel_release_identifier_ordering
    assert_operator Vers.compare_with_scheme("", "1.0", "bazel"), :>, 0
    assert_operator Vers.compare_with_scheme("1.0", "1.0.0", "bazel"), :<, 0
    assert_operator Vers.compare_with_scheme("1.0.patch.3", "1.0.patch.10", "bazel"), :<, 0
    assert_operator Vers.compare_with_scheme("1.0.patch3", "1.0.patch10", "bazel"), :>, 0
    assert_operator Vers.compare_with_scheme("4", "a", "bazel"), :<, 0
  end

  def test_bazel_build_metadata_is_ignored
    assert_equal 0, Vers.compare_with_scheme("1.0+build2", "1.0+build3", "bazel")
    assert_equal 0, Vers.compare_with_scheme("1.0-pre+build", "1.0-pre", "bazel")
  end

  def test_bazel_validation_accepts_relaxed_release_versions
    assert Vers.valid?("", "bazel")
    assert Vers.valid?("35.1", "bazel")
    assert Vers.valid?("0.7.1.bcr.1", "bazel")
    assert Vers.valid?("36.0-rc2", "bazel")
    assert Vers.valid?("1.0.patch.3", "bazel")
    assert Vers.valid?("18446744073709551615", "bazel")
  end

  def test_bazel_validation_rejects_invalid_versions
    invalid_versions = [
      "-abc",
      "1_2",
      "ßážëł",
      "1.0-pre?",
      "18446744073709551616",
      "1.0-pre///",
      "1..0",
      "1.0-pre..erp"
    ]

    invalid_versions.each do |version|
      refute Vers.valid?(version, "bazel"), version
    end
  end

  def test_bazel_stability_classification
    assert Vers.stable?("35.1", "bazel")
    assert Vers.stable?("0.7.1.bcr.1", "bazel")
    refute Vers.prerelease?("0.7.1.bcr.1", "bazel")

    refute Vers.stable?("36.0-rc2", "bazel")
    assert Vers.prerelease?("36.0-rc2", "bazel")
  end

  def test_no_scheme_stability_classification_is_unchanged
    assert Vers.stable?("1.2.3")
    refute Vers.prerelease?("1.2.3")

    refute Vers.stable?("1.2.3-alpha")
    assert Vers.prerelease?("1.2.3-alpha")
  end

  def test_parsed_bazel_range_uses_bazel_comparison
    range = Vers.parse("vers:bazel/>0.7.1")

    assert range.contains?("0.7.1.bcr.1")
    refute range.contains?("0.7.1")
  end

  def test_native_bazel_range_uses_standard_comparators
    range = Vers.parse_native(">=35.1", "bazel")

    assert range.contains?("36.0")
    refute range.contains?("35.0.bcr.1")
  end
end
