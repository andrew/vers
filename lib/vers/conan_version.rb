# frozen_string_literal: true

require_relative "version_comparison"

module Vers
  module ConanVersion
    extend self

    def compare(left, right)
      left_main, left_pre, left_build = split(left)
      right_main, right_pre, right_build = split(right)

      comparison = compare_main(left_main, right_main)
      return comparison unless comparison.zero?

      comparison = compare_optional(left_pre, right_pre, prerelease: true)
      return comparison unless comparison.zero?

      compare_optional(left_build, right_build, prerelease: false)
    end

    def split(value)
      main = value.to_s
      build = nil
      prerelease = nil

      separator = main.rindex("+")
      if separator
        build = main[(separator + 1)..]
        main = main[0...separator]
      end

      separator = main.rindex("-")
      if separator
        prerelease = main[(separator + 1)..]
        main = main[0...separator]
      end

      [main, prerelease, build]
    end

    def valid?(value)
      string = value.to_s.strip
      !string.empty? && !string.match?(/[[:space:]]/)
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      !split(value.to_s.strip)[1].nil?
    end

    def compare_main(left, right)
      left_parts = significant_parts(left)
      right_parts = significant_parts(right)

      left_parts.zip(right_parts).each do |left_part, right_part|
        break unless left_part && right_part

        comparison = if VersionComparison.numeric?(left_part) && VersionComparison.numeric?(right_part)
                       VersionComparison.compare_numbers(left_part, right_part)
                     else
                       left_part <=> right_part
                     end
        return comparison unless comparison.zero?
      end

      left_parts.length <=> right_parts.length
    end

    def significant_parts(value)
      parts = value.split(".", -1)
      parts.pop while parts.last && VersionComparison.numeric?(parts.last) && VersionComparison.compare_numbers(parts.last, "0").zero?
      parts
    end

    def compare_optional(left, right, prerelease:)
      return 0 if left.nil? && right.nil?
      return prerelease ? 1 : -1 if left.nil?
      return prerelease ? -1 : 1 if right.nil?

      compare(left, right)
    end
  end
end
