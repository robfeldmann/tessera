---
name: Ghostty VT Harness Spike
date: 2026-06-06
status: resolved
---

# Ghostty VT Harness Spike

## Question

Can Tessera implement Phase 2 Slice 1 with a Ghostty-backed `feed → inspect` snapshot
harness now, and should it use an existing SwiftPM wrapper or own a direct libghostty-vt
integration?

## Findings

- Created an isolated worktree/branch:
  - Branch: `spike-ghostty-vt-harness`
  - Path: `/Users/rob/Developer/robfeldmann/tessera/spike-ghostty-vt-harness`
- Existing SwiftPM wrappers inspected:
  - `ignislabsio/libghostty-spm`
  - `Lakr233/libghostty-spm`
- Both wrappers package the broader Ghostty embedding API as `GhosttyKit`, backed by an
  Apple `GhosttyKit.xcframework`/`libghostty` binary artifact.
- The wrapper API exposes `ghostty_surface_*` APIs, including
  `ghostty_surface_write_buffer` and `ghostty_surface_read_text`, but this is the full
  surface/app embedding layer rather than the standalone VT API.
- A scratch executable linked against the wrapper after adding missing Apple framework
  link settings (`CoreVideo`, `IOSurface`, `Metal`, `QuartzCore`), but creating a surface
  was not straightforward in a headless test process:
  - `ghostty_surface_new` returned `nil` when no AppKit view was provided.
  - Providing a detached `NSView` caused a segmentation fault.
- The wrapper path does not appear ideal for Tessera's snapshot harness because it pulls
  in renderer/platform concerns and Apple binary artifacts when the harness needs only VT
  parsing and screen-state inspection.
- Direct libghostty-vt source integration was validated through Ghostling:
  - Cloned `ghostty-org/ghostling` in the spike worktree.
  - Built Ghostty's `zig_build_lib_vt` CMake target using Zig 0.15.2.
  - Produced `libghostty-vt` plus headers under
    `.spike-deps/ghostling/build/_deps/ghostty-src/zig-out/`.
- The generated `ghostty/vt.h` header is exactly the API Tessera needs. It documents
  libghostty-vt as the terminal emulator library responsible for parsing escape sequences
  and maintaining terminal state such as styles, cursor position, screen, and scrollback.
- A C scratch probe proved the core `feed → inspect` flow:
  - `ghostty_terminal_new`
  - `ghostty_terminal_resize`
  - `ghostty_terminal_vt_write`
  - `ghostty_render_state_update`
  - `ghostty_render_state_get` for cursor position
  - row/cell iteration with `ghostty_render_state_row_iterator_next` and
    `ghostty_render_state_row_cells_next`
  - cell text via `GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_*`
  - style/color via `GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_STYLE`,
    `GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_FG_COLOR`, and
    `GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_BG_COLOR`
- The C probe fed `Hello ESC[2;3H ESC[1;3;4;38;5;196;48;2;1;2;3mXY` and read back:
  - cursor at zero-based `(x: 4, y: 1)`
  - row 0 text: `"Hello   "`
  - row 1 text: `"  XY    "`
  - bold/italic/underline style on `X`/`Y`
  - resolved foreground red from indexed color 196 and background RGB `(1,2,3)`
- A SwiftPM scratch probe also proved Swift can call direct libghostty-vt through a small
  system-library target:
  - `Sources/CGhosttyVT/module.modulemap`
  - symlinked/copied `ghostty` headers under the system-library include directory
  - executable linker settings with `-L` and `rpath` pointing at the built lib
  - imported `CGhosttyVT` from Swift and read back cursor/text via the same APIs
- Local direct libghostty-vt validation was on macOS only. Ghostling documents Linux build
  dependencies and says libghostty-vt supports Windows, but this spike did not validate
  those platforms.

## Conclusion

Proceed with Ghostty for Phase 2 Slice 1, but do **not** use `GhosttyKit`/the existing
SwiftPM wrappers for the snapshot harness. Tessera should own a narrow direct
`libghostty-vt` integration, probably as an internal C/system-library support target plus
build documentation/scripts that produce or locate the library and headers.

The durable Tessera API should remain `VirtualTerminal`, `RenderedCell`, `RenderedColor`,
and `ScreenSnapshot`. The Ghostty-specific C API should stay behind that boundary so
future libghostty-vt API changes affect only snapshot support.

Next implementation steps:

1. Update `docs/Spec.md` so Phase 2 Slice 1 clearly targets direct `libghostty-vt`, not a
   hand-rolled VT and not the full `GhosttyKit` surface wrapper.
2. Add package/build wiring for a narrow `CGhosttyVT`-style module.
3. Implement `VirtualTerminal` on top of `ghostty_terminal_vt_write` and render-state
   row/cell inspection.
4. Decide whether CI builds libghostty-vt from source or uses cached/prebuilt artifacts;
   Linux should be treated as expected future support, not assumed unsupported.

## Brew installs during spike

Installed during this spike:

- `cmake`
- `ninja`

Already present and used, but not installed during this spike:

- `zig@0.15`
