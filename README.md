# Vers - Version Range Parser for Ruby

A Ruby library for parsing, comparing and sorting versions according to the [VERS specification](https://github.com/package-url/purl-spec/blob/main/VERSION-RANGE-SPEC.rst).

This gem provides tools for working with version ranges across different package managers, using a mathematical interval model internally and supporting the vers specification from the Package URL (PURL) project.

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-red.svg)](https://www.ruby-lang.org/)
[![Gem Version](https://badge.fury.io/rb/vers.svg)](https://rubygems.org/gems/vers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**[Available on RubyGems](https://rubygems.org/gems/vers)** | **[API Documentation](https://rdoc.info/github/andrew/vers)** | **[GitHub Repository](https://github.com/andrew/vers)**

## Features

- **Universal version range parsing** with support for 6 package ecosystems (npm, gem, pypi, maven, debian, rpm)
- **Mathematical interval model** for precise set operations (union, intersection, complement)
- **VERS specification compliance** with full support for the Package URL version range specification
- **Native syntax support** - parse native package manager syntax (^1.2.3, ~>1.0, >=1.0,<2.0, [1.0,2.0))
- **Bidirectional conversion** between native syntax and universal vers URI format
- **Semantic versioning features** - version increment, constraint checking, prerelease handling
- **Comprehensive error handling** with detailed parsing exceptions
- **100% test coverage** with 113 tests and 366 assertions

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
Vers.satisfies?("1.5.0", ">=1.0.0,<2.0.0")  # => true

# Compare versions
Vers.compare("1.2.3", "1.2.4")  # => -1

# Version operations
version = Vers::Version.new("1.2.3")
version.increment_major  # => #<Vers::Version "2.0.0">
version.satisfies?("~> 1.2")  # => true
```

## Supported Package Managers

- **npm**: Caret ranges (^1.2.3), tilde ranges (~1.2.3), hyphen ranges (1.2.3 - 2.3.4)
- **RubyGems**: Pessimistic operator (~> 1.2), standard operators (>=, <=, etc.)
- **PyPI**: Comma-separated constraints (>=1.0,<2.0)
- **Maven**: Bracket notation ([1.0,2.0], (1.0,2.0))
- **Debian/RPM**: Standard comparison operators

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
range = Vers.parse("vers:gem/~>1.0")
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

The gem is available as open source under the terms of the MIT License.

## Code of Conduct

Everyone interacting in the Vers project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/andrew/vers/blob/main/CODE_OF_CONDUCT.md).
