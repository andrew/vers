# frozen_string_literal: true

module Vers
  module VersionComparison
    extend self

    def compare_numbers(left, right)
      normalized_left = normalize_number(left)
      normalized_right = normalize_number(right)

      length_comparison = normalized_left.length <=> normalized_right.length
      return length_comparison unless length_comparison.zero?

      normalized_left <=> normalized_right
    end

    def normalize_number(value)
      normalized = value.to_s.sub(/\A0+/, "")
      normalized.empty? ? "0" : normalized
    end

    def numeric?(value)
      value.match?(/\A\d+\z/)
    end
  end
end
