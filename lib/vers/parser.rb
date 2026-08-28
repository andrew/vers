# frozen_string_literal: true

require_relative 'constraint'
require_relative 'version_range'

module Vers
  ##
  # Parses vers URI strings and package manager specific version ranges
  #
  # This class handles parsing of vers URI format (e.g., "vers:npm/>=1.2.3|<2.0.0")
  # and provides extensible support for different package ecosystem syntaxes.
  #
  # == Examples
  #
  #   parser = Vers::Parser.new
  #   range = parser.parse("vers:npm/>=1.2.3|<2.0.0")
  #   range.contains?("1.5.0")  # => true
  #
  class Parser
    NGINX_RANGE_REGEX = /\A\d+(?:\.\d+)+-\d+(?:\.\d+)+\z/
    OPERATOR_PREFIX_REGEX = /\A[><=!]+/
    PUB_VERSION_PREFIX_REGEX = /\A[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?/
    SEMVER_OUTPUT_SCHEMES = %w[npm cargo nuget composer pub].freeze
    VERS_META_ENCODINGS = {
      "%" => "%25",
      "|" => "%7C",
      ">" => "%3E",
      "<" => "%3C",
      "=" => "%3D",
      "!" => "%21",
      "/" => "%2F",
      "*" => "%2A",
      " " => "%20"
    }.freeze
    # Maximum accepted length for a range string at parse/parse_native
    # entry points. Range strings concatenate multiple constraints so this
    # is set higher than Version::MAX_LENGTH while still bounding
    # split/regex work to a few KB.
    MAX_INPUT_LENGTH = 2048

    # Maximum number of |-separated or ||-separated constraints in a
    # single range. The exclusion loop in parse_constraints does
    # O(n^2 log n) work as each != splits an interval and reconstructs the
    # range; capping n keeps the worst case under a few thousand interval
    # operations.
    MAX_CONSTRAINTS = 64

    ##
    # Parses a vers URI string into a VersionRange
    #
    # @param vers_string [String] The vers URI string to parse
    # @return [VersionRange] The parsed version range
    # @raise [ArgumentError] if the vers string is invalid
    #
    # == Examples
    #
    #   parser = Vers::Parser.new
    #   parser.parse("vers:npm/>=1.2.3|<2.0.0")
    #   parser.parse_native("~>1.0", "gem")
    #   parser.parse_native("==1.2.3", "pypi")
    #
    def parse(vers_string, require_canonical_order: false)
      validate_input_length!(vers_string)

      return VersionRange.unbounded if vers_string == "*"
      unless vers_string.is_a?(String) && vers_string.start_with?("vers:")
        raise ArgumentError, "Invalid vers URI format: #{vers_string}"
      end
      if vers_string.match?(/[ \t\r\n]/)
        raise ArgumentError, "non-canonical VERS: whitespace is not permitted"
      end

      remainder = vers_string.delete_prefix("vers:")
      slash = remainder.index("/")
      unless slash && slash.positive?
        raise ArgumentError, "Invalid vers URI format: #{vers_string}"
      end

      raw_scheme = remainder[...slash]
      if raw_scheme != raw_scheme.downcase
        raise ArgumentError, "non-canonical VERS: type must be lowercase"
      end
      scheme = Scheme.canonical(raw_scheme)
      constraints_string = remainder[(slash + 1)..]
      if constraints_string.empty? || constraints_string == "*"
        return VersionRange.unbounded(scheme: scheme)
      end

      validate_vers_constraints!(constraints_string, scheme, require_canonical_order)

      parse_constraints(constraints_string, scheme, decode_versions: true)
    end

    ##
    # Parses a native package manager version range into a VersionRange
    #
    # @param range_string [String] The native version range string
    # @param scheme [String] The package manager scheme (npm, gem, pypi, etc.)
    # @return [VersionRange] The parsed version range
    #
    # == Examples
    #
    #   parser = Vers::Parser.new
    #   parser.parse_native("^1.2.3", "npm")
    #   parser.parse_native("~> 1.0", "gem")
    #   parser.parse_native(">=1.0,<2.0", "pypi")
    #
    def parse_native(range_string, scheme)
      validate_input_length!(range_string)

      canonical_scheme = Scheme.canonical(scheme)
      range = case canonical_scheme
      when "npm"
        parse_npm_range(range_string, scheme: "npm")
      when "gem"
        parse_gem_range(range_string)
      when "pypi"
        parse_pypi_range(range_string)
      when "composer"
        parse_composer_range(range_string)
      when "pub"
        parse_pub_range(range_string)
      when "conan"
        parse_conan_range(range_string)
      when "nginx"
        parse_nginx_range(range_string)
      when "openssl"
        parse_openssl_range(range_string)
      when "maven"
        parse_maven_range(range_string)
      when "cargo"
        parse_npm_range(range_string, scheme: "cargo")
      when "nuget"
        parse_nuget_range(range_string)
      when "hex"
        parse_hex_range(range_string)
      when "go"
        parse_go_range(range_string)
      when "deb"
        parse_debian_range(range_string)
      when "rpm"
        parse_rpm_range(range_string)
      else
        # Fall back to generic constraint parsing
        parse_constraints(range_string, canonical_scheme)
      end
      range.with_scheme(canonical_scheme)
    end

    ##
    # Converts a VersionRange back to a vers URI string
    #
    # @param version_range [VersionRange] The version range to convert
    # @param scheme [String] The package manager scheme
    # @return [String] The vers URI string
    #
    def to_vers_string(version_range, scheme)
      canonical_scheme = Scheme.canonical(scheme)
      if version_range.scheme && canonical_scheme != version_range.scheme
        raise ArgumentError, "Cannot serialize a #{version_range.scheme} range as #{canonical_scheme}"
      end

      scheme = canonical_scheme
      if version_range.unbounded? && (!version_range.raw_constraints || version_range.raw_constraints.empty?)
        return "vers:#{scheme}/*"
      end
      if version_range.empty? && (!version_range.raw_constraints || version_range.raw_constraints.empty?)
        return "vers:#{scheme}/"
      end

      intervals = serialization_intervals(version_range, scheme)
      constraints = []

      # Detect != pattern: two intervals (-∞,V) ∪ (V,+∞)
      if intervals.length == 2
        a, b = intervals
        if a.min.nil? && !a.max_inclusive && b.max.nil? && !b.min_inclusive && a.max == b.min
          version = encode_vers_version(normalize_vers_version(a.max, scheme))
          constraints << "!=#{version}"
          sort_constraints!(constraints, scheme)
          return "vers:#{scheme}/#{constraints.join('|')}"
        end
      end

      intervals.each do |interval|
        next if interval.unbounded?

        if interval.min == interval.max && interval.min_inclusive && interval.max_inclusive
          # Exact version
          constraints << encode_vers_version(normalize_vers_version(interval.min.to_s, scheme))
        else
          # Range constraints
          if interval.min
            operator = interval.min_inclusive ? ">=" : ">"
            version = encode_vers_version(normalize_vers_version(interval.min, scheme))
            constraints << "#{operator}#{version}"
          end

          if interval.max
            operator = interval.max_inclusive ? "<=" : "<"
            version = encode_vers_version(normalize_vers_version(interval.max, scheme))
            constraints << "#{operator}#{version}"
          end
        end
      end

      version_range.exclusions.each do |version|
        normalized = normalize_vers_version(version, scheme)
        constraints << "!=#{encode_vers_version(normalized)}"
      end

      sort_constraints!(constraints, scheme)

      "vers:#{scheme}/#{constraints.join('|')}"
    end

    private

    def validate_input_length!(input)
      return if input.nil?
      return if input.length <= MAX_INPUT_LENGTH
      raise ArgumentError, "Range string too long (#{input.length} > #{MAX_INPUT_LENGTH})"
    end

    def validate_vers_constraints!(constraints, scheme, require_canonical_order)
      if constraints.start_with?("|")
        raise ArgumentError, "non-canonical VERS: leading pipe is not permitted"
      end
      if constraints.end_with?("|")
        raise ArgumentError, "non-canonical VERS: trailing pipe is not permitted"
      end
      if constraints.include?("||")
        raise ArgumentError, "non-canonical VERS: consecutive pipes are not permitted"
      end

      previous = nil
      previous_raw = nil
      seen_versions = []
      constraints.split("|").each do |raw|
        constraint = Constraint.parse(raw)
        validate_vers_version!(constraint.version, scheme)
        decoded_version = decode_vers_version(constraint.version)

        if require_canonical_order
          if seen_versions.any? { |version| Version.compare_with_scheme(version, decoded_version, scheme).zero? }
            raise ArgumentError, "non-canonical VERS: duplicate versions are not permitted"
          end
          if previous
            order = Version.compare_with_scheme(previous, decoded_version, scheme)
            if order.positive? || (order.zero? && previous_raw > raw)
              raise ArgumentError, "non-canonical VERS: constraints are not sorted by version"
            end
          end
          seen_versions << decoded_version
        end

        previous = decoded_version
        previous_raw = raw
      end
    end

    def validate_vers_version!(version, scheme)
      index = 0
      while index < version.bytesize
        unless version.getbyte(index) == 37
          index += 1
          next
        end

        first = version.getbyte(index + 1)
        second = version.getbyte(index + 2)
        unless ascii_hex?(first) && ascii_hex?(second)
          raise ArgumentError, "non-canonical VERS: invalid percent-encoding in version"
        end
        if lowercase_ascii_hex?(first) || lowercase_ascii_hex?(second)
          raise ArgumentError, "non-canonical VERS: percent-encoding in version is not canonical"
        end

        index += 3
      end

      if version.match?(/[><=!*\/]/)
        raise ArgumentError, "non-canonical VERS: reserved characters in version must be percent-encoded"
      end

      return unless scheme == "datetime"
      if version.include?("%3A")
        raise ArgumentError, "non-canonical VERS: datetime time colons must be unencoded"
      end

      decoded = decode_vers_version(version)
      if (decoded.length > 10 && decoded[10] == "t") || decoded.end_with?("z")
        raise ArgumentError, "non-canonical VERS: datetime must use uppercase T and Z"
      end
    end

    def ascii_hex?(byte)
      byte && ((48..57).cover?(byte) || (65..70).cover?(byte) || lowercase_ascii_hex?(byte))
    end

    def lowercase_ascii_hex?(byte)
      byte && (97..102).cover?(byte)
    end

    def sort_constraints!(constraints, scheme)
      constraints.sort! do |left, right|
        left_version = decode_vers_version(left.sub(OPERATOR_PREFIX_REGEX, ""))
        right_version = decode_vers_version(right.sub(OPERATOR_PREFIX_REGEX, ""))
        comparison = Version.compare_with_scheme(left_version, right_version, scheme)
        comparison.zero? ? left <=> right : comparison
      end
    end

    def serialization_intervals(version_range, scheme)
      raw_constraints = version_range.raw_constraints
      return version_range.intervals unless raw_constraints
      return raw_constraints unless %w[npm cargo].include?(scheme)
      return raw_constraints if version_range.empty?

      grouped = intersect_consecutive_intervals(raw_constraints, scheme)
      raw_range = VersionRange.new(grouped, scheme: scheme)
      equivalent_intervals?(raw_range.intervals, version_range.intervals, scheme) ? raw_constraints : version_range.intervals
    end

    def equivalent_intervals?(left, right, scheme)
      return false unless left.length == right.length

      left.zip(right).all? do |left_interval, right_interval|
        left_interval.min_inclusive == right_interval.min_inclusive &&
          left_interval.max_inclusive == right_interval.max_inclusive &&
          equivalent_bound?(left_interval.min, right_interval.min, scheme) &&
          equivalent_bound?(left_interval.max, right_interval.max, scheme)
      end
    end

    def equivalent_bound?(left, right, scheme)
      return true if left.nil? && right.nil?
      return false if left.nil? || right.nil?

      Version.compare_for_range(left, right, scheme).zero?
    end

    def normalize_vers_version(version, scheme)
      canonical_scheme = Scheme.canonical(scheme)
      if %w[npm cargo].include?(canonical_scheme) && SemverVersion.valid?(version)
        return SemverVersion.normalize(version)
      end

      return version if version.include?("-")
      return version unless SEMVER_OUTPUT_SCHEMES.include?(canonical_scheme)
      return version unless SemverVersion.valid?(version)

      case version.count(".")
      when 0
        "#{version}.0.0"
      when 1
        "#{version}.0"
      else
        version
      end
    end

    def encode_vers_version(version)
      version.gsub(/[\%|><=!\/* ]/, VERS_META_ENCODINGS)
    end

    def parse_constraints(constraints_string, scheme, decode_versions: false)
      canonical_scheme = Scheme.canonical(scheme)
      return VersionRange.unbounded(scheme: canonical_scheme) if constraints_string == "*"

      # Limit constraint count to bound the O(n^2 log n) exclusion loop
      # below: each != splits an interval and reconstructs the range.
      constraint_strings = constraints_string.split(/[|,]/, MAX_CONSTRAINTS + 1)
      if constraint_strings.length > MAX_CONSTRAINTS
        raise ArgumentError, "Too many constraints (> #{MAX_CONSTRAINTS})"
      end
      intervals = []
      exclusions = []
      interval_scheme = canonical_scheme

      constraint_strings.each do |constraint_string|
        constraint = Constraint.parse(constraint_string.strip)
        if decode_versions
          constraint = Constraint.new(constraint.operator, decode_vers_version(constraint.version))
        end

        if constraint.exclusion?
          exclusions << constraint.version
        else
          interval = constraint.to_interval(scheme: interval_scheme)
          intervals << interval if interval
        end
      end

      grouped_intervals = intersect_consecutive_intervals(intervals, interval_scheme)

      # Start with the union of all positive constraints, or unbounded if only exclusions
      range = if grouped_intervals.any?
                VersionRange.new(
                  grouped_intervals,
                  raw_constraints: intervals,
                  scheme: interval_scheme,
                  exclusions: exclusions
                )
              elsif exclusions.any?
                VersionRange.new(
                  [Interval.unbounded(scheme: interval_scheme)],
                  raw_constraints: [],
                  scheme: interval_scheme,
                  exclusions: exclusions
                )
              else
                VersionRange.new([], scheme: interval_scheme)
              end

      range
    end

    def intersect_consecutive_intervals(intervals, scheme)
      grouped = []
      index = 0

      while index < intervals.length
        current = intervals.fetch(index)
        following = intervals[index + 1]
        opposite_bounds = following &&
          ((current.min && !current.max && following.max && !following.min) ||
           (current.max && !current.min && following.min && !following.max))

        if opposite_bounds
          intersection = current.intersect(following)
          unless intersection.empty?
            grouped << intersection
            index += 2
            next
          end
        end

        grouped << current.with_scheme(scheme)
        index += 1
      end

      grouped
    end

    def decode_vers_version(version)
      version.gsub(/%([0-9A-Fa-f]{2})/) { [$1.to_i(16)].pack("C") }
    end

    def parse_composer_range(range_string)
      constraint = range_string.to_s.strip
      return VersionRange.unbounded(scheme: "composer") if %w[* x X @dev].include?(constraint)

      parts = constraint.split(/\s*\|\|?\s*/)
      raise ArgumentError, "Invalid Composer range: #{range_string}" if parts.any?(&:empty?)

      ranges = parts.map { |part| parse_composer_conjunction(part) }
      ranges.reduce { |combined, range| combined.union(range) }
    end

    def parse_composer_conjunction(constraint)
      value = constraint.strip.sub(/\s+as\s+.+\z/i, "")
      if (match = /\A(\S+)\s+-\s+(\S+)\z/.match(value))
        return parse_composer_hyphen_range(match[1], match[2])
      end

      parts = value.tr(",", " ").split
      ranges = parts.map { |part| parse_composer_constraint(part) }
      ranges.reduce { |combined, range| combined.intersect(range) }
    end

    def parse_composer_constraint(constraint)
      return VersionRange.unbounded(scheme: "composer") if constraint == "@dev"

      value, stability = constraint.split("@", 2)
      return VersionRange.unbounded(scheme: "composer") if value.empty?
      return parse_composer_wildcard(value) if composer_wildcard?(value)
      return parse_composer_caret(value.delete_prefix("^")) if value.start_with?("^")
      return parse_composer_tilde(value.delete_prefix("~")) if value.start_with?("~")
      return composer_exact_range(value) if ComposerVersion.branch?(value)

      operator = value[/\A(?:==|<>|!=|>=|<=|>|<|=)/] || "="
      version = value.delete_prefix(operator)
      operator = "=" if operator == "=="
      operator = "!=" if operator == "<>"
      implicit = operator == "=" || operator == "!=" ? nil : "dev"
      normalized = ComposerVersion.normalize(version, implicit_stability: stability || implicit)

      return composer_exclusion_range(normalized) if operator == "!="
      return composer_exact_range(normalized) if operator == "="

      composer_interval_range(Constraint.new(operator, normalized).to_interval(scheme: "composer"))
    end

    def parse_composer_caret(version)
      parts = ComposerVersion.release_parts(version)
      raise ArgumentError, "Invalid Composer caret version: #{version}" unless parts

      bump = 0
      if VersionComparison.compare_numbers(parts[0], "0").zero? && parts.length > 1
        bump = 1
        if VersionComparison.compare_numbers(parts[1], "0").zero? && parts.length > 2
          bump = 2
        end
      end

      lower = ComposerVersion.normalize(version, implicit_stability: "dev")
      upper = increment_composer_release(parts, bump)
      composer_interval_range(Interval.new(min: lower, max: upper, min_inclusive: true, max_inclusive: false, scheme: "composer"))
    end

    def parse_composer_tilde(version)
      parts = ComposerVersion.release_parts(version)
      raise ArgumentError, "Invalid Composer tilde version: #{version}" unless parts

      bump = parts.length > 2 ? parts.length - 2 : 0
      lower = ComposerVersion.normalize(version, implicit_stability: "dev")
      upper = increment_composer_release(parts, bump)
      composer_interval_range(Interval.new(min: lower, max: upper, min_inclusive: true, max_inclusive: false, scheme: "composer"))
    end

    def parse_composer_wildcard(value)
      return VersionRange.unbounded(scheme: "composer") if %w[* x X].include?(value)

      segments = value.sub(/\Av(?=\d)/i, "").split(".")
      prefix = []
      wildcard = false
      segments.each do |segment|
        if segment == "*" || segment.casecmp?("x")
          wildcard = true
        elsif wildcard || !VersionComparison.numeric?(segment)
          raise ArgumentError, "Invalid Composer wildcard: #{value}"
        else
          prefix << segment
        end
      end
      raise ArgumentError, "Invalid Composer wildcard: #{value}" unless wildcard
      return VersionRange.unbounded(scheme: "composer") if prefix.empty?

      lower_parts = prefix.map { |part| VersionComparison.normalize_number(part) }
      lower_parts << "0" while lower_parts.length < 3
      lower = "#{lower_parts.join(".")}-dev"
      upper = increment_composer_release(prefix, prefix.length - 1)
      composer_interval_range(Interval.new(min: lower, max: upper, min_inclusive: true, max_inclusive: false, scheme: "composer"))
    end

    def parse_composer_hyphen_range(lower, upper)
      lower_parts = ComposerVersion.release_parts(lower)
      upper_parts = ComposerVersion.release_parts(upper)
      raise ArgumentError, "Invalid Composer hyphen range: #{lower} - #{upper}" unless lower_parts && upper_parts

      minimum = ComposerVersion.normalize(lower, implicit_stability: "dev")
      if upper_parts.length < 3 && !ComposerVersion.explicit_stability?(upper)
        maximum = increment_composer_release(upper_parts, upper_parts.length - 1)
        interval = Interval.new(min: minimum, max: maximum, min_inclusive: true, max_inclusive: false, scheme: "composer")
      else
        maximum = ComposerVersion.normalize(upper)
        interval = Interval.new(min: minimum, max: maximum, min_inclusive: true, max_inclusive: true, scheme: "composer")
      end
      composer_interval_range(interval)
    end

    def increment_composer_release(parts, index)
      length = [parts.length, 3].max
      incremented = Array.new(length, "0")
      parts.each_with_index { |part, part_index| incremented[part_index] = VersionComparison.normalize_number(part) }
      incremented[index] = (incremented[index].to_i + 1).to_s
      ((index + 1)...length).each { |part_index| incremented[part_index] = "0" }
      "#{incremented.join(".")}-dev"
    end

    def composer_wildcard?(value)
      value.split(".").any? { |part| part == "*" || part.casecmp?("x") }
    end

    def composer_interval_range(interval)
      VersionRange.new([interval], raw_constraints: [interval], scheme: "composer")
    end

    def composer_exact_range(version)
      interval = Interval.exact(ComposerVersion.branch?(version) ? version : ComposerVersion.normalize(version), scheme: "composer")
      composer_interval_range(interval)
    end

    def composer_exclusion_range(version)
      VersionRange.new(
        [Interval.unbounded(scheme: "composer")],
        raw_constraints: [],
        scheme: "composer",
        exclusions: [version]
      )
    end

    def parse_pub_range(range_string)
      constraint = range_string.to_s.strip
      return VersionRange.unbounded(scheme: "pub") if constraint == "any"
      raise ArgumentError, "Empty Pub range" if constraint.empty?
      raise ArgumentError, "Unsupported Pub range: #{range_string}" if constraint.match?(/[,|*]/) || constraint.include?("!=")
      return parse_pub_caret(constraint.delete_prefix("^")) if constraint.start_with?("^")

      ranges = tokenize_pub_constraints(constraint).map { |part| parse_pub_constraint(part) }
      adjust_pub_upper_bounds(ranges.reduce { |combined, range| combined.intersect(range) })
    end

    def tokenize_pub_constraints(constraint)
      remaining = constraint.strip
      tokens = []

      until remaining.empty?
        operator = remaining[/\A(?:>=|<=|>|<)/].to_s
        remaining = remaining.delete_prefix(operator).lstrip
        match = PUB_VERSION_PREFIX_REGEX.match(remaining)
        raise ArgumentError, "Invalid Pub range: #{constraint}" unless match

        tokens << "#{operator}#{match[0]}"
        remaining = remaining[match[0].length..].to_s.strip
      end

      tokens
    end

    def parse_pub_constraint(constraint)
      operator = constraint[/\A(?:>=|<=|>|<)/].to_s
      version = constraint.delete_prefix(operator)
      raise ArgumentError, "Invalid Pub version: #{version}" unless PubVersion.valid?(version)

      interval = if operator.empty?
                   Interval.exact(version, scheme: "pub")
                 else
                   Constraint.new(operator, version).to_interval(scheme: "pub")
                 end
      VersionRange.new([interval], raw_constraints: [interval], scheme: "pub")
    end

    def parse_pub_caret(version)
      parsed = PubVersion.parse(version)
      raise ArgumentError, "Invalid Pub caret version: #{version}" unless parsed

      upper = if VersionComparison.compare_numbers(parsed.core[0], "0").zero?
                "0.#{parsed.core[1].to_i + 1}.0-0"
              else
                "#{parsed.core[0].to_i + 1}.0.0-0"
              end
      interval = Interval.new(min: version, max: upper, min_inclusive: true, max_inclusive: false, scheme: "pub")
      VersionRange.new([interval], raw_constraints: [interval], scheme: "pub")
    end

    def adjust_pub_upper_bounds(range)
      replacements = {}
      intervals = range.intervals.map do |interval|
        next interval unless pub_upper_needs_first_prerelease?(interval)

        replacements[interval.max] = "#{interval.max}-0"
        Interval.new(
          min: interval.min,
          max: replacements.fetch(interval.max),
          min_inclusive: interval.min_inclusive,
          max_inclusive: interval.max_inclusive,
          scheme: "pub"
        )
      end
      raw_constraints = (range.raw_constraints || range.intervals).map do |interval|
        replacement = !interval.max_inclusive && replacements[interval.max]
        next interval unless replacement

        Interval.new(
          min: interval.min,
          max: replacement,
          min_inclusive: interval.min_inclusive,
          max_inclusive: interval.max_inclusive,
          scheme: "pub"
        )
      end
      VersionRange.new(intervals, raw_constraints: raw_constraints, scheme: "pub", exclusions: range.exclusions)
    end

    def pub_upper_needs_first_prerelease?(interval)
      return false unless interval.max && !interval.max_inclusive && PubVersion.valid?(interval.max)

      maximum = PubVersion.parse(interval.max)
      return false unless maximum.prerelease.empty? && maximum.build.empty?
      return true unless interval.min && PubVersion.valid?(interval.min)

      minimum = PubVersion.parse(interval.min)
      return true if minimum.prerelease.empty?

      !minimum.core.zip(maximum.core).all? do |minimum_part, maximum_part|
        VersionComparison.compare_numbers(minimum_part, maximum_part).zero?
      end
    end

    def parse_conan_range(range_string)
      constraint = range_string.to_s.strip.split(",", 2).first.to_s.strip
      return VersionRange.empty(scheme: "conan") if constraint.empty?

      if %w[* *-].include?(constraint)
        interval = Interval.greater_than("0.0.0", inclusive: true, scheme: "conan")
        return VersionRange.new([interval], raw_constraints: [interval], scheme: "conan")
      end

      if constraint.include?("||")
        parts = constraint.split("||").map(&:strip)
        raise ArgumentError, "Invalid Conan range: #{range_string}" if parts.any?(&:empty?)

        return parts.map { |part| parse_conan_range(part) }.reduce { |combined, range| combined.union(range) }
      end

      if constraint.match?(/\s/)
        parts = constraint.split
        return parts.map { |part| parse_conan_range(part) }.reduce { |combined, range| combined.intersect(range) }
      end

      constraint = constraint.delete_suffix("-")
      if constraint.start_with?("~", "^")
        operator = constraint[0]
        version = constraint[1..]
        upper = conan_upper_bound(version, operator)
        interval = Interval.new(
          min: version,
          max: upper,
          min_inclusive: true,
          max_inclusive: false,
          scheme: "conan"
        )
        return VersionRange.new([interval], raw_constraints: [interval], scheme: "conan")
      end

      parse_constraints(constraint, "conan")
    end

    def conan_upper_bound(version, operator)
      parts = version.split(".")
      unless parts.any? && parts.all? { |part| VersionComparison.numeric?(part) }
        raise ArgumentError, "Invalid Conan compatible version: #{version}"
      end

      index = 0
      if operator == "~" && parts.length > 1
        index = 1
      elsif operator == "^"
        index += 1 while index < parts.length - 1 && VersionComparison.compare_numbers(parts[index], "0").zero?
      end

      upper = parts.first(index + 1).map { |part| VersionComparison.normalize_number(part) }
      upper[index] = (upper[index].to_i + 1).to_s
      "#{upper.join(".")}-"
    end

    def parse_openssl_range(range_string)
      parts = range_string.to_s.split(",", -1).map(&:strip)
      intervals = parts.map do |version|
        unless OpenSSLVersion.valid?(version)
          raise ArgumentError, "Invalid OpenSSL version: #{version}"
        end

        Interval.exact(version, scheme: "openssl")
      end
      VersionRange.new(intervals, raw_constraints: intervals, scheme: "openssl")
    end

    def parse_nginx_range(range_string)
      constraint = range_string.to_s.strip
      if constraint.include?(",")
        parts = constraint.split(",", -1).map(&:strip)
        raise ArgumentError, "Invalid Nginx range: #{range_string}" if parts.any?(&:empty?)

        return parts.map { |part| parse_nginx_range(part) }.reduce { |combined, range| combined.union(range) }
      end

      if constraint.end_with?("+")
        version = constraint.delete_suffix("+")
        unless SemverVersion.valid?(version)
          raise ArgumentError, "Invalid Nginx range: #{range_string}"
        end

        parts = version.split(".")
        maximum = if parts.fetch(1).to_i.even?
                    "#{parts.fetch(0)}.#{parts.fetch(1).to_i + 1}.0"
                  end
        interval = Interval.new(
          min: version,
          max: maximum,
          min_inclusive: true,
          max_inclusive: false,
          scheme: "nginx"
        )
        return VersionRange.new([interval], raw_constraints: [interval], scheme: "nginx")
      end

      if NGINX_RANGE_REGEX.match?(constraint)
        minimum, maximum = constraint.split("-", 2)
        unless SemverVersion.valid?(minimum) && SemverVersion.valid?(maximum)
          raise ArgumentError, "Invalid Nginx range: #{range_string}"
        end

        interval = Interval.new(
          min: minimum,
          max: maximum,
          min_inclusive: true,
          max_inclusive: true,
          scheme: "nginx"
        )
        return VersionRange.new([interval], raw_constraints: [interval], scheme: "nginx")
      end

      parse_constraints(constraint, "nginx")
    end

    # NPM range parsing (^, ~, -, ||, etc.)
    def parse_npm_range(range_string, scheme: "npm")
      constraint = range_string.to_s.strip
      return VersionRange.unbounded(scheme: scheme) if constraint.empty? || %w[* x X].include?(constraint)

      if constraint.include?("||")
        or_parts = constraint.split("||", MAX_CONSTRAINTS + 1).map(&:strip)
        if or_parts.length > MAX_CONSTRAINTS
          raise ArgumentError, "Too many || clauses (> #{MAX_CONSTRAINTS})"
        end
        ranges = or_parts.map { |part| parse_npm_range(part, scheme: scheme) }
        return ranges.reduce { |combined, range| combined.union(range) }
      end

      if constraint.include?(" - ")
        lower, upper = constraint.split(" - ", 2).map(&:strip)
        return parse_npm_hyphen_range(lower, upper, scheme: scheme)
      end

      if constraint.match?(/[ \t\r\n]/)
        tokens = constraint.split
        merged = []
        tokens.each do |token|
          if merged.last&.match?(/\A(?:>=|<=|!=|>|<|=|~>|~|\^)\z/)
            merged[-1] = "#{merged.last}#{token}"
          else
            merged << token
          end
        end
        ranges = merged.map { |part| parse_npm_single_range(part, scheme: scheme) }
        return ranges.reduce { |combined, range| combined.intersect(range) }
      end

      parse_npm_single_range(constraint, scheme: scheme)
    end

    def parse_npm_single_range(range_string, scheme: "npm")
      constraint = range_string.to_s.strip
      return parse_caret_range(constraint.delete_prefix("^").strip, scheme: scheme) if constraint.start_with?("^")
      return parse_tilde_range(constraint.delete_prefix("~>").strip, scheme: scheme) if constraint.start_with?("~>")
      return parse_tilde_range(constraint.delete_prefix("~").strip, scheme: scheme) if constraint.start_with?("~")

      operator, version = extract_npm_operator(constraint)
      if constraint.end_with?(".x", ".X", ".*") || partial_npm_version?(version)
        return parse_npm_partial_range(version, operator, scheme: scheme)
      end

      parsed = Constraint.parse(constraint)
      unless NpmVersion.valid?(parsed.version)
        raise ArgumentError, "Invalid NPM range format: #{range_string}"
      end

      if parsed.exclusion?
        VersionRange.unbounded(scheme: scheme).exclude(parsed.version)
      else
        interval = parsed.to_interval(scheme: scheme)
        VersionRange.new([interval], scheme: scheme)
      end
    end

    def parse_caret_range(version, scheme: "npm")
      return VersionRange.unbounded(scheme: scheme) if version.empty? || %w[* x X].include?(version)
      return parse_npm_partial_range(version, "", scheme: scheme) if version.end_with?(".x", ".X", ".*")

      parsed = SemverVersion.parse(version)
      raise ArgumentError, "Invalid NPM caret version: #{version}" unless parsed && NpmVersion.valid?(version)

      base = version.split("+", 2).first.split("-", 2).first.delete_prefix("v").delete_prefix("V")
      segments = base.count(".") + 1
      major, minor, patch = parsed.core.map(&:to_i)
      upper = if segments == 1 || major.positive?
                "#{major + 1}.0.0"
              elsif segments == 2 || minor.positive?
                "0.#{minor + 1}.0"
              else
                "0.0.#{patch + 1}"
              end
      interval = Interval.new(min: version, max: upper, min_inclusive: true, max_inclusive: false, scheme: scheme)
      VersionRange.new([interval], scheme: scheme)
    end

    def parse_tilde_range(version, scheme: "npm")
      return VersionRange.unbounded(scheme: scheme) if version.empty? || %w[* x X].include?(version)
      return parse_npm_partial_range(version, "", scheme: scheme) if version.end_with?(".x", ".X", ".*")

      parsed = SemverVersion.parse(version)
      raise ArgumentError, "Invalid NPM tilde version: #{version}" unless parsed && NpmVersion.valid?(version)

      base = version.split("+", 2).first.split("-", 2).first.delete_prefix("v").delete_prefix("V")
      segments = base.count(".") + 1
      major, minor, patch = parsed.core.map(&:to_i)
      upper = if segments >= 2
                "#{major}.#{minor + 1}.0"
              else
                "#{major + 1}.0.0"
              end
      interval = Interval.new(min: version, max: upper, min_inclusive: true, max_inclusive: false, scheme: scheme)
      raw_constraints = if parsed.prerelease.empty?
                          nil
                        else
                          base_version = "#{major}.#{minor}.#{patch}"
                          next_patch = "#{major}.#{minor}.#{patch + 1}"
                          [
                            Interval.new(min: version, max: base_version, min_inclusive: true, max_inclusive: false, scheme: scheme),
                            Interval.new(min: base_version, max: next_patch, min_inclusive: true, max_inclusive: false, scheme: scheme)
                          ]
                        end
      VersionRange.new([interval], raw_constraints: raw_constraints, scheme: scheme)
    end

    def parse_npm_partial_range(version, operator, scheme: "npm")
      lower, upper = npm_partial_bounds(version)
      return VersionRange.unbounded(scheme: scheme) unless lower

      interval = case operator
                 when "", "="
                   Interval.new(min: lower, max: upper, min_inclusive: true, max_inclusive: false, scheme: scheme)
                 when ">="
                   Interval.greater_than(lower, inclusive: true, scheme: scheme)
                 when ">"
                   Interval.greater_than(upper, inclusive: true, scheme: scheme)
                 when "<="
                   Interval.less_than(upper, scheme: scheme)
                 when "<"
                   Interval.less_than(lower, scheme: scheme)
                 else
                   raise ArgumentError, "Invalid operator for NPM partial range: #{operator}"
                 end

      VersionRange.new([interval], raw_constraints: [interval], scheme: scheme)
    end

    def npm_partial_bounds(version)
      constraint = version.to_s.strip
      return [nil, nil] if constraint.empty? || %w[* x X].include?(constraint)

      segments = constraint.delete_prefix("v").delete_prefix("V").split(".", -1)
      raise ArgumentError, "Invalid NPM partial version: #{version}" if segments.length > 3

      parts = []
      wildcard = false
      segments.each do |segment|
        if %w[* x X].include?(segment)
          wildcard = true
        elsif wildcard || !VersionComparison.numeric?(segment)
          raise ArgumentError, "Invalid NPM partial version: #{version}"
        else
          parts << segment.to_i
        end
      end
      return [nil, nil] if parts.empty?

      lower_parts = parts.dup
      lower_parts << 0 while lower_parts.length < 3
      upper_parts = lower_parts.dup
      upper_parts[parts.length - 1] += 1
      (parts.length...upper_parts.length).each { |index| upper_parts[index] = 0 }
      [lower_parts.join("."), upper_parts.join(".")]
    end

    def partial_npm_version?(version)
      constraint = version.to_s.strip.delete_prefix("v").delete_prefix("V")
      segments = constraint.split(".", -1)
      return false if segments.length > 3

      partial = segments.length < 3
      segments.each do |segment|
        if %w[* x X].include?(segment)
          partial = true
        elsif !VersionComparison.numeric?(segment)
          return false
        end
      end
      partial
    end

    def extract_npm_operator(constraint)
      operator = constraint[/\A(?:>=|<=|!=|>|<|=)/].to_s
      [operator, constraint.delete_prefix(operator).strip]
    end

    def parse_npm_hyphen_range(lower, upper, scheme: "npm")
      minimum = partial_npm_version?(lower) ? npm_partial_bounds(lower).fetch(0) : lower
      if partial_npm_version?(upper)
        maximum = npm_partial_bounds(upper).fetch(1)
        maximum_inclusive = false
      else
        maximum = upper
        maximum_inclusive = true
      end
      unless NpmVersion.valid?(minimum) && NpmVersion.valid?(maximum)
        raise ArgumentError, "Invalid NPM hyphen range: #{lower} - #{upper}"
      end

      interval = Interval.new(
        min: minimum,
        max: maximum,
        min_inclusive: true,
        max_inclusive: maximum_inclusive,
        scheme: scheme
      )
      VersionRange.new([interval], scheme: scheme)
    end

    # Gem range parsing (~>, >=, etc.)
    def parse_gem_range(range_string)
      if range_string.match(/^~>\s*(.+)$/)
        # Pessimistic operator: ~> 1.2.3
        version = Regexp.last_match(1).strip
        parse_pessimistic_range(version)
      else
        # Standard constraints separated by commas
        constraints = range_string.split(',').map(&:strip)
        parse_constraints(constraints.join('|'), 'gem')
      end
    end

    def parse_pessimistic_range(version)
      v = Version.cached_new(version)
      upper_version = if v.patch
                        # ~> 1.2.3 := >= 1.2.3, < 1.3
                        "#{v.major}.#{v.minor + 1}"
                      elsif v.minor
                        # ~> 1.2 := >= 1.2.0, < 2
                        "#{v.major + 1}"
                      else
                        # ~> 1 := >= 1.0.0, < 2
                        "#{v.major + 1}"
                      end

      VersionRange.new([
        Interval.new(min: version, max: upper_version, min_inclusive: true, max_inclusive: false)
      ])
    end

    # Python/PyPI range parsing
    def parse_pypi_range(range_string)
      constraint = range_string.to_s.strip
      raise ArgumentError, "Empty PyPI range" if constraint.empty?

      if constraint.include?(",")
        ranges = constraint.split(",", -1).map do |part|
          raise ArgumentError, "Empty PyPI constraint" if part.strip.empty?

          parse_pypi_range(part)
        end
        return ranges.reduce { |combined, range| combined.intersect(range) }
      end

      return parse_pypi_compatible_range(constraint.delete_prefix("~=").strip) if constraint.start_with?("~=")
      if constraint.start_with?("===")
        raise ArgumentError, "PyPI arbitrary equality constraints are not supported: #{constraint}"
      end
      if constraint.start_with?("==") && constraint.delete_prefix("==").strip.end_with?(".*")
        return parse_pypi_prefix_range(constraint.delete_prefix("==").strip, exclude: false)
      end
      if constraint.start_with?("!=") && constraint.delete_prefix("!=").strip.end_with?(".*")
        return parse_pypi_prefix_range(constraint.delete_prefix("!=").strip, exclude: true)
      end

      constraint = "=#{constraint.delete_prefix("==").strip}" if constraint.start_with?("==")
      parse_constraints(constraint, "pypi")
    end

    def parse_pypi_compatible_range(version)
      parsed = PyPIVersion.parse(version)
      unless parsed && parsed.release.length >= 2
        raise ArgumentError, "Invalid PyPI compatible release: #{version}"
      end

      upper_release = parsed.release[0...-1].map { |part| VersionComparison.normalize_number(part) }
      upper_release[-1] = (upper_release.fetch(-1).to_i + 1).to_s
      upper = upper_release.join(".")
      unless VersionComparison.compare_numbers(parsed.epoch, "0").zero?
        upper = "#{VersionComparison.normalize_number(parsed.epoch)}!#{upper}"
      end

      interval = Interval.new(min: version, max: upper, min_inclusive: true, max_inclusive: false, scheme: "pypi")
      VersionRange.new([interval], raw_constraints: [interval], scheme: "pypi")
    end

    def parse_pypi_prefix_range(version, exclude:)
      prefix = version.delete_suffix(".*")
      parsed = PyPIVersion.parse(prefix)
      invalid = !parsed || !parsed.pre_tag.nil? || !parsed.post_number.nil? ||
        !parsed.dev_number.nil? || parsed.local.any?
      raise ArgumentError, "Invalid PyPI prefix constraint: #{version}" if invalid

      release = parsed.release.map { |part| VersionComparison.normalize_number(part) }
      upper_release = release.dup
      upper_release[-1] = (upper_release.fetch(-1).to_i + 1).to_s
      epoch = if VersionComparison.compare_numbers(parsed.epoch, "0").zero?
                ""
              else
                "#{VersionComparison.normalize_number(parsed.epoch)}!"
              end
      lower = "#{epoch}#{release.join(".")}.dev0"
      upper = "#{epoch}#{upper_release.join(".")}.dev0"

      intervals = if exclude
                    [
                      Interval.less_than(lower, scheme: "pypi"),
                      Interval.greater_than(upper, inclusive: true, scheme: "pypi")
                    ]
                  else
                    [Interval.new(min: lower, max: upper, min_inclusive: true, max_inclusive: false, scheme: "pypi")]
                  end
      VersionRange.new(intervals, raw_constraints: intervals, scheme: "pypi")
    end

    # Maven range parsing
    def parse_maven_range(range_string)
      # Validate bracket notation first
      if range_string.match(/^[\[\(].+[\]\)]$/)
        # Check for malformed single version ranges
        if range_string.match(/^\([^,]+\]$/) || range_string.match(/^\[[^,]+\)$/)
          raise ArgumentError, "Malformed Maven range: mismatched brackets in '#{range_string}'"
        end
      end

      case range_string
      when /^\[([^,]+),([^,]+)\]$/
        # [1.0,2.0] := >=1.0 <=2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: true, max_inclusive: true, scheme: "maven")
        ], scheme: "maven")
      when /^\(([^,]+),([^,]+)\)$/
        # (1.0,2.0) := >1.0 <2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: false, max_inclusive: false, scheme: "maven")
        ], scheme: "maven")
      when /^\[([^,]+),([^,]+)\)$/
        # [1.0,2.0) := >=1.0 <2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: true, max_inclusive: false, scheme: "maven")
        ], scheme: "maven")
      when /^\(([^,]+),([^,]+)\]$/
        # (1.0,2.0] := >1.0 <=2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: false, max_inclusive: true, scheme: "maven")
        ], scheme: "maven")
      when /^\[([^,]+)\]$/
        # [1.0] := exactly 1.0
        version = Regexp.last_match(1).strip
        VersionRange.exact(version, scheme: "maven")
      when /^\[([^,]+),\)$/
        # [1.0,) := >=1.0
        min_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(min: min_version, min_inclusive: true, scheme: "maven")
        ], scheme: "maven")
      when /^\(([^,]+),\)$/
        # (1.0,) := >1.0
        min_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(min: min_version, min_inclusive: false, scheme: "maven")
        ], scheme: "maven")
      when /^\(,([^,]+)\]$/
        # (,1.0] := <=1.0
        max_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(max: max_version, max_inclusive: true, scheme: "maven")
        ], scheme: "maven")
      when /^\(,([^,]+)\)$/
        # (,1.0) := <1.0
        max_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(max: max_version, max_inclusive: false, scheme: "maven")
        ], scheme: "maven")
      when /^[0-9]/
        # Simple version number without brackets - in Maven, this is minimum version
        if range_string.match(/^[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9.-]+)?$/)
          VersionRange.new([
            Interval.new(min: range_string, min_inclusive: true, scheme: "maven")
          ], scheme: "maven")
        else
          parse_constraints(range_string, 'maven')
        end
      when /^(.+),(.+)$/
        # Handle union ranges like "(,1.0],[1.2,)"
        parts = range_string.split(',')
        if parts.length > 2
          # Complex union - parse each part recursively
          ranges = []
          # Split and preserve bracket information
          # Find all individual ranges by splitting on comma between brackets
          individual_ranges = []
          remaining = range_string.strip

          while remaining.length > 0
            # Find the next complete bracket range
            if match = remaining.match(/^[\[\(][^\[\]\(\)]*[\]\)]/)
              individual_ranges << match[0].strip
              remaining = remaining[match.end(0)..-1].strip
              # Skip over comma and whitespace
              remaining = remaining.sub(/^\s*,\s*/, '')
            else
              break
            end
          end

          if individual_ranges.length > 1
            individual_ranges.each do |range_part|
              begin
                parsed_range = parse_maven_range(range_part)
                ranges << parsed_range
              rescue ArgumentError
                # If parsing fails, skip this part
              end
            end

            if ranges.any?
              return ranges.reduce { |acc, range| acc.union(range) }
            end
          end
        end

        # Fall back to standard constraint parsing
        parse_constraints(range_string, 'maven')
      else
        # Fall back to standard constraint parsing
        parse_constraints(range_string, 'maven')
      end
    end

    # NuGet range parsing (similar to Maven but with some differences)
    def parse_nuget_range(range_string)
      # NuGet uses the same bracket notation as Maven
      # But simple version strings like "1.0" are minimum versions, not exact
      case range_string
      when /^[\[\(].+[\]\)]$/
        # Parse bracket notation like Maven but with nuget scheme
        range = parse_nuget_bracket_range(range_string)
        range
      when /^[0-9]/
        # Simple version number - treat as minimum version for NuGet
        VersionRange.new([
          Interval.new(min: range_string, min_inclusive: true, scheme: "nuget")
        ], scheme: "nuget")
      else
        # Fall back to standard constraint parsing
        parse_constraints(range_string, 'nuget')
      end
    end

    def parse_nuget_bracket_range(range_string)
      case range_string
      when /^\[([^,]+),([^,]+)\]$/
        min_v = Regexp.last_match(1).strip
        max_v = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_v, max: max_v, min_inclusive: true, max_inclusive: true, scheme: "nuget")
        ], scheme: "nuget")
      when /^\(([^,]+),([^,]+)\)$/
        min_v = Regexp.last_match(1).strip
        max_v = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_v, max: max_v, min_inclusive: false, max_inclusive: false, scheme: "nuget")
        ], scheme: "nuget")
      when /^\[([^,]+),([^,]+)\)$/
        min_v = Regexp.last_match(1).strip
        max_v = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_v, max: max_v, min_inclusive: true, max_inclusive: false, scheme: "nuget")
        ], scheme: "nuget")
      when /^\(([^,]+),([^,]+)\]$/
        min_v = Regexp.last_match(1).strip
        max_v = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_v, max: max_v, min_inclusive: false, max_inclusive: true, scheme: "nuget")
        ], scheme: "nuget")
      when /^\[([^,]+)\]$/
        version = Regexp.last_match(1).strip
        VersionRange.exact(version, scheme: "nuget")
      when /^\[([^,]+),\)$/
        min_v = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(min: min_v, min_inclusive: true, scheme: "nuget")
        ], scheme: "nuget")
      when /^\(([^,]+),\)$/
        min_v = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(min: min_v, min_inclusive: false, scheme: "nuget")
        ], scheme: "nuget")
      when /^\(,([^,]+)\]$/
        max_v = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(max: max_v, max_inclusive: true, scheme: "nuget")
        ], scheme: "nuget")
      when /^\(,([^,]+)\)$/
        max_v = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(max: max_v, max_inclusive: false, scheme: "nuget")
        ], scheme: "nuget")
      else
        parse_constraints(range_string, 'nuget')
      end
    end

    # Hex/Elixir range parsing
    def parse_hex_range(range_string)
      # Handle "or" disjunction first
      if range_string.include?(" or ")
        or_parts = range_string.split(" or ").map(&:strip)
        ranges = or_parts.map { |part| parse_hex_single_range(part) }
        return ranges.reduce { |acc, range| acc.union(range) }
      end

      parse_hex_single_range(range_string)
    end

    def parse_hex_single_range(range_string)
      # Handle "and" conjunction and comma-separated AND constraints
      if range_string.include?(" and ") || range_string.include?(",")
        and_parts = range_string.split(/\s+and\s+|,/).map(&:strip).reject(&:empty?)
        ranges = and_parts.map { |part| parse_hex_constraint(part) }
        return ranges.reduce { |acc, range| acc.intersect(range) }
      end

      parse_hex_constraint(range_string)
    end

    def parse_hex_constraint(constraint_string)
      if constraint_string.match(/^~>\s*(.+)$/)
        parse_pessimistic_range(Regexp.last_match(1).strip)
      else
        # Normalize == to = for our internal constraint parsing
        normalized = constraint_string.gsub("==", "=")
        constraint = Constraint.parse(normalized.strip)
        if constraint.exclusion?
          VersionRange.unbounded.exclude(constraint.version)
        else
          VersionRange.new([constraint.to_interval])
        end
      end
    end

    # Go module range parsing (comma-separated AND constraints, v-prefix preserved)
    def parse_go_range(range_string)
      return VersionRange.unbounded if range_string.nil? || range_string.strip.empty?

      unless range_string.include?(',')
        return parse_constraints(range_string, 'go')
      end

      parts = range_string.split(',').map(&:strip)
      constraint_intervals = []
      exclusions = []

      parts.each do |part|
        constraint = Constraint.parse(part)
        if constraint.exclusion?
          exclusions << constraint.version
        else
          interval = constraint.to_interval
          constraint_intervals << interval if interval
        end
      end

      if constraint_intervals.any?
        range = VersionRange.new([constraint_intervals.first])
        constraint_intervals[1..].each do |interval|
          range = range.intersect(VersionRange.new([interval]))
        end
      else
        range = VersionRange.unbounded
      end

      exclusions.each { |version| range = range.exclude(version) }
      range
    end

    # Debian range parsing
    def parse_debian_range(range_string)
      # Debian uses operators like >=, <=, =, >>, <<
      range_string = range_string.gsub('>>', '>').gsub('<<', '<')
      parse_constraints(range_string, 'deb')
    end

    # RPM range parsing
    def parse_rpm_range(range_string)
      # RPM uses similar operators to Debian
      parse_constraints(range_string, 'rpm')
    end
  end
end
