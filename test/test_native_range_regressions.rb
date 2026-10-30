# frozen_string_literal: true

require "test_helper"

class TestNativeRangeRegressions < Minitest::Test
  CARGO_CASES = {
    ">= 2.1.0, < 2.41.0" => { "2.0.0" => false, "2.1.0" => true, "2.40.0" => true, "2.41.0" => false },
    ">=2.1.0,<2.41.0" => { "2.0.0" => false, "2.1.0" => true, "2.40.0" => true, "2.41.0" => false },
    "1.2.3" => { "1.2.2" => false, "1.2.3" => true, "1.9.0" => true, "2.0.0" => false },
    "1.2" => { "1.1.9" => false, "1.2.0" => true, "1.9.0" => true, "2.0.0" => false },
    "0.2.3" => { "0.2.2" => false, "0.2.3" => true, "0.2.9" => true, "0.3.0" => false },
    "=1.2.3" => { "1.2.2" => false, "1.2.3" => true, "1.2.4" => false },
    ">=2.1.0, <2.1.0" => { "2.0.0" => false, "2.1.0" => false, "2.2.0" => false }
  }.freeze

  CARGO_CASES.each_with_index do |(requirement, candidates), index|
    define_method("test_cargo_native_requirement_#{index}") do
      candidates.each do |version, expected|
        message = "#{version} in cargo:#{requirement}"
        assert_equal expected, Vers.satisfies?(version, requirement, "cargo"), message
        assert_equal expected, Vers.parse_native(requirement, "cargo").contains?(version), message
      end
    end
  end

  %w[npm cargo].each do |scheme|
    define_method("test_#{scheme}_native_ranges_exclude_prereleases_by_default") do
      refute Vers.satisfies?("1.7.0-alpha.2", "<3.0.0", scheme)
      refute Vers.parse_native("<3.0.0", scheme).contains?("1.7.0-alpha.2")
      assert Vers.satisfies?("1.7.0-alpha.2", ">=1.7.0-alpha.1", scheme)
    end

    define_method("test_#{scheme}_prerelease_option_preserves_range_boundaries") do
      requirement = scheme == "cargo" ? ">=1.0.0, <3.0.0" : ">=1.0.0 <3.0.0"
      range = Vers.parse_native(requirement, scheme)
      {
        "0.9.0-alpha.1" => false,
        "1.0.0-alpha.1" => false,
        "1.0.0" => true,
        "1.7.0-alpha.2" => true,
        "3.0.0" => false,
        "3.1.0-alpha.1" => false,
        "not-a-version" => false
      }.each do |version, expected|
        assert_equal expected, Vers.satisfies?(version, requirement, scheme, include_prerelease: true), version
        assert_equal expected, range.contains?(version, include_prerelease: true), version
      end

      refute Vers.satisfies?("1.7.0-alpha.2", "<3.0.0", scheme, include_prerelease: false)
      refute range.contains?("1.7.0-alpha.2", include_prerelease: false)
    end
  end

  def test_scheme_selection_distinguishes_native_and_generic_validation
    assert Vers.valid?("2.0", "semver")
    assert Vers.valid?("2.0", "maven")
    assert Vers.stable?("0.7.1.bcr.2", "bazel")
    assert_operator Vers.compare_with_scheme("0.7.1.bcr.2", "0.7.1", "bazel"), :>, 0

    refute Vers.valid?("2.0", "unknown")
    refute Vers.valid?("latest", "unknown")
    assert Vers.valid?("1.0.0", "unknown")
  end
end
