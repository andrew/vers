# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2025-01-25

### Added
- **Comprehensive Benchmark Suite**: Added `rake benchmark` tasks for performance analysis
  - `rake benchmark:parse` - Parsing performance across native and VERS URI formats
  - `rake benchmark:schemes` - Performance comparison across package manager schemes
  - `rake benchmark:memory` - Memory usage and object allocation analysis
  - `rake benchmark:stress` - Complexity stress tests with various input patterns
  - `rake benchmark:all` - Run all benchmarks

### Performance
- **60-75% Performance Improvements** across core operations with zero API changes
- **Version Parsing**: Added caching for Version objects (78K ranges/sec vs 48K previously)
- **Version Comparison**: Optimized comparison logic (1.2M comparisons/sec vs 507K previously)  
- **Constraint Parsing**: Added caching with pre-compiled regex patterns
- **Range Parsing**: Optimized NPM range parsing with pattern caching
- **Containment Checks**: Improved efficiency (257K checks/sec vs 67K previously)

### Internal
- Added LRU-style caching for parsed Version and Constraint objects
- Pre-compiled regex patterns for common NPM range formats
- Optimized version parsing algorithm for dot-separated patterns
- Enhanced parser with range result caching

## [1.0.0] - 2025-01-25

### Added
- **JSON Test Dataset** (`test-suite-data.json`) with 37 comprehensive test cases for cross-language compatibility
- **Enhanced NPM Support**: X-ranges (`1.2.x`), OR logic (`||`), wildcard support, invalid range validation
- **Maven Union Ranges**: Complex multi-range support like `"[2.0,2.3.1] , [2.4.0,2.12.2) , [2.13.0,2.15.0)"`
- **Prerelease Version Handling**: Caret and hyphen ranges with prerelease versions
- **Specification Compliance Tests**: Automated test suite validating VERS spec compliance
- **Cross-Ecosystem Compatibility Tests**: Verify equivalent ranges work across package managers
- **Bidirectional Conversion Tests**: Ensure parsing and regenerating produces equivalent results
- **Enhanced Rake Tasks**: 
  - `rake spec:compliance` - Run VERS specification compliance test suite
  - `rake spec:test_data` - Show JSON test dataset information
- **Comprehensive Error Handling**: Invalid ranges like `"blerg"` and `"git+https://..."` raise proper errors
- **Maven Malformed Range Validation**: Detect and reject invalid bracket notation like `"(1.0.0]"`

### Enhanced
- **NPM Parser**: Added support for empty ranges, X-ranges, OR logic, and invalid range detection
- **Maven Parser**: Fixed union range parsing with proper bracket preservation
- **Test Coverage**: Expanded from 113 to 129 tests with 725 assertions, all passing
- **Documentation**: Added package manager syntax comparison table inspired by Eve Martin-Jones and Elitsa Bankova's presentation

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

[Unreleased]: https://github.com/andrew/vers/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andrew/vers/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/andrew/vers/releases/tag/v0.1.0
