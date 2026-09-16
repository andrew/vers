# frozen_string_literal: true

require "test_helper"
require "json"

class TestRangeConformance < Minitest::Test
  FIXTURE_DIRECTORIES = {
    File.join(__dir__, "vers-spec", "tests") => "vers-spec/tests",
    File.join(__dir__, "testdata", "local", "tests") => "local/tests"
  }.freeze
  SKIPS = JSON.parse(File.read(File.join(__dir__, "testdata", "local", "skip.json"))).fetch("skips")
  USED_SKIPS = Array.new(SKIPS.length, false)

  FIXTURE_DIRECTORIES.each do |directory, relative_directory|
    Dir[File.join(directory, "*.json")].sort.each do |path|
      fixture = JSON.parse(File.read(path))
      relative_path = File.join(relative_directory, File.basename(path))

      fixture.fetch("tests").each_with_index do |test_case, index|
        next unless %w[containment from_native parse validate].include?(test_case.fetch("test_type"))

        skip_index = SKIPS.index do |entry|
          entry.fetch("file") == relative_path &&
            entry.fetch("test_type") == test_case.fetch("test_type") &&
            entry.fetch("input") == test_case.fetch("input") &&
            (!entry.key?("expected_output") || entry.fetch("expected_output") == test_case["expected_output"])
        end
        USED_SKIPS[skip_index] = true if skip_index

        test_name = "test_#{relative_path.gsub(/[^a-zA-Z0-9]+/, "_")}_#{test_case.fetch("test_type")}_#{index}"
        define_method(test_name) do
          skip SKIPS.fetch(skip_index).fetch("reason") if skip_index

          operation = lambda do
            case test_case.fetch("test_type")
            when "containment"
              input = test_case.fetch("input")
              Vers.parse(input.fetch("vers")).contains?(input.fetch("version", ""))
            when "from_native"
              input = test_case.fetch("input")
              scheme = input["type"] || input.fetch("scheme")
              range = Vers.parse_native(input.fetch("native_range"), scheme)
              Vers.to_vers_string(range, scheme)
            when "parse"
              range = Vers::Parser.new.parse(test_case.fetch("input"), require_canonical_order: true)
              {
                "type" => range.scheme,
                "constraints" => range_constraints(range)
              }
            when "validate"
              range = Vers.parse(test_case.fetch("input"))
              Vers.to_vers_string(range, range.scheme)
            end
          end

          if test_case["expected_failure"]
            error = assert_raises(ArgumentError, test_case.fetch("description"), &operation)
            if test_case["expected_message"]
              assert_equal test_case.fetch("expected_message"), error.message
            end
          else
            assert_equal test_case.fetch("expected_output"), operation.call, test_case.fetch("description")
          end
        end
      end
    end
  end

  def test_skip_manifest_entries_match_the_corpus
    unused = SKIPS.each_index.reject { |index| USED_SKIPS.fetch(index) }
    assert_empty unused, "Unused skip entries: #{unused.map { |index| SKIPS.fetch(index) }.inspect}"
  end

  def range_constraints(range)
    intervals = range.raw_constraints || range.intervals
    constraints = intervals.flat_map do |interval|
      if interval.min == interval.max && interval.min_inclusive && interval.max_inclusive
        [["=", interval.min]]
      else
        values = []
        values << [interval.min_inclusive ? ">=" : ">", interval.min] if interval.min
        values << [interval.max_inclusive ? "<=" : "<", interval.max] if interval.max
        values
      end
    end
    constraints + range.exclusions.map { |version| ["!=", version] }
  end
end
