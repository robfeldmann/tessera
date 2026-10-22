---
type: spec
description: "Slice 2: Focus events"
---

# Slice 2: Focus events

Slice 2 teaches Tessera when the terminal application gains and loses focus.

Focus events are not about keyboard focus _inside_ the app. They are about whether the
terminal emulator considers the application active: the user switched to another window,
changed tabs, clicked back into the terminal, or otherwise moved attention away from and
back to the running TUI. That signal is small, but useful. A terminal app may pause cursor
blinking while unfocused, dim presence indicators, defer expensive refresh work, mark data
as stale, or avoid treating background key delivery as active user interaction.

This is the right second modern protocol because it has the same basic lifecycle shape as
bracketed paste but a simpler parser shape. It reinforces the Phase 3 pattern — opt in on
startup, opt out during teardown, decode a small set of escape sequences into semantic
events — before the larger SGR mouse and Kitty keyboard slices add broader event surfaces.

Focus tracking mode uses these sequences:

- Enable with `ESC [ ? 1004 h`
- Disable with `ESC [ ? 1004 l`
- Focus gained event: `ESC [ I`
- Focus lost event: `ESC [ O`

> [!note] Ratatui References
>
> - crossterm's top-level `Event` enum includes `FocusGained` and `FocusLost` as sibling
>   events to `Key`, `Mouse`, `Paste`, and `Resize` (`crossterm` `src/event.rs`, line
>   550). Tessera's `.focusGained` / `.focusLost` should use the same top-level shape.
> - crossterm's `EnableFocusChange` / `DisableFocusChange` commands write `CSI ? 1004 h`
>   and `CSI ? 1004 l` respectively (`crossterm` `src/event.rs`, lines 379 and 400).
> - crossterm's Unix CSI parser maps `ESC [ I` to `Event::FocusGained` and `ESC [ O` to
>   `Event::FocusLost` alongside other CSI inputs (`crossterm`
>   `src/event/sys/unix/parse.rs`, lines 171-172).

This slice should extend `InputEvent` again (cases stay alphabetized):

```swift
public enum InputEvent: Equatable, Sendable {
    case focusGained
    case focusLost
    case key(Key)
    case paste(String)
    case resize(TerminalSize)
    case unknown([UInt8])
}
```

## Lifecycle behavior

Focus tracking is a terminal mode and should be managed with the same cleanup discipline
as bracketed paste:

- Enable focus tracking when Tessera enters application terminal mode.
- Disable focus tracking during normal teardown.
- Disable focus tracking from cleanup handlers after abnormal exit.
- Keep the disable sequence idempotent and safe to emit even if startup fails halfway.

