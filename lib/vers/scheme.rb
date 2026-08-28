# frozen_string_literal: true

module Vers
  module Scheme
    extend self

    ALIASES = {
      "rubygems" => "gem",
      "debian" => "deb",
      "golang" => "go",
      "elixir" => "hex",
      "alpine" => "apk"
    }.freeze

    HANDLERS = {
      "alpm" => ALPMVersion,
      "apk" => APKVersion,
      "bazel" => BazelVersion,
      "cargo" => CargoVersion,
      "composer" => ComposerVersion,
      "conan" => ConanVersion,
      "deb" => DebianVersion,
      "datetime" => DatetimeVersion,
      "gem" => GemVersion,
      "gentoo" => GentooVersion,
      "go" => GoVersion,
      "hex" => SemverVersion,
      "intdot" => IntDotVersion,
      "lexicographic" => LexicographicVersion,
      "maven" => MavenVersion,
      "nginx" => SemverVersion,
      "npm" => NpmVersion,
      "nuget" => NuGetVersion,
      "openssl" => OpenSSLVersion,
      "pub" => PubVersion,
      "pypi" => PyPIVersion,
      "rpm" => RPMVersion,
      "semver" => SemverVersion
    }.freeze

    def canonical(value)
      return nil if value.nil?

      scheme = value.to_s.downcase
      ALIASES.fetch(scheme, scheme)
    end

    def handler(value)
      HANDLERS[canonical(value)]
    end
  end
end
