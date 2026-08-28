# frozen_string_literal: true

require_relative "version_comparison"

module Vers
  module DebianVersion
    extend self

    UPSTREAM_PATTERN = /\A[0-9][0-9A-Za-z.+~]*\z/
    REVISION_PATTERN = /\A[0-9A-Za-z.+~]+\z/

    def compare(left, right)
      left_epoch, left_upstream, left_revision = split(left)
      right_epoch, right_upstream, right_revision = split(right)

      comparison = VersionComparison.compare_numbers(left_epoch, right_epoch)
      return comparison unless comparison.zero?

      comparison = compare_part(left_upstream, right_upstream)
      return comparison unless comparison.zero?

      compare_part(left_revision, right_revision)
    end

    def split(value)
      epoch, version = value.to_s.split(":", 2)
      unless version
        version = epoch
        epoch = ""
      end

      separator = version.rindex("-")
      if separator
        [epoch, version[0...separator], version[(separator + 1)..]]
      else
        [epoch, version, "0"]
      end
    end

    def valid?(value)
      string = value.to_s.strip
      epoch, version = string.split(":", 2)
      if version
        return false unless VersionComparison.numeric?(epoch)
      else
        version = epoch
      end

      separator = version.rindex("-")
      upstream = separator ? version[0...separator] : version
      revision = separator ? version[(separator + 1)..] : nil
      upstream.match?(UPSTREAM_PATTERN) && (revision.nil? || revision.match?(REVISION_PATTERN))
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      _, upstream, revision = split(value.to_s.strip)
      upstream.include?("~") || revision.include?("~")
    end

    def compare_part(left, right)
      left_index = 0
      right_index = 0

      while left_index < left.length || right_index < right.length
        while non_digit_at?(left, left_index) || non_digit_at?(right, right_index)
          left_byte = non_digit_at?(left, left_index) ? left.getbyte(left_index) : 0
          right_byte = non_digit_at?(right, right_index) ? right.getbyte(right_index) : 0
          comparison = character_order(left_byte) <=> character_order(right_byte)
          return comparison unless comparison.zero?

          left_index += 1 unless left_byte.zero?
          right_index += 1 unless right_byte.zero?
        end

        left_zero_end = skip_zeroes(left, left_index)
        right_zero_end = skip_zeroes(right, right_index)
        left_digit_end = scan_digits(left, left_zero_end)
        right_digit_end = scan_digits(right, right_zero_end)

        comparison = (left_digit_end - left_zero_end) <=> (right_digit_end - right_zero_end)
        return comparison unless comparison.zero?

        comparison = left[left_zero_end...left_digit_end] <=> right[right_zero_end...right_digit_end]
        return comparison unless comparison.zero?

        left_index = left_digit_end
        right_index = right_digit_end
      end

      0
    end

    def non_digit_at?(value, index)
      index < value.length && !digit?(value.getbyte(index))
    end

    def skip_zeroes(value, index)
      index += 1 while index < value.length && value.getbyte(index) == 48
      index
    end

    def scan_digits(value, index)
      index += 1 while index < value.length && digit?(value.getbyte(index))
      index
    end

    def character_order(byte)
      return -1 if byte == 126
      return 0 if byte.zero?
      return byte if alpha?(byte)

      byte + 256
    end

    def digit?(byte)
      byte&.between?(48, 57)
    end

    def alpha?(byte)
      byte&.between?(65, 90) || byte&.between?(97, 122)
    end
  end

  module RPMVersion
    extend self

    PART_PATTERN = /\A[0-9A-Za-z._+~^]+\z/

    def compare(left, right)
      left_epoch, left_version, left_release = split(left)
      right_epoch, right_version, right_release = split(right)

      comparison = VersionComparison.compare_numbers(left_epoch, right_epoch)
      return comparison unless comparison.zero?

      comparison = compare_part(left_version, right_version)
      return comparison unless comparison.zero?

      compare_part(left_release, right_release)
    end

    def split(value)
      epoch, version = value.to_s.split(":", 2)
      unless version
        version = epoch
        epoch = ""
      end

      separator = version.rindex("-")
      return [epoch, version, ""] unless separator

      [epoch, version[0...separator], version[(separator + 1)..]]
    end

    def valid?(value)
      string = value.to_s.strip
      return false if string.empty? || string.end_with?("-")

      epoch, version, release = split(string)
      return false unless epoch.empty? || VersionComparison.numeric?(epoch)

      version.match?(PART_PATTERN) && (release.empty? || release.match?(PART_PATTERN))
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      _, version, release = split(value.to_s.strip)
      version.include?("~") || release.include?("~")
    end

    def compare_part(left, right)
      left_index = 0
      right_index = 0

      while left_index < left.length || right_index < right.length
        left_index = skip_separators(left, left_index)
        right_index = skip_separators(right, right_index)

        if marker_at?(left, left_index, 126) || marker_at?(right, right_index, 126)
          return 1 unless marker_at?(left, left_index, 126)
          return -1 unless marker_at?(right, right_index, 126)

          left_index += 1
          right_index += 1
          next
        end

        if marker_at?(left, left_index, 94) || marker_at?(right, right_index, 94)
          return -1 if left_index >= left.length
          return 1 if right_index >= right.length
          return 1 unless marker_at?(left, left_index, 94)
          return -1 unless marker_at?(right, right_index, 94)

          left_index += 1
          right_index += 1
          next
        end

        return (left.length - left_index) <=> (right.length - right_index) if left_index >= left.length || right_index >= right.length

        left_numeric = digit?(left.getbyte(left_index))
        right_numeric = digit?(right.getbyte(right_index))
        return left_numeric ? 1 : -1 if left_numeric != right_numeric

        left_end = scan_segment(left, left_index, left_numeric)
        right_end = scan_segment(right, right_index, right_numeric)
        comparison = if left_numeric
                       VersionComparison.compare_numbers(left[left_index...left_end], right[right_index...right_end])
                     else
                       left[left_index...left_end] <=> right[right_index...right_end]
                     end
        return comparison unless comparison.zero?

        left_index = left_end
        right_index = right_end
      end

      0
    end

    def skip_separators(value, index)
      while index < value.length
        byte = value.getbyte(index)
        break if alphanumeric?(byte) || byte == 126 || byte == 94

        index += 1
      end
      index
    end

    def marker_at?(value, index, marker)
      index < value.length && value.getbyte(index) == marker
    end

    def scan_segment(value, index, numeric)
      if numeric
        index += 1 while index < value.length && digit?(value.getbyte(index))
      else
        index += 1 while index < value.length && alpha?(value.getbyte(index))
      end
      index
    end

    def digit?(byte)
      byte&.between?(48, 57)
    end

    def alpha?(byte)
      byte&.between?(65, 90) || byte&.between?(97, 122)
    end

    def alphanumeric?(byte)
      digit?(byte) || alpha?(byte)
    end
  end

  module ALPMVersion
    extend self

    def compare(left, right)
      left_epoch, left_version, left_release, left_has_release = split(left)
      right_epoch, right_version, right_release, right_has_release = split(right)

      comparison = compare_part(left_epoch, right_epoch)
      return comparison unless comparison.zero?

      comparison = compare_part(left_version, right_version)
      return comparison unless comparison.zero?

      return compare_part(left_release, right_release) if left_has_release && right_has_release

      0
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

    def split(value)
      epoch, version = value.to_s.split(":", 2)
      unless version
        version = epoch
        epoch = "0"
      end

      separator = version.rindex("-")
      return [epoch, version, "", false] unless separator

      [epoch, version[0...separator], version[(separator + 1)..], true]
    end

    def compare_part(left, right)
      left_segments = segments(left)
      right_segments = segments(right)

      [left_segments.length, right_segments.length].max.times do |index|
        left_segment = left_segments[index]
        right_segment = right_segments[index]
        return 0 unless left_segment || right_segment
        return right_segment[0] == :alpha ? 1 : -1 unless left_segment
        return left_segment[0] == :alpha ? -1 : 1 unless right_segment

        left_kind, left_value = left_segment
        right_kind, right_value = right_segment
        if left_kind != right_kind
          return 1 if left_kind == :digit
          return -1 if right_kind == :digit
          return 1 if left_kind == :other
          return -1
        end

        comparison = case left_kind
                     when :digit
                       VersionComparison.compare_numbers(left_value, right_value)
                     when :alpha
                       left_value <=> right_value
                     else
                       left_value.length <=> right_value.length
                     end
        return comparison unless comparison.zero?
      end

      0
    end

    def segments(value)
      result = []
      index = 0
      while index < value.length
        kind = segment_kind(value.getbyte(index))
        ending = index + 1
        ending += 1 while ending < value.length && segment_kind(value.getbyte(ending)) == kind
        result << [kind, value[index...ending]]
        index = ending
      end
      result
    end

    def segment_kind(byte)
      return :digit if byte.between?(48, 57)
      return :alpha if byte.between?(65, 90) || byte.between?(97, 122)

      :other
    end
  end

  module GentooVersion
    extend self

    PATTERN = /\A\d+(?:\.\d+)*[A-Za-z]?(?:_(?:p(?:re)?|beta|alpha|rc)\d*)*(?:-r\d+)?\z/

    SUFFIX_RANKS = {
      "alpha" => -4,
      "beta" => -3,
      "pre" => -2,
      "rc" => -1,
      "p" => 1
    }.freeze

    def compare(left, right)
      left_version, left_revision = split_revision(left)
      right_version, right_revision = split_revision(right)
      return VersionComparison.compare_numbers(left_revision, right_revision) if left_version == right_version

      left_base, left_suffixes = split_base(left_version)
      right_base, right_suffixes = split_base(right_version)
      comparison = compare_base(left_base, right_base)
      return comparison unless comparison.zero?

      comparison = compare_suffixes(left_suffixes, right_suffixes)
      return comparison unless comparison.zero?

      VersionComparison.compare_numbers(left_revision, right_revision)
    end

    def valid?(value)
      value.to_s.strip.match?(PATTERN)
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      version, = split_revision(value.to_s.strip)
      _, suffixes = split_base(version)
      suffixes&.any? { |suffix| SUFFIX_RANKS.fetch(parse_suffix(suffix).first, 0).negative? } || false
    end

    def split_revision(value)
      match = /-r(\d+)\z/.match(value.to_s)
      match ? [value[0...match.begin(0)], match[1]] : [value.to_s, ""]
    end

    def split_base(value)
      base, suffixes = value.split("_", 2)
      [base, suffixes&.split("_", -1)]
    end

    def compare_base(left, right)
      left_value, left_letter = split_letter(left)
      right_value, right_letter = split_letter(right)
      left_parts = left_value.split(".", -1)
      right_parts = right_value.split(".", -1)

      [left_parts.length, right_parts.length].min.times do |index|
        comparison = compare_component(index, left_parts[index], right_parts[index])
        return comparison unless comparison.zero?
      end

      comparison = left_parts.length <=> right_parts.length
      return comparison unless comparison.zero?

      left_letter <=> right_letter
    end

    def split_letter(value)
      return [value[0...-1], value.getbyte(-1)] if value.match?(/[A-Za-z]\z/)

      [value, -1]
    end

    def compare_component(index, left, right)
      return 0 if left == right
      return VersionComparison.compare_numbers(left, right) if index.zero? || (!left.start_with?("0") && !right.start_with?("0"))

      left.sub(/0+\z/, "") <=> right.sub(/0+\z/, "")
    end

    def compare_suffixes(left, right)
      index = 0
      loop do
        return 0 unless left || right

        unless left
          kind, number = parse_suffix(right[index])
          rank = SUFFIX_RANKS.fetch(kind, 0)
          return 0 <=> rank unless rank.zero?
          return VersionComparison.compare_numbers("0", number)
        end
        unless right
          kind, number = parse_suffix(left[index])
          rank = SUFFIX_RANKS.fetch(kind, 0)
          return rank <=> 0 unless rank.zero?
          return VersionComparison.compare_numbers(number, "0")
        end

        left_suffix = left[index]
        right_suffix = right[index]
        return 0 unless left_suffix || right_suffix
        unless left_suffix
          kind, number = parse_suffix(right_suffix)
          rank = SUFFIX_RANKS.fetch(kind, 0)
          return 0 <=> rank unless rank.zero?
          return VersionComparison.compare_numbers("0", number)
        end
        unless right_suffix
          kind, number = parse_suffix(left_suffix)
          rank = SUFFIX_RANKS.fetch(kind, 0)
          return rank <=> 0 unless rank.zero?
          return VersionComparison.compare_numbers(number, "0")
        end

        left_kind, left_number = parse_suffix(left_suffix)
        right_kind, right_number = parse_suffix(right_suffix)
        comparison = SUFFIX_RANKS.fetch(left_kind, 0) <=> SUFFIX_RANKS.fetch(right_kind, 0)
        return comparison unless comparison.zero?

        comparison = VersionComparison.compare_numbers(left_number, right_number)
        return comparison unless comparison.zero?

        index += 1
      end
    end

    def parse_suffix(value)
      match = /(\d*)\z/.match(value.to_s)
      [value.to_s[0...match.begin(0)], match[1]]
    end
  end
end
