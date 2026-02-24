# frozen_string_literal: true

require "test_helper"

class TestNuGetVersion < Minitest::Test
  def test_basic_ordering
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0", "2.0.0"))
    assert_equal(1, Vers::NuGetVersion.compare("2.0.0", "1.0.0"))
    assert_equal(0, Vers::NuGetVersion.compare("1.0.0", "1.0.0"))
  end

  def test_four_part_versions
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0.0", "1.0.0.1"))
    assert_equal(1, Vers::NuGetVersion.compare("1.0.0.2", "1.0.0.1"))
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0.0", "1.0.1.0"))
  end

  def test_trailing_zeros_equivalent
    assert_equal(0, Vers::NuGetVersion.compare("1.0", "1.0.0.0"))
    assert_equal(0, Vers::NuGetVersion.compare("1.0.0", "1.0.0.0"))
    assert_equal(0, Vers::NuGetVersion.compare("1", "1.0.0.0"))
  end

  def test_case_insensitive_prerelease
    assert_equal(0, Vers::NuGetVersion.compare("1.0.0-BETA", "1.0.0-beta"))
    assert_equal(0, Vers::NuGetVersion.compare("1.0.0-Alpha", "1.0.0-alpha"))
  end

  def test_prerelease_less_than_release
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0-alpha", "1.0.0"))
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0-rc1", "1.0.0"))
  end

  def test_prerelease_ordering
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0-alpha", "1.0.0-beta"))
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0-alpha.1", "1.0.0-alpha.2"))
  end

  def test_numeric_prerelease_parts
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0-alpha.1", "1.0.0-alpha.10"))
  end

  def test_build_metadata_ignored
    assert_equal(0, Vers::NuGetVersion.compare("1.0.0+build1", "1.0.0+build2"))
    assert_equal(0, Vers::NuGetVersion.compare("1.0.0-alpha+build", "1.0.0-alpha"))
  end

  def test_equal_strings_shortcircuit
    assert_equal(0, Vers::NuGetVersion.compare("1.2.3-beta.4", "1.2.3-beta.4"))
  end

  def test_shorter_prerelease_less_than_longer
    assert_equal(-1, Vers::NuGetVersion.compare("1.0.0-alpha", "1.0.0-alpha.1"))
  end
end
