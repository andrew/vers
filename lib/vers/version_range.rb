# frozen_string_literal: true

require_relative 'interval'
require_relative 'version'

module Vers
  class VersionRange
    VALIDATED_CONTAINMENT_SCHEMES = %w[bazel cargo composer npm pypi].freeze

    attr_reader :intervals, :raw_constraints, :scheme, :exclusions

    def initialize(intervals = [], raw_constraints: nil, scheme: nil, exclusions: [])
      canonical_scheme = Scheme.canonical(scheme)
      interval_schemes = intervals.compact.map(&:scheme).compact.map { |value| Scheme.canonical(value) }.uniq
      if interval_schemes.length > 1 || (canonical_scheme && interval_schemes.any? { |value| value != canonical_scheme })
        raise ArgumentError, "Cannot combine different version range schemes"
      end

      @scheme = canonical_scheme || interval_schemes.first
      @intervals = intervals.select { |interval| interval && !interval.empty? }.map { |interval| interval.with_scheme(@scheme) }
      if @scheme
        @intervals.sort! { |a, b| compare_interval_bounds(a, b) }
      else
        @intervals.sort_by! { |i| [i.min || '', i.max || ''] }
      end
      @raw_constraints = raw_constraints
      @exclusions = exclusions.dup
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
      exclusions.empty? && intervals.length == 1 && intervals.first.unbounded?
    end

    def contains?(version)
      if VALIDATED_CONTAINMENT_SCHEMES.include?(scheme) && !Version.valid?(version, scheme)
        return false
      end
      return false if exclusions.any? { |excluded| excluded_version?(version, excluded) }

      comparison_scheme = scheme == "cargo" ? "semver" : scheme
      intervals.any? do |interval|
        contains = if scheme == "composer"
                     composer_interval_contains?(interval, version)
                   elsif scheme == "pypi"
                     pypi_interval_contains?(interval, version)
                   else
                     interval.contains?(version, comparison_scheme: comparison_scheme)
                   end
        contains && prerelease_allowed?(interval, version)
      end
    end

    def composer_interval_contains?(interval, version)
      candidate_branch = ComposerVersion.branch?(version)
      minimum_branch = interval.min && ComposerVersion.branch?(interval.min)
      maximum_branch = interval.max && ComposerVersion.branch?(interval.max)
      return interval.contains?(version) unless candidate_branch || minimum_branch || maximum_branch
      return true if interval.unbounded?

      candidate_branch && minimum_branch && maximum_branch &&
        interval.min_inclusive && interval.max_inclusive && interval.min == interval.max && version == interval.min
    end

    def pypi_interval_contains?(interval, version)
      if interval.min && interval.max && interval.min_inclusive && interval.max_inclusive &&
          PyPIVersion.compare(interval.min, interval.max).zero?
        return PyPIVersion.specifier_equal?(version, interval.min)
      end
      return false unless interval.contains?(version)

      candidate = PyPIVersion.parse(version)
      return false unless candidate

      if interval.min && !interval.min_inclusive
        bound = PyPIVersion.parse(interval.min)
        if bound
          return false if PyPIVersion.specifier_equal?(version, interval.min)

          without_post = PyPIVersion.without_post_and_dev(candidate)
          if candidate.post_number && PyPIVersion.versions_equal?(without_post, bound, ignore_local: true)
            return false
          end
        end
      end

      if interval.max && !interval.max_inclusive
        bound = PyPIVersion.parse(interval.max)
        if bound
          bound_is_release = bound.pre_tag.nil? && bound.post_number.nil? && bound.dev_number.nil?
          if bound_is_release && PyPIVersion.same_release?(candidate, bound) &&
              (!candidate.pre_tag.nil? || !candidate.dev_number.nil?)
            return false
          end

          without_dev = PyPIVersion.without_dev(candidate)
          if candidate.dev_number && PyPIVersion.versions_equal?(without_dev, bound, ignore_local: true)
            return false
          end
        end
      end

      true
    end

    def prerelease_allowed?(interval, version)
      return true unless %w[npm cargo].include?(scheme)

      candidate = SemverVersion.parse(version.to_s.strip)
      return false unless candidate
      return true if candidate.prerelease.empty?

      [interval.min, interval.max].compact.any? do |bound|
        parsed_bound = SemverVersion.parse(bound.to_s.strip)
        next false unless parsed_bound && !parsed_bound.prerelease.empty?

        candidate.core.zip(parsed_bound.core).all? do |candidate_part, bound_part|
          VersionComparison.compare_numbers(candidate_part, bound_part).zero?
        end
      end
    end

    def excluded_version?(version, excluded)
      if scheme == "pypi"
        PyPIVersion.specifier_equal?(version, excluded)
      elsif scheme == "composer" && (ComposerVersion.branch?(version) || ComposerVersion.branch?(excluded))
        version == excluded
      else
        Version.compare_with_scheme(version, excluded, scheme).zero?
      end
    end

    def intersect(other)
      merged_scheme = compatible_scheme(other)
      result_intervals = []

      intervals.each do |interval1|
        other.intervals.each do |interval2|
          intersection = interval1.intersect(interval2)
          result_intervals << intersection unless intersection.empty?
        end
      end

      combined_raw = (raw_constraints || intervals) + (other.raw_constraints || other.intervals)
      self.class.new(
        result_intervals,
        raw_constraints: combined_raw,
        scheme: merged_scheme,
        exclusions: exclusions + other.exclusions
      )
    end

    def union(other)
      merged_scheme = compatible_scheme(other)
      combined_raw = (raw_constraints || intervals) + (other.raw_constraints || other.intervals)
      shared_exclusions = exclusions.select do |excluded|
        other.exclusions.any? { |candidate| Version.compare_with_scheme(excluded, candidate, merged_scheme).zero? }
      end
      self.class.new(
        intervals + other.intervals,
        raw_constraints: combined_raw,
        scheme: merged_scheme,
        exclusions: shared_exclusions
      )
    end

    def with_scheme(value)
      canonical = Scheme.canonical(value)
      if scheme && canonical && scheme != canonical
        raise ArgumentError, "Cannot combine #{scheme} and #{canonical} version ranges"
      end
      return self if scheme == canonical

      self.class.new(intervals, raw_constraints: raw_constraints, scheme: canonical, exclusions: exclusions)
    end

    def compatible_scheme(other)
      if scheme && other.scheme && scheme != other.scheme
        raise ArgumentError, "Cannot combine #{scheme} and #{other.scheme} version ranges"
      end

      scheme || other.scheme
    end

    def complement
      unless exclusions.empty?
        base = self.class.new(intervals, scheme: scheme).complement
        exclusions.each do |excluded|
          base = base.union(self.class.exact(excluded, scheme: scheme))
        end
        return base
      end

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
      return self unless contains?(version)

      self.class.new(
        intervals,
        raw_constraints: raw_constraints,
        scheme: scheme,
        exclusions: exclusions + [version]
      )
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
