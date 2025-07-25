# frozen_string_literal: true

require_relative 'interval'
require_relative 'version'

module Vers
  class VersionRange
    attr_reader :intervals

    def initialize(intervals = [])
      @intervals = intervals.compact.reject(&:empty?).sort_by { |i| [i.min || '', i.max || ''] }
      merge_overlapping_intervals!
    end

    def self.empty
      new([])
    end

    def self.unbounded
      new([Interval.unbounded])
    end

    def self.exact(version)
      new([Interval.exact(version)])
    end

    def self.greater_than(version, inclusive: false)
      new([Interval.greater_than(version, inclusive: inclusive)])
    end

    def self.less_than(version, inclusive: false)
      new([Interval.less_than(version, inclusive: inclusive)])
    end

    def empty?
      intervals.empty?
    end

    def unbounded?
      intervals.length == 1 && intervals.first.unbounded?
    end

    def contains?(version)
      intervals.any? { |interval| interval.contains?(version) }
    end

    def intersect(other)
      result_intervals = []
      
      intervals.each do |interval1|
        other.intervals.each do |interval2|
          intersection = interval1.intersect(interval2)
          result_intervals << intersection unless intersection.empty?
        end
      end
      
      self.class.new(result_intervals)
    end

    def union(other)
      self.class.new(intervals + other.intervals)
    end

    def complement
      return self.class.unbounded if empty?
      return self.class.empty if unbounded?

      result_intervals = []
      
      sorted_intervals = intervals.sort_by { |i| i.min || '' }
      
      first_interval = sorted_intervals.first
      if first_interval.min
        result_intervals << Interval.new(
          max: first_interval.min,
          max_inclusive: !first_interval.min_inclusive
        )
      end
      
      sorted_intervals.each_cons(2) do |curr, next_interval|
        if curr.max && next_interval.min
          comparison = version_compare(curr.max, next_interval.min)
          if comparison < 0 || (comparison == 0 && (!curr.max_inclusive || !next_interval.min_inclusive))
            result_intervals << Interval.new(
              min: curr.max,
              max: next_interval.min,
              min_inclusive: !curr.max_inclusive,
              max_inclusive: !next_interval.min_inclusive
            )
          end
        end
      end
      
      last_interval = sorted_intervals.last
      if last_interval.max
        result_intervals << Interval.new(
          min: last_interval.max,
          min_inclusive: !last_interval.max_inclusive
        )
      end
      
      self.class.new(result_intervals)
    end

    def exclude(version)
      return self if !contains?(version)
      
      result_intervals = []
      
      intervals.each do |interval|
        if interval.contains?(version)
          if interval.min && version_compare(interval.min, version) < 0
            result_intervals << Interval.new(
              min: interval.min,
              max: version,
              min_inclusive: interval.min_inclusive,
              max_inclusive: false
            )
          end
          
          if interval.max && version_compare(version, interval.max) < 0
            result_intervals << Interval.new(
              min: version,
              max: interval.max,
              min_inclusive: false,
              max_inclusive: interval.max_inclusive
            )
          end
        else
          result_intervals << interval
        end
      end
      
      self.class.new(result_intervals)
    end

    def to_s
      return "∅" if empty?
      return intervals.map(&:to_s).join(" ∪ ")
    end

    private

    def merge_overlapping_intervals!
      return if intervals.length <= 1

      merged = []
      current = intervals.first

      intervals[1..-1].each do |interval|
        union_result = current.union(interval)
        if union_result
          current = union_result
        else
          merged << current
          current = interval
        end
      end

      merged << current
      @intervals = merged
    end

    def version_compare(a, b)
      return 0 if a == b
      return -1 if a.nil?
      return 1 if b.nil?
      
      # Use the Version class for comparison
      Version.compare(a, b)
    end
  end
end