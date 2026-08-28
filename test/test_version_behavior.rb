# frozen_string_literal: true

require "test_helper"
require "json"

class TestVersionBehavior < Minitest::Test
  CASES = JSON.parse(File.read(File.join(__dir__, "testdata", "version_behavior.json"))).fetch("tests").freeze

  CASES.each_with_index do |test_case, index|
    define_method("test_scheme_behavior_#{index}") do
      scheme = test_case.fetch("scheme")
      version = test_case.fetch("version")
      valid = test_case.fetch("valid")

      assert_equal valid, Vers.valid?(version, scheme)
      assert_equal(valid && !test_case.fetch("prerelease", false), Vers.stable?(version, scheme))
      assert_equal(valid && test_case.fetch("prerelease", false), Vers.prerelease?(version, scheme))

      if valid
        normalized = test_case.fetch("normalized")
        assert_equal normalized, Vers.normalize(version, scheme)
        assert_equal normalized, Vers.clean(version, scheme)
        assert_equal 0, Vers.compare_with_scheme(version.strip, normalized, scheme)
      else
        assert_raises(ArgumentError) { Vers.normalize(version, scheme) }
        assert_nil Vers.clean(version, scheme)
      end
    end
  end
end
