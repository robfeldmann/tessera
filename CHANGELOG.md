# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-25

### Added

- Initial project setup with Swift Package Manager.
- `Tessera` core library target.
- `TesseraTerminal` library target with `swift-system` and `swift-displaywidth`
  dependencies.
- Swift 6 language mode with strict concurrency and `NonisolatedNonsendingByDefault`.
- Comprehensive development tooling configuration:
  - `.editorconfig` for editor consistency.
  - `.markdownlint.json` and `.prettierrc.json` for documentation styling.
  - `.pre-commit-config.yaml` for code quality enforcement.
  - `.spi.yml` for eventual release documentation hosting.
  - `.swift-format.json` for consistent code formatting.
  - `.swiftlint.yml` with community-standard rules.
- `Brewfile` for quick dependencies installation.
- `Justfile` for task running (build, test, lint, format, ci).
- Project documentation (`CHANGELOG.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`,
  `README.md`).
- MIT License.

[Unreleased]: https://github.com/robfeldmann/tessera/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/robfeldmann/tessera/releases/tag/v0.1.0
