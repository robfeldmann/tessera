# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added repository-local npm markup tooling and a pinned, check-only codespell
  environment; quality recipes, staged checks, contributor setup, and macOS CI now use
  those dependencies. SwiftLint formatting rules now defer to `swift-format` as the sole
  layout authority.

- Consolidated quality orchestration: deterministic formatter ordering, portable full-tree
  linting without DocC, parameterized local markup checks, and staged snapshot validation
  that recursively detects Swift and DocC changes before macOS-only DocC escalation.

- Replaced pre-commit with committed Lefthook configuration, including staged-index
  quality checks and a shared Conventional Commit validator for local commit messages and
  CI.

- Aligned CI and contributor workflows around canonical Just quality commands, pinned the
  Swift setup action to a reviewed commit, and kept warnings-as-errors DocC validation
  explicit and macOS-only.

- Added the Tessera design catalog under `design/`: a source-verified process for
  designing view-layer primitives and widgets, with per-component design docs (Button,
  List, ScrollView, SplitView, NavigationSplitView, Table, TextField, plus sketch stubs
  for Toggle, Picker, Stepper, and Section), primitive docs, a shared `tokens.md`, an
  `inbox.md` triage queue, wireframe and interaction templates, a `design-catalog` skill
  with catalog authoring prompts, and a `check-wireframes.py` fixture validator wired into
  `just quality`.

- Added the Tessera Showcase design (`design/showcase.md`), the runnable Phase 4
  integration example that composes the public catalog surface, defining its 1.0 component
  boundary, responsive presentation policy, immutable local diagnostics inspector,
  seven-slice growth plan, and thirteen composition wireframes.

- Added DocC icon and card artwork placeholders for the Tessera package and module
  documentation catalogs.

- Added comprehensive DocC catalogs, conceptual articles, and symbol extensions across the
  TesseraTerminal module family, covering the terminal substrate, modern protocols, ANSI
  encoding, buffers and styles, geometry, lifecycle management, semantic input, and
  terminal snapshot testing.

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

- Added Phase 3 Kitty Graphics Protocol support, including first-class APC encoding and
  parsing, session image query/transmission/deletion APIs, frame-scoped placement, cell
  pixel geometry, unconditional cleanup, Ghostty-backed graphics snapshot inspection, and
  a graphics panel in the Phase 3 protocols demo.
- Added Phase 3 color degradation baseline, including capability-aware color resolution
  (`Color.resolved(for:)`), a pinned xterm 256-color and ANSI-16 palette for deterministic
  RGB/indexed fallback, renderer SGR emission that degrades truecolor to 256-color, ANSI
  16, or no-color per the active session capability, application color capability
  override, and a color sample section in the Phase 3 demo capabilities panel.

- Added Phase 3 OSC 52 clipboard support, including semantic clipboard value types with
  validated selections and base64-owning encoding, exact OSC 52 control-sequence emission,
  a denied-by-default session write policy requiring explicit per-call user intent,
  payload size limits, SSH-permissive but nested tmux/screen-guarded passthrough policy,
  an advisory `osc52Clipboard` capability that stays not-detectable, and a clipboard panel
  in the Phase 3 protocols demo.

- Added Phase 3 mode lifecycle handling to deterministically enter, apply, restore, and
  clean up cursor styling state.

- Added Phase 3 semantic SGR underline style variants and colored underlines: undercurl
  and other SGR 4:x styles, underline color/reset, renderer diffing, compatibility with
  the legacy underline bit, snapshots, exact byte tests, and documentation.

- Added Phase 3 runtime protocol control and capability reconciliation: one bounded,
  permanently cached active-probe generation; serialized failure-safe mode transactions
  with requested, effective, and possibly-active state; live color, hyperlink,
  synchronized-output, underline, cursor, mouse, focus, and Kitty keyboard policy
  controls; configurable Kitty enhancement flags and advisory terminfo underline
  compatibility; injected emergency-cleanup storage for deterministic tests; and a tested
  runtime-control demo covering full-mask Kitty input, terminal-specific hyperlink and
  underline behavior, stable Kitty graphics failure recovery, and explicit full-screen
  repaint.

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

- Changed the Spec Phase 4 view-layer plan to re-sequence its slices around the Showcase's
  dependency-driven component landing order, adding a slice sequencing and component
  landing map with a dependency DAG, an immutable local developer diagnostics contract in
  Slice 1, and the full 1.0 widget surface, and renaming `TextInput` to `TextField`.

- Changed Phase 3 terminal capability detection to use active, protocol-native probes
  instead of terminal-name support decisions. Queryable protocols now report `.probing`,
  `.supported`, `.unsupported`, or `.unknown` from parser-observed evidence; OSC 8 is
  documented and tested as not actively detectable; `.kittyIfAvailable` only enables Kitty
  keyboard after active support is observed; and the Phase 3 demo distinguishes unanswered
  probes from observed protocol behavior.
- Changed terminal color capability detection to suppress color for the full `TERM=dumb`
  family (`dumb`, `dumb-300`, …) rather than only exact `TERM=dumb`, closing a regression
  where `dumb-` variants resolved to `.unknown` instead of `.noColor`.
- Removed the redundant `TerminalApplicationResolution.colorCapability` and
  `TerminalSession.colorCapability` mirrors; the effective color capability now lives
  solely on `TerminalCapabilities.color`, and `sgrDelta`/`encodeFullStyle` resolve a style
  once with an explicit precondition instead of passing a `.truecolor` sentinel.

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

- Fixed POSIX terminal input cancellation to break the stream/task retention cycle, wake
  blocked polls through a cancellation pipe, prevent empty-read CPU spins, and keep active
  capability-probe tests deterministic without timeout-based scheduling.
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
