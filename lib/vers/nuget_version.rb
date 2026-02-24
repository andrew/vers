# frozen_string_literal: true

module Vers
  module NuGetVersion
    module_function

    def compare(a, b)
      return 0 if a == b

      parts_a = parse_nuget(a)
      parts_b = parse_nuget(b)

      4.times do |i|
        cmp = parts_a[:numeric][i] <=> parts_b[:numeric][i]
        return cmp unless cmp == 0
      end

      pre_a = parts_a[:prerelease]
      pre_b = parts_b[:prerelease]

      return 1 if pre_a.empty? && !pre_b.empty?
      return -1 if !pre_a.empty? && pre_b.empty?
      return 0 if pre_a.empty? && pre_b.empty?

      compare_prerelease(pre_a, pre_b)
    end

    def parse_nuget(s)
      s = s.dup

      if (idx = s.index("+"))
        s = s[0...idx]
      end

      prerelease = ""
      if (idx = s.index("-"))
        prerelease = s[(idx + 1)..]
        s = s[0...idx]
      end

      numeric = [0, 0, 0, 0]
      parts = s.split(".")
      parts.each_with_index do |part, i|
        break if i >= 4
        numeric[i] = part.to_i
      end

      { numeric: numeric, prerelease: prerelease }
    end

    def compare_prerelease(a, b)
      parts_a = a.downcase.split(".")
      parts_b = b.downcase.split(".")

      max_len = [parts_a.length, parts_b.length].max

      max_len.times do |i|
        part_a = i < parts_a.length ? parts_a[i] : nil
        part_b = i < parts_b.length ? parts_b[i] : nil

        return -1 if part_a.nil?
        return 1 if part_b.nil?

        num_a = part_a.match?(/\A\d+\z/) ? part_a.to_i : nil
        num_b = part_b.match?(/\A\d+\z/) ? part_b.to_i : nil

        if num_a && num_b
          cmp = num_a <=> num_b
          return cmp unless cmp == 0
        else
          cmp = part_a <=> part_b
          return cmp unless cmp == 0
        end
      end

      0
    end
  end
end
