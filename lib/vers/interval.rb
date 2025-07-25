# frozen_string_literal: true

require_relative 'version'

module Vers
  class Interval
    attr_reader :min, :max, :min_inclusive, :max_inclusive

    def initialize(min: nil, max: nil, min_inclusive: true, max_inclusive: true)
      @min = min
      @max = max
      @min_inclusive = min_inclusive
      @max_inclusive = max_inclusive

      validate_bounds!
    end

    def self.empty
      new(min: "1", max: "0", min_inclusive: true, max_inclusive: true)
    end

    def self.unbounded
      new
    end

    def self.exact(version)
      new(min: version, max: version, min_inclusive: true, max_inclusive: true)
    end

    def self.greater_than(version, inclusive: false)
      new(min: version, min_inclusive: inclusive)
    end

    def self.less_than(version, inclusive: false)
      new(max: version, max_inclusive: inclusive)
    end

    def empty?
      return true if min && max && version_compare(min, max) > 0
      return true if min && max && version_compare(min, max) == 0 && (!min_inclusive || !max_inclusive)
      false
    end

    def unbounded?
      min.nil? && max.nil?
    end

    def contains?(version)
      return false if empty?
      return true if unbounded?

      within_min = min.nil? || 
                   (min_inclusive ? version_compare(version, min) >= 0 : version_compare(version, min) > 0)
      
      within_max = max.nil? || 
                   (max_inclusive ? version_compare(version, max) <= 0 : version_compare(version, max) < 0)

      within_min && within_max
    end

    def intersect(other)
      return self.class.empty if empty? || other.empty?

      new_min = nil
      new_min_inclusive = true
      new_max = nil
      new_max_inclusive = true

      if min && other.min
        comparison = version_compare(min, other.min)
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
        comparison = version_compare(max, other.max)
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
        max_inclusive: new_max_inclusive
      )
    end

    def union(other)
      return other if empty?
      return self if other.empty?

      return nil unless overlaps?(other) || adjacent?(other)

      new_min = nil
      new_min_inclusive = true
      new_max = nil
      new_max_inclusive = true

      if min && other.min
        comparison = version_compare(min, other.min)
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
      elsif min.nil?
        new_min = other.min
        new_min_inclusive = other.min_inclusive
      elsif other.min.nil?
        new_min = min
        new_min_inclusive = min_inclusive
      end

      if max && other.max
        comparison = version_compare(max, other.max)
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
      elsif max.nil?
        new_max = other.max
        new_max_inclusive = other.max_inclusive
      elsif other.max.nil?
        new_max = max
        new_max_inclusive = max_inclusive
      end

      self.class.new(
        min: new_min,
        max: new_max,
        min_inclusive: new_min_inclusive,
        max_inclusive: new_max_inclusive
      )
    end

    def overlaps?(other)
      return false if empty? || other.empty?
      !intersect(other).empty?
    end

    def adjacent?(other)
      return false if empty? || other.empty?
      
      if max && other.min && version_compare(max, other.min) == 0
        return (max_inclusive && !other.min_inclusive) || (!max_inclusive && other.min_inclusive)
      end
      
      if min && other.max && version_compare(min, other.max) == 0
        return (min_inclusive && !other.max_inclusive) || (!min_inclusive && other.max_inclusive)
      end
      
      false
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

    def validate_bounds!
      return unless min && max
      
      comparison = version_compare(min, max)
      if comparison > 0
        return
      elsif comparison == 0 && (!min_inclusive || !max_inclusive)
        return
      end
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