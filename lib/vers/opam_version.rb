# frozen_string_literal: true

require_relative "distribution_version"

module Vers
  # opam orders versions with the Debian algorithm, without an epoch
  # and without requiring a leading digit.
  module OpamVersion
    extend self

    PATTERN = /\A[0-9A-Za-z\-_+.~]+\z/

    def compare(left, right)
      left_upstream, left_revision = split(left)
      right_upstream, right_revision = split(right)

      comparison = DebianVersion.compare_part(left_upstream, right_upstream)
      return comparison unless comparison.zero?

      DebianVersion.compare_part(left_revision, right_revision)
    end

    # opam compares the part after the last hyphen only when the parts before it are equal.
    def split(value)
      version = value.to_s
      separator = version.rindex("-")
      separator ? [version[0...separator], version[(separator + 1)..]] : [version, ""]
    end

    def valid?(value)
      value.to_s.strip.match?(PATTERN)
    end

    def normalize(value)
      value.to_s.strip
    end

    def prerelease?(value)
      value.to_s.include?("~")
    end
  end
end
