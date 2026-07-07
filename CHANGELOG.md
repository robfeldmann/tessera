# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added DocC icon and card artwork placeholders for the Tessera package and module
  documentation catalogs.

- Added a project-local Windows smoke-testing skill and expanded the Windows Frost doctor
  with UTM GUI VM IPv4 discovery plus a PowerShell fallback command for manual lookup.

- Added `.worktreeinclude` so Worktrunk copies the gitignored Windows Frost env file into
  future worktrees, and clarified the Windows Frost source-sync message for unstaged
  deletes.

- Added the Phase 3 modern terminal protocols implementation plan bundle, with an umbrella
  coordination plan and separate executable slice plans for bracketed paste, focus events,
  SGR mouse tracking, Kitty keyboard, OSC 8 hyperlinks, and capability detection.

- Added Phase 3 bracketed paste support, including semantic paste input events, DEC
  private mode 2004 encoding and lifecycle cleanup, default app enablement, parser
  performance coverage, and the initial Phase 3 protocols demo panel.

- Added Phase 3 focus event support, including semantic focus gained/lost input events,
  DEC private mode 1004 encoding and lifecycle cleanup, default app enablement, parser
  paste-isolation coverage, and a focus panel in the Phase 3 protocols demo.

- Added Phase 3 SGR mouse tracking, including semantic mouse input events, SGR mouse
  control-sequence encoding, explicit opt-in lifecycle cleanup, bounded motion coalescing,
  parser coverage, and a mouse panel in the Phase 3 protocols demo.

- Added Phase 3 Kitty keyboard protocol support, including push/pop mode lifecycle,
  semantic press/repeat/release key events, expanded Kitty key-code coverage,
  alternate-key and associated-text preservation, Ghostty key-encoder oracle coverage,
  dynamic protocol mode application, and a keyboard panel in the Phase 3 protocols demo.

- Added Phase 3 OSC 8 hyperlink support, including validated hyperlink metadata, OSC 8
  open/close encoding, renderer hyperlink transitions independent from SGR state,
  hyperlink-aware buffer and virtual-terminal snapshot surfaces, and a links panel in the
  Phase 3 protocols demo.

- Added Phase 3 terminal capability detection, including passive environment-based
  capability hints, explicit protocol policy configuration, session inspection of detected
  and enabled terminal protocol state, hyperlink rendering policy control, and a
  capabilities panel in the Phase 3 protocols demo.

- Added Windows support for Ghostty-backed snapshot tests behind the
  `TESSERA_GHOSTTY_WINDOWS=1` package-manifest gate, linking the static
  `ghostty-vt-static.lib` so no runtime DLL discovery is needed.
- Added `scripts/build-libghostty-vt.ps1`, the Windows libghostty-vt build script. It
  prefetches every pinned dependency from the Ghostty checkout's `build.zig.zon.json` with
  `curl.exe` and hands local archives to `zig fetch`, working around Zig's
  `TlsInitializationFailed` package fetcher on Windows, and installs Zig 0.15.x from
  ziglang.org when missing.
- Added `just windows-frost build-ghostty` to build the pinned Windows artifact in the
  persistent Frost VM and cache it on the host; `just windows-frost test` provisions that
  cache into each disposable overlay and runs the Ghostty suites for real.
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

- Changed Windows terminal input to translate queued console key records through
  `ReadConsoleInputW`, so live Windows consoles deliver keystrokes and bracketed paste to
  Tessera apps without relying on `ReadFile`.
- Changed renderer text emission to canonical-precompose decomposed combining graphemes
  when possible, improving cell alignment in Windows Terminal while preserving buffer
  width accounting.
- Updated the example demos' Windows smoke-test behavior: terminal availability checks are
  platform-aware, lifecycle input is routed through Tessera events instead of `readLine`,
  raw-mode status lines use CRLF, and the renderer width page avoids terminal-dependent
  ZWJ/flag ruler samples.
- Changed Windows Frost source sync to suppress macOS AppleDouble metadata, preventing
  `._*` headers from reaching the Windows checkout and triggering Swift/Clang umbrella
  header warnings.
- Changed Windows Frost tests to persist SwiftPM's dependency cache on the host and
  restore it into disposable overlays, avoiding repeated GitHub dependency downloads when
  resolved dependencies are unchanged.

- Centralized SwiftLint coverage in the root config so example sources lint with the main
  package, removed the redundant example config symlink, and disabled cyclomatic
  complexity warnings.

- Enabled Ghostty-backed snapshot tests on hosted Windows CI: the test job now builds
  libghostty-vt on all three platforms (Windows via `scripts/build-libghostty-vt.ps1`) and
  sets `TESSERA_GHOSTTY_WINDOWS=1`.
- Changed the CI test matrix to `fail-fast` so one failing platform cancels sibling jobs,
  and gave Windows a longer per-job timeout for the one-time cold Zig build.
- Changed the libghostty-vt Actions cache to save immediately after the libghostty-vt
  build step (before `swift build`/`swift test`) and to store installed artifacts only,
  excluding source checkouts and intermediate build trees.
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
- Added a workspace-local Ghostty VT header bridge so cached artifacts stay in the shared
  cache root while `CGhosttyVT` can still resolve its checked-in header symlink.
- Changed Ghostty VT to default to `${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt` for
  multi-branch use.
- Changed Linux Lima to honor `TESSERA_LINUX_VM_NAME` so multiple worktrees can use
  separate VMs.
- Changed the Windows Frost docs to clarify that Frost state is VM artifacts and source
  snapshots, not a clone.
- Changed setup examples from fish syntax to POSIX `sh` syntax where applicable.
- Replaced the committed `CGhosttyVT` header symlink with a build-materialized, gitignored
  `Sources/CGhosttyVT/include/ghostty/` directory on every platform, and pointed the
  module map at a committed `CGhosttyVT.h` umbrella header that defines `GHOSTTY_STATIC`
  on Windows.
- Renamed `VirtualTerminal.isPlatformUnsupported` to `isGhosttyUnavailable` and
  `ghosttyOrPlatformUnsupported` to `ghosttyOrUnavailable`; sources now gate on
  `#if canImport(CGhosttyVT)` instead of `#if !os(Windows)`.

### Fixed

- Fixed the Linux Lima test recipe to forward zero or more `swift test` arguments without
  tripping Bash `nounset` on an empty array.

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
