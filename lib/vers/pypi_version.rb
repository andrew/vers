# frozen_string_literal: true

require_relative "version_comparison"

module Vers
  module PyPIVersion
    extend self

    PATTERN = /\A\s*v?
      (?:(\d+)!)?
      (\d+(?:\.\d+)*)
      (?:[-_.]?(alpha|beta|preview|pre|rc|a|b|c)[-_.]?(\d*))?
      (?:(?:[-_.]?(post|rev|r)[-_.]?(\d*))|(?:-(\d+)))?
      (?:[-_.]?(dev)[-_.]?(\d*))?
      (?:\+([a-z0-9]+(?:[-_.][a-z0-9]+)*))?
      \s*\z/ix

    PRE_TAGS = {
      "a" => 0,
      "alpha" => 0,
      "b" => 1,
      "beta" => 1,
      "c" => 2,
      "rc" => 2,
      "pre" => 2,
      "preview" => 2
    }.freeze

    LocalPart = Data.define(:value, :numeric)
    Parsed = Data.define(
      :epoch,
      :release,
      :pre_tag,
      :pre_number,
      :post_number,
      :dev_number,
      :local
    )

    def compare(left, right)
      parsed_left = parse(left)
      parsed_right = parse(right)
      return Version.compare(left, right) unless parsed_left && parsed_right

      comparison = VersionComparison.compare_numbers(parsed_left.epoch, parsed_right.epoch)
      return comparison unless comparison.zero?

      comparison = compare_release(parsed_left.release, parsed_right.release)
      return comparison unless comparison.zero?

      comparison = compare_pre(parsed_left, parsed_right)
      return comparison unless comparison.zero?

      comparison = compare_post(parsed_left, parsed_right)
      return comparison unless comparison.zero?

      comparison = compare_dev(parsed_left, parsed_right)
      return comparison unless comparison.zero?

      compare_local(parsed_left.local, parsed_right.local)
    end

    def parse(value)
      match = PATTERN.match(value.to_s)
      return nil unless match

      pre_tag = match[3]&.downcase
      post_number = match[7] || (match[5] ? match[6] : nil)
      local = if match[10]
                match[10].downcase.split(/[._-]/).map do |part|
                  LocalPart.new(part, VersionComparison.numeric?(part))
                end
              else
                []
              end

      Parsed.new(
        match[1].to_s,
        match[2].split("."),
        pre_tag && PRE_TAGS.fetch(pre_tag),
        pre_tag ? match[4].to_s : nil,
        post_number,
        match[8] ? match[9].to_s : nil,
        local.freeze
      )
    end

    def valid?(value)
      !parse(value).nil?
    end

    def prerelease?(value)
      parsed = parse(value)
      parsed && (!parsed.pre_tag.nil? || !parsed.dev_number.nil?)
    end

    def stable?(value)
      parsed = parse(value)
      parsed && parsed.pre_tag.nil? && parsed.dev_number.nil?
    end

    def normalize(value)
      parsed = parse(value)
      raise ArgumentError, "invalid pypi version: #{value}" unless parsed

      result = +""
      result << "#{VersionComparison.normalize_number(parsed.epoch)}!" unless VersionComparison.compare_numbers(parsed.epoch, "0").zero?
      result << parsed.release.map { |part| VersionComparison.normalize_number(part) }.join(".")

      unless parsed.pre_tag.nil?
        result << %w[a b rc].fetch(parsed.pre_tag)
        result << VersionComparison.normalize_number(parsed.pre_number)
      end
      result << ".post#{VersionComparison.normalize_number(parsed.post_number)}" unless parsed.post_number.nil?
      result << ".dev#{VersionComparison.normalize_number(parsed.dev_number)}" unless parsed.dev_number.nil?

      if parsed.local.any?
        result << "+"
        result << parsed.local.map { |part| part.numeric ? VersionComparison.normalize_number(part.value) : part.value }.join(".")
      end

      result
    end

    def specifier_equal?(version, specifier)
      parsed_version = parse(version)
      parsed_specifier = parse(specifier)
      return compare(version, specifier).zero? unless parsed_version && parsed_specifier
      versions_equal?(parsed_version, parsed_specifier, ignore_local: parsed_specifier.local.empty?)
    end

    def versions_equal?(left, right, ignore_local: false)
      local_equal = ignore_local || compare_local(left.local, right.local).zero?
      VersionComparison.compare_numbers(left.epoch, right.epoch).zero? &&
        compare_release(left.release, right.release).zero? &&
        compare_pre(left, right).zero? &&
        compare_post(left, right).zero? &&
        compare_dev(left, right).zero? &&
        local_equal
    end

    def same_release?(left, right)
      VersionComparison.compare_numbers(left.epoch, right.epoch).zero? &&
        compare_release(left.release, right.release).zero?
    end

    def without_post_and_dev(version)
      Parsed.new(
        version.epoch,
        version.release,
        version.pre_tag,
        version.pre_number,
        nil,
        nil,
        [].freeze
      )
    end

    def without_dev(version)
      Parsed.new(
        version.epoch,
        version.release,
        version.pre_tag,
        version.pre_number,
        version.post_number,
        nil,
        [].freeze
      )
    end

    def compare_release(left, right)
      [left.length, right.length].max.times do |index|
        comparison = VersionComparison.compare_numbers(left[index], right[index])
        return comparison unless comparison.zero?
      end

      0
    end

    def compare_pre(left, right)
      left_rank = pre_rank(left)
      right_rank = pre_rank(right)
      comparison = left_rank <=> right_rank
      return comparison unless comparison.zero?
      return 0 if left.pre_tag.nil?

      comparison = left.pre_tag <=> right.pre_tag
      return comparison unless comparison.zero?

      VersionComparison.compare_numbers(left.pre_number, right.pre_number)
    end

    def pre_rank(version)
      return -1 if version.pre_tag.nil? && version.post_number.nil? && !version.dev_number.nil?
      return 1 if version.pre_tag.nil?

      0
    end

    def compare_post(left, right)
      return 1 if !left.post_number.nil? && right.post_number.nil?
      return -1 if left.post_number.nil? && !right.post_number.nil?
      return 0 if left.post_number.nil?

      VersionComparison.compare_numbers(left.post_number, right.post_number)
    end

    def compare_dev(left, right)
      return -1 if !left.dev_number.nil? && right.dev_number.nil?
      return 1 if left.dev_number.nil? && !right.dev_number.nil?
      return 0 if left.dev_number.nil?

      VersionComparison.compare_numbers(left.dev_number, right.dev_number)
    end

    def compare_local(left, right)
      return 0 if left.empty? && right.empty?
      return -1 if left.empty?
      return 1 if right.empty?

      [left.length, right.length].max.times do |index|
        return -1 unless left[index]
        return 1 unless right[index]

        left_part = left[index]
        right_part = right[index]
        if left_part.numeric != right_part.numeric
          return left_part.numeric ? 1 : -1
        end

        comparison = if left_part.numeric
                       VersionComparison.compare_numbers(left_part.value, right_part.value)
                     else
                       left_part.value <=> right_part.value
                     end
        return comparison unless comparison.zero?
      end

      0
    end
  end
end
