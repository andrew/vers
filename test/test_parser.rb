# frozen_string_literal: true

require "test_helper"

class TestParser < Minitest::Test
  def setup
    @parser = Vers::Parser.new
  end

  def test_parse_vers_uri_basic
    range = @parser.parse("vers:npm/>=1.2.3|<2.0.0")
    assert range.contains?("1.5.0")
    refute range.contains?("2.0.0")
    refute range.contains?("1.0.0")
  end

  def test_parse_vers_uri_single_constraint
    range = @parser.parse("vers:gem/>=1.0.0")
    assert range.contains?("1.0.0")
    assert range.contains?("2.0.0")
    refute range.contains?("0.9.0")
  end

  def test_parse_vers_uri_exact_version
    range = @parser.parse("vers:pypi/=1.2.3")
    assert range.contains?("1.2.3")
    refute range.contains?("1.2.4")
  end

  def test_parse_vers_uri_with_exclusion
    range = @parser.parse("vers:npm/>=1.0.0|!=1.5.0|<2.0.0")
    assert range.contains?("1.4.0")
    assert range.contains?("1.6.0")
    refute range.contains?("1.5.0")  # excluded
    refute range.contains?("2.0.0")
  end

  def test_parse_star_wildcard
    range = @parser.parse("*")
    assert range.unbounded?
    assert range.contains?("0.0.1")
    assert range.contains?("999.999.999")
  end

  def test_parse_invalid_vers_uri
    assert_raises(ArgumentError) do
      @parser.parse("invalid:format")
    end
    
    assert_raises(ArgumentError) do
      @parser.parse("not-a-vers-uri")
    end
  end

  def test_parse_native_npm_caret
    range = @parser.parse_native("^1.2.3", "npm")
    assert range.contains?("1.2.3")
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
    refute range.contains?("1.1.0")
  end

  def test_parse_native_npm_tilde
    range = @parser.parse_native("~1.2.3", "npm")
    assert range.contains?("1.2.3")
    assert range.contains?("1.2.9")
    refute range.contains?("1.3.0")
    refute range.contains?("1.1.0")
  end

  def test_parse_native_npm_hyphen_range
    range = @parser.parse_native("1.2.3 - 2.3.4", "npm")
    assert range.contains?("1.2.3")
    assert range.contains?("2.0.0")
    assert range.contains?("2.3.4")
    refute range.contains?("1.2.2")
    refute range.contains?("2.3.5")
  end

  def test_parse_native_npm_or_operator
    range = @parser.parse_native("^1.2.3 || ^2.0.0", "npm")
    assert range.contains?("1.5.0")  # matches ^1.2.3
    assert range.contains?("2.5.0")  # matches ^2.0.0
    refute range.contains?("1.1.0")  # matches neither
    refute range.contains?("3.0.0")  # matches neither
  end

  def test_parse_native_npm_and_constraints
    range = @parser.parse_native(">=1.2.3 <2.0.0", "npm")
    assert range.contains?("1.5.0")
    refute range.contains?("1.2.2")
    refute range.contains?("2.0.0")
  end

  def test_parse_native_npm_wildcards
    tests = [
      ["*", true],
      ["x", true],
      ["X", true]
    ]
    
    tests.each do |input, should_be_unbounded|
      range = @parser.parse_native(input, "npm")
      assert_equal should_be_unbounded, range.unbounded?, "Failed for input: #{input}"
    end
  end

  def test_parse_native_gem_pessimistic
    range = @parser.parse_native("~> 1.2", "gem")
    assert range.contains?("1.2.0")
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
    refute range.contains?("1.1.9")
  end

  def test_parse_native_gem_pessimistic_patch
    range = @parser.parse_native("~> 1.2.3", "gem")
    assert range.contains?("1.2.3")
    assert range.contains?("1.2.9")
    refute range.contains?("1.3.0")
    refute range.contains?("1.2.2")
  end

  def test_parse_native_gem_comma_separated
    range = @parser.parse_native(">= 1.0, < 2.0", "gem")
    assert range.contains?("1.5.0")
    refute range.contains?("0.9.0")
    refute range.contains?("2.0.0")
  end

  def test_parse_native_pypi_comma_separated
    range = @parser.parse_native(">=1.0,<2.0", "pypi")
    assert range.contains?("1.5.0")
    refute range.contains?("0.9.0")
    refute range.contains?("2.0.0")
  end

  def test_parse_native_maven_brackets
    # [1.0,2.0] := >=1.0 <=2.0
    range = @parser.parse_native("[1.0,2.0]", "maven")
    assert range.contains?("1.0")
    assert range.contains?("1.5")
    assert range.contains?("2.0")
    refute range.contains?("0.9")
    refute range.contains?("2.1")
  end

  def test_parse_native_maven_parentheses
    # (1.0,2.0) := >1.0 <2.0
    range = @parser.parse_native("(1.0,2.0)", "maven")
    refute range.contains?("1.0")
    assert range.contains?("1.5")
    refute range.contains?("2.0")
  end

  def test_parse_native_maven_mixed_brackets
    # [1.0,2.0) := >=1.0 <2.0
    range = @parser.parse_native("[1.0,2.0)", "maven")
    assert range.contains?("1.0")
    assert range.contains?("1.5")
    refute range.contains?("2.0")
    
    # (1.0,2.0] := >1.0 <=2.0
    range2 = @parser.parse_native("(1.0,2.0]", "maven")
    refute range2.contains?("1.0")
    assert range2.contains?("1.5")
    assert range2.contains?("2.0")
  end

  def test_parse_native_debian
    range = @parser.parse_native(">> 1.0.0", "deb")
    # >> should be converted to >
    assert range.contains?("1.0.1")
    refute range.contains?("1.0.0")
  end

  def test_parse_native_unknown_scheme
    # Should fall back to generic constraint parsing
    range = @parser.parse_native(">=1.0.0", "unknown")
    assert range.contains?("1.0.0")
    assert range.contains?("2.0.0")
    refute range.contains?("0.9.0")
  end

  def test_to_vers_string_basic
    range = Vers::VersionRange.new([Vers::Interval.new(min: "1.2.3", max: "2.0.0", max_inclusive: false)])
    vers_string = @parser.to_vers_string(range, "npm")
    assert_equal "vers:npm/>=1.2.3|<2.0.0", vers_string
  end

  def test_to_vers_string_exact
    range = Vers::VersionRange.exact("1.2.3")
    vers_string = @parser.to_vers_string(range, "gem")
    assert_equal "vers:gem/=1.2.3", vers_string
  end

  def test_to_vers_string_unbounded
    range = Vers::VersionRange.unbounded
    vers_string = @parser.to_vers_string(range, "pypi")
    assert_equal "*", vers_string
  end

  def test_to_vers_string_empty
    range = Vers::VersionRange.empty
    vers_string = @parser.to_vers_string(range, "npm")
    assert_equal "vers:npm/", vers_string
  end

  def test_caret_range_edge_cases
    # ^0.2.3 := >=0.2.3 <0.3.0
    range = @parser.parse_native("^0.2.3", "npm")
    assert range.contains?("0.2.3")
    assert range.contains?("0.2.9")
    refute range.contains?("0.3.0")
    refute range.contains?("0.1.0")
    
    # ^0.0.3 := >=0.0.3 <0.0.4
    range2 = @parser.parse_native("^0.0.3", "npm")
    assert range2.contains?("0.0.3")
    refute range2.contains?("0.0.4")
    refute range2.contains?("0.0.2")
  end

  def test_tilde_range_edge_cases
    # ~1 := >=1.0.0 <2.0.0
    range = @parser.parse_native("~1", "npm")
    assert range.contains?("1.0.0")
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
  end

  def test_pessimistic_range_edge_cases
    # ~> 1 := >= 1.0.0, < 2.0.0
    range = @parser.parse_native("~> 1", "gem")
    assert range.contains?("1.0.0")
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
  end
end