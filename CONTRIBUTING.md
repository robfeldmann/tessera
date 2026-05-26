# Contributing to Tessera

Thank you for your interest in contributing to Tessera! This document provides guidelines
and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When
creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots if applicable
- Environment details (Swift version, platform, etc.)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- A clear and descriptive title
- A detailed description of the proposed feature
- Any relevant examples or mockups
- Explanation of why this enhancement would be useful

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run checks and tests (`just ci`)
5. Commit your changes (`git commit -m 'feat: Adds amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

### Prerequisites

- Swift 6.3 or later
- Xcode 26 or later (for macOS development)

### Installing Dependencies (Recommended)

We recommend using [Homebrew](https://brew.sh/) to manage local development tools. We
provide a `Brewfile` to install everything at once:

```sh
brew bundle install
```

This will install the following tools:

- **[SwiftLint](https://github.com/realm/SwiftLint)** (0.54.0): For Swift code linting.
- **[swift-format](https://github.com/apple/swift-format)** (602.0.0): For Swift code
  formatting.
- **[pre-commit](https://pre-commit.com/)**: For managing git hooks.
- **[just](https://github.com/casey/just)**: For running project tasks.
- **[Prettier](https://prettier.io/)**: For Markdown and config file formatting.
- **[Python 3](https://www.python.org/)**: For local documentation previews
  (`just docs-preview`).

Exact versions are pinned in `.pre-commit-config.yaml`.

After installing dependencies, set up the git hooks:

```sh
just install-hooks
```

### Alternative Installation

If you prefer not to use Homebrew, you can install these tools individually using their
respective installation guides linked above. Ensure they are available in your system
`PATH`.

### Building

```sh
swift build
```

### Testing

```sh
swift test
```

### Pre-commit Hooks

We use the [pre-commit](https://pre-commit.com/) framework to ensure code quality and
conventional commit messages. To install it:

```sh
# Install the framework (if not already installed)
brew install pre-commit

# Install the hooks for this project
just install-hooks
```

This will configure Git to run `swift-format`, `swiftlint`, and commit message checks
automatically.

### Linting

```sh
# Run all linters (auto-fixes safe issues first)
just lint

# Or run individual linters
swiftlint
swift-format lint -r Sources Tests Package.swift
```

### Formatting

```sh
swift-format format -i -r Sources Tests
```

## Coding Standards

### General Guidelines

- Follow Swift API Design Guidelines
- Use Swift 6 language features appropriately
- Write documentation comments for public APIs
- Keep functions small and focused
- Prefer value types over reference types when appropriate

### Code Style

- **Indentation**: 2 spaces (no tabs)
- **Line length**: Maximum 90 characters (soft limit), 150 characters (hard limit)
- **Trailing commas**: Required in multi-line arrays and dictionaries
- **Imports**: Sorted alphabetically
- **Properties**: Sorted alphabetically within their visibility groups
- **Naming**: Use camelCase for variables/functions, PascalCase for types

### Concurrency

- Use structured concurrency whenever possible
- Mark async functions appropriately
- Use actors for shared mutable state
- Enable strict concurrency checking

### Testing

- Write tests for all new functionality
- Use Swift Testing framework
- Follow the Arrange-Act-Assert pattern
- Test edge cases and error conditions
- Aim for high code coverage

## Review Process

All submissions require review. Reviewers will check for:

- Correctness and completeness
- Code style and conventions
- Test coverage
- Documentation
- Performance implications

## License

By contributing, you agree that your contributions will be licensed under the project's
license.
