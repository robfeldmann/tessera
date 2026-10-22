---
name: Windows Ghostty Snapshot Enablement
description:
  Productize the Windows libghostty-vt build path proven by the Phase 5 spike and enable
  Ghostty-backed snapshot tests on Windows behind an explicit local gate.
status: complete
created: 2026-07-02
updated: 2026-07-02
---

## Progress

- [x] **Phase 1 — Windows-safe header bridge (all platforms)**
  - [x] 1.1 Replace the committed `CGhosttyVT` header symlink with a build-materialized
        directory
- [x] **Phase 2 — Windows libghostty-vt build script**
  - [x] 2.1 Add `scripts/build-libghostty-vt.ps1` with curl-based dependency prefetch
- [x] **Phase 3 — Package and source enablement behind `canImport(CGhosttyVT)`**
  - [x] 3.1 Gate `CGhosttyVT` on Windows by environment opt-in; link the static library
  - [x] 3.2 Convert source guards from `#if !os(Windows)` to `#if canImport(CGhosttyVT)`
- [x] **Phase 4 — Frost workflow, docs, and verification**
  - [x] 4.1 Cache the Windows artifact on the host and provision it into test guests
  - [x] 4.2 Update docs and verify the full Windows snapshot suite in Frost

### Implementation outcome (2026-07-02)

- Cold-cache validation passed in the Frost guest: with `ZIG_GLOBAL_CACHE_DIR` pointed at
  an empty directory, `build-libghostty-vt.ps1` prefetched all 36 manifest dependencies
  (curl + `zig fetch <local-file>`, keys verified against `build.zig.zon.json`, including
  the `git+https` uucode entry via its GitHub codeload archive) and built the artifact.
- Two implementation findings beyond the plan:
  - The static link needs upstream's `GHOSTTY_STATIC` define (otherwise `vt.h` declares
    `__declspec(dllimport)` symbols the static lib cannot satisfy). The module now uses a
    committed umbrella header `Sources/CGhosttyVT/include/CGhosttyVT.h` that defines it on
    Windows before including `ghostty/vt.h`; this also stops clang from directory-scanning
    the materialized headers.
  - Zig's std library calls ntdll syscalls directly, so Windows linker flags add `-lntdll`
    next to `-lghostty-vt-static`. Host-side artifact provisioning tars with
    `COPYFILE_DISABLE=1` so macOS AppleDouble (`._*`) files never reach the guest.
- Verification: Frost `just windows-frost test` full suite passed with the gate on (245
  tests, Ghostty suites executing — not skipped); macOS full suite passed (247 tests);
  gate-off package graph (manifest constant forced false) compiles all test targets and
  omits `CGhosttyVT`; `just quality lint` passes. No `.github/workflows/` changes, no
  push, no hosted CI run.

## Overview

The Phase 5 spike of plan 012 (recorded in
`.agents/investigations/006-windows-libghostty-vt-snapshot-spike.md`) proved that the
pinned `libghostty-vt` revision (`scripts/ghostty-vt-version.txt`,
`ae52f97dcac558735cfa916ea3965f247e5c6e9e`) builds on Windows ARM64 with
`zig build -Demit-lib-vt -Dsimd=false -Doptimize=ReleaseFast --prefix <install>`, and that
with the artifact present the Ghostty-backed test suites pass in the Frost guest (6 + 34 +
47 + 8 tests). Three seams blocked committing that result:

1. **Cold-cache Zig fetch.** Zig 0.15.2 on Windows ARM64 fails with
   `TlsInitializationFailed` against `https://deps.files.ghostty.org`, while `git` and
   `curl.exe` work in the same guest.
2. **Header bridge.** The committed `Sources/CGhosttyVT/include/ghostty` symlink is a
   broken reparse point on Windows checkouts; SwiftPM ignores it and compilation fails.
3. **DLL discovery.** The spike needed the artifact `bin` directory prepended to `PATH`
   for `ghostty-vt.dll` at test time.

This plan closes all three:

