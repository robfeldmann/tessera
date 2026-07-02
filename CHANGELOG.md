# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added Windows console mode setup and restore coverage for `TesseraTerminalIO`.
- Added live Windows terminal device I/O for `TesseraTerminalIO`, including console handle
  validation, writes, alternate-screen control, size reads, and shared async input and
  resize event translation.
- Added focused Linux, Windows Frost, and Windows UTM VM test recipes that forward
  `swift test` arguments after `--`.
- Added a Windows-focused CI recipe and post-build SwiftPM cache save path for hosted
  bring-up runs.
- Added `just core doctor` to report Ghostty VT, Linux Lima, Static Linux SDK, and Windows
  Frost state.
- Added `just core clean-libghostty-vt` to remove the shared Ghostty VT cache root.
- Added `docs/LocalDevelopmentState.md` as the canonical guide for checkout, cache, and VM
  state scopes.

### Changed

- Documented per-platform terminal recovery commands, including the Windows PowerShell
  reset sequence for consoles without `reset` or `stty sane`.
- Expanded the Phase 4 view-layer spec with SwiftUI-inspired runtime lessons, explicit
  import-boundary/package-graph checks, and Tessera-native oracle test expectations.
- Temporarily narrowed hosted CI/docs checks to Windows-focused `TesseraTerminalIOTests`
  while the Windows runner path is being stabilized.
- Restored hosted macOS/Linux CI, DocC validation, and full Windows test execution after
  the focused Windows runner path passed.
- Removed the Swift-DocC plugin dependency from Windows manifests so hosted Windows builds
  do not restore or compile DocC plugin symlink trees.
- Pinned hosted macOS/Linux Ghostty VT output to `.build/libghostty-vt` so the C target
  header symlink and linker flags use the same artifact root.
- Changed Ghostty VT to default to `${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt` for
  multi-branch use.
- Changed Linux Lima to honor `TESSERA_LINUX_VM_NAME` so multiple worktrees can use
  separate VMs.
- Changed the Windows Frost docs to clarify that Frost state is VM artifacts and source
  snapshots, not a clone.
- Changed setup examples from fish syntax to POSIX `sh` syntax where applicable.

### Fixed

- Fixed CI and docs workflows to restore the shared Ghostty VT cache from the new default
  location.
- Fixed Windows Frost SSH automation to prefer the configured key once available and to
  disable public-key attempts during password fallback so unrelated `ssh-agent` keys do
  not exhaust Windows OpenSSH authentication attempts.

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
