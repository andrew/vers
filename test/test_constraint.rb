# frozen_string_literal: true

require "test_helper"

class TestConstraint < Minitest::Test
  def test_constraint_creation
    constraint = Vers::Constraint.new(">=", "1.2.3")
    assert_equal ">=", constraint.operator
    assert_equal "1.2.3", constraint.version
  end

  def test_constraint_invalid_operator
    assert_raises(ArgumentError) do
      Vers::Constraint.new("~", "1.2.3")
    end
  end

  def test_constraint_parse_simple
    constraint = Vers::Constraint.parse("1.2.3")
    assert_equal "=", constraint.operator
    assert_equal "1.2.3", constraint.version
  end

  def test_constraint_parse_operators
    tests = [
      [">=1.2.3", ">=", "1.2.3"],
      ["<=1.2.3", "<=", "1.2.3"],
      [">1.2.3", ">", "1.2.3"],
      ["<1.2.3", "<", "1.2.3"],
      ["=1.2.3", "=", "1.2.3"],
      ["!=1.2.3", "!=", "1.2.3"]
    ]
    
    tests.each do |input, expected_op, expected_version|
      constraint = Vers::Constraint.parse(input)
      assert_equal expected_op, constraint.operator, "Failed for input: #{input}"
      assert_equal expected_version, constraint.version, "Failed for input: #{input}"
    end
  end

  def test_constraint_parse_invalid
    # ~ is not a valid operator, should be parsed as exact version "~1.2.3"
    constraint = Vers::Constraint.parse("~1.2.3")
    assert_equal "=", constraint.operator
    assert_equal "~1.2.3", constraint.version
  end

  def test_constraint_to_interval
    # Test each operator
    eq_constraint = Vers::Constraint.new("=", "1.2.3")
    interval = eq_constraint.to_interval
    assert_equal "1.2.3", interval.min
    assert_equal "1.2.3", interval.max
    assert interval.min_inclusive
    assert interval.max_inclusive
    
    gte_constraint = Vers::Constraint.new(">=", "1.2.3")
    interval = gte_constraint.to_interval
    assert_equal "1.2.3", interval.min
    assert_nil interval.max
    assert interval.min_inclusive
    
    gt_constraint = Vers::Constraint.new(">", "1.2.3")
    interval = gt_constraint.to_interval
    assert_equal "1.2.3", interval.min
    assert_nil interval.max
    refute interval.min_inclusive
    
    lte_constraint = Vers::Constraint.new("<=", "1.2.3")
    interval = lte_constraint.to_interval
    assert_nil interval.min
    assert_equal "1.2.3", interval.max
    assert interval.max_inclusive
    
    lt_constraint = Vers::Constraint.new("<", "1.2.3")
    interval = lt_constraint.to_interval
    assert_nil interval.min
    assert_equal "1.2.3", interval.max
    refute interval.max_inclusive
    
    # != constraint should return nil (handled specially in parsing)
    ne_constraint = Vers::Constraint.new("!=", "1.2.3")
    assert_nil ne_constraint.to_interval
  end

  def test_constraint_exclusion
    ne_constraint = Vers::Constraint.new("!=", "1.2.3")
    assert ne_constraint.exclusion?
    
    eq_constraint = Vers::Constraint.new("=", "1.2.3")
    refute eq_constraint.exclusion?
  end

  def test_constraint_satisfies
    gte_constraint = Vers::Constraint.new(">=", "1.2.3")
    assert gte_constraint.satisfies?("1.2.3")
    assert gte_constraint.satisfies?("1.2.4")
    assert gte_constraint.satisfies?("2.0.0")
    refute gte_constraint.satisfies?("1.2.2")
    
    eq_constraint = Vers::Constraint.new("=", "1.2.3")
    assert eq_constraint.satisfies?("1.2.3")
    refute eq_constraint.satisfies?("1.2.4")
    
    ne_constraint = Vers::Constraint.new("!=", "1.2.3")
    refute ne_constraint.satisfies?("1.2.3")
    assert ne_constraint.satisfies?("1.2.4")
    
    lt_constraint = Vers::Constraint.new("<", "2.0.0")
    assert lt_constraint.satisfies?("1.9.9")
    refute lt_constraint.satisfies?("2.0.0")
    refute lt_constraint.satisfies?("2.0.1")
  end

  def test_constraint_to_s
    constraint = Vers::Constraint.new(">=", "1.2.3")
    assert_equal ">=1.2.3", constraint.to_s
  end

  def test_constraint_equality
    constraint1 = Vers::Constraint.new(">=", "1.2.3")
    constraint2 = Vers::Constraint.new(">=", "1.2.3")
    constraint3 = Vers::Constraint.new(">", "1.2.3")
    
    assert_equal constraint1, constraint2
    refute_equal constraint1, constraint3
  end

  def test_constraint_hash
    constraint1 = Vers::Constraint.new(">=", "1.2.3")
    constraint2 = Vers::Constraint.new(">=", "1.2.3")
    
    assert_equal constraint1.hash, constraint2.hash
  end

  def test_constraint_valid_operators
    Vers::Constraint::OPERATORS.each do |operator|
      constraint = Vers::Constraint.new(operator, "1.2.3")
      assert_equal operator, constraint.operator
      assert_equal "1.2.3", constraint.version
    end
  end

  def test_constraint_parse_edge_cases
    # Test parsing version that starts with operator-like characters
    constraint = Vers::Constraint.parse("1.0.0-alpha")
    assert_equal "=", constraint.operator
    assert_equal "1.0.0-alpha", constraint.version
    
    # Test empty version after operator
    assert_raises(ArgumentError) do
      Vers::Constraint.parse(">=")
    end
  end
end