1. **Prefetch, don't fix TLS.** The pinned Ghostty checkout ships offline-packaging
   manifests: `build.zig.zon.txt` (flat list of every transitive dependency URL) and
   `build.zig.zon.json` (Zig cache key → name/url/sha256). Upstream's own
   `nix/build-support/fetch-zig-cache.sh` iterates `build.zig.zon.txt` and `zig fetch`es
   each entry because `zig build --fetch` misses transitive dependencies
   (ziglang/zig#20976). The Windows script does the same, but downloads each `https` URL
   with `curl.exe` first and runs `zig fetch <local-file>` — Zig hashes unpacked content,
   so a local-file fetch produces the same cache key as a network fetch, and Zig's broken
   Windows TLS client is never used.
2. **Materialize, don't symlink.** All platforms stop committing a symlink: the build
   scripts copy `<install>/include/ghostty` into `Sources/CGhosttyVT/include/ghostty`
   (gitignored). POSIX and Windows share one convention; SwiftPM sees a real directory.
3. **Link static, don't discover DLLs.** On Windows, `CGhosttyVT` links
   `ghostty-vt-static.lib` (produced by the same build). libghostty-vt is zero-dependency,
   so static linking removes the runtime `PATH` requirement entirely.

**Gating.** Hosted GitHub CI must not run Ghostty on Windows until the user approves.
`Package.swift` includes `CGhosttyVT` on Windows only when `TESSERA_GHOSTTY_WINDOWS=1` is
set in the manifest-load environment. Source files switch from `#if !os(Windows)` to
`#if canImport(CGhosttyVT)`, so the same sources compile correctly in both configurations
with no second guard convention. The hosted `windows-latest` CI job (which never sets the
variable) keeps today's behavior byte-for-byte; the Frost test workflow sets it and
provisions the artifact.

### Key design decisions

- **`canImport(CGhosttyVT)` is the single availability seam.** When the manifest omits the
  target (Windows, gate off), `canImport` is false and the Ghostty sources compile out
  exactly as today. When the gate is on (Frost, or future approved CI), they compile in.
  No new `#define`, no parallel guard style.
- **Rename `isPlatformUnsupported` → `isGhosttyUnavailable`.** Availability now depends on
  build configuration, not just platform; the old name would lie on a gate-off Windows
  build. All ~38 call sites are the mechanical
  `.disabled(if: VirtualTerminal.isPlatformUnsupported, …)` trait pattern plus
  `ghosttyOrPlatformUnsupported` (5 files). Runtime skip traits stay; on a gate-on Windows
  build they evaluate false and the suites run for real.
- **Static linking on Windows only.** POSIX keeps the current dynamic `-lghostty-vt` +
  rpath flags untouched — no re-validation of shipped platforms. Risk: Zig-produced
  `ghostty-vt-static.lib` must link cleanly under Swift's MSVC-ABI toolchain (the spike
  linked the _import_ lib successfully; the static lib is the same object code plus
  possible compiler-rt symbols). Fallback if it does not link: keep the import lib and
  have `run-windows-frost-tests.ps1` prepend the artifact `bin` to `PATH` (proven in the
  spike).
- **Host-cached guest artifact.** `windows-frost-test.sh` boots a disposable overlay, so
  an in-guest Zig build on every test run is unacceptable (full Ghostty toolchain
  bootstrap per run). Instead a new `just windows-frost build-ghostty` recipe builds once
  in the persistent VM and copies the artifact back to
  `$TESSERA_FROST_WORK/libghostty-vt/<revision>/windows-arm64`; the test workflow syncs
  that directory into each guest. Keyed by pinned revision, so a pin bump invalidates
  naturally.
- **uucode is the one git dependency.** `build.zig.zon.txt` line 1 is
  `git+https://github.com/jacobsandlund/uucode#<sha>`; `zig fetch git+https://…` would hit
  the same TLS path. Prefetch it as a tarball instead:
  `curl.exe https://github.com/jacobsandlund/uucode/archive/<sha>.tar.gz` +
  `zig fetch <file>`. Verify the printed cache key matches the `uucode-…` key in
  `build.zig.zon.json`; if the tarball hash diverges from the git-tree hash (unlikely —
  Zig hashes manifest-included file contents), fall back to `git clone` + checkout +
  `zig fetch <local-dir>`.

### Constraints carried from the spike

- No push to GitHub; no hosted Ghostty-on-Windows CI run until the user explicitly
  approves. Nothing in this plan edits `.github/workflows/`.
- PowerShell file writes must use UTF-8 **without BOM**
  (`System.Text.UTF8Encoding($false)`), never `Set-Content -Encoding UTF8` — a BOM in
  `Package.swift` breaks SwiftPM tools-version parsing.
- `winget` is broken in the Frost guest (`0x8a15000f`); Zig must be fetched from
  `ziglang.org` directly.
- Frost host env: `TESSERA_FROST_ROOT=~/Developer/solcreek/frost/main`; work dir
  `~/.local/state/tessera/windows-frost`; guest SSH `tester@localhost:2222`.

## Phase 1 — Windows-safe header bridge (all platforms)

