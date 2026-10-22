---
name: Herdr Cursor and Underline Color Loss
date: 2026-07-09
status: resolved
---

# Herdr Cursor and Underline Color Loss

## Question

Do herdr issue [#1234](https://github.com/ogulcancelik/herdr/issues/1234), where a child
pane's OSC 12/112 cursor color does not affect the visible host cursor, and missing Neovim
underline colors inside herdr share a root cause?

## Findings

- Vendored `libghostty-vt` parses and stores both feature families. Cursor color is
  available through `src/ghostty/mod.rs`'s `effective_cursor_color`. Underline style and
  color reach `CellStyle` and are projected into Ratatui `Style` by `ghostty_cell_style`
  in `src/pane/terminal.rs`.
- Cursor color disappears after terminal-core state. `TerminalCursorState` in
  `src/pane/terminal.rs` contains only `x`, `y`, `visible`, and `shape`. `CursorState` in
  `src/protocol/wire.rs` has the same fields. `HostCursorState` and
  `write_host_cursor_state` in `src/protocol/render_ansi.rs` emit cursor position,
  DECSCUSR shape, and visibility, but have no color state and emit neither OSC 12 nor
  OSC 112.
- Underline color disappears at an analogous projection boundary. `ghostty_cell_style`
  assigns `Style::underline_color`, but `CellData` in `src/protocol/wire.rs` contains only
  `symbol`, foreground, background, modifier bits, skip state, and hyperlink index.
  `build_sgr` in `src/protocol/render_ansi.rs` accepts only foreground, background, and
  modifiers, so the semantic frame/ANSI path cannot emit SGR 58/59. Underline variants
  survive separately through custom modifier bits and can be re-emitted as SGR `4:2`
  through `4:5`.
- A raw live-pane probe bypassing Neovim confirmed the Ghostty pane core accepts the
  protocols. Feeding SGR `4:3;58;2;255;0;0` and `4:2;58;2;0;128;255` produced
  `pane read --ansi` output containing both exact `4:x` variants and exact SGR 58 colors.
- Neovim adds a second, independent capability-negotiation problem. Herdr forces child
  panes to `TERM=xterm-256color` and `COLORTERM=truecolor` in `src/pane.rs`. The local
  `xterm-256color` terminfo lacks `Smulx` and `Setulc`. In a normal herdr Neovim pane,
  readback contained only basic SGR 4 and no SGR 58. Launching the same clean Neovim demo
  with `TERM=xterm-ghostty` inside herdr caused readback to contain `4:3`, `4`, `4:2`, and
  the requested RGB SGR 58 values.
- Herdr has explicit XTGETTCAP responses for `Smulx` and `Setulc` in
  `src/pane/xtgettcap.rs`, but the observed Neovim startup still changed behavior based on
  the forced `TERM`. The override experiment establishes the capability-advertisement
  boundary without proving which Neovim discovery path won.

## Conclusion

The cursor-color issue and visually lost underline color are the same architectural class
of bug: the embedded terminal understands the child protocol, but herdr's intermediate
render model does not carry the color to host-terminal emission. They are not the same
parser bug and need separate state fields and encoders.

Issue #1234 should carry optional cursor color through `TerminalCursorState`, wire
`CursorState`, render diff memory, and `HostCursorState`, then emit OSC 12 on a
concrete-color transition and OSC 112 when returning to default. Underline color needs an
optional/encoded underline-color field in `CellData`, frame comparison/diffing, and SGR
58/59 output in `build_sgr`.

Neovim also needs truthful underline capability advertisement. A dedicated herdr terminfo
entry or another discovery path that Neovim consumes is safer than globally claiming
`xterm-ghostty`; the latter misidentifies the intermediary and may advertise protocols
herdr cannot preserve end to end.
