# frozen_string_literal: true

require "test_helper"

class TestVers < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Vers::VERSION
  end

  def test_parse_vers_uri
    range = Vers.parse("vers:npm/>=1.2.3|<2.0.0")
    assert range.contains?("1.5.0")
    refute range.contains?("2.1.0")
    refute range.contains?("1.0.0")
  end

  def test_parse_native_npm_caret
    range = Vers.parse_native("^1.2.3", "npm")
    assert range.contains?("1.2.3")
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
    refute range.contains?("1.1.0")
  end

  def test_parse_native_gem_pessimistic
    range = Vers.parse_native("~> 1.2", "gem")
    assert range.contains?("1.2.0")
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
    refute range.contains?("1.1.9")
  end

  def test_satisfies_with_vers_uri
    assert Vers.satisfies?("1.5.0", "vers:npm/>=1.0.0|<2.0.0")
    refute Vers.satisfies?("2.1.0", "vers:npm/>=1.0.0|<2.0.0")
  end

  def test_satisfies_with_native_format
    assert Vers.satisfies?("1.5.0", "^1.2.3", "npm")
    refute Vers.satisfies?("2.0.0", "^1.2.3", "npm")
  end

  def test_compare_versions
    assert_equal(-1, Vers.compare("1.2.3", "1.2.4"))
    assert_equal(1, Vers.compare("2.0.0", "1.9.9"))
    assert_equal(0, Vers.compare("1.0.0", "1.0.0"))
  end

  def test_normalize_version
    assert_equal "1.2.3", Vers.normalize("1.2.3")
    assert_equal "1.0.0", Vers.normalize("1")
  end

  def test_valid_version
    assert Vers.valid?("1.2.3")
    assert Vers.valid?("1.0.0-alpha")
    assert Vers.valid?("v1.0.0")
    refute Vers.valid?("")
    refute Vers.valid?("not-a-version")
    refute Vers.valid?("1.0")
    refute Vers.valid?("latest")
  end

  def test_clean_version
    assert_equal "1.0.0", Vers.clean("1.0.0")
    assert_equal "1.0.0", Vers.clean("v1.0.0")
    assert_equal "2.5.3", Vers.clean("v2.5.3")
    assert_equal "1.7.0-alpha.2", Vers.clean("1.7.0-alpha.2")
    assert_nil Vers.clean("not-a-version")
    assert_nil Vers.clean("1.0")
    assert_nil Vers.clean("latest")
  end

  def test_satisfies_with_or_ranges
    assert Vers.satisfies?("1.5.0", ">= 1.0.0, < 2.0.0 || >= 3.0.0, < 4.0.0", "gem")
    assert Vers.satisfies?("3.5.0", ">= 1.0.0, < 2.0.0 || >= 3.0.0, < 4.0.0", "gem")
    refute Vers.satisfies?("2.5.0", ">= 1.0.0, < 2.0.0 || >= 3.0.0, < 4.0.0", "gem")
  end

  def test_exact_range
    range = Vers.exact("1.2.3")
    assert range.contains?("1.2.3")
    refute range.contains?("1.2.4")
  end

  def test_greater_than_range
    range = Vers.greater_than("1.2.3", inclusive: true)
    assert range.contains?("1.2.3")
    assert range.contains?("2.0.0")
    refute range.contains?("1.2.2")
  end

  def test_less_than_range
    range = Vers.less_than("2.0.0", inclusive: false)
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
    refute range.contains?("2.0.1")
  end

  def test_unbounded_range
    range = Vers.unbounded
    assert range.contains?("0.0.1")
    assert range.contains?("999.999.999")
    assert range.unbounded?
  end

  def test_empty_range
    range = Vers.empty
    refute range.contains?("1.0.0")
    assert range.empty?
  end

  def test_satisfies_returns_false_when_parse_native_returns_nil
    mock_parser = Minitest::Mock.new
    mock_parser.expect(:parse_native, nil, [String, String])

    Vers.class_variable_set(:@@parser, mock_parser)
    refute Vers.satisfies?("1.0.0", "< 2.0.0", "npm")
  ensure
    Vers.class_variable_set(:@@parser, Vers::Parser.new)
  end

  def test_to_vers_string
    range = Vers.parse("vers:npm/>=1.2.3|<2.0.0")
    vers_string = Vers.to_vers_string(range, "npm")
    assert_match(/vers:npm\//, vers_string)
  end
end
