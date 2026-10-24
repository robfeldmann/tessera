<!-- rumdl-disable MD022 MD032 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Established the Swift Package Manager foundation with the `Tessera` and `TesseraTerminal` libraries, Swift 6 strict concurrency, and the `swift-system` and `swift-displaywidth` dependencies.
- Added repository quality and development tooling with pinned npm markup checks, codespell, swift-format, SwiftLint, Lefthook Conventional Commit validation, Just workflows, cross-platform CI, DocC validation, environment diagnostics, and local-state documentation.
- Added the Tessera design catalog, including component contracts, tokens, templates, wireframe validation, responsive compositions, and local diagnostics.
- Added the declarative view and layout foundation with acyclic Core, Layout, and Widgets targets; persistent `ViewGraph` reconciliation and diagnostics; environments and styled text; snapshot support; stacks, modifiers, Divider, SplitView, and ScrollView; and Flex constraints and pane negotiation.
- Added comprehensive DocC catalogs, articles, symbol extensions, icons, and card artwork across the Tessera module family.
- Added semantic terminal protocols for bracketed paste, focus events, SGR mouse tracking, Kitty keyboard input, OSC 8 hyperlinks, and capability detection, with lifecycle management, parser coverage, and protocol demo panels.
- Added Kitty Graphics Protocol support with APC encoding and parsing, image query/transmission/deletion APIs, frame-scoped placement, cell pixel geometry, cleanup, Ghostty-backed inspection, and a graphics demo panel.
- Added capability-aware color degradation with deterministic truecolor, xterm 256-color, ANSI-16, and no-color resolution and rendering.
- Added denied-by-default OSC 52 clipboard support with validated value types, exact encoding, explicit user intent, payload limits, guarded passthrough, and a demo panel.
- Added deterministic mode lifecycle handling, semantic SGR underline variants, colored underlines, renderer transitions, compatibility behavior, snapshots, and exact-byte coverage.
- Added runtime protocol controls and capability reconciliation with bounded active probes, serialized failure-safe mode transactions, live policy changes, emergency cleanup storage, repaint behavior, and a runtime-control demo.
- Added `package`-level seams the headless harness drives, with no new public API: `InMemoryTerminalDevice` can stay open and deliver `.resize` mid-session (`init(…keepsInputOpen:)`, `deliverResize(to:)`, `closeInput()`); `TerminalSession.withApplicationTerminal(configuration:io:…)` forwards `probeImageID` and `probeSleep`; `TerminalSession` exposes `lastDrawn`, `size`, and `outputTap`; and `ViewGraph` reads an injected clock.
- Added the `TesseraRuntime` module with the `Application` protocol, re-exported by `Tessera`: a reference type that owns its model, whose `body` is the root view, whose `apply(_:)` receives each event the view graph left unhandled and every resize, and whose `isFinished` (default `false`) tells a host to stop. It refines nothing but `AnyObject`, so plain classes, `@Observable` models, default-main-actor types, and `@MainActor` models (through `: @MainActor Application`) all adopt it where the type is declared.
- Added the `TesseraHarness` library product, the first home of the developer tooling: the scenario parser, runner, and report that the HeadlessRunner spike proved, ported with its scenario corpus and tests as `package` code. It declares no public API yet.
- Added Windows Ghostty snapshot support with a static library, reproducible Zig build and cache tooling, Frost VM recipes, console mode setup and restoration, live terminal device I/O, focused cross-platform test recipes, and hosted CI coverage.
- Added public issue, Discussion, and pull-request forms, private security and conduct reporting, solo-maintainer ownership metadata, and a fork-safe reviewed contributor vouch gate with tested trust parsing.
- Added read-only DocC pull-request validation plus main-branch and manual GitHub Pages deployment for the combined static documentation site.
- Added macOS VMs under Tart for local validation: `vm:` tasks build macOS 26 and 27 bases with Xcode 26.6 and 27.1 from Cirrus Labs vanilla images, clone work instances, deliver the working tree, and run the check matrix in the guest; the Lima tasks moved to `vm:linux-*`, keeping `linux:*` as aliases.

