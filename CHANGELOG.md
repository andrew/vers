# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-25

### Added

- **Initial release** of Vers Ruby gem for parsing, comparing and sorting versions according to the VERS specification
- **Mathematical interval model** for precise version range representation
- **Universal version range parsing** with support for 6 package ecosystems:
  - npm (Node.js): Caret ranges (^1.2.3), tilde ranges (~1.2.3), hyphen ranges (1.2.3 - 2.3.4)
  - gem (RubyGems): Pessimistic operator (~> 1.2), standard operators (>=, <=, etc.)
  - pypi (Python): Comma-separated constraints (>=1.0,<2.0), exclusions (!=1.5.0)
  - maven (Java): Bracket notation ([1.0,2.0], (1.0,2.0), [1.0,2.0))
  - debian: Standard comparison operators (>=1.0.0, <<2.0.0)
  - rpm: Standard comparison operators (>=1.0.0, <=2.0.0)
- **VERS URI format support** - parse and generate vers URI strings (e.g., `vers:npm/>=1.2.3|<2.0.0`)
- **Bidirectional conversion** between native package manager syntax and universal vers URI format
- **Set operations** on version ranges:
  - Union: combine multiple version ranges
  - Intersection: find overlapping versions
  - Complement: find versions NOT in a range
  - Exclusion: remove specific versions from ranges
- **Semantic versioning features** inspired by the semantic gem:
  - Version increment methods (`increment_major`, `increment_minor`, `increment_patch`)
  - Pessimistic constraint checking (`version.satisfies?("~> 1.2")`)
  - Prerelease and build metadata support
  - Version comparison and normalization
- **Comprehensive error handling** with detailed parsing exceptions
- **Core classes**:
  - `Vers::Version` - semantic version parsing and comparison
  - `Vers::Interval` - mathematical interval representation with bounds
  - `Vers::VersionRange` - collection of intervals with set operations
  - `Vers::Constraint` - individual version constraints (>=, <, etc.)
  - `Vers::Parser` - extensible translation layer for package manager syntaxes
- **Complete test coverage** with 113 tests and 366 assertions
- **Comprehensive RDoc documentation** for all public APIs
- **Development tooling**:
  - Rake tasks for specification validation and examples
  - Security policy and contributing guidelines
  - GitHub Actions-ready project structure

### Documentation

- **README.md** with comprehensive usage examples and API documentation
- **CONTRIBUTING.md** with development guidelines and project structure
- **SECURITY.md** with vulnerability reporting procedures
- **VERSION-RANGE-SPEC.rst** - official VERS specification included in repository
- **RDoc documentation** for all classes and methods

### Dependencies

- **Ruby 3.2+** required
- **No runtime dependencies** - pure Ruby implementation
- **Minitest** for testing (development dependency only)

[Unreleased]: https://github.com/andrew/vers/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/andrew/vers/releases/tag/v0.1.0