**Goal**: Remove the committed symlink that breaks Windows checkouts; make header
materialization a build-script responsibility with one cross-platform convention.

### Step 1.1 — Replace the committed `CGhosttyVT` header symlink with a build-materialized directory

- Files: `Sources/CGhosttyVT/include/ghostty` (delete symlink), `.gitignore`,
  `scripts/build-libghostty-vt.sh`, `docs/UpdatingGhosttyVT.md`.
- `git rm` the `Sources/CGhosttyVT/include/ghostty` symlink; add
  `Sources/CGhosttyVT/include/ghostty/` to `.gitignore`.
- In `scripts/build-libghostty-vt.sh`, replace `update_workspace_header_bridge_symlink()`
  (and the now-unused `.build/libghostty-vt/current` bridge) with
  `materialize_header_bridge()`: delete any existing `Sources/CGhosttyVT/include/ghostty`
  (symlink or directory), then copy `$install_dir/include/ghostty` there. Call it on both
  the fresh-build path and the already-built early-exit path (lines 126–131), so
  `just core build-libghostty-vt` always leaves a valid header directory. Keep the
  cache-level `current` symlink — it is diagnostic and POSIX-only.
- `Sources/CGhosttyVT/include/module.modulemap` (`umbrella "ghostty"`) is unchanged.
- Update `docs/UpdatingGhosttyVT.md`: describe materialization instead of the symlink;
  keep the "do not commit generated artifacts" rule (the directory is gitignored).
- Windows note: `scripts/windows-frost-sync-source.sh` packages
  `git ls-files --cached --others --exclude-standard`, so after this step the tar carries
  neither symlink nor headers — the guest materializes its own copy (Phase 4).
- Acceptance: on macOS, `just core build-libghostty-vt` then
  `swift build --target TesseraTerminalSnapshotSupport` and
  `swift test --filter TesseraTerminalSnapshotSupportTests` pass; `git status` is clean
  afterward (headers ignored); deleting `Sources/CGhosttyVT/include/ghostty` and
  re-running the build script restores it without a full rebuild.

## Phase 2 — Windows libghostty-vt build script

**Goal**: A cold Windows machine with only git + curl can produce the pinned artifact.

### Step 2.1 — Add `scripts/build-libghostty-vt.ps1` with curl-based dependency prefetch

- Files: new `scripts/build-libghostty-vt.ps1`.
- Mirror the bash script's contract:
  - Revision from `scripts/ghostty-vt-version.txt` (or `GHOSTTY_VT_REVISION_FILE`).
  - Output root: `GHOSTTY_VT_OUTPUT_DIR` else `$env:LOCALAPPDATA\tessera\libghostty-vt`.
  - Install dir: `<root>/<revision>/windows-<arch>` (`arm64`/`x86_64` from
    `$env:PROCESSOR_ARCHITECTURE`).
  - Early exit when `include/ghostty/vt.h` **and** `lib/ghostty-vt-static.lib` exist and
    `-Force` is absent; still materialize the header bridge (repo-path parameter, see
    Phase 4) before exiting.
- Zig acquisition: honor `ZIG_EXECUTABLE`; else `zig` on `PATH` if `zig version` starts
  with `0.15`; else download
  `https://ziglang.org/download/0.15.2/zig-<zigarch>-windows-0.15.2.zip` with
  `curl.exe -fL` into `$env:LOCALAPPDATA\Programs\zig\` and extract (`Expand-Archive`). Do
  not use `winget` (broken in the guest: `0x8a15000f`).
- Source checkout: `git clone`/`fetch --depth 1` the pinned revision into
  `<root>/source/<revision>` and verify `rev-parse HEAD`, matching the bash script.
- Dependency prefetch (the TLS workaround; mirrors upstream
  `nix/build-support/fetch-zig-cache.sh`):
  - Set `ZIG_GLOBAL_CACHE_DIR` explicitly (default `$env:LOCALAPPDATA\zig`) so cache
    location is deterministic.
  - For each line of `<source>/build.zig.zon.txt`:
    - `https://…` → `curl.exe -fL -o <tmp>\<basename>` then `zig fetch <tmp-file>`.
    - `git+https://<repo>#<sha>` →
      `curl.exe -fL -o <tmp>\<sha>.tar.gz https://<repo-path>/archive/<sha>.tar.gz` then
      `zig fetch <tmp-file>`; verify the printed cache key against the matching entry in
      `build.zig.zon.json`, falling back to `git clone` + `git checkout <sha>` +
      `zig fetch <local-dir>` on mismatch.
  - Fail with the URL and curl/zig output on any error; no silent skips.
