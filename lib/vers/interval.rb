# frozen_string_literal: true

require_relative 'version'

module Vers
  class Interval
    attr_reader :min, :max, :min_inclusive, :max_inclusive, :scheme

    def initialize(min: nil, max: nil, min_inclusive: true, max_inclusive: true, scheme: nil)
      @min = min
      @max = max
      @min_inclusive = min_inclusive
      @max_inclusive = max_inclusive
      @scheme = Scheme.canonical(scheme)
      @empty = compute_empty
    end

    def self.empty(scheme: nil)
      new(min: "1", max: "0", min_inclusive: true, max_inclusive: true, scheme: scheme)
    end

    def self.unbounded(scheme: nil)
      new(scheme: scheme)
    end

    def self.exact(version, scheme: nil)
      new(min: version, max: version, min_inclusive: true, max_inclusive: true, scheme: scheme)
    end

    def self.greater_than(version, inclusive: false, scheme: nil)
      new(min: version, min_inclusive: inclusive, scheme: scheme)
    end

    def self.less_than(version, inclusive: false, scheme: nil)
      new(max: version, max_inclusive: inclusive, scheme: scheme)
    end

    def empty?
      @empty
    end

    def unbounded?
      min.nil? && max.nil?
    end

    def contains?(version, comparison_scheme: scheme)
      return false if empty?
      return true if unbounded?

      within_min = min.nil? || 
                   (min_inclusive ? version_compare(version, min, comparison_scheme) >= 0 : version_compare(version, min, comparison_scheme) > 0)
      
      within_max = max.nil? || 
                   (max_inclusive ? version_compare(version, max, comparison_scheme) <= 0 : version_compare(version, max, comparison_scheme) < 0)

      within_min && within_max
    end

    def intersect(other)
      merged_scheme = compatible_scheme(other)
      return self.class.empty(scheme: merged_scheme) if empty? || other.empty?

      new_min = nil
      new_min_inclusive = true
      new_max = nil
      new_max_inclusive = true

      if min && other.min
        comparison = version_compare(min, other.min, merged_scheme)
        if comparison > 0
          new_min = min
          new_min_inclusive = min_inclusive
        elsif comparison < 0
          new_min = other.min
          new_min_inclusive = other.min_inclusive
        else
          new_min = min
          new_min_inclusive = min_inclusive && other.min_inclusive
        end
      elsif min
        new_min = min
        new_min_inclusive = min_inclusive
      elsif other.min
        new_min = other.min
        new_min_inclusive = other.min_inclusive
      end

      if max && other.max
        comparison = version_compare(max, other.max, merged_scheme)
        if comparison < 0
          new_max = max
          new_max_inclusive = max_inclusive
        elsif comparison > 0
          new_max = other.max
          new_max_inclusive = other.max_inclusive
        else
          new_max = max
          new_max_inclusive = max_inclusive && other.max_inclusive
        end
      elsif max
        new_max = max
        new_max_inclusive = max_inclusive
      elsif other.max
        new_max = other.max
        new_max_inclusive = other.max_inclusive
      end

      self.class.new(
        min: new_min,
        max: new_max,
        min_inclusive: new_min_inclusive,
        max_inclusive: new_max_inclusive,
        scheme: merged_scheme
      )
    end

    def union(other)
      merged_scheme = compatible_scheme(other)
      return other if empty?
      return self if other.empty?

      return nil unless overlaps?(other) || adjacent?(other)

      new_min = nil
      new_min_inclusive = true
      new_max = nil
      new_max_inclusive = true

      if min && other.min
        comparison = version_compare(min, other.min, merged_scheme)
        if comparison < 0
          new_min = min
          new_min_inclusive = min_inclusive
        elsif comparison > 0
          new_min = other.min
          new_min_inclusive = other.min_inclusive
        else
          new_min = min
          new_min_inclusive = min_inclusive || other.min_inclusive
        end
      elsif min.nil? || other.min.nil?
        new_min = nil
        new_min_inclusive = true
      end

      if max && other.max
        comparison = version_compare(max, other.max, merged_scheme)
        if comparison > 0
          new_max = max
          new_max_inclusive = max_inclusive
        elsif comparison < 0
          new_max = other.max
          new_max_inclusive = other.max_inclusive
        else
          new_max = max
          new_max_inclusive = max_inclusive || other.max_inclusive
        end
      elsif max.nil? || other.max.nil?
        new_max = nil
        new_max_inclusive = true
      end

      self.class.new(
        min: new_min,
        max: new_max,
        min_inclusive: new_min_inclusive,
        max_inclusive: new_max_inclusive,
        scheme: merged_scheme
      )
    end

    def overlaps?(other)
      merged_scheme = compatible_scheme(other)
      return false if empty? || other.empty?
      return true if unbounded? || other.unbounded?

      # Check if the intervals can't overlap by comparing bounds directly
      if max && other.min
        cmp = version_compare(max, other.min, merged_scheme)
        return false if cmp < 0
        return false if cmp == 0 && (!max_inclusive || !other.min_inclusive)
      end

      if min && other.max
        cmp = version_compare(min, other.max, merged_scheme)
        return false if cmp > 0
        return false if cmp == 0 && (!min_inclusive || !other.max_inclusive)
      end

      true
    end

    def adjacent?(other)
      merged_scheme = compatible_scheme(other)
      return false if empty? || other.empty?
      
      if max && other.min && version_compare(max, other.min, merged_scheme) == 0
        return (max_inclusive && !other.min_inclusive) || (!max_inclusive && other.min_inclusive)
      end
      
      if min && other.max && version_compare(min, other.max, merged_scheme) == 0
        return (min_inclusive && !other.max_inclusive) || (!min_inclusive && other.max_inclusive)
      end
      
      false
    end

    def with_scheme(value)
      canonical = Scheme.canonical(value)
      if scheme && canonical && scheme != canonical
        raise ArgumentError, "Cannot combine #{scheme} and #{canonical} version ranges"
      end
      return self if scheme == canonical

      self.class.new(
        min: min,
        max: max,
        min_inclusive: min_inclusive,
        max_inclusive: max_inclusive,
        scheme: canonical
      )
    end

    def compatible_scheme(other)
      if scheme && other.scheme && scheme != other.scheme
        raise ArgumentError, "Cannot combine #{scheme} and #{other.scheme} version ranges"
      end

      scheme || other.scheme
    end

    def to_s
      return "∅" if empty?
      return "(-∞,+∞)" if unbounded?

      min_bracket = min_inclusive ? "[" : "("
      max_bracket = max_inclusive ? "]" : ")"
      min_str = min || "-∞"
      max_str = max || "+∞"

      "#{min_bracket}#{min_str},#{max_str}#{max_bracket}"
    end

    private

    def compute_empty
      if min && max
        cmp = version_compare(min, max)
        cmp > 0 || (cmp == 0 && (!min_inclusive || !max_inclusive))
      else
        false
      end
    end

    def version_compare(a, b, comparison_scheme = @scheme)
      return 0 if a == b
      return -1 if a.nil?
      return 1 if b.nil?

      if comparison_scheme
        Version.compare_with_scheme(a, b, comparison_scheme)
      else
        Version.compare(a, b)
      end
    end
  end
end
