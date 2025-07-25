# frozen_string_literal: true

require "test_helper"

class TestInterval < Minitest::Test
  def test_interval_creation
    interval = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    assert_equal "1.0.0", interval.min
    assert_equal "2.0.0", interval.max
    assert interval.min_inclusive
    assert interval.max_inclusive
  end

  def test_interval_exact
    interval = Vers::Interval.exact("1.2.3")
    assert_equal "1.2.3", interval.min
    assert_equal "1.2.3", interval.max
    assert interval.min_inclusive
    assert interval.max_inclusive
  end

  def test_interval_greater_than
    interval = Vers::Interval.greater_than("1.0.0", inclusive: true)
    assert_equal "1.0.0", interval.min
    assert_nil interval.max
    assert interval.min_inclusive
  end

  def test_interval_less_than
    interval = Vers::Interval.less_than("2.0.0", inclusive: false)
    assert_nil interval.min
    assert_equal "2.0.0", interval.max
    refute interval.max_inclusive
  end

  def test_interval_empty
    interval = Vers::Interval.empty
    assert interval.empty?
  end

  def test_interval_unbounded
    interval = Vers::Interval.unbounded
    assert interval.unbounded?
    refute interval.empty?
  end

  def test_interval_contains
    interval = Vers::Interval.new(min: "1.0.0", max: "2.0.0", min_inclusive: true, max_inclusive: false)
    
    assert interval.contains?("1.0.0")   # min inclusive
    assert interval.contains?("1.5.0")   # middle
    refute interval.contains?("2.0.0")   # max exclusive
    refute interval.contains?("0.9.0")   # below min
    refute interval.contains?("2.1.0")   # above max
  end

  def test_interval_intersect
    interval1 = Vers::Interval.new(min: "1.0.0", max: "3.0.0")
    interval2 = Vers::Interval.new(min: "2.0.0", max: "4.0.0")
    
    intersection = interval1.intersect(interval2)
    assert_equal "2.0.0", intersection.min
    assert_equal "3.0.0", intersection.max
  end

  def test_interval_intersect_no_overlap
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.0.0", max_inclusive: false)
    interval2 = Vers::Interval.new(min: "2.0.0", max: "3.0.0", min_inclusive: true)
    
    intersection = interval1.intersect(interval2)
    assert intersection.empty?
  end

  def test_interval_union_overlapping
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.5.0")
    interval2 = Vers::Interval.new(min: "2.0.0", max: "3.0.0")
    
    union = interval1.union(interval2)
    refute_nil union
    assert_equal "1.0.0", union.min
    assert_equal "3.0.0", union.max
  end

  def test_interval_union_non_overlapping
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.0.0", max_inclusive: false)
    interval2 = Vers::Interval.new(min: "3.0.0", max: "4.0.0")
    
    union = interval1.union(interval2)
    assert_nil union  # Non-overlapping intervals cannot be unioned into single interval
  end

  def test_interval_union_adjacent
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.0.0", max_inclusive: false)
    interval2 = Vers::Interval.new(min: "2.0.0", max: "3.0.0", min_inclusive: true)
    
    union = interval1.union(interval2)
    refute_nil union  # Adjacent intervals can be unioned
    assert_equal "1.0.0", union.min
    assert_equal "3.0.0", union.max
  end

  def test_interval_overlaps
    interval1 = Vers::Interval.new(min: "1.0.0", max: "3.0.0")
    interval2 = Vers::Interval.new(min: "2.0.0", max: "4.0.0")
    interval3 = Vers::Interval.new(min: "4.0.0", max: "5.0.0")
    
    assert interval1.overlaps?(interval2)
    refute interval1.overlaps?(interval3)
  end

  def test_interval_adjacent
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.0.0", max_inclusive: false)
    interval2 = Vers::Interval.new(min: "2.0.0", max: "3.0.0", min_inclusive: true)
    interval3 = Vers::Interval.new(min: "3.0.0", max: "4.0.0", min_inclusive: false)
    
    assert interval1.adjacent?(interval2)
    # interval2 ends at 3.0.0 inclusive, interval3 starts at 3.0.0 exclusive, so they should be adjacent
    assert interval2.adjacent?(interval3)
  end

  def test_interval_to_s
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    assert_equal "[1.0.0,2.0.0]", interval1.to_s
    
    interval2 = Vers::Interval.new(min: "1.0.0", max: "2.0.0", min_inclusive: false, max_inclusive: false)
    assert_equal "(1.0.0,2.0.0)", interval2.to_s
    
    interval3 = Vers::Interval.unbounded
    assert_equal "(-∞,+∞)", interval3.to_s
    
    interval4 = Vers::Interval.empty
    assert_equal "∅", interval4.to_s
  end

  def test_interval_empty_conditions
    # Empty interval where min > max
    interval1 = Vers::Interval.new(min: "2.0.0", max: "1.0.0")
    assert interval1.empty?
    
    # Empty interval where min == max but not inclusive
    interval2 = Vers::Interval.new(min: "1.0.0", max: "1.0.0", min_inclusive: false)
    assert interval2.empty?
    
    interval3 = Vers::Interval.new(min: "1.0.0", max: "1.0.0", max_inclusive: false)
    assert interval3.empty?
  end

  def test_interval_unbounded_conditions
    interval1 = Vers::Interval.new
    assert interval1.unbounded?
    
    interval2 = Vers::Interval.new(min: "1.0.0")
    refute interval2.unbounded?
    
    interval3 = Vers::Interval.new(max: "2.0.0")
    refute interval3.unbounded?
  end
end