### Changed
- Changed `TerminalSession` to run its terminal teardown in an uncancellable task, so a cancelled body still leaves raw mode and the alternate screen, and to throw `TerminalSessionError.closed` from every writing call once `withApplicationTerminal` has returned; `events` and `nextEvent()` now drain one shared input queue, size changes keep only the newest value, and overlapping draws and flushes are serialized so each byte is sent once and frames diff against what the terminal received.
- Changed `TerminalSession.draw` to a `nonisolated(nonsending)` entry point: the frame body runs in the caller's isolation, so a `@MainActor` host (or any actor) renders a non-`Sendable` graph where it lives, while the session still serializes draws and commits the finished buffer; the body and the result are no longer `sending`.
- Changed `ModeLifecycle` to close after a successful `exit()`: `enter` and `apply` then throw `ModeLifecycleError.closed` before writing; `exit()` stays retryable. `PlatformIO.flush` no longer retries `writeWouldBlock`; a `TerminalDevice` write either blocks until it makes progress or throws.
- Changed the POSIX input loop to run on a dedicated thread with cancellation through its pipe, and bounded terminal write waits to 50 ms slices that honor task cancellation.
- Changed layout containers to lay out `ForEach`, conditional, optional, and tuple children element by element instead of as one overlapping child.
- Changed the baseline toolchain to Swift 6.3.3 (Xcode 26.6 on macOS, swift.org 6.3.3 on Linux and Windows) and added Swift 6.4 lanes (Xcode 27.1, swift.org 6.4.1 on Linux) in CI and the Lima VM; macOS CI now selects Xcode through the setup action, and the Static Linux SDK follows the active compiler.
- Changed every pinned dependency to its latest release: swift-snapshot-testing 1.19.6 (with the resolved graph: swift-custom-dump 1.7.3, swift-displaywidth 0.2.0, swift-syntax 604.0.0, swift-system 1.8.1, xctest-dynamic-overlay 1.13.1), Prettier 3.9.10, and the GitHub Actions pins (actions/cache 6.1.0, actions/checkout 7.0.1, actions/deploy-pages 5.0.1, actions/upload-artifact 7.0.2, softprops/action-gh-release 3.0.3, SwiftyLab/setup-swift 1.14.2).
- Relicensed Tessera's original material from the MIT License to the Apache License 2.0 before the first public release.
- Changed capability detection to use active protocol-native probes and parser-observed evidence; OSC 8 remains explicitly not actively detectable, and conditional Kitty keyboard support enables only after support is observed.
- Changed color handling to suppress output for the full `TERM=dumb` family and keep the effective capability solely on `TerminalCapabilities.color`, with explicit one-time style resolution.
- Changed Windows input to use `ReadConsoleInputW`, renderer text emission to canonical-precompose compatible graphemes, and example smoke behavior to use platform-aware lifecycle and width handling.
- Hardened Windows Frost source synchronization, SSH fallback, and dependency caching while suppressing AppleDouble metadata and preserving reusable SwiftPM and Ghostty artifacts across disposable overlays.
- Centralized linting and quality orchestration, enabled Ghostty-backed Windows CI, made the test matrix fail fast, restored full macOS/Linux/Windows and DocC validation, and moved cache saves to immediately follow reproducible artifact builds.
- Changed Ghostty VT integration to use a shared XDG cache, build-materialized local headers, a committed static-aware umbrella header, and `canImport(CGhosttyVT)` availability checks; Linux Lima now supports per-worktree VM names and setup examples use POSIX shell syntax.
- Hardened public-fork automation with immutable action pins, read-only validation, edited-PR checks, credential-free caches, restricted Actions permissions, protected required checks, and npm Dependabot coverage.
- Changed DocC transformations and local previews to support the `/tessera` GitHub Pages project-site path, and serialized production deployment runs without cancelling an active deployment.
- Changed the Windows lane to a UTM guest driven by `scripts/vm.py` (`mise run vm:windows-*`: create or import, provision, snapshot, push, test, ssh), like the macOS (Tart) and Linux (Lima) guests; `windows-utm:sync` and `windows-utm:test` remain as aliases for one release.
- Changed libghostty-vt to ship as a prebuilt SE-0482 static-library artifact bundle (macOS universal; Linux glibc 2.28 and musl for x86_64 and aarch64; Windows x86_64 and aarch64) that `.github/workflows/ghostty-vt.yml` builds once per Ghostty pin and publishes as a `ghostty-vt-<revision>` prerelease, with the licenses of the components linked into it. `Package.swift` links it by URL and checksum with no `unsafeFlags`, the Ghostty headers are committed, and an app that depends on Tessera by version links it without Zig; CI's test, docs, and VM runs no longer build Zig, and a `version consumer` job proves the by-version path on macOS (arm64 and x86_64), Linux, and Windows. The producer publishes only a complete bundle and never replaces a published zip unless a manual run opts in. `TESSERA_GHOSTTY_VT_BUNDLE=local` with `scripts/package-libghostty-vt-bundle.sh` covers pin bumps ([Updating Ghostty VT](docs/guides/updating-ghostty-vt.md)).
- Changed `mise run linux:build` to build the library targets for x86_64 and aarch64 with the Static Linux SDK through a swift.org toolchain (swiftly's on macOS), now that `TesseraTerminalIO` imports `Musl` where `Glibc` is absent; a `static Linux SDK` CI job runs it and a statically linked Ghostty round trip.

### Removed
- Removed the Frost Windows workflow (its scripts, `windows-frost:` tasks, guide, and the Homebrew `qemu`, `swtpm`, and `sshpass` dependencies); QEMU's Apple hypervisor backend aborts on the TPM device on macOS 27, and snapshots of the UTM guest replace Frost's disposable overlays.
- Removed the Showcase example (`Examples/Sources/TesseraShowcase`, its tests and Xcode schemes) and the `core:showcase` task: each view component ships its own demo instead, and `mise run core:example` runs what remains in the Examples package.

### Fixed
- Fixed `Package.resolved` churn between toolchains: the resolved files (root, `Examples`, and the workspace) are resolved with Swift 6.4, whose graph adds swift-issue-reporting, and every repository entry point passes `--only-use-versions-from-resolved-file`, so Swift 6.3.3 no longer prunes that pin; each CI test leg fails when a resolved file is out of date or a run changes it.
- Fixed `PlatformIO` to keep its raw input byte stream private to the event parser: a second reader raced the parser for chunks (an `AsyncStream` has one consumer), which surfaced as a flaky `TesseraTerminalIOTests` failure on the Xcode 27 lane.
- Fixed Windows terminal input shutdown so queued resize notifications drain before the event stream finishes, and fixed text snapshots to omit wide-cell continuation placeholders.
- Fixed POSIX input cancellation to break retention cycles, wake blocked polls, prevent empty-read CPU spins, and keep active-probe tests deterministic; Linux Lima test arguments now support an empty forwarded argument list.
- Fixed CI and documentation cache restoration and made Windows Frost SSH prefer the configured key without exhausting authentication attempts during password fallback.