Concretely, this is the same `ModeLifecycle` change as Slice 1, for the existing
`.focusEvents` mode case: lift it out of the `unsupportedModes` rejection, place it in
`acquisitionOrder`/`supportedModes`, emit bytes through `io.write` + `io.flush`, and
include the disable in `installCleanup()` teardown bytes. Enable at startup by including
`.focusEvents` in `TerminalApplicationConfiguration.modes` (and in `.default`, matching
slice 6's enablement policy).

The teardown ordering should be boring and explicit. Disable optional application modes
before restoring the user's terminal state. A reasonable ordering is:

1. Disable focus tracking.
2. Disable bracketed paste.
3. Leave alternate screen / restore cursor / restore styles, according to the existing
   Phase 2 lifecycle ordering.
4. Restore raw mode / console mode through `PlatformIO`.

The exact order can follow whatever Phase 2 already established, but the invariant should
be: no modern opt-in mode is left enabled after Tessera exits.

## Parser behavior

Focus events are ordinary CSI sequences from the parser's point of view:

- `ESC [ I` emits `.focusGained`
- `ESC [ O` emits `.focusLost`

The concrete hook: `csiCode(finalByte:params:)` gains final bytes `I` (0x49) and `O`
(0x4F), valid only with empty parameters — but those two decode to `InputEvent` cases, not
`Key` values, so the helper's return type (currently `Key?`) needs to widen to an event,
or the dispatch happens in `parseCSI` before the key-decoding fallback. `ESC [ I` or
`ESC [ O` with parameters follows the existing unknown policy.

They should be recognized wherever the normal escape-sequence parser recognizes CSI input,
including when bytes arrive split across reads. They should not be recognized while the
parser is inside bracketed paste mode; inside paste mode, those bytes are payload unless
they are part of the exact bracketed-paste end marker.

This interaction is the main edge case for the slice. `ESC [ I` can mean “focus gained”
when the parser is in normal mode, but it can also be literal pasted bytes when a user
pastes text containing that sequence. Parser mode determines which interpretation wins.

Design notes:

- Focus gained/lost are top-level input events, not keys.
- They carry no payload. The terminal protocol does not report which window, tab, pane, or
  application focus moved to.
- Do not attempt to maintain an `isFocused` boolean inside `InputParser`. The parser
  should decode events, not own terminal state. Application/runtime code can derive focus
  state by observing the event stream.
- Duplicate events should be surfaced as received. If a terminal sends two focus-gained
  events in a row, Tessera should not silently coalesce them at the parser layer.

## Encoder behavior

Add a semantic control sequence for focus tracking, mirroring bracketed paste's
`Bool`-parameterized shape:

```swift
public enum ControlSequence: Equatable, Sendable {
    // Existing cases, kept alphabetized...
    case enableFocusTracking(Bool)
}
```

Tests should assert the exact bytes:

- enable: `\u{1B}[?1004h`
- disable: `\u{1B}[?1004l`

Keep these as explicit encoder operations rather than generic “set private mode” calls in
lifecycle code. `ANSIByteEncoding.appendCSI` is the internal helper; public and call-site
code should read in terminal concepts: enable focus tracking, disable focus tracking.

## Platform notes

On POSIX terminals this is just bytes in and bytes out. On Windows Terminal and other
ConPTY-backed environments, the VT input mode from Phase 2
(`ENABLE_VIRTUAL_TERMINAL_INPUT`, owned by `WindowsConsoleMode`) is what lets these escape
sequences flow through the same parser path as macOS and Linux.

There must not be a separate Windows focus-event implementation using Win32 console focus
records. Those records describe the console window/input buffer model, not the modern
terminal protocol Tessera is standardizing around — and `WindowsInputLoop` already drains
and discards legacy `FOCUS_EVENT` records while pumping the console input queue, so the VT
`ESC [ I` / `ESC [ O` bytes are the only focus signal that can reach the parser. Phase 2
deliberately put Windows behind the same `PlatformIO` seam; Phase 3 continues paying the
cross-platform tax only at the byte transport layer, not by inventing a second event
semantics.

## Tests

Add parser tests for:

- focus gained in one feed
- focus lost in one feed
- focus gained split byte-by-byte
- focus lost split byte-by-byte
- focus event between ordinary key events
- repeated focus events are emitted repeatedly
- unknown or malformed `ESC [` sequences still follow the existing unknown-sequence policy
- `ESC [ I` inside bracketed paste payload does not emit `.focusGained`
- `ESC [ O` inside bracketed paste payload does not emit `.focusLost`

Add lifecycle/encoder tests (assert recorded bytes via `InMemoryTerminalDevice`) for:

- startup emits focus tracking enable
- teardown emits focus tracking disable
- cleanup path emits focus tracking disable
- focus tracking disable is emitted along with bracketed paste disable
- teardown leaves no optional Phase 3 modes enabled even when startup fails partway
  through

## Non-goals

Do not build application-level focus management yet. Phase 4 will decide which view owns
keyboard focus, how focus moves between widgets, and how focus styling works. This slice
only reports terminal focus events.

Do not add focus-based rendering policy yet. No automatic dimming, no frame throttling, no
cursor blinking behavior, and no runtime-level pause/resume semantics. Those are consumers
of `.focusGained` / `.focusLost`, not part of the terminal parser.

Do not add capability detection yet. As with bracketed paste, focus tracking is cheap to
enable and safe to disable. If a terminal ignores `?1004`, the only consequence is that no
focus events arrive.

## End of Slice 2

`TesseraTerminal` can enable focus tracking, reliably disable it on every exit path, and
surface terminal focus changes as `.focusGained` and `.focusLost` events without confusing
those sequences with pasted content.
