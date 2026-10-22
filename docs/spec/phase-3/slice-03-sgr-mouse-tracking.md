---
type: spec
description: "Slice 3: SGR mouse tracking"
---

# Slice 3: SGR mouse tracking

Slice 3 teaches Tessera to understand mouse input in terminal coordinates.

Mouse support is where terminal input stops looking like “keyboard, but with more escape
sequences” and starts looking like an event system. Clicks, releases, drags, and scrolls
carry position, button identity, and modifier keys. They are essential for many modern TUI
interactions — selectable lists, scroll views, text selection, split panes, buttons,
inspectors, command palettes, and any app that wants to feel native to users who expect a
mouse to work.

This slice should use **SGR mouse mode** (`?1006`) rather than older X10 / normal tracking
formats. The older encodings pack coordinates and button bits into bytes, have awkward
coordinate limits, and are not worth building a public API around. SGR mouse reports
events as readable CSI sequences and is the modern baseline for serious terminal apps.

Present two tracking granularities as an explicit choice rather than a single fixed mode:

```swift
public enum MouseTracking: Hashable, Sendable {
    case anyEvent
    case buttonEvents
}
```

`.buttonEvents` is the default everywhere a tracking granularity is not explicitly
requested. `.anyEvent` is a strict superset of `.buttonEvents` at the terminal level — it
additionally reports plain mouse motion with no button held — and is an explicit opt-in
for hover-driven UI (Phase 4 Slice 5 builds on it).

- `.buttonEvents` (default): `ESC [ ? 1002 h`, then `ESC [ ? 1006 h`
- `.anyEvent` (opt-in): `ESC [ ? 1003 h`, then `ESC [ ? 1006 h`
- Disable is always defensive, regardless of what was enabled: `ESC [ ? 1003 l`, then
  `ESC [ ? 1002 l`, then `ESC [ ? 1006 l`

Button-event tracking reports button presses, button releases, scroll-wheel events, and
movement while a button is pressed. It does _not_ report every mouse movement — that is
the right default for TesseraTerminal: useful enough for real apps, much less noisy than
any-event mode, and compatible with the view-layer focus/layout work that comes later.
Any-event tracking additionally reports motion with no button held, decoded as `.move`;
applications that want hover feedback opt into it explicitly (see Lifecycle behavior,
below) rather than paying its cost by default.

SGR mouse event sequences have this shape:

```text
ESC [ < button ; column ; row M   // press, drag, or scroll
ESC [ < button ; column ; row m   // release
```

> [!note] Ratatui References
>
> - Ratatui's `examples/apps/mouse-drawing/src/main.rs` is the practical reference for the
>   app-facing shape: it enables crossterm mouse capture before the loop, disables it
>   after the loop, receives `Event::Mouse(MouseEvent)`, and reacts to
>   `MouseEventKind::Down` / `MouseEventKind::Drag`
>   (`examples/apps/mouse-drawing/src/main.rs`, lines 13, 41, 47, and 73-80).
> - Ratatui's demo crossterm runner enables mouse capture together with alternate screen
>   and disables it during terminal restore (`examples/apps/demo/src/crossterm.rs`, lines
>   18 and 27-31). Tessera should keep this lifecycle concern inside terminal
>   startup/teardown rather than forcing every example to remember it.
> - crossterm's `EnableMouseCapture` has no granular alternative — it always enables
>   normal tracking (`?1000`), button-event tracking (`?1002`), any-event tracking
>   (`?1003`), RXVT (`?1015`), and SGR (`?1006`) together, and disables them the same way
>   (`crossterm` `src/event.rs`, lines 321-337; disable, lines 354-364). Tessera's
>   granular `MouseTracking` choice — `?1002` + `?1006` by default, `?1003` + `?1006` as
>   an explicit opt-in — is deliberately better terminal citizenship: apps pay for motion
>   noise only when they ask for it.
> - crossterm's SGR parser is the closest decoding reference: it parses
>   `ESC [ < Cb ; Cx ; Cy M/m`, subtracts 1 from coordinates, and uses lowercase `m` to
>   turn a button-down decode into a release event (`crossterm`
>   `src/event/sys/unix/parse.rs`, lines 714-755).
> - crossterm's `parse_cb` documents the packed mouse button bits and maps them to down,
>   drag, scroll, and modifier values (`crossterm` `src/event/sys/unix/parse.rs`, lines
>   762-799).
> - crossterm's `MouseEventKind::Moved` documents itself as "moved the mouse cursor while
>   not pressing a mouse button" (`crossterm` `src/event.rs`, line 808); its SGR parser
>   maps button numbers 3/4/5 with the motion bit set to `Moved` (`crossterm`
>   `src/event/sys/unix/parse.rs`, lines 776-810) — the same motion-bit/no-button shape
>   Tessera decodes as `.move` (see Button and modifier decoding, below).
> - No Ratatui widget or example consumes `Moved` — the `mouse-drawing` example wildcards
>   it away in its match arm. Tessera's opt-in `.anyEvent` granularity exists so hover
>   consumers (Phase 4 Slice 5) put motion to deliberate use, rather than leaving it
>   unused downstream the way crossterm's all-or-nothing capture does.

