# frozen_string_literal: true

module Vers
  module MavenVersion
    MavenComponent = Struct.new(:is_numeric, :numeric, :qualifier, :is_null, :after_dash, keyword_init: true) do
      def initialize(is_numeric: false, numeric: 0, qualifier: "", is_null: false, after_dash: false)
        super
      end
    end

    QUALIFIER_ORDER = {
      "alpha" => 1,
      "beta" => 2,
      "milestone" => 3,
      "rc" => 4,
      "snapshot" => 5,
      "" => 6,
      "sp" => 7
    }.freeze

    UNKNOWN_QUALIFIER_ORDER = 8

    module_function

    def compare(a, b)
      return 0 if a == b

      parts_a = parse_maven_version(a)
      parts_b = parse_maven_version(b)

      max_len = [parts_a.length, parts_b.length].max

      max_len.times do |i|
        comp_a = i < parts_a.length ? parts_a[i] : MavenComponent.new(is_null: true)
        comp_b = i < parts_b.length ? parts_b[i] : MavenComponent.new(is_null: true)

        cmp = compare_components(comp_a, comp_b)
        return cmp unless cmp == 0
      end

      0
    end

    def parse_maven_version(s)
      s = s.downcase

      parts, after_dash_flags = split_with_separators(s)

      result = []
      parts.each_with_index do |part, i|
        next if part.empty?

        next_is_digit = if i + 1 < parts.length
                          parts[i + 1].match?(/\A\d+\z/)
                        else
                          false
                        end

        normalized = normalize_qualifier(part, next_is_digit)
        next if normalized.empty?

        after_dash = i < after_dash_flags.length ? after_dash_flags[i] : false

        if normalized.match?(/\A\d+\z/)
          result << MavenComponent.new(is_numeric: true, numeric: normalized.to_i, after_dash: after_dash)
        else
          result << MavenComponent.new(qualifier: normalized, after_dash: after_dash)
        end
      end

      normalize_components(result)
    end

    def split_with_separators(s)
      parts = []
      after_dash = []
      current = +""
      last_was_digit = false
      first_char = true
      current_after_dash = false

      s.each_char do |c|
        if c == "." || c == "-"
          if current.length > 0
            parts << current
            after_dash << current_after_dash
            current = +""
          end
          current_after_dash = (c == "-")
          first_char = true
          next
        end

        is_digit = c >= "0" && c <= "9"

        if !first_char && is_digit != last_was_digit && current.length > 0
          parts << current
          after_dash << current_after_dash
          current = +""
          current_after_dash = true
        end

        current << c
        last_was_digit = is_digit
        first_char = false
      end

      if current.length > 0
        parts << current
        after_dash << current_after_dash
      end

      [parts, after_dash]
    end

    def normalize_qualifier(q, next_is_digit)
      if next_is_digit && q.length == 1
        case q
        when "a" then return "alpha"
        when "b" then return "beta"
        when "m" then return "milestone"
        end
      end

      case q
      when "cr" then "rc"
      when "ga", "final", "release" then ""
      else q
      end
    end

    def normalize_components(components)
      return components if components.empty?

      first_sublist_idx = components.index { |c| c.after_dash }

      if first_sublist_idx && first_sublist_idx > 0
        base_end = first_sublist_idx
        while base_end > 1 && components[base_end - 1].is_numeric && components[base_end - 1].numeric == 0
          base_end -= 1
        end
        if base_end < first_sublist_idx
          components = components[0...base_end] + components[first_sublist_idx..]
        end
      elsif first_sublist_idx.nil?
        while components.length > 0 && components.last.is_numeric && components.last.numeric == 0
          components.pop
        end
      end

      components
    end

    def compare_components(a, b)
      return 0 if a.is_null && b.is_null

      if a.is_null
        return compare_to_null(b) * -1
      end
      if b.is_null
        return compare_to_null(a)
      end

      if a.after_dash != b.after_dash
        if a.after_dash
          return b.is_numeric ? -1 : 1
        else
          return a.is_numeric ? 1 : -1
        end
      end

      if a.is_numeric && b.is_numeric
        return a.numeric <=> b.numeric
      end

      if a.is_numeric && !b.is_numeric
        return 1
      end
      if !a.is_numeric && b.is_numeric
        return -1
      end

      order_a = qualifier_order(a.qualifier)
      order_b = qualifier_order(b.qualifier)

      if order_a != order_b
        return order_a <=> order_b
      end

      known_a = QUALIFIER_ORDER.key?(a.qualifier)
      known_b = QUALIFIER_ORDER.key?(b.qualifier)

      if !known_a && !known_b
        return a.qualifier <=> b.qualifier
      end

      0
    end

    def compare_to_null(comp)
      if comp.is_numeric
        if comp.numeric == 0
          0
        else
          1
        end
      else
        order_comp = qualifier_order(comp.qualifier)
        order_null = QUALIFIER_ORDER[""]
        order_comp <=> order_null
      end
    end

    def qualifier_order(q)
      QUALIFIER_ORDER.fetch(q, UNKNOWN_QUALIFIER_ORDER)
    end
  end
end
