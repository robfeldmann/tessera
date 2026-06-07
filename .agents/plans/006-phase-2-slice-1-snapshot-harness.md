---
name: Phase 2 Slice 1 Ghostty Snapshot Harness
description:
  Build the Ghostty-backed virtual terminal harness for renderer snapshot coverage.
status: in-progress
created: 2026-06-05
updated: 2026-06-05
---

## Progress

- [x] **Phase 1 — Ghostty feasibility spike**
  - [x] 1.1 Create an isolated spike branch/worktree
  - [x] 1.2 Compare Ghostty integration paths and prove `feed → inspect`
  - [x] 1.3 Record the spike findings and recommendation
- [x] **Phase 2 — Correct the slice direction and build path**
  - [x] 2.1 Update `docs/Spec.md` based on the accepted spike result
  - [x] 2.2 Add pinned source build script and CI cache for libghostty-vt
  - [x] 2.3 Wire the selected direct libghostty-vt integration path on macOS and Linux
- [ ] **Phase 3 — Ghostty-backed inspection API**
  - [x] 3.1 Add `VirtualTerminal` dependency and durable inspection types
  - [ ] 3.2 Implement `VirtualTerminal` on top of Ghostty with focused harness tests
- [ ] **Phase 4 — Renderer integration snapshots**
  - [ ] 4.1 Add readable terminal snapshot/custom-dump helpers
  - [ ] 4.2 Add an end-to-end renderer-to-Ghostty snapshot test
- [ ] **Phase 5 — Slice closeout**
  - [ ] 5.1 Document Ghostty integration limits and platform support
  - [ ] 5.2 Run slice validation and update progress

## Overview

This plan implements Phase 2 Slice 1 from `docs/Spec.md`. Phase 1 validated that Ghostty
can provide the needed `feed → inspect` terminal-state API and that Tessera should own a
narrow direct `libghostty-vt` integration rather than use the broader `GhosttyKit` surface
wrapper. Ghostty/libghostty-vt is itself cross-platform, including Linux; any platform
gating should come from the actual build path, not from assumptions about Apple-only
SwiftPM wrappers. The main Tessera products still must not depend on Ghostty;
`libghostty-vt` belongs behind `TesseraTerminalSnapshotSupport` so the production terminal
library remains portable.

## Phase 1 — Ghostty feasibility spike

**Goal**: Validate Ghostty integration before updating the spec or production package
graph.

### Step 1.1 — Create an isolated spike branch/worktree

- Files: none required in `main`; spike files may be throwaway.
- Create a separate branch such as `spike/ghostty-vt-harness` or a linked worktree so the
  experiment can freely edit `Package.swift`, add scratch targets, and test build scripts.
- Keep any committed plan/spec edits on the main implementation branch unless explicitly
  choosing to preserve spike artifacts.
- Acceptance: the spike environment is isolated and the current reviewable plan remains
  intact.

### Step 1.2 — Compare Ghostty integration paths and prove `feed → inspect`

- Files: scratch package/target files on the spike branch/worktree.
- Evaluate at least:
  - an existing SwiftPM wrapper that exposes Ghostty's C API;
  - direct libghostty source/build integration owned by Tessera.
- For each viable path, determine how to create a terminal/parser, feed bytes, inspect
  cells, inspect cursor position, and map colors/styles into Tessera values.
- Do not use a SwiftPM `platforms` array as evidence that Linux is unsupported; SwiftPM
  has no `.linux` platform declaration. Gate only when an actual dependency artifact or
  build step requires it.
- Acceptance: a tiny scratch program or test feeds text plus one cursor/style sequence and
  reads back enough state to prove the harness API is implementable, or documents the
  blocker precisely.

### Step 1.3 — Record the spike findings and recommendation

- File: `.agents/investigations/<date>-ghostty-vt-harness-spike.md`
- Record which package/revision/build path was tried, which APIs worked, which platforms
  were actually validated, and the recommended implementation path.
- Include a clear yes/no on whether to proceed with Ghostty for Slice 1 now.
- Acceptance: the investigation is sufficient to update `docs/Spec.md` and the remaining
  plan without re-running the spike.

## Phase 2 — Correct the slice direction and build path

**Goal**: Align the spec, package graph, and reproducible libghostty-vt build path with
the accepted spike result.

### Step 2.1 — Update the spec based on the accepted spike result

- File: `docs/Spec.md`
- Rewrite Phase 2 Slice 1 around direct `libghostty-vt` as Tessera's rendering reference.
- Remove the stale hand-rolled VT and `GhosttyKit`/surface-wrapper directions as active
  implementation paths.