The terminal reports `column` and `row` as 1-based coordinates. Tessera should expose them
as 0-based buffer coordinates, matching the rest of the renderer and buffer API.

This slice should extend `InputEvent` with a mouse case (cases stay alphabetized):

```swift
public enum InputEvent: Equatable, Sendable {
    case focusGained
    case focusLost
    case key(Key)
    case mouse(MouseEvent)
    case paste(String)
    case resize(TerminalSize)
    case unknown([UInt8])
}
```

Suggested event model, following the codebase's `var`-property and sorted-conformance
conventions:

```swift
public struct MouseEvent: Equatable, Sendable {
    public var kind: MouseEventKind
    public var modifiers: Modifiers
    public var position: TerminalPosition

    public init(kind: MouseEventKind, position: TerminalPosition, modifiers: Modifiers = [])
}

public enum MouseEventKind: Equatable, Sendable {
    case drag(MouseButton)
    case move
    case press(MouseButton)
    case release(MouseButton?)
    case scroll(MouseScrollDirection)
}

public enum MouseButton: Equatable, Sendable {
    case left
    case middle
    case right
}

public enum MouseScrollDirection: Equatable, Sendable {
    case down
    case left
    case right
    case up
}
```

`.move` carries no associated value: it represents motion with no button held, as distinct
from `.drag(button)`, which is motion while a button is held.

`TerminalPosition` is the existing `TesseraTerminalCore` type (`column`/`row`, 0-based,
same origin as buffers and rendering). If the terminal sends row 1 / column 1, Tessera
reports `TerminalPosition(column: 0, row: 0)`.

## Button and modifier decoding

SGR mouse's `button` parameter is a bit-packed integer. Decode only the pieces Tessera can
represent clearly:

- Low button code `0` = left button
- Low button code `1` = middle button
- Low button code `2` = right button
- Low button code `3` = no button (a motion-only report)
- Modifier bit `4` = shift
- Modifier bit `8` = alt
- Modifier bit `16` = control
- Motion bit `32` = a motion report rather than a press/release: paired with button code
  `0`/`1`/`2` it means drag; paired with button code `3` it means move
- Wheel bit `64` = scroll wheel event

Wheel events should decode to scroll directions. At minimum support:

- `64` = scroll up
- `65` = scroll down

If horizontal wheel events are supported by the terminals you test against, map the common
codes too:

- `66` = scroll left
- `67` = scroll right

For release events (`m` final byte), prefer `.release(button)` when the button code still
identifies a button and `.release(nil)` when the sequence only says “some button was
released.” SGR mode usually preserves enough information to identify the released button,
but the optional payload avoids pretending certainty when a terminal sends less specific
data.

