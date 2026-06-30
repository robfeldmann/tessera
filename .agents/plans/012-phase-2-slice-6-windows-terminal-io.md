---
name: Phase 2 Slice 6 Windows Terminal IO
description:
  Complete TesseraTerminalIO's Windows implementation and enable Windows CI for Phase 2.
status: pending
created: 2026-06-14
updated: 2026-06-29
---

## Progress

- [x] **Phase 0 — Local Windows dev toolchain (UTM + Windows 11 ARM64 + Swift)**
  - [x] 0.1 Provision a Windows 11 ARM64 VM in UTM with OpenSSH and the Swift toolchain
  - [x] 0.2 Add Brewfile, Just recipes, and CONTRIBUTING docs for the Windows VM workflow
- [x] **Phase 1 — Windows-safe package and snapshot scaffolding**
  - [x] 1.1 Make platform C and Ghostty snapshot targets compile safely on Windows
  - [x] 1.2 Mark Ghostty-backed tests explicitly skipped on Windows
- [x] **Phase 2 — Windows cleanup and console modes**
  - [x] 2.1 Generalize emergency cleanup for POSIX and Windows state
  - [x] 2.2 Add Windows console mode setup/restore behind the existing PlatformIO API
- [x] **Phase 3 — Windows terminal device I/O**
  - [x] 3.1 Add Windows handles, environment validation, writes, alt screen, and size
  - [x] 3.2 Add Windows async input and resize event translation
- [ ] **Phase 4 — CI, recovery docs, and manual verification**
  - [ ] 4.1 Document per-platform terminal recovery (POSIX `reset`; Windows PowerShell
        RIS)
  - [ ] 4.2 Enable Windows CI and document Windows manual verification
- [ ] **Phase 5 — Windows snapshot build spike (investigation)**
  - [ ] 5.1 Attempt the Windows libghostty-vt build; enable snapshots or confirm the skip

## Overview

This plan implements Phase 2 Slice 6 from `docs/Spec.md`: TesseraTerminal gets a real
Windows backend while preserving the existing public API shape used by `TerminalSession`.
The durable seam remains `PlatformIO`/`PlatformHandles`/`TerminalDevice`; the scope is
limited by putting platform-specific implementation and tests behind `#if os(Windows)`.
Snapshot rendering remains backed by libghostty-vt on macOS/Linux, with Windows snapshot
coverage explicitly skipped until the Ghostty build path is proven there.

### Key design constraints discovered during review

- **Single Windows input source.** On Windows, byte input and `WINDOW_BUFFER_SIZE_EVENT`
  resize records arrive on the _same_ console input queue. `TerminalDevice` currently
  models `bytes()` and `sizeChanges()` as two independent `AsyncStream`s built by separate
  closures (POSIX gets bytes from a read loop and resize from a SIGWINCH registry, so they
  never contend). On Windows a naive port would spawn two loops both calling
  `ReadConsoleInput`/`ReadFile` on `STD_INPUT_HANDLE`, and they would steal events from
  each other. The Windows live device must own **one** input loop, created once, that fans
  out byte chunks to the `bytes` stream and resize events to the `sizeChanges` stream. See
  Step 3.2.
- **CGhosttyVT is fully compiled out on Windows (not stubbed).** Its headers come solely
  from the `.build/libghostty-vt/current` symlink that `build-libghostty-vt` creates — the
  committed `Sources/CGhosttyVT/include/ghostty` symlink points there and the modulemap is
  `umbrella "ghostty"`. With no Windows Ghostty build that symlink dangles, so there is no
  header to import, and the committed git symlink is itself unreliable on Windows
  checkouts (`core.symlinks`). The module therefore cannot be made "header-importable"
  without building. Decision: on Windows, drop the `CGhosttyVT` target and its dependency
  from the package entirely, and `#if !os(Windows)`-guard the only two importers
  (`VirtualTerminal+Ghostty.swift`; `VirtualTerminalError.swift`'s `import` and `.ghostty`
  case) plus `VirtualTerminal.testValue`. `GhosttyResult` is unavailable on Windows. A
  hand-written stub header was considered and rejected (drift risk; still forces SwiftPM
  to process the symlinked module on Windows). See Steps 1.1–1.2.
- **CI cannot reuse `just ci` on Windows.** The `ci` recipe runs `build-libghostty-vt` (a
  bash + zig script) before `swift build`/`swift test`. Windows must skip that and invoke
  `swift build`/`swift test --no-parallel` directly. See Step 4.2.