- Build: `zig build -Demit-lib-vt -Dsimd=false -Doptimize=ReleaseFast --prefix <install>`
  from the source checkout (flags proven in the spike).
- Post-build: write `build-metadata.txt` (same keys as the bash script) using
  `System.Text.UTF8Encoding($false)`; no `current` symlink on Windows.
- Acceptance (run in the Frost persistent VM): with `ZIG_GLOBAL_CACHE_DIR` pointed at an
  **empty** directory, the script completes end-to-end and the install dir contains
  `bin/ghostty-vt.dll`, `lib/ghostty-vt.lib`, `lib/ghostty-vt-static.lib`, and
  `include/ghostty/vt.h`. Re-running exits early via the built check.

## Phase 3 — Package and source enablement behind `canImport(CGhosttyVT)`

**Goal**: One package graph that compiles Ghostty in whenever `CGhosttyVT` is present:
always on macOS/Linux, on Windows only under the explicit local gate.

### Step 3.1 — Gate `CGhosttyVT` on Windows by environment opt-in; link the static library

- Files: `Package.swift`.
- Replace the `#if !os(Windows)` guards around the `CGhosttyVT` forward declaration (line
  116), target append (line 158), snapshot-support platform dependencies (lines 377–383),
  and the Ghostty VT build-output block (line 423) with one manifest constant:

  ```swift
  #if os(Windows)
    let GhosttyVTEnabled =
      ProcessInfo.processInfo.environment["TESSERA_GHOSTTY_WINDOWS"] == "1"
  #else
    let GhosttyVTEnabled = true
  #endif
  ```

  and `if GhosttyVTEnabled { … }` around the target/dependency/linker wiring.

- In the build-output block: add `GhosttyVTPlatform = "windows"`; extend
  `defaultGhosttyVTOutputRoot` so Windows falls back to
  `LOCALAPPDATA\tessera\libghostty-vt` (keep `GHOSTTY_VT_OUTPUT_DIR` as the primary
  override — Frost sets it); Windows linker flags are `["-L<lib>", "-lghostty-vt-static"]`
  — no `-rpath` (POSIX flags unchanged).
- If `ghostty-vt-static.lib` fails to link under Swift/MSVC (undefined compiler-rt symbols
  are the plausible failure), fall back to `-lghostty-vt` (import lib) and add the
  artifact `bin` `PATH` prepend to `run-windows-frost-tests.ps1` in Phase 4; record which
  path was taken in the investigation.
- Acceptance: on macOS, `swift package describe` and the snapshot-support tests are
  unchanged. In the Frost guest: without `TESSERA_GHOSTTY_WINDOWS`, `swift build` succeeds
  with Ghostty compiled out; with `TESSERA_GHOSTTY_WINDOWS=1` + `GHOSTTY_VT_OUTPUT_DIR`
  set, `swift build --target TesseraTerminalSnapshotSupport` links against the Phase 2
  artifact.

### Step 3.2 — Convert source guards from `#if !os(Windows)` to `#if canImport(CGhosttyVT)`

- Files: `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`,
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminalError.swift`,
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+platformUnsupported.swift`, plus
  the ~38 `.disabled(if:)` call sites in
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererVisualEquivalenceTests.swift`,
  `Tests/TesseraTerminalSnapshotSupportTests/VirtualTerminalTests.swift`,
  `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`.
- Mechanical conversions:
  - `VirtualTerminal+Ghostty.swift`: outer `#if !os(Windows)` →
    `#if canImport(CGhosttyVT)`.
  - `VirtualTerminalError.swift`: both guards → `#if canImport(CGhosttyVT)`.
  - `VirtualTerminal+platformUnsupported.swift`: rename `isPlatformUnsupported` →
    `isGhosttyUnavailable` and `ghosttyOrPlatformUnsupported` → `ghosttyOrUnavailable`
    (keep `platformUnsupported` internals but rename to `ghosttyUnavailable`; update the
    issue-reporting message to say "libghostty-vt is not available in this build"); switch
    its `#if os(Windows)` branches to `#if canImport(CGhosttyVT)` (inverted).
  - Update every test call site to the new names; the runtime skip-trait pattern itself is
    unchanged. This is a good `sonic` delegation.
- No IO-target changes: the `os(Windows)` guards in `TesseraTerminalIO` are real platform
  seams, not Ghostty availability, and stay as they are.
- Acceptance: macOS `swift test --filter TesseraTerminalSnapshotSupportTests` and
  `--filter TesseraTerminalANSITests` pass (suites run, not skipped); Frost gate-off
  `swift test --no-parallel` passes with the Ghostty suites reported skipped, matching
  today.