Decode `.move` unconditionally whenever the motion bit is set with low button code `3`,
regardless of which tracking granularity — `.buttonEvents`, `.anyEvent`, or none — was
enabled. A terminal that reports motion Tessera did not explicitly ask for still yields a
semantic `.move` event rather than `InputEvent.unknown([UInt8])`: this is strictly more
robust than gating the decode on the active granularity.

Malformed, out-of-range, or semantically impossible button codes should follow the
parser's existing unknown-sequence policy. Do not invent `.unknownMouse`; unknown input
remains an `InputEvent.unknown([UInt8])` because the parser failed to decode the whole
sequence into a semantic event.

## Lifecycle behavior

Mouse tracking is another opt-in terminal mode and must follow the same cleanup discipline
as bracketed paste and focus tracking:

- Enable the requested tracking granularity when Tessera enters application terminal mode.
- Disable mouse tracking during normal teardown.
- Disable mouse tracking from cleanup handlers after abnormal exit.
- Keep all disable sequences idempotent and safe to emit even if enable failed partway
  through startup.

Concretely, this is again the Slice 1 `ModeLifecycle` change, but the existing
`.mouseTracking` mode case becomes parameterized:

```swift
case mouseTracking(MouseTracking)
```

Because modes live in `Set<Mode>`, a configuration may contain both
`.mouseTracking(.anyEvent)` and `.mouseTracking(.buttonEvents)` at once. Normalize with a
documented and tested **broadest wins** rule: if the set contains
`.mouseTracking(.anyEvent)`, the session enables any-event tracking, and the coexisting
`.buttonEvents` entry is not an error — it is subsumed, since any-event tracking is a
strict superset of button-event tracking at the terminal level.