- **Platform state belongs in one typed value, not parallel `#if` fields.** Step 2.1
  landed parallel `#if os(macOS) || os(Linux)` fd fields vs `#elseif os(Windows)` handle
  fields on `TerminalDevice`, plus an init that declares both the POSIX and Windows params
  unconditionally (the Windows params are dead weight on POSIX, and `savedTermios` is
  forced to `{ nil }` rather than passed). Treat that as an interim shape. The target is a
  single `cleanupState: PlatformCleanupState` field whose type is defined once per
  platform (alongside the platform-internal `PlatformHandles` of Step 3.1), so
  `TerminalDevice`'s body and init carry no `#if`, and `PlatformIO`'s `#if`-guarded
  `savedTermios()` becomes a platform-neutral accessor the cleanup-install path consumes.
  See Step 3.1.

### Local Windows unit-test command before Phase 1 work

- Before starting Phase 1, verify the Frost host setup with the actual local Frost
  worktree path. The default `just windows-frost doctor` currently fails on this machine
  because the scripts default to `~/Developer/frost`, while Frost is checked out at
  `~/Developer/solcreek/frost/main`:

  ```fish
  env TESSERA_FROST_ROOT=~/Developer/solcreek/frost/main just windows-frost doctor
  ```

- Run the Windows unit-test loop with the same environment override:

  ```fish
  env TESSERA_FROST_ROOT=~/Developer/solcreek/frost/main just windows-frost test
  ```

  `just windows-frost::test` resolves to the same recipe in the installed `just`, but use
  the documented module form above. The recipe boots a disposable Windows overlay, syncs
  the current macOS working tree into `C:\Users\tester\tessera`, and runs
  `swift test --no-parallel` in the guest via `scripts/run-windows-frost-tests.ps1`.

## Phase 0 — Local Windows dev toolchain (UTM + Windows 11 ARM64 + Swift)

**Goal**: Give a macOS (Apple Silicon) contributor a repeatable way to build, unit-test,
and interactively run Tessera on Windows locally, mirroring the existing Lima/Linux flow
as closely as the Windows ecosystem allows. This is a developer-enablement foundation: it
has no shipping code and is not CI-verifiable, so it lands first and the rest of the slice
depends on it for local iteration.

