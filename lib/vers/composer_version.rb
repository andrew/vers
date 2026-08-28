# frozen_string_literal: true

require_relative "version_comparison"

module Vers
  module ComposerVersion
    extend self

    PATTERN = /\Av?([0-9]+(?:\.[0-9]+){0,3})(?:[-._]?([a-z]+)(?:[.-]?([0-9]+(?:[.-][0-9]+)*))?)?(?:\+\S+)?\z/i
    NUMERIC_BRANCH_PATTERN = /\Av?\d+(?:\.\d+)*\.x-dev\z/i
    Parsed = Data.define(:core, :stability, :number)

    STABILITIES = {
      "dev" => 0,
      "a" => 1,
      "alpha" => 1,
      "b" => 2,
      "beta" => 2,
      "rc" => 3,
      "stable" => 4,
      "p" => 5,
      "pl" => 5,
      "patch" => 5
    }.freeze

    def compare(left, right)
      parsed_left = parse(left)
      parsed_right = parse(right)
      left_branch = branch?(left)
      right_branch = branch?(right)

      return -1 if left_branch && !right_branch
      return 1 if !left_branch && right_branch
      return left.downcase <=> right.downcase unless parsed_left && parsed_right

      parsed_left.core.zip(parsed_right.core).each do |left_part, right_part|
        comparison = VersionComparison.compare_numbers(left_part, right_part)
        return comparison unless comparison.zero?
      end

      comparison = parsed_left.stability <=> parsed_right.stability
      return comparison unless comparison.zero?

      compare_numbers(parsed_left.number, parsed_right.number)
    end

    def parse(value)
      match = PATTERN.match(value.to_s.strip)
      return nil unless match

      core = match[1].split(".")
      core << "0" while core.length < 4
      qualifier = match[2]&.downcase
      stability = qualifier ? STABILITIES[qualifier] : 4
      return nil unless stability

      Parsed.new(core.freeze, stability, match[3].to_s)
    end

    def branch?(value)
      string = value.to_s.strip
      (string.downcase.start_with?("dev-") && string.length > 4) || string.match?(NUMERIC_BRANCH_PATTERN)
    end

    def valid?(value)
      string = value.to_s.strip
      !string.empty? && !string.match?(/[[:space:]]/) && (!parse(string).nil? || branch?(string))
    end

    def normalize(value, implicit_stability: nil)
      string = value.to_s.strip
      return string if branch?(string)

      match = PATTERN.match(string.sub(/\Av(?=\d)/i, ""))
      raise ArgumentError, "Invalid Composer version: #{value}" unless match

      core = match[1].split(".").map { |part| VersionComparison.normalize_number(part) }
      core << "0" while core.length < 3
      qualifier = match[2]&.downcase || implicit_stability
      qualifier = {"a" => "alpha", "b" => "beta", "rc" => "RC", "p" => "patch", "pl" => "patch"}.fetch(qualifier, qualifier)
      return core.join(".") if qualifier.nil? || qualifier == "stable"

      "#{core.join(".")}-#{qualifier}#{match[3]}"
    end

    def release_parts(value)
      match = PATTERN.match(value.to_s.strip.sub(/\Av(?=\d)/i, ""))
      return nil unless match

      match[1].split(".")
    end

    def explicit_stability?(value)
      match = PATTERN.match(value.to_s.strip.sub(/\Av(?=\d)/i, ""))
      match && !match[2].nil?
    end

    def prerelease?(value)
      return true if branch?(value)

      parsed = parse(value)
      parsed && parsed.stability < STABILITIES.fetch("stable")
    end

    def compare_numbers(left, right)
      left_parts = left.split(/[.-]/)
      right_parts = right.split(/[.-]/)

      [left_parts.length, right_parts.length].max.times do |index|
        comparison = VersionComparison.compare_numbers(left_parts[index], right_parts[index])
        return comparison unless comparison.zero?
      end

      0
    end
  end
end
