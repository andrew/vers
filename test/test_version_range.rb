# frozen_string_literal: true

require "test_helper"

class TestVersionRange < Minitest::Test
  def test_version_range_creation
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    interval2 = Vers::Interval.new(min: "3.0.0", max: "4.0.0")
    
    range = Vers::VersionRange.new([interval1, interval2])
    assert_equal 2, range.intervals.length
  end

  def test_version_range_empty
    range = Vers::VersionRange.empty
    assert range.empty?
    assert_equal 0, range.intervals.length
  end

  def test_version_range_unbounded
    range = Vers::VersionRange.unbounded
    assert range.unbounded?
    assert_equal 1, range.intervals.length
    assert range.intervals.first.unbounded?
  end

  def test_version_range_exact
    range = Vers::VersionRange.exact("1.2.3")
    assert range.contains?("1.2.3")
    refute range.contains?("1.2.4")
  end

  def test_version_range_greater_than
    range = Vers::VersionRange.greater_than("1.0.0", inclusive: true)
    assert range.contains?("1.0.0")
    assert range.contains?("2.0.0")
    refute range.contains?("0.9.0")
  end

  def test_version_range_less_than
    range = Vers::VersionRange.less_than("2.0.0", inclusive: false)
    assert range.contains?("1.9.9")
    refute range.contains?("2.0.0")
    refute range.contains?("2.1.0")
  end

  def test_version_range_contains
    interval = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    range = Vers::VersionRange.new([interval])
    
    assert range.contains?("1.5.0")
    refute range.contains?("2.5.0")
    refute range.contains?("0.5.0")
  end

  def test_version_range_intersect
    range1 = Vers::VersionRange.new([Vers::Interval.new(min: "1.0.0", max: "3.0.0")])
    range2 = Vers::VersionRange.new([Vers::Interval.new(min: "2.0.0", max: "4.0.0")])
    
    intersection = range1.intersect(range2)
    assert intersection.contains?("2.5.0")
    refute intersection.contains?("1.5.0")
    refute intersection.contains?("3.5.0")
  end

  def test_version_range_union
    range1 = Vers::VersionRange.new([Vers::Interval.new(min: "1.0.0", max: "2.0.0")])
    range2 = Vers::VersionRange.new([Vers::Interval.new(min: "3.0.0", max: "4.0.0")])
    
    union = range1.union(range2)
    assert union.contains?("1.5.0")
    assert union.contains?("3.5.0")
    refute union.contains?("2.5.0")
  end

  def test_version_range_exclude
    range = Vers::VersionRange.new([Vers::Interval.new(min: "1.0.0", max: "3.0.0")])
    excluded_range = range.exclude("2.0.0")
    
    assert excluded_range.contains?("1.5.0")
    assert excluded_range.contains?("2.5.0")
    refute excluded_range.contains?("2.0.0")
  end

  def test_version_range_complement
    range = Vers::VersionRange.new([Vers::Interval.new(min: "1.0.0", max: "2.0.0")])
    complement = range.complement
    
    refute complement.contains?("1.5.0")
    assert complement.contains?("0.5.0")
    assert complement.contains?("2.5.0")
  end

  def test_version_range_merge_overlapping
    interval1 = Vers::Interval.new(min: "1.0.0", max: "2.5.0")
    interval2 = Vers::Interval.new(min: "2.0.0", max: "3.0.0")
    
    range = Vers::VersionRange.new([interval1, interval2])
    # Should merge overlapping intervals
    assert_equal 1, range.intervals.length
    assert_equal "1.0.0", range.intervals.first.min
    assert_equal "3.0.0", range.intervals.first.max
  end

  def test_version_range_to_s
    range1 = Vers::VersionRange.empty
    assert_equal "∅", range1.to_s
    
    interval = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    range2 = Vers::VersionRange.new([interval])
    assert_equal "[1.0.0,2.0.0]", range2.to_s
  end

  def test_version_range_complex_operations
    # Test a complex scenario with multiple operations
    range1 = Vers::VersionRange.new([Vers::Interval.new(min: "1.0.0", max: "5.0.0")])
    range2 = Vers::VersionRange.new([Vers::Interval.new(min: "3.0.0", max: "7.0.0")])
    
    # Union: should cover 1.0.0 to 7.0.0
    union = range1.union(range2)
    assert union.contains?("2.0.0")
    assert union.contains?("4.0.0")
    assert union.contains?("6.0.0")
    
    # Intersection: should cover 3.0.0 to 5.0.0
    intersection = range1.intersect(range2)
    refute intersection.contains?("2.0.0")
    assert intersection.contains?("4.0.0")
    refute intersection.contains?("6.0.0")
  end

  def test_version_range_empty_intervals_filtered
    empty_interval = Vers::Interval.empty
    valid_interval = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    
    range = Vers::VersionRange.new([empty_interval, valid_interval])
    assert_equal 1, range.intervals.length
    assert_equal valid_interval, range.intervals.first
  end

  def test_version_range_sorting
    interval1 = Vers::Interval.new(min: "3.0.0", max: "4.0.0")
    interval2 = Vers::Interval.new(min: "1.0.0", max: "2.0.0")
    
    range = Vers::VersionRange.new([interval1, interval2])
    # Should be sorted by min version
    assert_equal "1.0.0", range.intervals.first.min
    assert_equal "3.0.0", range.intervals.last.min
  end
end