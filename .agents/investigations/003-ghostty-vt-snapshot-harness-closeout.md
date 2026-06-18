---
name: Ghostty VT Snapshot Harness Closeout
date: 2026-06-06
status: resolved
---

# Ghostty VT Snapshot Harness Closeout

## Question

What Ghostty integration path did Tessera choose for Phase 2 Slice 1, which APIs does it
use, and which platforms have been validated?

## Findings

- Tessera owns a direct source build of Ghostty's `libghostty-vt`, pinned in
  `scripts/ghostty-vt-version.txt` to commit `ae52f97dcac558735cfa916ea3965f247e5c6e9e`.
- Local and CI builds run through `scripts/build-libghostty-vt.sh`, which installs
  artifacts under `.build/libghostty-vt/<revision>/<platform>-<arch>/` and refreshes the
  SwiftPM-facing `.build/libghostty-vt/current` symlink.
- SwiftPM sees Ghostty through the internal `CGhosttyVT` C target and links only
  `TesseraTerminalSnapshotSupport` against it. Public Tessera products do not expose or
  depend on Ghostty.
- The live `VirtualTerminal.ghostty(cols:rows:)` implementation uses:
  - `ghostty_terminal_new`
  - `ghostty_terminal_vt_write`
  - `ghostty_render_state_new`
  - `ghostty_render_state_update`
  - `ghostty_render_state_get` for cursor position and row iteration
  - `ghostty_render_state_row_get` for row cells
  - `ghostty_render_state_row_cells_next`, `ghostty_render_state_row_cells_select`, and
    `ghostty_render_state_row_cells_get` for text, style, and color inspection
- Each call to `VirtualTerminal.ghostty(cols:rows:)` creates a fresh Ghostty terminal
  state. The state is protected by `Synchronization.Mutex`, and the implementation avoids
  `@unchecked Sendable`.
- SnapshotTesting helpers live in `TesseraTerminalTestSupport`:
  - `.terminalText(trim:)`
  - `.terminalStyledGrid(trim:)`
  - `.terminalDebugDump`
- macOS arm64 validation passed with:
  - `swift test --filter TesseraTerminalSnapshotSupportTests`
  - `swift test --filter TesseraTerminalRenderingTests`
  - `just quality changed`
- Local Linux validation passed in the Lima VM with `just linux test` after installing
  Ghostty build prerequisites and Zig 0.15.2. The VM recipe now provisions those tools and
  `just linux test` builds/refreshes `libghostty-vt` before running `swift test`.
- Local Homebrew prerequisites are listed in `Brewfile` under "Ghostty Test Harness":
  `cmake`, `ninja`, and `zig@0.15`.
- `docs/UpdatingGhosttyVT.md` documents how to update the pinned Ghostty revision and how
  the cache/symlink path works.

## Conclusion

Phase 2 Slice 1 can use direct `libghostty-vt` as Tessera's screen-state reconstruction
backend on macOS and Linux. Windows remains future work. The main follow-up is to keep the
Ghostty C API isolated behind `TesseraTerminalSnapshotSupport` as upstream APIs evolve.