## Phase 4 — Frost workflow, docs, and verification

**Goal**: `just windows-frost test` exercises the real Ghostty-backed suites, using a
host-cached artifact so disposable overlays stay fast; docs cover the whole loop.

### Step 4.1 — Cache the Windows artifact on the host and provision it into test guests

- Files: new `scripts/windows-frost-build-ghostty.sh`, `justfiles/windows-frost.just`,
  `scripts/windows-frost-test.sh`, `scripts/run-windows-frost-tests.ps1`.
- `scripts/windows-frost-build-ghostty.sh` + `just windows-frost build-ghostty`: requires
  the persistent VM (`just windows-frost start`); syncs source
  (`windows-frost-sync-source.sh`); runs `scripts/build-libghostty-vt.ps1` in the guest
  over SSH; copies `<revision>/windows-arm64` back to
  `$TESSERA_FROST_WORK/libghostty-vt/<revision>/windows-arm64` (tar over SSH, matching the
  sync-source transport). Idempotent: skips the guest build when the host cache for the
  pinned revision already exists unless `--force`.
- `scripts/windows-frost-test.sh`: after `[4/7] sync source`, check the host cache for the
  pinned revision — missing → fail fast with "run `just windows-frost build-ghostty`
  first" (keeps disposable runs deterministic; no surprise 20-minute in-guest builds).
  Present → tar-copy it into the guest at
  `C:/Users/tester/AppData/Local/tessera/libghostty-vt/<revision>/windows-arm64`, then
  pass `-GhosttyOutputDir C:/Users/tester/AppData/Local/tessera/libghostty-vt` to the
  guest test script.
- `scripts/run-windows-frost-tests.ps1`: add `-GhosttyOutputDir`; when set, (a) copy
  `<output>/<revision>/windows-arm64/include/ghostty` into
  `$RepoPath/Sources/CGhosttyVT/include/ghostty` (materialize — the source tar no longer
  carries headers), (b) set `GHOSTTY_VT_OUTPUT_DIR` and `TESSERA_GHOSTTY_WINDOWS=1` for
  the `swift` invocations, and (c) if Step 3.1 landed on the import-lib fallback, prepend
  `<artifact>\bin` to `$env:Path`. When absent, run exactly as today (gate off).
- Acceptance: `just windows-frost build-ghostty` populates the host cache;
  `just windows-frost test -- --filter TesseraTerminalSnapshotSupportTests` runs the suite
  for real in a disposable overlay (6 tests executed, not skipped).

### Step 4.2 — Update docs and verify the full Windows snapshot suite in Frost

- Files: `docs/UpdatingGhosttyVT.md`, `CONTRIBUTING.md`,
  `.agents/investigations/006-windows-libghostty-vt-snapshot-spike.md`.
- `docs/UpdatingGhosttyVT.md`: add the Windows path to the update process
  (`build-libghostty-vt.ps1`, prefetch behavior, `just windows-frost build-ghostty` after
  a pin bump); document `TESSERA_GHOSTTY_WINDOWS`.
- `CONTRIBUTING.md`: extend the Windows Frost workflow section with the `build-ghostty` →
  `test` loop.
- Investigation 006: append an enablement note pointing at this plan; keep `resolved`.
- Full verification (all local):
  - Frost: `just windows-frost test` (full suite) green with Ghostty suites executing —
    expected counts from the spike: SnapshotSupport 6, ANSI 34, Rendering 47,
    ModeLifecycle 8.
  - macOS: `just quality changed` during iteration; `just quality lint` before any commit;
    full `swift test` green.
  - Markdown: `pnpx markdownlint-cli` on every edited `.md`.
- Explicit non-goals, pending user approval: no `.github/workflows/` changes, no push, no
  hosted Ghostty-on-Windows CI run.

## Risks

- **Static lib link failure under Swift/MSVC** — mitigated by the documented
  import-lib-plus-`PATH` fallback already proven in the spike.
- **uucode tarball hash mismatch vs git-tree hash** — mitigated by the clone +
  `zig fetch <dir>` fallback; verified against `build.zig.zon.json` keys either way.
- **`zig fetch <local-file>` cache-key parity** — high confidence (Zig hashes unpacked,
  manifest-filtered content, and the spike's cache-copy proved content-addressed reuse);
  Phase 2's cold-cache acceptance test settles it empirically before anything depends on
  it.
- **Disposable-overlay staleness after a pin bump** — the host cache is keyed by revision
  and the test script fails fast when the pinned revision's artifact is missing, so a bump
  cannot silently test against an old library.