- Capture the testing philosophy: raw byte tests still belong at the ANSI encoder layer,
  while renderer/view tests assert Ghostty-reconstructed screen state.
- Acceptance: `pnpx markdownlint-cli docs/Spec.md` passes.
- Completed: `docs/Spec.md` now describes direct `libghostty-vt`, `VirtualTerminal`,
  snapshot strategies, concurrency constraints, and the damage-tracking test shape.

### Step 2.2 — Add pinned source build script and CI cache for libghostty-vt

- Files:
  - `scripts/ghostty-vt-version.txt`
  - `scripts/build-libghostty-vt.sh`
  - CI workflow/cache files discovered during implementation
  - documentation comments or docs for local prerequisites
- Pin Ghostty in one committed text file, preferably to an exact commit while
  `libghostty-vt` APIs are still evolving. Move to a release tag later only when the
  needed VT/render-state API is stable in a Ghostty release.
- Add a script that builds or locates `libghostty-vt` from source for the current
  platform/architecture. Inputs should include the pinned Ghostty revision, output
  directory, Zig version, and build mode.
- Output build artifacts under `.build/libghostty-vt/<revision>/<platform>-<arch>/` or an
  equivalent ignored build directory, including headers and the dynamic/static library
  needed by `CGhosttyVT`.
- Use source build plus GitHub Actions cache for now; do not commit built libraries or use
  Git LFS in this slice. Cache keys should include at least Ghostty revision, OS, arch,
  Zig version, and the build script hash.
- Install or document prerequisites for both local and CI builds:
  - Zig 0.15.x
  - CMake
  - Ninja
  - C compiler/toolchain
  - Linux packages required by the Ghostty/Ghostling build path, if any
- Acceptance: the script can build `libghostty-vt` on macOS and Linux, reuses cached
  artifacts in CI when available, and leaves no generated artifacts tracked by Git.
- Completed: added `scripts/ghostty-vt-version.txt` pinned to Ghostty commit
  `ae52f97dcac558735cfa916ea3965f247e5c6e9e`, added `scripts/build-libghostty-vt.sh`, and
  added a GitHub Actions cache for `.build/libghostty-vt` keyed by OS, architecture, Zig
  version, pinned revision, and build script hash. The script was validated locally on
  macOS arm64 and reuses the existing generated artifacts on a second run.

### Step 2.3 — Wire the selected direct libghostty-vt integration path on macOS and Linux

- Files:
  - `Package.swift`
  - C module/build support files to be determined during implementation
  - scripts or CI setup needed to build/find `libghostty-vt`
  - any CI workflow files discovered during implementation
- Expose the scripted `libghostty-vt` output to Swift via a narrow `CGhosttyVT`-style
  C/system-library module.
- Validate and support both macOS and Linux by the end of this plan; Linux is not a
  follow-up unless an external blocker is documented and accepted.
- Depend on that module only from `TesseraTerminalSnapshotSupport` or a snapshot test
  target, not from public Tessera products.
- Gate only for actual dependency artifact/build-step limits discovered during
  implementation. Windows may remain skipped/documented until Phase 2 Slice 6.
- Acceptance: `swift package describe` succeeds, and the narrow snapshot-support build
  succeeds on macOS and Linux.
- Completed: added the internal `CGhosttyVT` C target, linked
  `TesseraTerminalSnapshotSupport` to the built `libghostty-vt` artifact directory, and
  updated CI to install Zig/prerequisites, restore the libghostty-vt cache, and run the
  source build before `just ci`. Local validation passed on macOS arm64 with
  `swift package describe` and `swift build --target TesseraTerminalSnapshotSupport`.

## Phase 3 — Ghostty-backed inspection API

**Goal**: Provide the stable `feed → inspect` Swift API backed by Ghostty.

### Step 3.1 — Add `VirtualTerminal` dependency and durable inspection types

- File: `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal.swift`
- Add `VirtualTerminal` as a Point-Free Dependencies factory seam, with a Ghostty live
  implementation and an unimplemented/test default.
- Add the needed `Dependencies` target dependency only to snapshot support, not to public
  Tessera products unless already required elsewhere.
- Add `VirtualTerminal` as the per-test session interface returned by its own
  `make(cols:rows:)` factory, with `feed(_ bytes:)`, `feed(_ string:)`, `text(row:)`,
  `cell(row:column:)`, `cursorPosition()`, and `snapshot()`.
- Add `RenderedCell`, `RenderedColor`, and `ScreenSnapshot` with the public API from the
  spec.
- Keep Ghostty-specific symbols private/internal so renderer tests depend on the stable
  Tessera harness API only.
