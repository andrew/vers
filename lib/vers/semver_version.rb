# frozen_string_literal: true

require_relative "version_comparison"

module Vers
  module SemverVersion
    extend self

    Parsed = Data.define(:core, :prerelease, :build)

    def compare(left, right)
      parsed_left = parse(left)
      parsed_right = parse(right)
      return left <=> right unless parsed_left && parsed_right

      parsed_left.core.zip(parsed_right.core).each do |left_part, right_part|
        comparison = VersionComparison.compare_numbers(left_part, right_part)
        return comparison unless comparison.zero?
      end

      compare_prerelease(parsed_left.prerelease, parsed_right.prerelease)
    end

    def parse(value)
      string = value.to_s.strip
      index = string.start_with?("v") ? 1 : 0
      core = []

      3.times do |part|
        start = index
        index += 1 while index < string.length && string.getbyte(index).between?(48, 57)
        return nil if index == start

        core << string[start...index]
        break unless index < string.length && string.getbyte(index) == 46
        return nil if part == 2

        index += 1
      end

      core << "0" while core.length < 3
      prerelease = ""
      build = ""

      if index < string.length && string.getbyte(index) == 45
        start = index + 1
        index = start
        index += 1 while index < string.length && string.getbyte(index) != 43
        return nil if index == start

        prerelease = string[start...index]
      end

      if index < string.length && string.getbyte(index) == 43
        index += 1
        return nil if index == string.length || string[index..].include?("\n")

        build = string[index..]
        index = string.length
      end

      return nil unless index == string.length

      Parsed.new(core.freeze, prerelease, build)
    end

    def valid?(value)
      parsed = parse(value.to_s.strip)
      return false unless parsed

      [parsed.prerelease, parsed.build].all? do |field|
        field.empty? || field.split(".", -1).all? { |part| part.match?(/\A[0-9A-Za-z-]+\z/) }
      end
    end

    def normalize(value, preserve_v: false)
      string = value.to_s.strip
      parsed = parse(string)
      raise ArgumentError, "Invalid semantic version: #{value}" unless parsed && valid?(string)

      result = parsed.core.map { |part| VersionComparison.normalize_number(part) }.join(".")
      result = "v#{result}" if preserve_v && string.start_with?("v")
      unless parsed.prerelease.empty?
        prerelease = parsed.prerelease.split(".").map do |part|
          VersionComparison.numeric?(part) ? VersionComparison.normalize_number(part) : part
        end
        result += "-#{prerelease.join(".")}"
      end
      result += "+#{parsed.build}" unless parsed.build.empty?
      result
    end

    def prerelease?(value)
      parsed = parse(value.to_s.strip)
      parsed && !parsed.prerelease.empty?
    end

    def compare_prerelease(left, right)
      return 0 if left.empty? && right.empty?
      return 1 if left.empty?
      return -1 if right.empty?

      left_parts = left.split(".", -1)
      right_parts = right.split(".", -1)
      left_parts.zip(right_parts).each do |left_part, right_part|
        return 1 if right_part.nil?

        comparison = compare_identifier(left_part, right_part)
        return comparison unless comparison.zero?
      end

      left_parts.length <=> right_parts.length
    end

    def compare_identifier(left, right)
      left_numeric = VersionComparison.numeric?(left)
      right_numeric = VersionComparison.numeric?(right)
      return -1 if left_numeric && !right_numeric
      return 1 if !left_numeric && right_numeric

      if left_numeric
        VersionComparison.compare_numbers(left, right)
      else
        left <=> right
      end
    end
  end

  module NpmVersion
    extend self

    def compare(left, right)
      SemverVersion.compare(left.strip, right.strip)
    end

    def valid?(value)
      SemverVersion.valid?(value.to_s.strip)
    end

    def normalize(value)
      SemverVersion.normalize(value.to_s.strip)
    end

    def prerelease?(value)
      SemverVersion.prerelease?(value.to_s.strip)
    end
  end

  module CargoVersion
    extend self

    def compare(left, right)
      comparison = SemverVersion.compare(left, right)
      return comparison unless comparison.zero?

      parsed_left = SemverVersion.parse(left)
      parsed_right = SemverVersion.parse(right)
      return comparison unless parsed_left && parsed_right

      compare_build(parsed_left.build, parsed_right.build)
    end

    def compare_build(left, right)
      return 0 if left == right
      return -1 if left.empty?
      return 1 if right.empty?

      left_parts = left.split(".", -1)
      right_parts = right.split(".", -1)
      left_parts.zip(right_parts).each do |left_part, right_part|
        return 1 if right_part.nil?

        comparison = compare_build_identifier(left_part, right_part)
        return comparison unless comparison.zero?
      end

      left_parts.length <=> right_parts.length
    end

    def compare_build_identifier(left, right)
      left_numeric = VersionComparison.numeric?(left)
      right_numeric = VersionComparison.numeric?(right)
      return -1 if left_numeric && !right_numeric
      return 1 if !left_numeric && right_numeric
      return left <=> right unless left_numeric

      normalized_left = VersionComparison.normalize_number(left)
      normalized_right = VersionComparison.normalize_number(right)
      comparison = normalized_left.length <=> normalized_right.length
      return comparison unless comparison.zero?

      comparison = normalized_left <=> normalized_right
      return comparison unless comparison.zero?

      left.length <=> right.length
    end

    def valid?(value)
      SemverVersion.valid?(value.to_s.strip)
    end

    def normalize(value)
      SemverVersion.normalize(value.to_s.strip)
    end

    def prerelease?(value)
      SemverVersion.prerelease?(value.to_s.strip)
    end
  end

  module GoVersion
    extend self

    def compare(left, right)
      return SemverVersion.compare(left, right) unless left.start_with?("v") || right.start_with?("v")

      parsed_left = parse(left)
      parsed_right = parse(right)
      return 1 if parsed_left && !parsed_right
      return -1 if !parsed_left && parsed_right
      return 0 unless parsed_left && parsed_right

      parsed_left.core.zip(parsed_right.core).each do |left_part, right_part|
        comparison = VersionComparison.compare_numbers(left_part, right_part)
        return comparison unless comparison.zero?
      end

      SemverVersion.compare_prerelease(parsed_left.prerelease, parsed_right.prerelease)
    end

    def parse(value)
      return nil unless value.start_with?("v")

      string = value.delete_prefix("v")
      core_end = string.index(/[-+]/) || string.length
      core = string[0...core_end].split(".", -1)
      return nil if core.empty? || core.length > 3
      return nil unless core.all? { |part| valid_core_part?(part) }
      return nil if core.length < 3 && core_end != string.length

      core << "0" while core.length < 3
      remainder = string[core_end..]
      prerelease = ""
      build = ""

      if remainder.start_with?("-")
        value = remainder.delete_prefix("-")
        prerelease_end = value.index("+") || value.length
        prerelease = value[0...prerelease_end]
        return nil unless valid_identifiers?(prerelease, build: false)

        remainder = value[prerelease_end..]
      end

      if remainder.start_with?("+")
        build = remainder.delete_prefix("+")
        return nil unless valid_identifiers?(build, build: true)

        remainder = ""
      end

      return nil unless remainder.empty?

      SemverVersion::Parsed.new(core.freeze, prerelease, build)
    end

    def valid_core_part?(part)
      VersionComparison.numeric?(part) && (part == "0" || !part.start_with?("0"))
    end

    def valid_identifiers?(value, build:)
      return false if value.empty?

      value.split(".", -1).all? do |identifier|
        next false unless identifier.match?(/\A[0-9A-Za-z-]+\z/)

        build || identifier == "0" || !VersionComparison.numeric?(identifier) || !identifier.start_with?("0")
      end
    end

    def valid?(value)
      string = value.to_s.strip
      string.start_with?("v") ? !parse(string).nil? : SemverVersion.valid?(string)
    end

    def normalize(value)
      SemverVersion.normalize(value.to_s.strip, preserve_v: true)
    end

    def prerelease?(value)
      SemverVersion.prerelease?(value.to_s.strip)
    end
  end
end
