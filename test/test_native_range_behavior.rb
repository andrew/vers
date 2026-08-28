# frozen_string_literal: true

require "test_helper"
require "json"

class TestNativeRangeBehavior < Minitest::Test
  CASES = JSON.parse(File.read(File.join(__dir__, "testdata", "native_range_behavior.json"))).fetch("tests").freeze

  CASES.each_with_index do |test_case, index|
    define_method("test_native_range_behavior_#{index}") do
      actual = Vers.satisfies?(test_case.fetch("version"), test_case.fetch("range"), test_case.fetch("scheme"))

      assert_equal test_case.fetch("expected"), actual,
        "#{test_case.fetch("version")} in #{test_case.fetch("scheme")}:#{test_case.fetch("range")}"
    end
  end
end
