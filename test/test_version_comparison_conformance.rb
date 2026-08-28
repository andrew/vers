# frozen_string_literal: true

require "test_helper"
require "json"

class TestVersionComparisonConformance < Minitest::Test
  FIXTURE_DIRECTORIES = [
    File.join(__dir__, "vers-spec", "tests"),
    File.join(__dir__, "testdata", "local", "tests")
  ].freeze

  fixture_files = FIXTURE_DIRECTORIES.flat_map do |directory|
    Dir[File.join(directory, "*_version_cmp_test.json")] +
      Dir[File.join(directory, "lexicographic-test.json")]
  end.sort

  fixture_files.each do |path|
    fixture = JSON.parse(File.read(path))

    fixture.fetch("tests").each_with_index do |test_case, index|
      next unless %w[comparison equality].include?(test_case.fetch("test_type"))

      relative_path = path.delete_prefix("#{__dir__}/")
      test_name = "test_#{relative_path.gsub(/[^a-zA-Z0-9]+/, "_")}_#{index}"

      define_method(test_name) do
        input = test_case.fetch("input")
        scheme = input["input_type"] || input.fetch("input_scheme")
        versions = input.fetch("versions")

        if test_case.fetch("test_type") == "equality"
          expected = test_case.fetch("expected_output")
          actual = Vers.compare_with_scheme(versions.fetch(0), versions.fetch(1), scheme).zero?
          assert_equal expected, actual, test_case.fetch("description")
        else
          expected = test_case.fetch("expected_output")
          actual = versions.sort { |left, right| Vers.compare_with_scheme(left, right, scheme) }

          versions.combination(2) do |left, right|
            forward = Vers.compare_with_scheme(left, right, scheme)
            reverse = Vers.compare_with_scheme(right, left, scheme)
            assert_equal(-forward, reverse, "#{test_case.fetch("description")}: comparator is not antisymmetric")
          end
          actual.each_cons(3) do |first, _second, third|
            assert_operator Vers.compare_with_scheme(first, third, scheme), :<=, 0,
              "#{test_case.fetch("description")}: comparator is not transitive"
          end

          assert_equal expected.length, actual.length, test_case.fetch("description")
          actual.zip(expected).each do |actual_version, expected_version|
            assert_equal 0,
              Vers.compare_with_scheme(actual_version, expected_version, scheme),
              "#{test_case.fetch("description")}: sorted #{versions.inspect} as #{actual.inspect}, expected #{expected.inspect}"
          end
        end
      end
    end
  end
end
