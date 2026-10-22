---
type: spec
description: "Slice 10: Cursor styling"
---

# Slice 10: Cursor styling

Cursor styling is application/session policy. Tessera models cursor shape and cursor color
as typed configuration that is applied by the session lifecycle and restored by lifecycle
cleanup; apps must not use `RawTerminalPayload`, `Frame.writeRaw`, or ad-hoc terminal
writes to change cursor shape or cursor color.

Protocols in scope:

- **DECSCUSR cursor shape**: `CSI Ps SP q`.
  - `0` restores the terminal/user configured cursor shape.
  - `1` selects blinking block.
  - `2` selects steady block.
  - `3` selects blinking underline.
  - `4` selects steady underline.
  - `5` selects blinking bar.
  - `6` selects steady bar.
- **OSC 12 cursor color**: `OSC 12;Pt ST`, where Tessera's `Pt` is restricted to an RGB
  `#RRGGBB` color string generated from typed values. Tessera terminates its OSC 12/112
  with ST (`ESC \`), the ECMA-48 standard terminator that OSC 8 hyperlinks already use, in
  preference to BEL: ST is silent if a parser desyncs, whereas a stray BEL beeps or
  flashes.
- **OSC 112 cursor-color reset**: `OSC 112 ST`, used to return the text cursor color to
  the terminal default.

Add `CursorShape` in `TesseraTerminalANSI` with cases `defaultUserShape`, `blinkingBlock`,
`steadyBlock`, `blinkingUnderline`, `steadyUnderline`, `blinkingBar`, and `steadyBar`. Add
an RGB-only `CursorColor` value type. Do not accept arbitrary strings, named xterm colors,
indexed palette values, or raw OSC fragments; cursor color is serialized only as uppercase
`#RRGGBB`.

Add `CursorStyle` with optional `shape` and optional `color` facets. `nil` means Tessera
leaves that facet untouched. `CursorShape.defaultUserShape` is an explicit command to send
DECSCUSR `0`; it is not the same as `nil`. Add semantic `ControlSequence` cases for cursor
shape, cursor color, and cursor-color reset. These cases are the only supported way to
produce DECSCUSR/OSC 12/OSC 112 bytes from Tessera APIs.

Add cursor styling policy to `TerminalApplicationConfiguration`, disabled by default. This
policy is the application's declaration that cursor style changes are allowed for the
session; it is not limited to a single static startup style. The policy may include an
optional default cursor style to apply when no focused component requests one.

Future Phase 4 views must be able to request cursor style declaratively when they have
focus — for example, a text input might request a steady bar while a normal command panel
uses the default block. Phase 3 should therefore build the lower-level session and
`ModeLifecycle.apply` machinery that can change cursor style dynamically, while still
leaving the Phase 4 focused-component API out of scope.

If cursor styling is enabled and a default or dynamically requested style has at least one
non-`nil` facet, configuration/runtime resolution adds a session-owned lifecycle mode such
as `.cursorStyle(cursorStyle)` and carries the effective style through
`TerminalApplicationResolution` and `TerminalSession` for introspection. `nil` means
Tessera leaves that facet untouched. Draw transactions continue to hide the cursor by
default and show/move it when a frame requests a position; draw must not re-emit shape or
color on every frame.

Cursor styling is acquired after raw mode and alternate screen are entered, before
higher-level application protocol modes such as bracketed paste, focus events, mouse
tracking, and Kitty keyboard. Applying a cursor style sends one flush containing
`setCursorShape` first, when `shape != nil`, followed by `setCursorColor`, when
`color != nil`.

Disabling a cursor style sends one flush containing DECSCUSR `0` when Tessera previously
owned `shape`, followed by OSC 112 when Tessera previously owned `color`. Dynamic
lifecycle reconciliation must treat cursor styling like other app protocol modes: applying
the same style is idempotent; changing styles resets old owned facets before applying new
facets; disabling style restores only the facets Tessera owned.

Normal session exit restores cursor visibility as today, then lifecycle exit restores
cursor shape/color before leaving the alternate screen and raw mode. Emergency cleanup
bytes include cursor-shape reset and/or cursor-color reset only when requested or active
cursor styling proves Tessera owns those facets.

Unsupported terminals are not startup failures. DECSCUSR and OSC 12/112 have no required
active probe in this slice; terminals that do not support them may ignore the sequences.
Passive terminal identity hints must not be treated as proof of cursor-styling support. Do
not add a terminal-name allowlist that changes failure behavior. `NO_COLOR` and SGR
color-depth policy do not implicitly disable cursor color: cursor color is an explicit
application opt-in and is not cell text color. Tessera does not query and restore the
user's exact pre-existing cursor color; restore means terminal/user default via OSC 112.

Multiplexer behavior follows the same producer boundary. When Tessera runs inside a
multiplexer that owns a virtual screen and renders its own host cursor, such as herdr, the
multiplexer must either model child cursor color state and re-emit equivalent OSC 12/112
for its host cursor, or intentionally leave cursor color unsupported. Tessera must not
bypass that layer or invent tmux/screen-style passthrough wrappers for cursor styling; a
flushed OSC 12/112 sequence only proves Tessera sent the request to its immediate terminal
device.

Tests should cover all DECSCUSR values, exact `CSI Ps SP q` bytes including the space
byte, OSC 12 RGB serialization, OSC 112 reset, disabled-by-default configuration, enabled
policy with no default style, enabled policy with a default style, focused/requested style
overrides, enter/exit ordering, dynamic apply, shape-only/color-only behavior, failed
enable rollback, unsupported-terminal no-failure policy, emergency cleanup reset bytes for
owned facets only, and no per-frame shape/color emission.

## Non-goals

Do not add Windows console API cursor styling, arbitrary OSC color strings, cursor style
query/restore, terminal-name support allowlists, or Sixel. Do not implement the Phase 4
focused-component cursor-style API in this slice, but keep the session/lifecycle machinery
ready for it.

## End of Slice 10

`TesseraTerminal` can opt into cursor shape and cursor color styling as session-owned
lifecycle state, restore only the facets it owns, and leave user cursor preferences alone
when applications do not request styling.
