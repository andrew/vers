# frozen_string_literal: true

require "test_helper"
require "json"

class TestVersionComparisonConformance < Minitest::Test
  TEST_FILES = {
    "nuget" => "nuget_version_cmp_test.json",
    "maven" => "maven_version_cmp_test.json"
  }.freeze

  TEST_FILES.each do |scheme_name, file|
    path = File.join(File.dirname(__FILE__), "testdata", file)
    next unless File.exist?(path)

    data = JSON.parse(File.read(path))

    data["tests"].each_with_index do |tc, idx|
      versions = tc.dig("input", "versions")
      scheme = tc.dig("input", "input_scheme")
      test_type = tc["test_type"]
      expected = tc["expected_output"]
      v1, v2 = versions

      case test_type
      when "equality"
        define_method("test_#{scheme_name}_equality_#{idx}_#{v1}_vs_#{v2}") do
          cmp = Vers::Version.compare_with_scheme(v1, v2, scheme)
          got = cmp == 0
          assert_equal expected, got,
            "compare_with_scheme(#{v1.inspect}, #{v2.inspect}, #{scheme.inspect}) == 0 is #{got}, want #{expected} (cmp=#{cmp})"
        end

      when "comparison"
        define_method("test_#{scheme_name}_comparison_#{idx}_#{v1}_vs_#{v2}") do
          cmp = Vers::Version.compare_with_scheme(v1, v2, scheme)

          if expected[0] == expected[1] ||
              Vers::Version.compare_with_scheme(expected[0], expected[1], scheme) == 0
            assert_equal 0, cmp,
              "compare_with_scheme(#{v1.inspect}, #{v2.inspect}, #{scheme.inspect}) = #{cmp}, want 0 (equal versions)"
          else
            v1_matches_first = Vers::Version.compare_with_scheme(v1, expected[0], scheme) == 0
            if v1_matches_first
              assert(cmp < 0,
                "compare_with_scheme(#{v1.inspect}, #{v2.inspect}, #{scheme.inspect}) = #{cmp}, want < 0 (expected order: #{expected})")
            else
              assert(cmp > 0,
                "compare_with_scheme(#{v1.inspect}, #{v2.inspect}, #{scheme.inspect}) = #{cmp}, want > 0 (expected order: #{expected})")
            end
          end
        end
      end
    end
  end
end
