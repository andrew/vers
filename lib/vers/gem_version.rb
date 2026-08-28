# frozen_string_literal: true

require_relative "version_comparison"

module Vers
  module GemVersion
    extend self

    Segment = Data.define(:value, :numeric)
    PATTERN = /\A[0-9]+(?:\.[0-9A-Za-z]+)*(?:-[0-9A-Za-z][0-9A-Za-z.-]*)?\z/

    def compare(left, right)
      compare_segments(parse(left), parse(right))
    end

    def parse(value)
      segments = []

      value.to_s.strip.scan(/-|\d+|[A-Za-z]+/) do |part|
        if part == "-"
          segments << Segment.new("pre", false)
        else
          segments << Segment.new(part, VersionComparison.numeric?(part))
        end
      end

      first_text = segments.index { |segment| !segment.numeric }
      if first_text && first_text.positive?
        start = first_text
        start -= 1 while start.positive? && segments[start - 1].numeric && VersionComparison.compare_numbers(segments[start - 1].value, "0").zero?
        segments.slice!(start...first_text) if start < first_text
      end

      segments.pop while segments.last&.numeric && VersionComparison.compare_numbers(segments.last.value, "0").zero?
      segments
    end

    def valid?(value)
      value.to_s.strip.match?(PATTERN)
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      parse(value).any? { |segment| !segment.numeric }
    end

    def compare_segments(left, right)
      left.zip(right).each do |left_segment, right_segment|
        break unless left_segment && right_segment

        if left_segment.numeric != right_segment.numeric
          return left_segment.numeric ? 1 : -1
        end

        comparison = if left_segment.numeric
                       VersionComparison.compare_numbers(left_segment.value, right_segment.value)
                     else
                       left_segment.value <=> right_segment.value
                     end
        return comparison unless comparison.zero?
      end

      return 0 if left.length == right.length
      return compare_missing(right.drop(left.length)) if left.length < right.length

      -compare_missing(left.drop(right.length))
    end

    def compare_missing(segments)
      segments.each do |segment|
        return 1 unless segment.numeric
        return -1 unless VersionComparison.compare_numbers(segment.value, "0").zero?
      end

      0
    end
  end
end
