# frozen_string_literal: true

module Vers
  VERSION = "1.0.0"

  ##
  # Handles version comparison and normalization across different package ecosystems.
  #
  # This class provides version comparison functionality that can handle different
  # versioning schemes used by various package managers (npm, gem, pypi, etc.).
  #
  # == Examples
  #
  #   Vers::Version.compare("1.2.3", "1.2.4")     # => -1
  #   Vers::Version.compare("2.0.0", "1.9.9")     # => 1
  #   Vers::Version.compare("1.0.0", "1.0.0")     # => 0
  #
  class Version
    # Regex for parsing semantic version components including build metadata
    SEMANTIC_VERSION_REGEX = /\A(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([^+]+))?(?:\+(.+))?\z/

    attr_reader :major, :minor, :patch, :prerelease, :build

    ##
    # Creates a new Version object
    #
    # @param version_string [String] The version string to parse
    #
    def initialize(version_string)
      @original = version_string.to_s
      parse_version
    end

    ##
    # Compares two version strings
    #
    # @param a [String] First version string
    # @param b [String] Second version string
    # @return [Integer] -1 if a < b, 0 if a == b, 1 if a > b
    #
    def self.compare(a, b)
      return 0 if a == b
      return -1 if a.nil?
      return 1 if b.nil?

      version_a = new(a)
      version_b = new(b)
      
      version_a <=> version_b
    end

    ##
    # Normalizes a version string to a consistent format
    #
    # @param version_string [String] The version string to normalize
    # @return [String] The normalized version string
    #
    def self.normalize(version_string)
      new(version_string).to_s
    end

    ##
    # Checks if a version string is valid
    #
    # @param version_string [String] The version string to validate
    # @return [Boolean] true if the version is valid
    #
    def self.valid?(version_string)
      new(version_string)
      true
    rescue ArgumentError
      false
    end

    ##
    # Version comparison operator
    #
    # @param other [Version] The other version to compare to
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      return 0 if @original == other.to_s

      # Compare major.minor.patch numerically
      major_cmp = (major || 0) <=> (other.major || 0)
      return major_cmp unless major_cmp == 0

      minor_cmp = (minor || 0) <=> (other.minor || 0)
      return minor_cmp unless minor_cmp == 0

      patch_cmp = (patch || 0) <=> (other.patch || 0)
      return patch_cmp unless patch_cmp == 0

      # Handle prerelease comparison
      return 1 if prerelease.nil? && !other.prerelease.nil?
      return -1 if !prerelease.nil? && other.prerelease.nil?
      return 0 if prerelease.nil? && other.prerelease.nil?

      compare_prerelease(prerelease, other.prerelease)
    end

    ##
    # String representation of the version
    #
    # @return [String] The normalized version string
    #
    def to_s
      version = "#{major || 0}"
      version += ".#{minor || 0}"
      version += ".#{patch || 0}"
      version += "-#{prerelease}" if prerelease
      version
    end

    def ==(other)
      other.is_a?(Version) && self <=> other == 0
    end

    def <(other)
      (self <=> other) < 0
    end

    def <=(other)
      (self <=> other) <= 0
    end

    def >(other)
      (self <=> other) > 0
    end

    def >=(other)
      (self <=> other) >= 0
    end

    def hash
      [@original].hash
    end

    ##
    # Increments the specified component of the version
    #
    # @param component [Symbol] The component to increment (:major, :minor, :patch)
    # @return [Version] A new Version object with the incremented component
    #
    # == Examples
    #
    #   version = Vers::Version.new("1.2.3")
    #   version.increment(:major)  # => #<Vers::Version "2.0.0">
    #   version.increment(:minor)  # => #<Vers::Version "1.3.0">
    #   version.increment(:patch)  # => #<Vers::Version "1.2.4">
    #
    def increment(component)
      case component
      when :major
        self.class.new("#{major + 1}.0.0")
      when :minor
        self.class.new("#{major}.#{(minor || 0) + 1}.0")
      when :patch
        self.class.new("#{major}.#{minor || 0}.#{(patch || 0) + 1}")
      else
        raise ArgumentError, "Invalid component: #{component}. Must be :major, :minor, or :patch"
      end
    end

    ##
    # Increments the major version component
    #
    # @return [Version] A new Version object with incremented major version
    #
    def increment_major
      increment(:major)
    end

    ##
    # Increments the minor version component
    #
    # @return [Version] A new Version object with incremented minor version
    #
    def increment_minor
      increment(:minor)
    end

    ##
    # Increments the patch version component
    #
    # @return [Version] A new Version object with incremented patch version
    #
    def increment_patch
      increment(:patch)
    end

    ##
    # Checks if this version satisfies a constraint using pessimistic operator logic
    #
    # @param constraint [String] The constraint string (e.g., "~> 1.2")
    # @return [Boolean] true if this version satisfies the constraint
    #
    # == Examples
    #
    #   version = Vers::Version.new("1.2.5")
    #   version.satisfies?("~> 1.2")    # => true (>= 1.2.0, < 1.3.0)
    #   version.satisfies?("~> 1.2.3")  # => true (>= 1.2.3, < 1.3.0)
    #   version.satisfies?("~> 1.3")    # => false
    #
    def satisfies?(constraint)
      if constraint.start_with?("~>")
        # Pessimistic constraint
        base_version = constraint.sub(/^~>\s*/, "").strip
        base = self.class.new(base_version)
        
        # Must be >= base version
        return false if self < base
        
        # Must be < next significant version
        if base.patch && base.patch > 0
          # ~> 1.2.3 means >= 1.2.3, < 1.3.0
          upper_bound = self.class.new("#{base.major}.#{(base.minor || 0) + 1}.0")
        elsif base.minor
          # ~> 1.2 means >= 1.2.0, < 1.3.0  
          upper_bound = self.class.new("#{base.major}.#{(base.minor || 0) + 1}.0")
        else
          # ~> 1 means >= 1.0.0, < 2.0.0
          upper_bound = self.class.new("#{base.major + 1}.0.0")
        end
        
        self < upper_bound
      else
        # For other constraints, delegate to constraint parsing
        # This would require the Constraint class, so for now return true
        true
      end
    end

    ##
    # Checks if this is a stable release (no prerelease components)
    #
    # @return [Boolean] true if this is a stable release
    #
    def stable?
      prerelease.nil?
    end

    ##
    # Checks if this is a prerelease version
    #
    # @return [Boolean] true if this is a prerelease version
    #
    def prerelease?
      !prerelease.nil?
    end

    ##
    # Gets the semantic version components as a hash
    #
    # @return [Hash] Hash with :major, :minor, :patch, :prerelease, :build keys
    #
    def to_h
      {
        major: major,
        minor: minor,
        patch: patch,
        prerelease: prerelease,
        build: build
      }
    end

    ##
    # Creates a new Version with the same major.minor but patch set to 0
    #
    # @return [Version] A new Version object with patch reset to 0
    #
    def base
      self.class.new("#{major}.#{minor || 0}.0")
    end

    private

    def parse_version
      # Handle simple numeric versions
      if @original.match(/^\d+$/)
        @major = @original.to_i
        return
      end

      # Try semantic version parsing first
      if match = @original.match(SEMANTIC_VERSION_REGEX)
        @major = match[1]&.to_i
        @minor = match[2]&.to_i
        @patch = match[3]&.to_i
        @prerelease = match[4]
        @build = match[5]
        return
      end

      # Fall back to splitting on dots/dashes
      parts = @original.split(/[.-]/)
      
      if parts.empty?
        raise ArgumentError, "Invalid version format: #{@original}"
      end

      @major = parts[0]&.to_i
      @minor = parts[1]&.to_i if parts[1]
      @patch = parts[2]&.to_i if parts[2]
      
      # Everything after patch is considered prerelease
      if parts.length > 3
        @prerelease = parts[3..-1].join('.')
      end
    end

    def compare_prerelease(pre_a, pre_b)
      parts_a = pre_a.split('.')
      parts_b = pre_b.split('.')
      
      max_length = [parts_a.length, parts_b.length].max
      
      0.upto(max_length - 1) do |i|
        part_a = parts_a[i]
        part_b = parts_b[i]
        
        return -1 if part_a.nil?
        return 1 if part_b.nil?
        
        # Try numeric comparison first
        if part_a.match(/^\d+$/) && part_b.match(/^\d+$/)
          numeric_cmp = part_a.to_i <=> part_b.to_i
          return numeric_cmp unless numeric_cmp == 0
        else
          string_cmp = part_a <=> part_b
          return string_cmp unless string_cmp == 0
        end
      end
      
      0
    end
  end
end
