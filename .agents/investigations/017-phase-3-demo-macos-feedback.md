---
name: Phase 3 demo macOS feedback
date: 2026-07-11
status: resolved
---

# Phase 3 demo macOS feedback

## Question

Which reported Phase 3 demo behaviors are application defects, protocol limitations,
renderer bugs, or terminal-emulator limitations, and what should change?

## Findings

### Navigation, hints, and input state

- `DemoControls.tabs` is the single source for numeric routing, tab rendering, and click
  hit regions. The requested order can be implemented without a second navigation mapping.
- The Mouse panel intentionally records every mouse event. Outside that panel, `m`
  controls only pointer-motion logging; press, release, and scroll events remain visible.
  Calling it an event-log filter was inaccurate.
- Kitty keyboard protocol event types encode press, repeat, and release as values 1, 2,
  and 3. Tessera requests event types and parses all three. The application-wide default
  remains the conservative mask 7, but configuration now accepts an exact startup flag
  mask. The demo requests mask 31, including `reportAllKeysAsEscapeCodes` and
  `reportAssociatedText`, so bare modifiers and text-key releases are observable whenever
  Kitty mode is effective.
- `TerminalSession.invalidateRenderer()` is the existing full-repaint seam. It emits an
  erase before the next repaint and is safe to expose as a collision-free global `r` demo
  action.

### OSC 8 links

- The demo combined an explicit SGR single underline with Ghostty's own hyperlink-hover
  underline. The two affordances visually layered into a double underline; Tessera did not
  leak OSC 8 scope across the row. Link styles should leave hover decoration to the
  terminal.
- Disabling hyperlink rendering correctly removes OSC 8 metadata and invalidates the
  renderer, but the demo retained its blue single-underline presentation. Disabled links
  need an intentionally distinct non-link style so the policy change is visible.
- `file://Sources/...` parses `Sources` as an authority/host under RFC 8089. A local file
  link must use an absolute, percent-encoded `file:///...` URI. The demo can derive that
  URI from its compile-time source location.

### Underline evidence and Apple Terminal

- The demo previously left `underlineCompatibility` set to `.off`, so underline
  declarations were always `.unknown`; it never attempted terminfo lookup. Explicit
  `.terminfoDatabase` compatibility makes the Caps panel useful while keeping declarations
  advisory.
- The system `xterm-256color` entry used by Apple Terminal does not declare `Smulx` or
  `Setulc`. Ghostty's bundled `xterm-ghostty` entry declares both when its terminfo root
  is readable. `.unknown` means no readable entry, not unsupported terminal behavior.
- Apple Terminal 2.15 misinterprets extended underline style/color sequences; this is an
  emulator limitation already documented in investigation 015. A caller-selected terminfo
  projection gives the demo a conservative baseline for the ordinary Apple Terminal entry.
  Runtime `s`/`c` toggles remain explicit experiments.
- The renderer already invalidates the entire screen when underline policy changes. Panel
  switches now also invalidate, which clears emulator-corrupted stale cells without adding
  an Apple-specific renderer branch.

### Mouse selection and Kitty graphics

- The mouse grid cleared its cyan selection immediately on release, so a normal click's
  highlighted press frame was too brief to observe. Renderer damage and coordinate mapping
  were correct. Selection should persist through release and clear on a later press
  outside the grid.
- The demo already sends the correct Kitty placement-deletion command before drawing a
  non-graphics panel. Stored image data intentionally remains reusable after placement
  deletion. On unsupported terminals, forcibly emitted Kitty bytes may appear as text;
  invalidating on panel switches and exposing `r` ensures an erase/repaint clears that
  text.
- `g` is a force-output control, not a visibility toggle on terminals where graphics
  evidence is already supported. Its label must say `force graphics output`.

## Conclusion

Fix the demo at its presentation and state seams: central tab order, truthful mouse
labels, teal key-token styling, explicit Kitty event limitations, terminal-owned link
hover styling, absolute file URIs, visible disabled-link styling, terminfo opt-in,
persistent mouse selection, and renderer invalidation on panel changes plus global `r`. Do
not add terminal-brand branches, broaden Tessera's conservative Kitty default, weaken
renderer equality, or delete all Kitty image data on every tab switch.
