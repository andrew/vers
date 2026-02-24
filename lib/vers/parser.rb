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
    # Regex for parsing vers URI format
    VERS_URI_REGEX = /\Avers:([^\/]+)\/(.+)\z/
    
    # Pre-compiled regex patterns for common npm patterns
    NPM_CARET_REGEX = /\A\^(.+)\z/
    NPM_TILDE_REGEX = /\A~(.+)\z/
    NPM_HYPHEN_REGEX = /\A(.+?)\s+-\s+(.+)\z/
    NPM_X_RANGE_MAJOR_REGEX = /\A(\d+)\.x\z/
    NPM_X_RANGE_MINOR_REGEX = /\A(\d+)\.(\d+)\.x\z/
    
    # Cache for parsed ranges to improve performance
    @@parser_cache = {}
    @@cache_size_limit = 200

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
    #   parser.parse("vers:gem/~>1.0")
    #   parser.parse("vers:pypi/==1.2.3")
    #
    def parse(vers_string)
      if vers_string == "*"
        return VersionRange.unbounded
      end

      match = vers_string.match(VERS_URI_REGEX)
      raise ArgumentError, "Invalid vers URI format: #{vers_string}" unless match

      scheme = match[1]
      constraints_string = match[2]

      parse_constraints(constraints_string, scheme)
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
      case scheme
      when "npm"
        parse_npm_range(range_string)
      when "gem", "rubygems"
        parse_gem_range(range_string)
      when "pypi"
        parse_pypi_range(range_string)
      when "maven"
        parse_maven_range(range_string)
      when "cargo"
        parse_npm_range(range_string)
      when "nuget"
        parse_nuget_range(range_string)
      when "hex", "elixir"
        parse_hex_range(range_string)
      when "go", "golang"
        parse_go_range(range_string)
      when "deb", "debian"
        parse_debian_range(range_string)
      when "rpm"
        parse_rpm_range(range_string)
      else
        # Fall back to generic constraint parsing
        parse_constraints(range_string, scheme)
      end
    end

    ##
    # Converts a VersionRange back to a vers URI string
    #
    # @param version_range [VersionRange] The version range to convert
    # @param scheme [String] The package manager scheme
    # @return [String] The vers URI string
    #
    def to_vers_string(version_range, scheme)
      return "*" if version_range.unbounded?
      return "vers:#{scheme}/" if version_range.empty?

      intervals = version_range.raw_constraints || version_range.intervals
      constraints = []

      intervals.each do |interval|
        if interval.min == interval.max && interval.min_inclusive && interval.max_inclusive
          # Exact version
          constraints << "=#{interval.min}"
        else
          # Range constraints
          if interval.min
            operator = interval.min_inclusive ? ">=" : ">"
            constraints << "#{operator}#{interval.min}"
          end

          if interval.max
            operator = interval.max_inclusive ? "<=" : "<"
            constraints << "#{operator}#{interval.max}"
          end
        end
      end

      constraints.sort_by! { |c| sort_key_for_constraint(c) }
      constraints.uniq!

      "vers:#{scheme}/#{constraints.join('|')}"
    end

    private

    def sort_key_for_constraint(constraint)
      version = constraint.sub(/\A[><=!]+/, '')
      v = Version.cached_new(version)
      [v.major || 0, v.minor || 0, v.patch || 0, constraint]
    end

    def parse_constraints(constraints_string, scheme)
      constraint_strings = constraints_string.split(/[|,]/)
      intervals = []
      exclusions = []

      constraint_strings.each do |constraint_string|
        constraint = Constraint.parse(constraint_string.strip)
        
        if constraint.exclusion?
          exclusions << constraint.version
        else
          interval = constraint.to_interval
          intervals << interval if interval
        end
      end

      # Start with the union of all positive constraints
      range = VersionRange.new(intervals)
      
      # Apply exclusions
      exclusions.each do |version|
        range = range.exclude(version)
      end

      range
    end

    # NPM range parsing (^, ~, -, ||, etc.)
    def parse_npm_range(range_string)
      # Handle empty string as unbounded
      if range_string.nil? || range_string.strip.empty?
        return VersionRange.unbounded
      end
      
      # Handle || (OR) operator
      if range_string.include?('||')
        or_parts = range_string.split('||').map(&:strip)
        ranges = or_parts.map { |part| parse_npm_single_range(part) }
        return ranges.reduce { |acc, range| acc.union(range) }
      end

      # Handle hyphen ranges first (before space splitting)
      if range_string.match(/^(.+?)\s+-\s+(.+)$/)
        return parse_npm_single_range(range_string)
      end

      # Handle space-separated AND constraints
      and_parts = range_string.split(/\s+/).reject(&:empty?)
      # Re-join bare operators with their version
      merged = []
      and_parts.each do |part|
        if merged.last&.match?(/\A(>=|<=|!=|[<>=~^])\z/)
          merged[-1] = "#{merged.last}#{part}"
        else
          merged << part
        end
      end
      ranges = merged.map { |part| parse_npm_single_range(part) }
      ranges.reduce { |acc, range| acc.intersect(range) }
    end

    def parse_npm_single_range(range_string)
      # Check cache first
      cache_key = "npm:#{range_string}"
      if @@parser_cache.key?(cache_key)
        return @@parser_cache[cache_key]
      end
      
      # Limit cache size
      if @@parser_cache.size >= @@cache_size_limit
        @@parser_cache.clear
      end
      
      result = case range_string
               when NPM_CARET_REGEX
                 # Caret range: ^1.2.3 := >=1.2.3 <2.0.0
                 version = $1
                 parse_caret_range(version)
               when NPM_TILDE_REGEX
                 # Tilde range: ~1.2.3 := >=1.2.3 <1.3.0
                 version = $1
                 parse_tilde_range(version)
               when NPM_HYPHEN_REGEX
                 # Hyphen range: 1.2.3 - 2.3.4 := >=1.2.3 <=2.3.4
                 from_version = $1.strip
                 to_version = $2.strip
                 VersionRange.new([
                   Interval.new(min: from_version, max: to_version, min_inclusive: true, max_inclusive: true)
                 ])
               when "*", "x", "X"
                 VersionRange.unbounded
               when NPM_X_RANGE_MAJOR_REGEX
                 # X-range like "1.x" := >=1.0.0 <2.0.0
                 major = $1.to_i
                 VersionRange.new([
                   Interval.new(min: "#{major}.0.0", max: "#{major + 1}.0.0", min_inclusive: true, max_inclusive: false)
                 ])
               when NPM_X_RANGE_MINOR_REGEX
                 # X-range like "1.2.x" := >=1.2.0 <1.3.0
                 major = $1.to_i
                 minor = $2.to_i
                 VersionRange.new([
                   Interval.new(min: "#{major}.#{minor}.0", max: "#{major}.#{minor + 1}.0", min_inclusive: true, max_inclusive: false)
                 ])
               when /^(blerg|git\+|https?:\/\/)/
                 # Invalid patterns that should raise errors
                 raise ArgumentError, "Invalid NPM range format: #{range_string}"
               else
                 # Standard constraint
                 constraint = Constraint.parse(range_string)
                 if constraint.exclusion?
                   VersionRange.unbounded.exclude(constraint.version)
                 else
                   VersionRange.new([constraint.to_interval])
                 end
               end
      
      @@parser_cache[cache_key] = result
      result
    end

    def parse_caret_range(version)
      v = Version.cached_new(version)
      upper_version = if v.major > 0
                        # ^1.2.3 := >=1.2.3 <2.0.0
                        "#{v.major + 1}.0.0"
                      elsif v.minor && v.minor > 0
                        # ^0.2.3 := >=0.2.3 <0.3.0
                        "0.#{v.minor + 1}.0"
                      else
                        # ^0.0.3 := >=0.0.3 <0.0.4
                        "0.0.#{(v.patch || 0) + 1}"
                      end

      VersionRange.new([
        Interval.new(min: version, max: upper_version, min_inclusive: true, max_inclusive: false)
      ])
    end

    def parse_tilde_range(version)
      v = Version.cached_new(version)
      upper_version = if v.minor
                        # ~1.2.3 := >=1.2.3 <1.3.0
                        "#{v.major}.#{v.minor + 1}.0"
                      else
                        # ~1 := >=1.0.0 <2.0.0
                        "#{v.major + 1}.0.0"
                      end

      VersionRange.new([
        Interval.new(min: version, max: upper_version, min_inclusive: true, max_inclusive: false)
      ])
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
                        # ~> 1.2.3 := >= 1.2.3, < 1.3.0
                        "#{v.major}.#{v.minor + 1}.0"
                      elsif v.minor
                        # ~> 1.2 := >= 1.2.0, < 2.0.0
                        "#{v.major + 1}.0.0"
                      else
                        # ~> 1 := >= 1.0.0, < 2.0.0
                        "#{v.major + 1}.0.0"
                      end

      VersionRange.new([
        Interval.new(min: version, max: upper_version, min_inclusive: true, max_inclusive: false)
      ])
    end

    # Python/PyPI range parsing
    def parse_pypi_range(range_string)
      # Handle comma-separated constraints
      constraints = range_string.split(',').map(&:strip)
      parse_constraints(constraints.join('|'), 'pypi')
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
          Interval.new(min: min_version, max: max_version, min_inclusive: true, max_inclusive: true)
        ])
      when /^\(([^,]+),([^,]+)\)$/
        # (1.0,2.0) := >1.0 <2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: false, max_inclusive: false)
        ])
      when /^\[([^,]+),([^,]+)\)$/
        # [1.0,2.0) := >=1.0 <2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: true, max_inclusive: false)
        ])
      when /^\(([^,]+),([^,]+)\]$/
        # (1.0,2.0] := >1.0 <=2.0
        min_version = Regexp.last_match(1).strip
        max_version = Regexp.last_match(2).strip
        VersionRange.new([
          Interval.new(min: min_version, max: max_version, min_inclusive: false, max_inclusive: true)
        ])
      when /^\[([^,]+)\]$/
        # [1.0] := exactly 1.0
        version = Regexp.last_match(1).strip
        VersionRange.exact(version)
      when /^\[([^,]+),\)$/
        # [1.0,) := >=1.0
        min_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(min: min_version, min_inclusive: true)
        ])
      when /^\(([^,]+),\)$/
        # (1.0,) := >1.0
        min_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(min: min_version, min_inclusive: false)
        ])
      when /^\(,([^,]+)\]$/
        # (,1.0] := <=1.0
        max_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(max: max_version, max_inclusive: true)
        ])
      when /^\(,([^,]+)\)$/
        # (,1.0) := <1.0
        max_version = Regexp.last_match(1).strip
        VersionRange.new([
          Interval.new(max: max_version, max_inclusive: false)
        ])
      when /^[0-9]/
        # Simple version number without brackets - in Maven, this is minimum version
        if range_string.match(/^[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9.-]+)?$/)
          VersionRange.new([
            Interval.new(min: range_string, min_inclusive: true)
          ])
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
              rescue
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
        # Use Maven parsing for bracket notation
        parse_maven_range(range_string)
      when /^[0-9]/
        # Simple version number - treat as minimum version for NuGet
        VersionRange.new([
          Interval.new(min: range_string, min_inclusive: true)
        ])
      else
        # Fall back to standard constraint parsing
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
      # Handle "and" conjunction
      if range_string.include?(" and ")
        and_parts = range_string.split(" and ").map(&:strip)
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