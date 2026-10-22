---
type: spec
description: "Terminal citizenship thesis: be composable, not a compatibility ceiling"
---

# Terminal citizenship thesis: be composable, not a compatibility ceiling

Tessera is a terminal **producer**: it turns application/view intent into bytes. It is not
an emulator, a PTY host, or a tmux-class multiplexer. The goal is therefore not “support
every terminal standard ever emitted by arbitrary guest programs.” That is the decoder and
screen-model problem that belongs to terminal emulators and multiplexers.

Tessera's citizenship goal is narrower and more important: **never be the layer that
needlessly strips, blocks, or hides a terminal feature.** For a producer library, that
means four design rules:

1. **Restore the terminal on every exit path.** Raw mode, alternate screen, cursor
   visibility, mouse tracking, bracketed paste, focus events, Kitty keyboard, synchronized
   output, and future protocol modes must have symmetric teardown owned by the session.
2. **Expose a scoped raw-output escape hatch.** Users need a way to emit a protocol
   Tessera does not model yet — sixel, iTerm2 inline images, a future OSC, vendor
   extensions — without forking the library. This must be rendered data inside a frame,
   paired with explicit damage-tracking policy, not a public file descriptor or arbitrary
   live write.
3. **Treat capabilities as advisory and degrade gracefully.** Respect environment and user
   policy (`NO_COLOR`, color depth, `TERM`/`COLORTERM`, nested tmux/screen, Windows VT
   mode), observe protocols that actually respond, and let apps inspect what Tessera
   assumed or detected. Capability uncertainty should reduce feature use, not break
   startup.
4. **Coexist with the surrounding terminal session.** Support alternate-screen apps and
   future inline rendering, keep signal/suspend/resume behavior polite, avoid hidden
   global state, and make advanced protocol enablement explicit in session/runtime policy.

The escape hatch is intentionally modeled after the lesson in Ratatui's current buffer
layer: `CellDiffOption` exists because raw ANSI/OSC payloads can affect the screen without
matching the bytes or width of a normal grapheme. Tessera should start with a richer
per-cell/region diff policy instead of retrofitting a boolean later.

If a future Tessera sibling project hosts guest applications in panes, that project is a
terminal emulator/multiplexer. It should embed or delegate to a real VT engine for the
per-pane decode/screen model and keep Tessera for producer-side chrome. Do not let that
future scope leak into Tessera's Phase 1–3 terminal producer substrate.
