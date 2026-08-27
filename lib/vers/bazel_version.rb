# frozen_string_literal: true

module Vers
  module BazelVersion
    VERSION_REGEX = /\A(?<release>[a-zA-Z0-9.]+)(?:-(?<prerelease>[a-zA-Z0-9.-]+))?(?:\+[a-zA-Z0-9.-]+)?\z/
    MAX_NUMERIC_IDENTIFIER = (2**64) - 1

    Identifier = Struct.new(:numeric, :number, :text, keyword_init: true)
    ParsedVersion = Struct.new(:release, :prerelease, :empty, keyword_init: true)

    module_function

    def compare(a, b)
      return 0 if a == b

      version_a = parse(a)
      version_b = parse(b)

      return 1 if version_a.empty && !version_b.empty
      return -1 if !version_a.empty && version_b.empty

      release_comparison = compare_identifiers(version_a.release, version_b.release)
      return release_comparison unless release_comparison == 0

      return 1 if version_a.prerelease.empty? && !version_b.prerelease.empty?
      return -1 if !version_a.prerelease.empty? && version_b.prerelease.empty?

      compare_identifiers(version_a.prerelease, version_b.prerelease)
    end

    def valid?(version)
      parse(version)
      true
    rescue ArgumentError
      false
    end

    def stable?(version)
      parse(version).prerelease.empty?
    rescue ArgumentError
      false
    end

    def prerelease?(version)
      !parse(version).prerelease.empty?
    rescue ArgumentError
      false
    end

    def parse(version)
      raise ArgumentError, "Invalid Bazel version: #{version.inspect}" unless version.is_a?(String)

      if version.empty?
        return ParsedVersion.new(release: [], prerelease: [], empty: true)
      end

      match = VERSION_REGEX.match(version)
      raise ArgumentError, "Invalid Bazel version: #{version.inspect}" unless match

      ParsedVersion.new(
        release: parse_identifiers(match[:release], version),
        prerelease: match[:prerelease] ? parse_identifiers(match[:prerelease], version) : [],
        empty: false
      )
    end

    def parse_identifiers(value, version)
      value.split(".", -1).map do |identifier|
        raise ArgumentError, "Invalid Bazel version: #{version}" if identifier.empty?

        if identifier.match?(/\A[0-9]+\z/)
          number = identifier.to_i
          if number > MAX_NUMERIC_IDENTIFIER
            raise ArgumentError, "Numeric Bazel version identifier is too large: #{identifier}"
          end

          Identifier.new(numeric: true, number: number, text: identifier)
        else
          Identifier.new(numeric: false, number: 0, text: identifier)
        end
      end
    end

    def compare_identifiers(identifiers_a, identifiers_b)
      [identifiers_a.length, identifiers_b.length].min.times do |index|
        comparison = compare_identifier(identifiers_a[index], identifiers_b[index])
        return comparison unless comparison == 0
      end

      identifiers_a.length <=> identifiers_b.length
    end

    def compare_identifier(identifier_a, identifier_b)
      if identifier_a.numeric != identifier_b.numeric
        return identifier_a.numeric ? -1 : 1
      end

      if identifier_a.numeric
        number_comparison = identifier_a.number <=> identifier_b.number
        return number_comparison unless number_comparison == 0
      end

      identifier_a.text <=> identifier_b.text
    end
  end
end
