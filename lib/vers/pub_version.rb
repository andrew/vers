# frozen_string_literal: true

module Vers
  module PubVersion
    extend self

    PATTERN = /\A[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?\z/

    def compare(left, right)
      parsed_left = parse(left)
      parsed_right = parse(right)
      return Version.compare(left, right) unless parsed_left && parsed_right

      parsed_left.core.zip(parsed_right.core).each do |left_part, right_part|
        comparison = VersionComparison.compare_numbers(left_part, right_part)
        return comparison unless comparison.zero?
      end

      comparison = SemverVersion.compare_prerelease(parsed_left.prerelease, parsed_right.prerelease)
      return comparison unless comparison.zero?

      compare_build(parsed_left.build, parsed_right.build)
    end

    def parse(value)
      return nil unless PATTERN.match?(value.to_s)

      SemverVersion.parse(value)
    end

    def valid?(value)
      !parse(value.to_s.strip).nil?
    end

    def normalize(value)
      normalized = SemverVersion.normalize(value.to_s.strip)
      core_and_prerelease, build = normalized.split("+", 2)
      return core_and_prerelease unless build

      normalized_build = build.split(".").map do |part|
        VersionComparison.numeric?(part) ? VersionComparison.normalize_number(part) : part
      end
      "#{core_and_prerelease}+#{normalized_build.join(".")}"
    end

    def prerelease?(value)
      parsed = parse(value.to_s.strip)
      parsed && !parsed.prerelease.empty?
    end

    def compare_build(left, right)
      return 0 if left.empty? && right.empty?
      return -1 if left.empty?
      return 1 if right.empty?

      SemverVersion.compare_prerelease(left, right)
    end
  end
end
