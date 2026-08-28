# Vers - Version Range Parser for Ruby

A Ruby library for parsing VERS ranges and applying package-manager version rules. It supports canonical VERS strings, native range syntax, scheme-aware comparison, validation, normalization, and release classification.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-red.svg)](https://www.ruby-lang.org/)
[![Gem Version](https://badge.fury.io/rb/vers.svg)](https://rubygems.org/gems/vers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[Available on RubyGems](https://rubygems.org/gems/vers)** | **[API Documentation](https://rdoc.info/github/andrew/vers)** | **[GitHub Repository](https://github.com/andrew/vers)**

## Features

- Parse and serialize canonical VERS strings.
- Parse native ranges for npm, Cargo, RubyGems, PyPI, Composer, Pub, Maven, NuGet, Hex, Go, Debian, RPM, Conan, OpenSSL, and nginx.
- Compare, validate, normalize, clean, and classify versions with package-manager rules.
- Combine ranges with union, intersection, complement, and exclusions.
- Check containment with the range's version scheme.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'vers'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install vers
```

## Quick Start

```ruby
require 'vers'

# Parse a vers URI
range = Vers.parse("vers:npm/>=1.2.3|<2.0.0")
range.contains?("1.5.0")  # => true
range.contains?("2.1.0")  # => false

# Parse native package manager syntax
npm_range = Vers.parse_native("^1.2.3", "npm")
gem_range = Vers.parse_native("~> 1.0", "gem")

# Check version containment
Vers.satisfies?("1.5.0", ">=1.0.0,<2.0.0", "pypi")  # => true

# Compare versions
Vers.compare("1.2.3", "1.2.4")  # => -1

# Use Bazel's module version rules
Vers.compare_with_scheme("0.7.1", "0.7.1.bcr.1", "bazel")  # => -1
Vers.valid?("35.1", "bazel")                                # => true
Vers.normalize("v01.02", "composer")                        # => "1.2.0"
Vers.clean(" v1.2 ", "npm")                                 # => "1.2.0"
Vers.stable?("0.7.1.bcr.1", "bazel")                        # => true
Vers.prerelease?("36.0-rc2", "bazel")                       # => true

# Version operations
version = Vers::Version.new("1.2.3")
version.increment_major  # => #<Vers::Version "2.0.0">
version.satisfies?("~> 1.2")  # => true
```

## Version Schemes

Scheme-aware version operations support these groups:

- SemVer family: SemVer, npm, Cargo, Go modules, Hex, and nginx.
- Language registries: RubyGems, PyPI, Composer, Pub, Maven, and NuGet.
- Distribution packages: Debian, RPM, APK, Gentoo, and ALPM.
- Other formats: Bazel, Conan, OpenSSL, integer-dot, RFC 3339 datetime, and lexicographic versions.

The aliases `rubygems`, `debian`, `golang`, `elixir`, and `alpine` map to their canonical schemes. Unknown schemes keep the generic version behavior. Bazel is an implementation-defined scheme in this library and remains separate from the VERS specification types.

Native range parsing includes npm and Cargo caret, tilde, wildcard, hyphen, AND, and OR forms; Composer stability and branch forms; Pub caret ranges; RubyGems pessimistic ranges; PyPI specifiers; Maven and NuGet bracket ranges; Conan compatible ranges; OpenSSL exact-version lists; and nginx plus ranges. Other schemes accept standard VERS comparison operators.

## Mathematical Model

Internally, all version ranges are represented as mathematical intervals, similar to those used in mathematics:

- `[1.0.0, 2.0.0)` represents versions from 1.0.0 (inclusive) to 2.0.0 (exclusive)
- `(1.0.0, 2.0.0]` represents versions from 1.0.0 (exclusive) to 2.0.0 (inclusive)

This allows for precise set operations like union, intersection, and complement, regardless of the original package manager syntax.

## Usage Examples

### Basic Version Range Parsing

```ruby
require 'vers'

# Parse vers URI format
range = Vers.parse("vers:npm/>=1.2.3|<2.0.0")
puts range.contains?("1.5.0")  # => true
puts range.contains?("2.1.0")  # => false

# Parse native package manager syntax
npm_range = Vers.parse_native("^1.2.3", "npm")
gem_range = Vers.parse_native("~> 1.0", "gem")
pypi_range = Vers.parse_native(">=1.0,<2.0", "pypi")
maven_range = Vers.parse_native("[1.0,2.0)", "maven")
```

### Creating Version Ranges

```ruby
# Create exact version range
exact = Vers.exact("1.2.3")
puts exact.contains?("1.2.3")  # => true
puts exact.contains?("1.2.4")  # => false

# Create comparison ranges
greater = Vers.greater_than("1.0.0", inclusive: true)
less = Vers.less_than("2.0.0", inclusive: false)

# Create unbounded and empty ranges
all_versions = Vers.unbounded
no_versions = Vers.empty
```

### Converting Between Formats

```ruby
# Parse native syntax and convert to vers URI
npm_range = Vers.parse_native("^1.2.3", "npm")
vers_string = Vers.to_vers_string(npm_range, "npm")
puts vers_string  # => "vers:npm/>=1.2.3|<2.0.0"

# Parse vers URI and use in your application
range = Vers.parse_native("~>1.0", "gem")
puts range.contains?("1.5.0")  # => true
```

### Set Operations on Version Ranges

```ruby
range1 = Vers.parse("vers:npm/>=1.0.0|<2.0.0")
range2 = Vers.parse("vers:npm/>=1.5.0|<3.0.0")

# Union: versions in either range
union = range1.union(range2)
puts union.contains?("0.9.0")  # => false
puts union.contains?("1.2.0")  # => true
puts union.contains?("2.5.0")  # => true

# Intersection: versions in both ranges
intersection = range1.intersect(range2)
puts intersection.contains?("1.2.0")  # => false
puts intersection.contains?("1.7.0")  # => true
puts intersection.contains?("2.5.0")  # => false

# Complement: versions NOT in range
complement = range1.complement
puts complement.contains?("0.5.0")  # => true
puts complement.contains?("1.5.0")  # => false

# Exclusions: remove specific versions
excluded = range1.exclude("1.5.0")
puts excluded.contains?("1.4.0")  # => true
puts excluded.contains?("1.5.0")  # => false
puts excluded.contains?("1.6.0")  # => true
```

### Version Comparison and Manipulation

```ruby
version = Vers::Version.new("1.2.3-alpha.1+build.123")

# Access version components
puts version.major      # => 1
puts version.minor      # => 2
puts version.patch      # => 3
puts version.prerelease # => "alpha.1"
puts version.build      # => "build.123"

# Compare versions
puts Vers.compare("1.2.3", "1.2.4")  # => -1
puts Vers.compare("2.0.0", "1.9.9")  # => 1
puts Vers.compare("1.0.0", "1.0.0")  # => 0

# Increment versions (returns new Version objects)
puts version.increment_major  # => #<Vers::Version "2.0.0">
puts version.increment_minor  # => #<Vers::Version "1.3.0">  
puts version.increment_patch  # => #<Vers::Version "1.2.4">

# Version properties
puts version.stable?      # => false (has prerelease)
puts version.prerelease?  # => true
puts version.to_h         # => {major: 1, minor: 2, patch: 3, ...}
```

### Constraint Checking

```ruby
version = Vers::Version.new("1.2.5")

# Pessimistic constraint checking (Ruby-style)
puts version.satisfies?("~> 1.2")    # => true  (>= 1.2.0, < 1.3.0)
puts version.satisfies?("~> 1.2.3")  # => true  (>= 1.2.3, < 1.3.0)
puts version.satisfies?("~> 1.3")    # => false

# General satisfaction checking
puts Vers.satisfies?("1.5.0", "vers:npm/>=1.0.0|<2.0.0")  # => true
puts Vers.satisfies?("1.5.0", "^1.2.3", "npm")            # => true
```

## Specification Compliance

This gem implements the [PURL Version Range Specification](https://github.com/package-url/purl-spec/blob/main/VERSION-RANGE-SPEC.rst), providing a universal way to express version ranges across different software packaging ecosystems.

Learn more about the motivation and design behind VERS in the [presentation from Open Source Summit NA 2025](https://www.youtube.com/watch?v=EU-TodN27rM) ([slides PDF](https://static.sched.com/hosted_files/ossna2025/74/We%20need%20a%20standard%20for%20open%20source%20package%20requirements.pdf)) by Eve Martin-Jones and Elitsa Bankova. The following table from their talk shows how different package managers express the same version constraints:

| Operator | NPM | Cargo | Carthage | RubyGems | PyPI | Maven | NuGet |
|----------|-----|-------|----------|----------|------|-------|--------|
| **behavior with no op** | 1.0.0 | ^1.0.0⁴ | illegal | 1.0.0 | illegal | *⁵ | >=1.0 |
| **= ==** | =1.0 | = | == | = | == | [1.0]⁵ | [1.0]⁸ |
| **>** | > | > | | > | > | (1.0,) | (1.0,) |
| **>=** | >= | >= | >= | >= | >= | 1.0⁵ | 1.0⁷ᵇᵃ |
| **<** | < | < | | < | < | (,1.0) | (,1.0) |
| **<=** | <= | <= | | <= | <= | (,1.0] | (,1.0] |
| **!=** | | | | != | != | | |
| **^** | ^ | ^² | | | | | |
| **~** | ~, ~>¹ | ~ | | | ~= | | |
| **~>** | ¹ | | ~> | ~> | | | |
| **wildcards** | * x X | * x X | | | * | * | |
| **OR** | \|\| | | | | | , | |
| **AND** | space | , | | ,³ | , | | |
| **RANGE** | - | | | | | [,],(,)⁶ | [,],(,) |

This complexity across ecosystems is exactly why VERS provides a universal format that works consistently across all package managers.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/andrew/vers. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/andrew/vers/blob/main/CODE_OF_CONDUCT.md).

## Related Projects

- [purl](https://github.com/andrew/purl) - Ruby implementation of Package URL (PURL)
- [semantic_range](https://github.com/librariesio/semantic_range) - Semantic version parsing (JavaScript style)
- [univers](https://github.com/package-url/univers) - Python implementation of version ranges
- [versatile](https://github.com/package-url/versatile) - Java implementation of version ranges

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).

## Code of Conduct

Everyone interacting in the Vers project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/andrew/vers/blob/main/CODE_OF_CONDUCT.md).
