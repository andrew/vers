# frozen_string_literal: true

module Vers
  ##
  # Represents a single version constraint (e.g., ">=1.2.3", "!=2.0.0")
  # 
  # A constraint consists of an operator and a version. This class handles
  # parsing constraint strings and converting them to intervals.
  #
  # == Examples
  #
  #   constraint = Vers::Constraint.new(">=", "1.2.3")
  #   constraint.operator  # => ">="
  #   constraint.version   # => "1.2.3"
  #   constraint.to_interval # => [1.2.3,+∞)
  #
  class Constraint
    # Valid constraint operators as defined in the vers spec
    OPERATORS = %w[= != < <= > >=].freeze
    
    # Pre-compiled regex patterns for performance
    OPERATOR_REGEX = /\A(!=|>=|<=|[<>=])/
    
    # Cache for parsed constraints
    @@constraint_cache = {}
    @@cache_size_limit = 500

    attr_reader :operator, :version

    ##
    # Creates a new constraint with the given operator and version
    #
    # @param operator [String] The constraint operator (=, !=, <, <=, >, >=)
    # @param version [String] The version string
    # @raise [ArgumentError] if operator is invalid
    #
    def initialize(operator, version)
      raise ArgumentError, "Invalid operator: #{operator}" unless OPERATORS.include?(operator)
      
      @operator = operator
      @version = version
    end

    ##
    # Parses a constraint string into operator and version components
    #
    # @param constraint_string [String] The constraint string to parse
    # @return [Constraint] A new constraint object
    # @raise [ArgumentError] if the constraint string is invalid
    #
    # == Examples
    #
    #   Vers::Constraint.parse(">=1.2.3")  # => #<Vers::Constraint:0x... @operator=">=", @version="1.2.3">
    #   Vers::Constraint.parse("!=2.0.0")  # => #<Vers::Constraint:0x... @operator="!=", @version="2.0.0">
    #
    def self.parse(constraint_string)
      # Limit cache size to prevent memory bloat
      if @@constraint_cache.size >= @@cache_size_limit
        @@constraint_cache.clear
      end
      
      # Return cached constraint if available
      return @@constraint_cache[constraint_string] if @@constraint_cache.key?(constraint_string)
      
      constraint = parse_uncached(constraint_string)
      @@constraint_cache[constraint_string] = constraint
      constraint
    end
    
    ##
    # Internal uncached parsing method
    #
    def self.parse_uncached(constraint_string)
      # Use regex for faster operator detection
      if match = constraint_string.match(OPERATOR_REGEX)
        operator = match[1]
        version = constraint_string[operator.length..-1]
        raise ArgumentError, "Invalid constraint format: #{constraint_string}" if version.empty?
        new(operator, version)
      else
        # No operator found, treat as exact match
        new("=", constraint_string)
      end
    end

    ##
    # Converts this constraint to an interval representation
    #
    # @return [Interval] The interval representation of this constraint
    #
    # == Examples
    #
    #   Vers::Constraint.new(">=", "1.2.3").to_interval  # => [1.2.3,+∞)
    #   Vers::Constraint.new("=", "1.0.0").to_interval   # => [1.0.0,1.0.0]
    #
    def to_interval
      case operator
      when "="
        Interval.exact(version)
      when "!="
        # != constraints need special handling in ranges - they create exclusions
        nil
      when ">"
        Interval.greater_than(version, inclusive: false)
      when ">="
        Interval.greater_than(version, inclusive: true)
      when "<"
        Interval.less_than(version, inclusive: false)
      when "<="
        Interval.less_than(version, inclusive: true)
      end
    end

    ##
    # Returns true if this is an exclusion constraint (!=)
    #
    # @return [Boolean]
    #
    def exclusion?
      operator == "!="
    end

    ##
    # Checks if a version satisfies this constraint
    #
    # @param version_string [String] The version to check
    # @return [Boolean] true if the version satisfies the constraint
    #
    def satisfies?(version_string)
      comparison = Version.compare(version_string, version)
      
      case operator
      when "="
        comparison == 0
      when "!="
        comparison != 0
      when ">"
        comparison > 0
      when ">="
        comparison >= 0
      when "<"
        comparison < 0
      when "<="
        comparison <= 0
      end
    end

    ##
    # String representation of this constraint
    #
    # @return [String] The constraint as a string
    #
    def to_s
      "#{operator}#{version}"
    end

    def ==(other)
      other.is_a?(Constraint) && operator == other.operator && version == other.version
    end

    def hash
      [operator, version].hash
    end
  end
end