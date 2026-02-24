# frozen_string_literal: true

require_relative 'interval'
require_relative 'version'

module Vers
  class VersionRange
    attr_reader :intervals, :raw_constraints, :scheme

    def initialize(intervals = [], raw_constraints: nil, scheme: nil)
      @scheme = scheme
      @intervals = intervals.compact.reject(&:empty?)
      if @scheme
        @intervals.sort! { |a, b| compare_interval_bounds(a, b) }
      else
        @intervals.sort_by! { |i| [i.min || '', i.max || ''] }
      end
      @raw_constraints = raw_constraints
      merge_overlapping_intervals!
    end

    def self.empty(scheme: nil)
      new([], scheme: scheme)
    end

    def self.unbounded(scheme: nil)
      new([Interval.unbounded(scheme: scheme)], scheme: scheme)
    end

    def self.exact(version, scheme: nil)
      new([Interval.exact(version, scheme: scheme)], scheme: scheme)
    end

    def self.greater_than(version, inclusive: false, scheme: nil)
      new([Interval.greater_than(version, inclusive: inclusive, scheme: scheme)], scheme: scheme)
    end

    def self.less_than(version, inclusive: false, scheme: nil)
      new([Interval.less_than(version, inclusive: inclusive, scheme: scheme)], scheme: scheme)
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
      merged_scheme = @scheme || other.scheme
      result_intervals = []

      intervals.each do |interval1|
        other.intervals.each do |interval2|
          intersection = interval1.intersect(interval2)
          result_intervals << intersection unless intersection.empty?
        end
      end

      combined_raw = (raw_constraints || intervals) + (other.raw_constraints || other.intervals)
      self.class.new(result_intervals, raw_constraints: combined_raw, scheme: merged_scheme)
    end

    def union(other)
      merged_scheme = @scheme || other.scheme
      combined_raw = (raw_constraints || intervals) + (other.raw_constraints || other.intervals)
      self.class.new(intervals + other.intervals, raw_constraints: combined_raw, scheme: merged_scheme)
    end

    def complement
      return self.class.unbounded(scheme: @scheme) if empty?
      return self.class.empty(scheme: @scheme) if unbounded?

      result_intervals = []

      sorted_intervals = if @scheme
                           intervals.sort { |a, b| compare_interval_bounds(a, b) }
                         else
                           intervals.sort_by { |i| i.min || '' }
                         end

      first_interval = sorted_intervals.first
      if first_interval.min
        result_intervals << Interval.new(
          max: first_interval.min,
          max_inclusive: !first_interval.min_inclusive,
          scheme: @scheme
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
              max_inclusive: !next_interval.min_inclusive,
              scheme: @scheme
            )
          end
        end
      end

      last_interval = sorted_intervals.last
      if last_interval.max
        result_intervals << Interval.new(
          min: last_interval.max,
          min_inclusive: !last_interval.max_inclusive,
          scheme: @scheme
        )
      end

      self.class.new(result_intervals, scheme: @scheme)
    end

    def exclude(version)
      return self if !contains?(version)

      result_intervals = []

      intervals.each do |interval|
        if interval.contains?(version)
          if interval.min.nil? || version_compare(interval.min, version) < 0
            result_intervals << Interval.new(
              min: interval.min,
              max: version,
              min_inclusive: interval.min_inclusive,
              max_inclusive: false,
              scheme: @scheme
            )
          end

          if interval.max.nil? || version_compare(version, interval.max) < 0
            result_intervals << Interval.new(
              min: version,
              max: interval.max,
              min_inclusive: false,
              max_inclusive: interval.max_inclusive,
              scheme: @scheme
            )
          end
        else
          result_intervals << interval
        end
      end

      self.class.new(result_intervals, raw_constraints: raw_constraints, scheme: @scheme)
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

      if @scheme
        Version.compare_with_scheme(a, b, @scheme)
      else
        Version.compare(a, b)
      end
    end

    def compare_interval_bounds(a, b)
      min_a = a.min
      min_b = b.min
      min_cmp = if min_a.nil? && min_b.nil?
                  0
                elsif min_a.nil?
                  -1
                elsif min_b.nil?
                  1
                else
                  version_compare(min_a, min_b)
                end
      return min_cmp unless min_cmp == 0

      max_a = a.max
      max_b = b.max
      if max_a.nil? && max_b.nil?
        0
      elsif max_a.nil?
        1
      elsif max_b.nil?
        -1
      else
        version_compare(max_a, max_b)
      end
    end
  end
end