Mouse tracking acquires last in the Phase 3 acquisition order — raw mode, alt screen,
bracketed paste, focus events, mouse tracking — and tears down in the reverse order.
Neither granularity belongs in `TerminalApplicationConfiguration.default`: both visibly
change terminal selection/scrollback behavior, so applications opt in by adding
`.mouseTracking(.buttonEvents)` or `.mouseTracking(.anyEvent)` to `configuration.modes`
(slice 6's enablement policy keeps it configuration-driven). Any-event tracking is doubly
out of `.default` — it is the noisier, more user-visible of the two.

Because mouse mode visibly changes terminal behavior, cleanup matters. Leaving mouse
tracking enabled can make a user's shell appear broken: clicks may stop selecting text,
and scrolling may send escape sequences instead of moving the scrollback.

A reasonable teardown ordering for Phase 3 modes is:

1. Disable mouse tracking — always emit the full defensive disable (`?1003 l`, `?1002 l`,
   `?1006 l`) whenever any mouse mode was requested or active, regardless of which
   granularity was actually enabled. This is deliberate, documented behavior, not
   defensive hedging: normal teardown, rollback after partial startup, and the
   emergency-cleanup byte registry all emit the same bytes, so no code path can leave a
   stray tracking mode running because it forgot which granularity it started.
2. Disable focus tracking.
3. Disable bracketed paste.
4. Continue with the existing alternate-screen, cursor/style reset, and raw-mode restore
   sequence from Phase 2.

The exact order is less important than the invariant: no opt-in application protocol stays
enabled after Tessera exits.

## Parser behavior

The parser should recognize SGR mouse CSI sequences in normal input mode:

```text
ESC [ < b ; x ; y M
ESC [ < b ; x ; y m
```

Parsing requirements:

- Accept multi-digit `button`, `column`, and `row` parameters.
- Handle sequences split across reads.
- Convert terminal coordinates from 1-based to 0-based.
- Reject coordinates less than 1 as malformed.
- Decode modifier bits into the existing `Modifiers` option set.
- Decode press, release, drag, and scroll into `MouseEventKind`.
- Preserve ordinary keyboard/focus/paste behavior before and after mouse events.

The concrete hook: no new parser state is needed. `<` is 0x3C, inside `parseCSI`'s
accumulate range (0x20–0x3F), so the whole report accumulates in the existing `.csi` state
and decodes at the final byte `M`/`m`. Reuse `csiParameterValues` for the three numeric
fields after stripping the `<` prefix. Note that the SGR-mouse modifier bits (shift 4, alt
8, control 16) are packed differently from the legacy `1 + bits` CSI modifier encoding
handled by `modifiers(encodedAs:)` — write a separate mouse-modifier decode rather than
reusing that helper.

As with focus events, SGR mouse sequences must not be interpreted while inside bracketed
paste mode. A paste payload containing `ESC [ < 0 ; 1 ; 1 M` is pasted text, not a mouse
click.

## Bounded motion coalescing

Any-event tracking's motion stream is the noisy stream the ownership and isolation thesis
has in mind when it promises that Tessera's input design "bounds noisy streams such as
mouse movement." This section defines that policy; Phase 4 Slice 5 cites it directly for
`.onMouse`'s raw event stream.

The coalescing seam lives in `AsyncEventBuffer`, not the parser — the parser keeps
decoding every SGR report into a semantic event; coalescing only bounds how many of those
events pile up in the pending backlog. Add an optional coalescing predicate to the buffer:

```swift
package init(
    coalescing: (@Sendable (_ buffered: Element, _ incoming: Element) -> Bool)? = nil
)
```

In `yield`, when there are no waiters and the predicate returns `true` for the last
buffered element and the incoming element, replace the last buffered element instead of
appending — latest position wins. Delivery to a waiting consumer is never coalesced:
coalescing only bounds the pending backlog under backpressure, it never delays or drops an
event a consumer is actively awaiting.

`TerminalSession` constructs its input buffer with a predicate that coalesces exactly two
shapes, both requiring equal modifiers:

- a buffered `.mouse(kind: .move)` with an incoming `.mouse(kind: .move)`
- a buffered `.mouse(kind: .drag(button))` with an incoming `.mouse(kind: .drag(button))`
  for the same button

Nothing else coalesces. Press, release, and scroll events are never dropped, and a press
arriving between two moves breaks the run — the predicate only ever compares the buffer's
current last element against the newest incoming one, so a press in between forces both
moves to survive as separate elements. When two moves (or two same-button drags) do
coalesce, the surviving event takes the incoming — latest — position.

## Encoder behavior

Add a semantic control sequence rather than writing raw private-mode escapes at lifecycle
call sites. Follow the existing paired-case precedent (`enterAltScreen` / `exitAltScreen`)
rather than a single `enableMouseTracking(Bool)`, because enabling needs a granularity and
disabling is always defensive:

```swift
public enum ControlSequence: Equatable, Sendable {
    // Existing cases, kept alphabetized...
    case disableMouseTracking
    case enableMouseTracking(MouseTracking)
}
```

Each case may emit multiple CSI private-mode operations internally. Tests should assert
the exact bytes and ordering, pinned to these sequences:

- `enableMouseTracking(.buttonEvents)`:

  ```text
  ESC [ ? 1002 h
  ESC [ ? 1006 h
  ```

- `enableMouseTracking(.anyEvent)`:

  ```text
  ESC [ ? 1003 h
  ESC [ ? 1006 h
  ```

- `disableMouseTracking`:

  ```text
  ESC [ ? 1003 l
  ESC [ ? 1002 l
  ESC [ ? 1006 l
  ```

`disableMouseTracking` always disables both granularities plus SGR encoding, regardless of
which granularity (if any) was enabled. This is deliberate and idempotent, not accidental
noise — name it as such in tests.

## Platform notes

Mouse tracking should remain a VT protocol feature across all platforms. On macOS and
Linux, the terminal emulator sends SGR mouse sequences through the normal input file
descriptor. On Windows, Windows Terminal / ConPTY does the same when
`ENABLE_VIRTUAL_TERMINAL_INPUT` is active — which Phase 2's raw mode already guarantees.

Do not add a separate Win32 `MOUSE_EVENT_RECORD` public path. It does not have the same
semantics as SGR mouse mode, it would create platform-specific behavior in the public
event stream, and it would undermine the Phase 2 decision to keep OS differences inside
`PlatformIO`. `WindowsInputLoop` already drains and discards legacy mouse records from the
console input queue.

`?1003` behavior through `tmux`/`screen` and over high-latency SSH is less uniform than
`?1002` — multiplexers and slow links are more likely to drop, coalesce, or delay motion
reports than button events. This is an unverified, inference-grade caution rather than a
finding checked against a real matrix of terminals and multiplexers; Slice 6's capability
detection may inform a more precise any-event enablement policy later.

Terminal hover is inherently degraded compared to a GUI: it is cell-granular (no sub-cell
position) and terminals give no mouse-leave signal. Phase 4 Slice 5 clears hover state on
`focusLost` and on motion-tracking disable to bound the resulting stuck-hover risk.

## Tests

Add parser tests for:

- left/middle/right press events
- button release events
- drag events for each button
- move events (no button held) under any-event tracking
- move events decode the same way even when only button-event tracking (or nothing) was
  enabled — the parser never gates `.move` on which granularity is active
- scroll up and scroll down
- horizontal scroll if supported by the chosen decoding table
- shift/alt/control modifiers
- combined modifiers
- multi-digit row and column values
- coordinate conversion from 1-based terminal coordinates to 0-based Tessera coordinates
- coordinates less than 1 are rejected as malformed/unknown
- mouse sequences split byte-by-byte
- mouse event between ordinary key events
- mouse event between focus events
- mouse-looking sequence inside bracketed paste payload does not emit `.mouse`
- malformed SGR mouse sequences follow the existing unknown-sequence policy

Add lifecycle/encoder tests (assert recorded bytes via `InMemoryTerminalDevice`) for:

- startup emits button-event tracking enable sequences (`?1002 h`, `?1006 h`) by default
- startup emits any-event tracking enable sequences (`?1003 h`, `?1006 h`) when
  `.mouseTracking(.anyEvent)` is requested
- a `configuration.modes` set containing both `.mouseTracking(.buttonEvents)` and
  `.mouseTracking(.anyEvent)` normalizes to any-event tracking (broadest wins)
- teardown and cleanup paths always emit the full defensive disable sequence (`?1003 l`,
  `?1002 l`, `?1006 l`), regardless of which granularity was active
- mouse tracking disable is emitted before focus/bracketed-paste disable, or whatever
  explicit teardown ordering the implementation chooses
- teardown leaves no optional Phase 3 modes enabled even when startup fails partway
  through

Add coalescing tests (`AsyncEventBuffer`) for:

- consecutive `.move` events collapse to the latest position when the consumer is not
  currently waiting (backpressure)
- consecutive same-button `.drag` events with equal modifiers collapse the same way
- a press event arriving between two `.move` events breaks the run — both moves and the
  press survive as separate elements
- a consumer already waiting on `next()` receives the next event immediately, uncoalesced,
  even if a later event would otherwise have coalesced with it

## Non-goals

Do not implement the old X10, VT200, UTF-8 extended, or urxvt mouse encodings unless tests
prove a real compatibility need. SGR mouse is the modern target.

Do not add view-layer hit testing yet. This slice only reports mouse events in terminal
coordinates. Phase 4 will decide how those coordinates map to views, widgets, focus, and
scroll regions.

Do not add selection policy yet. Mouse drag events are just input events; they should not
automatically select text, scroll panes, or intercept terminal selection behavior beyond
what enabling mouse tracking inherently does.

Do not implement hover enter/exit semantics here. `onHover`, hover state, and the
`wantsMouseMotion` arbitration that decides when a view needs any-event tracking are Phase
4 Slice 5's job. This slice's contract ends at producing coalesced `.move` events on
`InputEvent` — it has no opinion about what a view does with them.

## End of Slice 3

`TesseraTerminal` can enable SGR mouse tracking at either granularity — button-event by
default, any-event as an explicit opt-in — reliably disable it on every exit path, and
surface clicks, releases, drags, scrolls, motion, positions, and modifiers as semantic,
bounded-coalesced mouse events without confusing mouse-looking escape sequences for pasted
content.
