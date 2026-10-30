# frozen_string_literal: true

require "test_helper"

class TestMissingRangeVersions < Minitest::Test
  %w[npm cargo].each do |scheme|
    %w[> >= < <= = != ^ ~ ~>].each do |operator|
      define_method("test_#{scheme}_rejects_#{operator}_without_a_version") do
        [operator, " #{operator} ", ">=1.0.0 #{operator}"].each do |requirement|
          assert_raises(ArgumentError, requirement) { Vers.parse_native(requirement, scheme) }
          [false, true].each do |include_prerelease|
            assert_raises(ArgumentError, requirement) do
              Vers.satisfies?("1.5.0", requirement, scheme, include_prerelease: include_prerelease)
            end
          end
        end
      end
    end

    define_method("test_#{scheme}_preserves_explicit_wildcards_and_partial_versions") do
      ["*", ">=1", ">= 1.0", "^1.0.0", "~1.2", "1.*", "1.2.*", ">=1.0.0 <2.0.0"].each do |requirement|
        assert Vers.satisfies?("1.2.3", requirement, scheme), requirement
      end
    end
  end

  def test_cargo_rejects_a_missing_version_after_a_comma
    assert_raises(ArgumentError) { Vers.satisfies?("1.5.0", ">=1.0.0, <", "cargo") }
  end
end