**Honest constraints (why this can't be a turnkey `just windows-utm start`):**

- There is no Lima equivalent for Windows guests. UTM has no checked-in declarative VM
  spec like `tessera-linux.yaml`; creating the VM and installing Windows 11 ARM64 is a
  one-time GUI step that cannot be fully scripted.
- The Windows 11 ARM64 disk image is downloaded manually from Microsoft and run
  unactivated for development (cosmetic watermark; acceptable for a test VM).
- Swift **6.3.2** (matching `.swift-version`) ships an official **ARM64 Windows
  toolchain** — verified at <https://www.swift.org/install/windows/>. Install with
  `winget install --id Swift.Toolchain -e` (not Swiftly, which the Linux path uses). No
  x86-64-under-emulation fallback is required.
- The Swift Windows toolchain requires **Visual Studio 2022 Community** with the Windows
  11 SDK and C++ build tools installed first. This is the heaviest part of guest setup
  (multi-GB) and `scripts/setup-windows-vm.ps1` should install/verify it (e.g. via winget
  `Microsoft.VisualStudio.2022.Community` with the required workloads) before Swift.
- Automation parity for _running tests_ is still achievable: enable the built-in Windows
  OpenSSH server in the VM, then a `just windows-utm test` recipe can SSH in and run
  `swift test --no-parallel`, paralleling `test-linux-vm`'s `limactl shell` step.

### Step 0.1 — Provision a Windows 11 ARM64 VM in UTM with OpenSSH and Swift

- Files: new `scripts/setup-windows-vm.ps1` (PowerShell provisioning run once inside the
  guest), optionally `scripts/config/utm/` for any reusable config/notes.
- Document/script the one-time guest setup: install Swift (winget `Swift.Toolchain` or the
  Windows installer), Git, and enable the OpenSSH server feature; verify `swift --version`
  inside the guest matches `.swift-version`.
- Establish how macOS reaches the guest (UTM port-forward or shared-network IP). The repo
  lives in the guest via `git clone` (decided — avoids the non-portable-`.build` trap of a
  shared mount entirely; the guest gets its own checkout and its own `.build`).
- Acceptance: from the guest, `swift build` and `swift test --no-parallel` run against a
  checkout of this repo (Windows-specific code is still stubbed/unsupported at this point,
  so the suite passes via the existing `#else` paths); `ssh <guest> swift --version` works
  from macOS.

### Step 0.2 — Add Brewfile, Just recipes, and CONTRIBUTING docs for the Windows workflow

- Files: `Brewfile`, `Justfile`, `CONTRIBUTING.md`.
- `Brewfile`: add `cask "utm"` (first cask in the file; `brew bundle` supports casks) with
  a comment mirroring the `lima # Linux virtual machines` entry.
- `Justfile`: add a `# ── Windows ──` section with recipes that match the Linux naming
  pattern as far as feasible — e.g. `windows-vm-ssh` (open a shell), `test-windows-vm`
  (SSH in and run `swift test --no-parallel`), and a guard that prints a clear message
  when the VM/SSH host is unreachable (mirroring the `limactl not found` guard). Recipes
  that cannot be automated (VM creation) should point at the CONTRIBUTING section rather
  than pretend to work.
- `CONTRIBUTING.md`: add a "Windows Test Runs with UTM" subsection next to "Linux Test
  Runs with Lima", covering UTM install via `brew bundle`, Windows 11 ARM64 image
  acquisition, running `scripts/setup-windows-vm.ps1`, the SSH/share setup, and the
  `just windows-utm test` loop. Also update the Brewfile-derived prerequisites list if it
  enumerates tools.
- Acceptance: `brew bundle check` passes with the new cask; `just --list` shows the
  Windows recipes; `prettier --check` / `just quality markdown` pass for
  `CONTRIBUTING.md`; a fresh contributor can follow the doc end-to-end to reach a working
  `just windows-utm test`.

## Phase 1 — Windows-safe package and snapshot scaffolding

**Goal**: Make the package graph capable of compiling on Windows before adding behavior.

### Step 1.1 — Make platform C and Ghostty snapshot targets compile safely on Windows

- Files: `Package.swift`,
  `Sources/CTesseraTerminalPlatform/include/CTesseraTerminalPlatform.h`,
  `Sources/CTesseraTerminalPlatform/cleanup.c`,
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`,
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminalError.swift`.
- Guard POSIX-only C includes (`termios.h`, `unistd.h`, signal APIs) away from Windows in
  `CTesseraTerminalPlatform`.
- **Decision: fully compile out `CGhosttyVT` on Windows** (chosen over a stub header; see
  the Overview constraint for why). The module's headers exist only via the
  `.build/libghostty-vt/current` symlink, which never exists on Windows, so there is
  nothing to import and the committed git symlink is itself a Windows hazard.
  - In `Package.swift`, declare the `CGhosttyVT` target **and** the
    `TesseraTerminalSnapshotSupport` → `CGhosttyVT` dependency only on non-Windows (e.g.
    `#if !os(Windows)` around the target append and the dependency, or a
    platform-conditioned dependency). This also keeps SwiftPM from ever reading the
    modulemap/symlink on Windows, and removes the now-unconditional `CGhosttyVT`
    `linkerSettings` (`-lghostty-vt`, `-rpath`) on Windows. Verify the
    excluded/unreferenced C target is not built on Windows.
  - `#if !os(Windows)`-guard the only two importers: `VirtualTerminal+Ghostty.swift`
    (whole file) and `VirtualTerminalError.swift` (its `import CGhosttyVT` and the
    `.ghostty(operation:result:)` case). `GhosttyResult` is unavailable on Windows.
  - On Windows, `VirtualTerminal.ghostty(...)` is absent; callers get a clear unsupported
    path (`VirtualTerminal.testValue` handled in Step 1.2).
- Acceptance: `swift build` and `swift test --filter TesseraTerminalSnapshotSupportTests`
  still pass on macOS; Windows CI will later verify Windows compilation.

### Step 1.2 — Mark Ghostty-backed tests explicitly skipped on Windows

- Files: `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal.swift` (the
  `testValue { Self.ghostty(...) }` dependency default — must be conditionalized so the
  module compiles on Windows once `.ghostty` is unavailable there),
  `Tests/TesseraTerminalSnapshotSupportTests/VirtualTerminalTests.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererVisualEquivalenceTests.swift`,
  `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`, and any
  `TesseraTerminalTestSupport` snapshot helpers that route through `VirtualTerminal`.
- Cover every direct `VirtualTerminal.ghostty(...)` call, not just files named "snapshot".
  Because `.ghostty` is absent on Windows, disabled/skip traits alone are not enough for
  those tests: wrap the Ghostty-backed bodies in `#if !os(Windows)` and provide Windows
  placeholder tests that are explicitly skipped/disabled with comments explaining that
  Windows snapshot coverage is deferred to a future libghostty-vt build path.
- Keep macOS/Linux Ghostty-backed behavior unchanged.
- Acceptance: Ghostty-backed tests continue to run on macOS/Linux; on Windows they are
  reported as intentionally skipped rather than failing or silently disappearing.

## Phase 2 — Windows cleanup and console modes

**Goal**: Implement the teardown-critical Windows console state path before live I/O.

### Step 2.1 — Generalize emergency cleanup for POSIX and Windows state

- Files: `Sources/CTesseraTerminalPlatform/include/CTesseraTerminalPlatform.h`,
  `Sources/CTesseraTerminalPlatform/cleanup.c`,
  `Sources/TesseraTerminalIO/CleanupRegistry.swift`,
  `Sources/TesseraTerminalIO/PlatformIO.swift`,
  `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift`.
- Split cleanup installation into POSIX termios state and Windows console mode state while
  keeping one `CleanupRegistry` Swift facade.
- On Windows, store input/output handles, saved input/output modes, and teardown bytes;
  install `SetConsoleCtrlHandler` for `CTRL_C_EVENT`, `CTRL_BREAK_EVENT`, and
  `CTRL_CLOSE_EVENT`, plus the same `atexit` backstop pattern.
- Keep the die-now restore path in the C shim (consistent with the existing POSIX design,
  which deliberately walls the unsafe surface in `CTesseraTerminalPlatform`): the Windows
  branch uses `SetConsoleMode` + `WriteFile` rather than the Swift `tesseraCtrlHandler`
  sketch in `docs/Spec.md`. Note this intentional divergence from the spec.
- `PlatformIO.installCleanup` is currently `#if os(macOS) || os(Linux)` only and pulls
  `inputFileDescriptor`/`outputFileDescriptor` (`CInt`) off `TerminalDevice`. Add a
  Windows branch that sources console `HANDLE`s + saved modes instead. The parallel
  `#if os(Windows)` fields shipped here are interim (keeps POSIX untouched for 2.1); Step
  3.1 collapses them into one typed `PlatformCleanupState` value (see the design
  constraint above).
- Add testing hooks only where needed to assert saved mode state and handler installation.
- Acceptance: existing POSIX cleanup tests pass; Windows-only cleanup tests verify
  install, clear, emergency cleanup, and handler/backstop registration behavior.

### Step 2.2 — Add Windows console mode setup/restore behind the existing PlatformIO API

- Files: `Sources/TesseraTerminalIO/TerminalDevice.swift`,
  `Sources/TesseraTerminalIO/TerminalDevice+Live.swift`,
  `Sources/TesseraTerminalIO/PlatformIOError.swift`, new
  `Sources/TesseraTerminalIO/WindowsConsoleMode.swift`,
  `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`, new
  `Tests/TesseraTerminalIOTests/WindowsConsoleModeTests.swift`.
- Add a testable Windows console-system seam for `GetConsoleMode`/`SetConsoleMode`.
- Enable raw input and VT output using named flag helpers, saving modes before mutation
  and restoring exactly those saved modes on exit.
- Add clear errors for failed mode calls and unsupported/non-console environments.
- Acceptance: Windows-only mode tests cover flag combinations, idempotent enter/exit,
  restore-on-exit, and error propagation; existing mode lifecycle tests still pass on
  POSIX.

## Phase 3 — Windows terminal device I/O

**Goal**: Provide a complete live `TerminalDevice` implementation on Windows.

### Step 3.1 — Add Windows handle acquisition, environment validation, writes, alt screen, and size reads

- Files: `Sources/TesseraTerminalIO/PlatformHandles.swift`,
  `Sources/TesseraTerminalIO/TerminalDevice+Live.swift`,
  `Sources/TesseraTerminalIO/PlatformIOError.swift`, new
  `Sources/TesseraTerminalIO/WindowsConsole.swift`,
  `Tests/TesseraTerminalIOTests/PlatformHandlesTests.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOSizeTests.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`.
- Make `PlatformHandles` platform-specific internally: POSIX stores file descriptors;
  Windows stores standard input/output console handles.
- Validate redirected/unsupported consoles early in `PlatformHandles.standard()` or live
  device construction with clear errors.
- Implement Windows writes, alternate-screen bytes, and `GetConsoleScreenBufferInfo` size
  reads behind the existing `PlatformIO` methods.
- Collapse the interim parallel `#if` cleanup fields on `TerminalDevice` (from Step 2.1)
  into a single `cleanupState: PlatformCleanupState` field, defined once per platform next
  to the platform-internal `PlatformHandles`. Remove the unconditional Windows init params
  on POSIX and the `#if`-guarded `PlatformIO.savedTermios()`; the cleanup-install path
  reads the typed value through a platform-neutral accessor. Net: `TerminalDevice` and its
  init carry no `#if`.
- Acceptance: Windows-only tests cover standard handle validation, redirected I/O errors,
  write retry/error mapping, alternate screen bytes, and size decoding.

### Step 3.2 — Add Windows async input and resize event translation

- Files: new `Sources/TesseraTerminalIO/WindowsInputLoop.swift`,
  `Sources/TesseraTerminalIO/TerminalDevice+Live.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOInputTests.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOSizeTests.swift`, new
  `Tests/TesseraTerminalIOTests/WindowsInputLoopTests.swift`.
- Implement the Windows input stream using `WaitForSingleObject`, `PeekConsoleInput`,
  selective `ReadConsoleInput` draining for non-character events, and `ReadFile` for byte
  input.
- **Drive both `bytes()` and `sizeChanges()` from one shared input loop.** Because both
  read from the same console input queue (see Key design constraints), the Windows live
  device must create a single owning loop once and fan out: byte chunks (including empty
  idle chunks for ESC-timeout handling, matching the POSIX contract) to the `bytes`
  continuation, and translated `WINDOW_BUFFER_SIZE_EVENT` sizes to the `sizeChanges`
  continuation. Do **not** implement `bytes()` and `sizeChanges()` as two independent
  loops over `STD_INPUT_HANDLE`. This likely means the Windows `live(handles:)` builds a
  shared coordinator and both closures return streams it feeds, rather than each closure
  spawning its own loop.
- Only `ReadFile` when `PeekConsoleInput` shows character bytes are queued, so a pending
  resize/focus record never blocks `ReadFile` waiting for a keypress.
- Comment the peek/drain/read shape because it is the subtle part of the slice.
- Acceptance: Windows-only tests cover byte reads, idle notifications/cancellation, resize
  translation, non-character event draining without blocking `ReadFile`, input
  closure/error handling, and integration through `PlatformIO.events`.

## Phase 4 — CI, recovery docs, and manual verification

**Goal**: Prove the slice on Windows and document the manual verification path.

### Step 4.1 — Document per-platform terminal recovery (no shipped executable)

- Files: `README.md`, `CONTRIBUTING.md`.
- Do **not** add a `tessera-reset` executable. Tessera is a library, not a CLI, so an
  executable has no coherent distribution path: `Examples` depends on `Tessera` (not the
  reverse), so downstream SwiftPM consumers never receive it, and an emergency recovery
  tool that requires `swift run` (a build) inside a package dir is strictly worse than
  typing `reset`. This re-confirms the Slice 3 decision (`008…lifecycle.md`, Step 7.1).
- The README "Terminal recovery" section already documents POSIX recovery (`reset`,
  `stty sane`). Add the **Windows** path, which has no native `reset`/`stty sane`: a
  PowerShell one-liner emitting RIS (`ESC c`) — e.g. `[Console]::Write([char]27 + 'c')`,
  plus show-cursor and leave-alt-screen for good measure. Confirm the exact incantation in
  the Phase 0 VM.
- Update CONTRIBUTING's recovery note (currently references "future `tessera-reset`
  tooling") to drop that wording and point at the documented per-platform commands.
- Acceptance: `pnpx markdownlint-cli README.md CONTRIBUTING.md` passes; recovery docs
  cover macOS/Linux and Windows.

### Step 4.2 — Enable Windows CI and document Windows manual verification

- Files: `.github/workflows/ci.yml`, `Justfile` (a Windows-only CI recipe is required, not
  just optional), `CONTRIBUTING.md`, this plan.
- Add `windows-latest` to the `test` matrix (`fail-fast: false` is already set on that
  matrix). The `setup-swift` composite action uses `bash` steps and SwiftyLab/setup-swift
  supports Windows, so it should work on the Windows runner — verify the bash steps run
  under the runner's Git bash.
- **Do not run `just ci` on Windows.** The existing `ci`/`ci-build-test` recipes depend on
  `build-libghostty-vt` (bash + zig) and `swift test --no-parallel`. Add a Windows path
  (e.g. a `ci-windows` recipe, or branch the matrix step by `runner.os`) that runs
  `swift build` and `swift test --no-parallel`, with no Ghostty build and no
  zig/cmake/ninja install steps. Gate the existing Ghostty prerequisite + cache steps to
  non-Windows runners.
- Confirm `just` is available on the Windows runner if a `just` recipe is used; otherwise
  invoke `swift`/Examples build directly in the workflow step for Windows.
- Document manual checks in Windows Terminal, conhost, and PowerShell: arrow keys, `q`
  clean exit, Ctrl-C cleanup, resize-driven redraw, and clean terminal restoration.
- Acceptance: macOS/Linux validation remains green; Windows CI is green; Markdown lint
  passes for edited docs.

## Phase 5 — Windows snapshot build spike (investigation)

**Goal**: After the core Windows I/O work is done and the documented snapshot skip is in
place as a safety net, take a time-boxed attempt at building libghostty-vt on Windows so
Windows gets real snapshot coverage. Placed last on purpose: the slice's actual
deliverable (Windows `PlatformIO`) must not be blocked by open-ended build R&D, and by
this point the Phase 0 VM exists and the whole package already compiles on Windows.

### Step 5.1 — Attempt the Windows libghostty-vt build; enable snapshots or confirm the skip

- Driver doc: `.agents/investigations/006-windows-libghostty-vt-snapshot-spike.md` (full
  research, alternatives considered, and the step-by-step spike). Update its `status` to
  `resolved` with the outcome when finished.
- Files (on success): `scripts/ghostty-vt-version.txt` (bump approved by owner if needed),
  `scripts/build-libghostty-vt.sh` (Windows platform/arch path + `.dll`/`.lib` glob),
  `Package.swift` (re-enable the `CGhosttyVT` target + `TesseraTerminalSnapshotSupport`
  dependency on Windows — flip the Step 1.1 platform condition — plus the Windows
  `GhosttyVTPlatform`/artifact path and linker settings), the two
  `#if !os(Windows)`-guarded importers and `VirtualTerminal.testValue` (unguard for
  Windows), `docs/UpdatingGhosttyVT.md` (document the Windows artifact path and Windows
  re-validation, which it currently omits), plus flipping the Phase 1 Windows snapshot
  skips to enabled and generating Windows baselines.
- Prefer a direct `zig build` of the vt target that bypasses the full-app CMake/libxml2
  graph (the documented Windows blocker); bump the pinned revision to one with the
  upstream libxml2-on-Windows fix if required (re-validate macOS/Linux snapshots against
  the new rev).
- Acceptance (success): Windows CI builds libghostty-vt and runs the previously-skipped
  snapshot tests green; macOS/Linux snapshots still pass against any bumped revision.
- Acceptance (fallback): if the toolchain fights back within the time box, keep the
  documented Windows snapshot skip from Phase 1, record where it failed in the
  investigation doc, and mark it `resolved`. Byte-stream unit tests still cover
  encoder/parser/renderer correctness on Windows, so the slice is complete either way.

## Validation

During implementation, run the narrowest relevant test first, for example:

```fish
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalSnapshotSupportTests
just quality changed
```

Before committing the completed slice:

```fish
just quality lint
swift test
```

For edited Markdown:

```fish
pnpx markdownlint-cli CONTRIBUTING.md .agents/plans/012-phase-2-slice-6-windows-terminal-io.md
```

Windows-specific acceptance runs in two places: GitHub Actions (`windows-latest`) and the
local UTM + Windows 11 ARM64 VM established in Phase 0. From macOS, iterate with:

```fish
just windows-utm test
```

Manual interactive verification (arrow keys, clean `q` exit, Ctrl-C cleanup, resize
redraw) is done by hand inside that VM's Windows Terminal and conhost, per Step 4.2.

## References

- `docs/Spec.md`, Phase 2 Slice 6: Windows support and Phase 2 completion.
- `.agents/investigations/006-windows-libghostty-vt-snapshot-spike.md` — snapshot oracle
  research and the Windows build spike (Phase 5).
- `docs/UpdatingGhosttyVT.md` — pinned-revision bump process (to be extended for Windows).
- `Sources/TesseraTerminalIO/PlatformIO.swift`
- `Sources/TesseraTerminalIO/TerminalDevice+Live.swift`
- `Sources/CTesseraTerminalPlatform/cleanup.c`
- `.github/workflows/ci.yml`
