# frozen_string_literal: true

require "time"
require_relative "version_comparison"

module Vers
  module APKVersion
    extend self

    TOKEN_INITIAL_DIGIT = 0
    TOKEN_DIGIT = 1
    TOKEN_LETTER = 2
    TOKEN_SUFFIX = 3
    TOKEN_SUFFIX_NUMBER = 4
    TOKEN_COMMIT_HASH = 5
    TOKEN_REVISION_NUMBER = 6
    TOKEN_END = 7
    TOKEN_INVALID = 8
    SUFFIXES = {
      "alpha" => 1,
      "beta" => 2,
      "pre" => 3,
      "rc" => 4,
      "cvs" => 6,
      "svn" => 7,
      "git" => 8,
      "hg" => 9,
      "p" => 10
    }.freeze
    SUFFIX_NONE = 5
    UINT64_MASK = (1 << 64) - 1

    def compare(left, right)
      left_tokens = parse(left)
      right_tokens = parse(right)

      index = 0
      while token_type(left_tokens, index) == token_type(right_tokens, index) && token_type(left_tokens, index) < TOKEN_END
        comparison = compare_token(left_tokens.fetch(index), right_tokens.fetch(index))
        return comparison unless comparison.zero?

        index += 1
      end

      left_type = token_type(left_tokens, index)
      right_type = token_type(right_tokens, index)
      return 0 if left_type == right_type

      left_token = left_tokens[index]
      right_token = right_tokens[index]
      return -1 if left_type == TOKEN_SUFFIX && left_token.fetch(1) < SUFFIX_NONE
      return 1 if right_type == TOKEN_SUFFIX && right_token.fetch(1) < SUFFIX_NONE
      return -1 if left_type > right_type
      return 1 if right_type > left_type

      0
    end

    def valid?(value)
      parse(value.to_s.strip).none? { |type, _value| type == TOKEN_INVALID }
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      tokens = parse(value.to_s.strip)
      return false if tokens.any? { |type, _value| type == TOKEN_INVALID }

      tokens.any? { |type, suffix| type == TOKEN_SUFFIX && suffix < SUFFIX_NONE }
    end

    def parse(value)
      string = value.to_s.strip
      tokens = []
      first, index = scan_digits(string, 0)
      return invalid_tokens(tokens) if first.empty?

      tokens << [TOKEN_INITIAL_DIGIT, first]
      previous = TOKEN_INITIAL_DIGIT

      while index < string.length
        byte = string.getbyte(index)
        case byte
        when 97..122
          return invalid_tokens(tokens) if previous > TOKEN_DIGIT

          tokens << [TOKEN_LETTER, byte]
          previous = TOKEN_LETTER
          index += 1
        when 46
          return invalid_tokens(tokens) if previous > TOKEN_DIGIT

          digits, index = scan_digits(string, index + 1)
          return invalid_tokens(tokens) if digits.empty?

          tokens << [TOKEN_DIGIT, digits]
          previous = TOKEN_DIGIT
        when 48..57
          type = if previous == TOKEN_INITIAL_DIGIT || previous == TOKEN_DIGIT
                   TOKEN_DIGIT
                 elsif previous == TOKEN_SUFFIX
                   TOKEN_SUFFIX_NUMBER
                 end
          return invalid_tokens(tokens) unless type

          digits, index = scan_digits(string, index)
          tokens << [type, digits]
          previous = type
        when 95
          return invalid_tokens(tokens) if previous > TOKEN_SUFFIX_NUMBER

          suffix, index = scan_lowercase(string, index + 1)
          rank = SUFFIXES[suffix]
          return invalid_tokens(tokens) unless rank

          tokens << [TOKEN_SUFFIX, rank]
          previous = TOKEN_SUFFIX
        when 126
          return invalid_tokens(tokens) if previous >= TOKEN_COMMIT_HASH

          commit, index = scan_hex(string, index + 1)
          return invalid_tokens(tokens) if commit.empty?

          tokens << [TOKEN_COMMIT_HASH, commit]
          previous = TOKEN_COMMIT_HASH
        when 45
          if previous >= TOKEN_REVISION_NUMBER || string[index, 2] != "-r"
            return invalid_tokens(tokens)
          end

          revision, index = scan_digits(string, index + 2)
          return invalid_tokens(tokens) if revision.empty?

          tokens << [TOKEN_REVISION_NUMBER, revision]
          previous = TOKEN_REVISION_NUMBER
        else
          return invalid_tokens(tokens)
        end
      end

      tokens
    end

    def invalid_tokens(tokens)
      tokens << [TOKEN_INVALID, nil]
    end

    def compare_token(left, right)
      type = left.fetch(0)
      left_value = left.fetch(1)
      right_value = right.fetch(1)

      case type
      when TOKEN_DIGIT
        return left_value <=> right_value if left_value.start_with?("0") || right_value.start_with?("0")

        uint64(left_value) <=> uint64(right_value)
      when TOKEN_INITIAL_DIGIT, TOKEN_SUFFIX_NUMBER, TOKEN_REVISION_NUMBER
        uint64(left_value) <=> uint64(right_value)
      else
        left_value <=> right_value
      end
    end

    def token_type(tokens, index)
      tokens[index]&.fetch(0) || TOKEN_END
    end

    def uint64(value)
      value.each_byte.reduce(0) { |number, byte| ((number * 10) + byte - 48) & UINT64_MASK }
    end

    def scan_digits(value, index)
      ending = index
      ending += 1 while ending < value.length && value.getbyte(ending).between?(48, 57)
      [value[index...ending], ending]
    end

    def scan_lowercase(value, index)
      ending = index
      ending += 1 while ending < value.length && value.getbyte(ending).between?(97, 122)
      [value[index...ending], ending]
    end

    def scan_hex(value, index)
      ending = index
      while ending < value.length
        byte = value.getbyte(ending)
        break unless byte.between?(48, 57) || byte.between?(65, 70) || byte.between?(97, 102)

        ending += 1
      end
      [value[index...ending], ending]
    end
  end

  module OpenSSLVersion
    extend self

    Parsed = Data.define(:core, :patch)

    def compare(left, right)
      parsed_left = parse(left)
      parsed_right = parse(right)
      return Version.compare(left, right) unless parsed_left && parsed_right
      return SemverVersion.compare(left, right) if version_three_or_newer?(parsed_left, parsed_right)

      parsed_left.core.zip(parsed_right.core).each do |left_part, right_part|
        comparison = VersionComparison.compare_numbers(left_part, right_part)
        return comparison unless comparison.zero?
      end

      left_prerelease = prerelease_patch?(parsed_left.patch)
      right_prerelease = prerelease_patch?(parsed_right.patch)
      return -1 if left_prerelease && !right_prerelease
      return 1 if !left_prerelease && right_prerelease

      parsed_left.patch <=> parsed_right.patch
    end

    def parse(value)
      parts = value.to_s.split(".", 3)
      return nil unless parts.length == 3
      return nil unless parts[0].match?(/\A\d+\z/) && parts[1].match?(/\A\d+\z/)

      match = /\A(\d+)(.*)\z/.match(parts[2])
      return nil unless match

      Parsed.new([parts[0], parts[1], match[1]].freeze, match[2])
    end

    def version_three_or_newer?(left, right)
      VersionComparison.compare_numbers(left.core[0], "3") >= 0 &&
        VersionComparison.compare_numbers(right.core[0], "3") >= 0
    end

    def prerelease_patch?(patch)
      patch.start_with?("-alpha", "-beta")
    end

    def valid?(value)
      !parse(value.to_s.strip).nil?
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      parsed = parse(value.to_s.strip)
      return false unless parsed

      if VersionComparison.compare_numbers(parsed.core[0], "3") >= 0
        parsed.patch.start_with?("-")
      else
        prerelease_patch?(parsed.patch)
      end
    end
  end

  module DatetimeVersion
    extend self

    def compare(left, right)
      Time.iso8601(left) <=> Time.iso8601(right)
    rescue ArgumentError
      left <=> right
    end

    def valid?(value)
      Time.iso8601(value.to_s.strip)
      value.to_s.strip.match?(/T/) && !value.to_s.strip.match?(/[[:space:]]/)
    rescue ArgumentError
      false
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(_value)
      false
    end
  end

  module IntDotVersion
    extend self

    def compare(left, right)
      left_parts = left.to_s[/\A[\d.]*/].split(".", -1)
      right_parts = right.to_s[/\A[\d.]*/].split(".", -1)

      [left_parts.length, right_parts.length].max.times do |index|
        comparison = VersionComparison.compare_numbers(left_parts[index], right_parts[index])
        return comparison unless comparison.zero?
      end

      0
    end

    def valid?(value)
      value.to_s.strip.match?(/\A\d+(?:\.\d+)*\z/)
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(_value)
      false
    end
  end

  module LexicographicVersion
    extend self

    def compare(left, right)
      left <=> right
    end

    def valid?(value)
      string = value.to_s.strip
      !string.empty? && !string.match?(/[[:space:]]/)
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(_value)
      false
    end
  end
end
