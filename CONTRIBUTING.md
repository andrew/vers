# Contributing to Vers

Thank you for your interest in contributing to the Vers Ruby library! This document provides guidelines and information for contributors.

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Issues

Before creating an issue, please:
1. Search existing issues to avoid duplicates
2. Use the latest version of the gem
3. Provide a clear, descriptive title
4. Include steps to reproduce the issue
5. Share relevant code examples or error messages

### Suggesting Enhancements

Enhancement suggestions are welcome! Please:
1. Check if the enhancement is already requested
2. Explain the use case and expected behavior
3. Consider if it fits the project's scope
4. Be willing to help implement if accepted

### Pull Requests

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b my-new-feature`)
3. **Make** your changes following our coding standards
4. **Add** tests for your changes
5. **Ensure** all tests pass (`rake test`)
6. **Run** the full test suite including any compliance tests
7. **Commit** your changes with clear, descriptive messages
8. **Push** to your branch (`git push origin my-new-feature`)
9. **Create** a Pull Request with a clear description

## Development Setup

### Prerequisites

- Ruby 3.2 or higher
- Bundler gem

### Setup

```bash
git clone https://github.com/andrew/vers.git
cd vers
bundle install
```

### Running Tests

```bash
# Run all tests
rake test

# Run tests with coverage
bundle exec rake test

# Show all available tasks
rake -T
```

### Coding Standards

- Follow Ruby best practices and conventions
- Use meaningful variable and method names
- Add RDoc documentation for public methods
- Keep methods focused and concise
- Follow the existing code style
- Use `frozen_string_literal: true` at the top of all files

### Testing Requirements

All contributions must include appropriate tests:

- **Unit tests** for new functionality
- **Integration tests** for feature interactions
- **Edge case tests** for boundary conditions
- **Error handling tests** for exception cases

### Documentation

- Update the README.md if adding new features
- Add RDoc documentation for complex methods
- Update CHANGELOG.md following the format
- Include examples in documentation

## Project Structure

```
├── lib/
│   ├── vers.rb                 # Main module
│   └── vers/
│       ├── version.rb          # Version class with semantic versioning
│       ├── interval.rb         # Mathematical interval model
│       ├── version_range.rb    # Version range operations
│       ├── constraint.rb       # Individual version constraints
│       └── parser.rb           # Package manager syntax parsers
├── test/                       # Test files
├── VERSION-RANGE-SPEC.rst     # Official specification
└── README.md                  # Project documentation
```

## Adding New Package Manager Support

To add support for a new package manager:

1. **Add parser methods** to `lib/vers/parser.rb`
2. **Include examples** in documentation
3. **Add comprehensive tests** for the new syntax
4. **Update README** with supported syntax examples
5. **Verify** against VERS specification compliance

## Version Range Operations

When working with version ranges:

1. **Use interval model** for internal representation
2. **Test set operations** (union, intersection, complement)
3. **Verify mathematical correctness** of operations
4. **Handle edge cases** like empty and unbounded ranges

## VERS Specification Compliance

This library maintains compliance with the VERS specification:

- All changes must maintain specification compliance
- New features should align with the spec
- Report spec issues upstream when discovered
- Test against official specification examples

## Release Process

Releases are handled by maintainers:

1. Update version in `lib/vers/version.rb`
2. Update `CHANGELOG.md` with changes
3. Run full test suite
4. Create release tag
5. Publish to RubyGems

## Getting Help

- **Issues**: Use GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub discussions for questions
- **Security**: Follow our [Security Policy](SECURITY.md)

## Recognition

Contributors will be recognized in:
- Git commit history
- CHANGELOG.md for significant contributions
- Project documentation where appropriate

## License

By contributing to Vers, you agree that your contributions will be licensed under the [MIT License](LICENSE).

## Development Philosophy

### Mathematical Accuracy

Version ranges are implemented using mathematical interval theory:
- Intervals have clear bounds and inclusivity rules
- Set operations follow mathematical principles
- Edge cases are handled consistently

### Extensibility

The architecture supports easy extension:
- New package managers can be added via parser methods
- Version comparison logic is centralized
- Testing framework supports new syntax validation

### Performance

Consider performance implications:
- Avoid excessive regular expression backtracking
- Cache compiled patterns where appropriate
- Test with large version lists

### Error Handling

Provide clear, actionable error messages:
- Include context about what failed
- Suggest corrections when possible
- Use specific exception types

Thank you for contributing to make Vers better for everyone!