<!-- markdownlint-disable MD022 MD032 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Established the Swift Package Manager foundation with the `Tessera` and `TesseraTerminal` libraries, Swift 6 strict concurrency, and the `swift-system` and `swift-displaywidth` dependencies.
- Added repository quality and development tooling with pinned npm markup checks, codespell, swift-format, SwiftLint, Lefthook Conventional Commit validation, Just workflows, cross-platform CI, DocC validation, environment diagnostics, and local-state documentation.
- Added the Tessera design catalog and runnable Showcase, including component contracts, tokens, templates, wireframe validation, responsive compositions, and local diagnostics.
- Added the declarative view and layout foundation with acyclic Core, Layout, and Widgets targets; persistent `ViewGraph` reconciliation and diagnostics; environments and styled text; snapshot support; stacks, modifiers, Divider, SplitView, and ScrollView; Flex constraints and pane negotiation; and responsive Showcase layouts.
- Added comprehensive DocC catalogs, articles, symbol extensions, icons, and card artwork across the Tessera module family.
- Added semantic terminal protocols for bracketed paste, focus events, SGR mouse tracking, Kitty keyboard input, OSC 8 hyperlinks, and capability detection, with lifecycle management, parser coverage, and protocol demo panels.
- Added Kitty Graphics Protocol support with APC encoding and parsing, image query/transmission/deletion APIs, frame-scoped placement, cell pixel geometry, cleanup, Ghostty-backed inspection, and a graphics demo panel.
- Added capability-aware color degradation with deterministic truecolor, xterm 256-color, ANSI-16, and no-color resolution and rendering.
- Added denied-by-default OSC 52 clipboard support with validated value types, exact encoding, explicit user intent, payload limits, guarded passthrough, and a demo panel.
- Added deterministic mode lifecycle handling, semantic SGR underline variants, colored underlines, renderer transitions, compatibility behavior, snapshots, and exact-byte coverage.
- Added runtime protocol controls and capability reconciliation with bounded active probes, serialized failure-safe mode transactions, live policy changes, emergency cleanup storage, repaint behavior, and a runtime-control demo.
- Added Windows Ghostty snapshot support with a static library, reproducible Zig build and cache tooling, Frost VM recipes, console mode setup and restoration, live terminal device I/O, focused cross-platform test recipes, and hosted CI coverage.
- Added public issue, Discussion, and pull-request forms, private security and conduct reporting, solo-maintainer ownership metadata, and a fork-safe reviewed contributor vouch gate with tested trust parsing.

### Changed

- Relicensed Tessera's original material from the MIT License to the Apache License 2.0 before the first public release.
- Changed capability detection to use active protocol-native probes and parser-observed evidence; OSC 8 remains explicitly not actively detectable, and conditional Kitty keyboard support enables only after support is observed.
- Changed color handling to suppress output for the full `TERM=dumb` family and keep the effective capability solely on `TerminalCapabilities.color`, with explicit one-time style resolution.
- Changed Windows input to use `ReadConsoleInputW`, renderer text emission to canonical-precompose compatible graphemes, and example smoke behavior to use platform-aware lifecycle and width handling.
- Hardened Windows Frost source synchronization, SSH fallback, and dependency caching while suppressing AppleDouble metadata and preserving reusable SwiftPM and Ghostty artifacts across disposable overlays.
- Centralized linting and quality orchestration, enabled Ghostty-backed Windows CI, made the test matrix fail fast, restored full macOS/Linux/Windows and DocC validation, and moved cache saves to immediately follow reproducible artifact builds.
- Changed Ghostty VT integration to use a shared XDG cache, build-materialized local headers, a committed static-aware umbrella header, and `canImport(CGhosttyVT)` availability checks; Linux Lima now supports per-worktree VM names and setup examples use POSIX shell syntax.
- Hardened public-fork automation with immutable action pins, read-only validation, edited-PR checks, credential-free caches, restricted Actions permissions, protected required checks, and npm Dependabot coverage.

### Fixed

- Fixed Windows terminal input shutdown so queued resize notifications drain before the event stream finishes, and fixed text snapshots to omit wide-cell continuation placeholders.
- Fixed POSIX input cancellation to break retention cycles, wake blocked polls, prevent empty-read CPU spins, and keep active-probe tests deterministic; Linux Lima test arguments now support an empty forwarded argument list.
- Fixed CI and documentation cache restoration and made Windows Frost SSH prefer the configured key without exhausting authentication attempts during password fallback.

[Unreleased]: https://github.com/robfeldmann/tessera/commits/main