- Acceptance: `swift build --target TesseraTerminalSnapshotSupport` passes on macOS and
  Linux.
- Completed: added the macro-free `VirtualTerminal` Point-Free Dependencies seam, durable
  per-session client interface, `RenderedCell`, `RenderedColor`, and `ScreenSnapshot` API
  shapes, and the target dependencies on `Dependencies`, `IssueReporting`, and
  `TesseraTerminalCore`. The live factory is wired through a Ghostty entry point that Step
  3.2 will replace with the concrete `libghostty-vt` implementation.

### Step 3.2 — Implement `VirtualTerminal` on top of Ghostty with focused harness tests

- Files:
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal.swift`
  - `Tests/TesseraTerminalSnapshotSupportTests/VirtualTerminalTests.swift`
- Bridge direct `libghostty-vt` terminal/render-state APIs into Tessera's
  `VirtualTerminal`, `RenderedCell`, `RenderedColor`, `TerminalPosition`, and
  `ScreenSnapshot` values.
- Use `ghostty_terminal_vt_write` for feeding bytes and render-state row/cell inspection
  for text, styles, colors, and cursor position.
- Add tests for initial blank screen, character writes, cursor movement, erase behavior,
  SGR style/color inspection, and cursor inspection.
- Keep each `VirtualTerminal` owned by one test; do not introduce `@unchecked Sendable`.
- Keep any API-discovery scratch code out of committed sources.
- Acceptance: `swift test --filter TesseraTerminalSnapshotSupportTests` passes on macOS
  and Linux.

## Phase 4 — Renderer integration snapshots

**Goal**: Use Ghostty to inspect real renderer bytes in a readable whole-screen test.

### Step 4.1 — Add preferred SnapshotTesting strategies for terminal screens

- File: `Sources/TesseraTerminalTestSupport/VirtualTerminalSnapshotting.swift`
- Define reusable `Snapshotting` strategies in SnapshotTesting's preferred style, e.g.
  `extension Snapshotting where Value == ScreenSnapshot, Format == String` or the most
  ergonomic equivalent after checking the library API.
- Add three explicit strategies:
  - text grid: character rows only, for layout and everyday renderer behavior;
  - styled grid: character rows plus a spatially aligned style/attribute grid;
  - debug dump: richer diagnostics including cursor position and useful cell/style
    metadata for complex failures.
- Make whitespace policy explicit in the text/styled strategies, e.g. trailing-trimmed
  layout snapshots and exact-row snapshots when spaces matter.
- Keep custom-dump helpers only where they complement SnapshotTesting strategies; do not
  make ad hoc dumps the primary snapshot API.
- Keep raw byte dumps with existing renderer helpers when terminal byte output itself is
  under test.
- Acceptance: dependent targeted tests compile and renderer snapshot tests use the new
  strategies rather than one-off formatting.

### Step 4.2 — Add an end-to-end renderer-to-Ghostty snapshot test

- File: `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`
- Feed Phase 1 renderer output into `VirtualTerminal` and assert the resulting
  `ScreenSnapshot` with `assertInlineSnapshot`/custom dump.
- Generate inline snapshots by recording them rather than hand-writing large snapshot
  bodies.
- Acceptance: `swift test --filter TesseraTerminalRenderingTests` passes on macOS and
  Linux.

## Phase 5 — Slice closeout

**Goal**: Capture known limits and validate the slice before review.

### Step 5.1 — Document Ghostty integration limits and platform support

- File: `.agents/investigations/` or the relevant docs section, depending on what is most
  useful after implementation.
- Record which Ghostty package/revision/build path was chosen, which APIs are used, and
  which platforms are actually covered by snapshot tests today.
- Acceptance: future agents can tell how to update Ghostty, build it on Linux, or debug
  any intentional platform skips.

### Step 5.2 — Run slice validation and update progress

- Files:
  - `.agents/plans/006-phase-2-slice-1-snapshot-harness.md`
  - changed source/test/doc files
- Run the narrow target tests first, then `just lint-changed`; run markdown lint for all
  edited Markdown.
- Before requesting review, run `swift test --filter TesseraTerminalSnapshotSupportTests`
  and `swift test --filter TesseraTerminalRenderingTests` on macOS and Linux.
- Acceptance: validation passes or any failures are documented with the next action.

## References

- `docs/Spec.md`, Phase 2 Slice 1: The snapshot harness.
- `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal.swift` existing placeholder.
- `.agents/investigations/002-ghostty-vt-harness-spike.md`.
- Ghostty upstream describes `libghostty-vt` as cross-platform; wrapper/package/build
  constraints must be verified separately from Ghostty's own platform support.
