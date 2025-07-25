# frozen_string_literal: true

require_relative "vers/version"
require_relative "vers/interval"
require_relative "vers/version_range"
require_relative "vers/constraint"
require_relative "vers/parser"

##
# Vers - A Ruby gem for parsing, comparing and sorting versions according to the VERS spec
#
# This gem provides tools for working with version ranges across different package managers,
# using a mathematical interval model internally and supporting the vers specification from
# the Package URL (PURL) project.
#
# == Features
#
# * Parse version ranges from multiple package ecosystems (npm, gem, pypi, maven, etc.)
# * Convert between native version range syntax and universal vers URI format
# * Mathematical interval-based operations (union, intersection, complement)
# * Version comparison and containment checking
# * Extensible architecture for adding new package manager support
#
# == Quick Start
#
#   require 'vers'
#
#   # Parse a vers URI
#   range = Vers.parse("vers:npm/>=1.2.3|<2.0.0")
#   range.contains?("1.5.0")  # => true
#   range.contains?("2.1.0")  # => false
#
#   # Parse native package manager syntax
#   npm_range = Vers.parse_native("^1.2.3", "npm")
#   gem_range = Vers.parse_native("~> 1.0", "gem")
#
#   # Check version containment
#   Vers.satisfies?("1.5.0", ">=1.0.0,<2.0.0")  # => true
#
#   # Compare versions
#   Vers.compare("1.2.3", "1.2.4")  # => -1
#
# == Mathematical Model
#
# Internally, all version ranges are represented as mathematical intervals,
# similar to those used in mathematics (e.g., [1.0.0, 2.0.0) represents
# versions from 1.0.0 inclusive to 2.0.0 exclusive).
#
# This allows for precise set operations like union, intersection, and
# complement, regardless of the original package manager syntax.
#
# @see https://github.com/package-url/purl-spec/blob/main/VERSION-RANGE-SPEC.rst
# @author Andrew Nesbitt
#
module Vers
  class Error < StandardError; end

  # Default parser instance for convenience methods
  @@parser = Parser.new

  ##
  # Parses a vers URI string into a VersionRange
  #
  # @param vers_string [String] The vers URI string (e.g., "vers:npm/>=1.2.3|<2.0.0")
  # @return [VersionRange] The parsed version range
  # @raise [ArgumentError] if the vers string is invalid
  #
  # == Examples
  #
  #   Vers.parse("vers:npm/>=1.2.3|<2.0.0")
  #   Vers.parse("vers:gem/~>1.0")
  #   Vers.parse("*")  # unbounded range
  #
  def self.parse(vers_string)
    @@parser.parse(vers_string)
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
  #   Vers.parse_native("^1.2.3", "npm")      # npm caret range
  #   Vers.parse_native("~> 1.0", "gem")      # gem pessimistic operator
  #   Vers.parse_native(">=1.0,<2.0", "pypi") # python constraints
  #
  def self.parse_native(range_string, scheme)
    @@parser.parse_native(range_string, scheme)
  end

  ##
  # Converts a VersionRange to a vers URI string
  #
  # @param version_range [VersionRange] The version range to convert
  # @param scheme [String] The package manager scheme
  # @return [String] The vers URI string
  #
  def self.to_vers_string(version_range, scheme)
    @@parser.to_vers_string(version_range, scheme)
  end

  ##
  # Checks if a version satisfies a version range constraint
  #
  # @param version [String] The version to check
  # @param constraint [String] The version constraint (vers URI or native format)
  # @param scheme [String, nil] The package manager scheme (if not using vers URI)
  # @return [Boolean] true if the version satisfies the constraint
  #
  # == Examples
  #
  #   Vers.satisfies?("1.5.0", "vers:npm/>=1.0.0|<2.0.0")  # => true
  #   Vers.satisfies?("1.5.0", "^1.2.3", "npm")            # => true
  #
  def self.satisfies?(version, constraint, scheme = nil)
    range = if scheme
              parse_native(constraint, scheme)
            else
              parse(constraint)
            end
    
    range.contains?(version)
  end

  ##
  # Compares two version strings
  #
  # @param a [String] First version string
  # @param b [String] Second version string
  # @return [Integer] -1 if a < b, 0 if a == b, 1 if a > b
  #
  # == Examples
  #
  #   Vers.compare("1.2.3", "1.2.4")  # => -1
  #   Vers.compare("2.0.0", "1.9.9")  # => 1
  #   Vers.compare("1.0.0", "1.0.0")  # => 0
  #
  def self.compare(a, b)
    Version.compare(a, b)
  end

  ##
  # Normalizes a version string to a consistent format
  #
  # @param version_string [String] The version string to normalize
  # @return [String] The normalized version string
  #
  def self.normalize(version_string)
    Version.normalize(version_string)
  end

  ##
  # Checks if a version string is valid
  #
  # @param version_string [String] The version string to validate
  # @return [Boolean] true if the version is valid
  #
  def self.valid?(version_string)
    Version.valid?(version_string)
  end

  ##
  # Creates an exact version range
  #
  # @param version [String] The exact version
  # @return [VersionRange] A range containing only the specified version
  #
  def self.exact(version)
    VersionRange.exact(version)
  end

  ##
  # Creates a greater-than version range
  #
  # @param version [String] The minimum version
  # @param inclusive [Boolean] Whether to include the minimum version
  # @return [VersionRange] A range for versions greater than (or equal to) the specified version
  #
  def self.greater_than(version, inclusive: false)
    VersionRange.greater_than(version, inclusive: inclusive)
  end

  ##
  # Creates a less-than version range
  #
  # @param version [String] The maximum version
  # @param inclusive [Boolean] Whether to include the maximum version
  # @return [VersionRange] A range for versions less than (or equal to) the specified version
  #
  def self.less_than(version, inclusive: false)
    VersionRange.less_than(version, inclusive: inclusive)
  end

  ##
  # Creates an unbounded version range (matches all versions)
  #
  # @return [VersionRange] An unbounded range
  #
  def self.unbounded
    VersionRange.unbounded
  end

  ##
  # Creates an empty version range (matches no versions)
  #
  # @return [VersionRange] An empty range
  #
  def self.empty
    VersionRange.empty
  end
end
