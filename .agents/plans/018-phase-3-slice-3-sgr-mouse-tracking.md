---
name: Phase 3 Slice 3 SGR Mouse Tracking
description:
  Add SGR mouse tracking with semantic press, release, drag, scroll, and motion events,
  opt-in any-event hover tracking with bounded motion coalescing, mode lifecycle cleanup,
  parser coverage, and an interactive demo panel.
status: pending
created: 2026-07-02
updated: 2026-07-04
---

## Progress

- [ ] **Phase 1 — Mouse event API and parser coverage**
  - [ ] 1.1 Add semantic mouse event types and tracking granularity
  - [ ] 1.2 Decode SGR mouse reports through the CSI parser
  - [ ] 1.3 Add bounded motion coalescing to the input event buffer
- [ ] **Phase 2 — Encoder and lifecycle support**
  - [ ] 2.1 Add exact SGR mouse control-sequence encoding
  - [ ] 2.2 Enable, disable, and cleanup `.mouseTracking`
  - [ ] 2.3 Keep mouse tracking explicit, not default
- [ ] **Phase 3 — Example app and validation**
  - [ ] 3.1 Add the mouse panel to `Phase3ProtocolsDemo`
  - [ ] 3.2 Run narrow parser, encoder, lifecycle, session, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 3. Tessera adopts SGR mouse reports, not
X10, VT200 byte-packed mouse reports, urxvt reports, or Win32 console mouse records. The
app-facing event stream reports terminal coordinates, mouse event kind (press, release,
drag, scroll, or motion), button identity, and modifiers.

Tessera exposes mouse tracking through a `MouseTracking` granularity:

- `.buttonEvents` is the default granularity whenever mouse tracking is requested:
  button-event tracking plus SGR encoding — enable `ESC [ ? 1002 h` then `ESC [ ? 1006 h`.
  It reports presses, releases, scroll, and drags; the terminal sends nothing while no
  button is held.
- `.anyEvent` is an additional, explicit opt-in on top of that: any-event tracking plus
  SGR encoding — enable `ESC [ ? 1003 h` then `ESC [ ? 1006 h`. It reports everything
  `.buttonEvents` reports, plus `.move` for motion while no button is held — the mode that
  makes hover possible.

Disabling mouse tracking always emits the same defensive, idempotent sequence regardless
of which granularity (if any) was enabled — `ESC [ ? 1003 l`, `ESC [ ? 1002 l`, then
`ESC [ ? 1006 l` — so teardown, rollback, and emergency cleanup never need to remember
which granularity was active.

Mouse tracking remains opt-in: it changes terminal selection and scrollback behavior, so
it must not silently become part of `TerminalApplicationConfiguration.default` in this
slice. Any-event tracking is opt-in a second time over that: it is the noisiest, most
user-visible mode a terminal application can request, so applications choose it explicitly
through `.mouseTracking(.anyEvent)` rather than getting it as a side effect of any other
mouse mode.

> **Out of scope**: hover enter/exit semantics, the `onHover` view modifier, and
> `wantsMouse`/`wantsMouseMotion` arbitration are Phase 4 Slice 5 work. This slice only
> produces coalesced semantic mouse events — including `.move` — and the opt-in any-event
> tracking mode that makes them possible.

## Phase 1 — Mouse event API and parser coverage

**Goal**: SGR mouse byte sequences become semantic `.mouse(MouseEvent)` values — including
`.move` for hover motion under any-event tracking — while all existing key, paste, focus,
resize, and unknown behavior stays intact.

### Step 1.1 — Add semantic mouse event types and tracking granularity

- Files:
  - `Sources/TesseraTerminalInput/InputEvent.swift`
  - new `Sources/TesseraTerminalInput/MouseEvent.swift`
  - new `Sources/TesseraTerminalANSI/MouseTracking.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Add `case mouse(MouseEvent)` to `InputEvent`.
- Keep final event order: `focusGained`, `focusLost`, `key`, `mouse`, `paste`, `resize`,
  `unknown`.
- Add public value types:

```swift
public struct MouseEvent: Equatable, Sendable {
  public var kind: MouseEventKind
  public var modifiers: Modifiers
  public var position: TerminalPosition
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

- Add the tracking-granularity type in a NEW file
  `Sources/TesseraTerminalANSI/MouseTracking.swift`. It lives beside `ControlSequence`,
  like `EraseMode`, because both `ControlSequence` (Step 2.1) and `ModeLifecycle` (Step
  2.2) need it, and `TesseraTerminalIO` already imports `TesseraTerminalANSI`:

```swift
/// Granularity of terminal mouse reporting.
public enum MouseTracking: Hashable, Sendable {
  /// Any-event tracking (DECSET 1003): reports motion even with no button held.
  case anyEvent

  /// Button-event tracking (DECSET 1002): presses, releases, scroll, and drags only.
  case buttonEvents
}
```

- `.anyEvent` is a strict superset of `.buttonEvents` at the terminal level ("broadest").
  The default wherever a caller does not choose explicitly is `.buttonEvents`.
- Keep coordinates zero-based in `TerminalPosition`, matching buffers and rendering.
- Extend parser event-log snapshot formatting to render mouse events, including `.move`,
  compactly.

Acceptance:

- Mouse event values are simple `Equatable, Sendable` data.
- `MouseTracking` is `Hashable, Sendable` and lives in `TesseraTerminalANSI`, not
  `TesseraTerminalInput`.
- No mouse-specific key codes are added.
- `MouseEventKind` cases stay alphabetized: `drag`, `move`, `press`, `release`, `scroll`.

### Step 1.2 — Decode SGR mouse reports through the CSI parser

- File: `Sources/TesseraTerminalInput/InputParser.swift`.
- Decode normal-mode CSI reports of this shape:

```text
ESC [ < button ; column ; row M
ESC [ < button ; column ; row m
```

- No new parser state is needed. The `<` byte is already valid CSI parameter/intermediate
  input and should be preserved in the accumulated CSI bytes.
- Strip the `<` prefix, parse three integer fields, and reject malformed reports as
  `.unknown(sequence)`.
- Convert terminal coordinates from one-based to zero-based.
- Reject `row < 1` or `column < 1` as malformed.
- Decode button fields with a mouse-specific helper. Do not reuse legacy CSI
  `modifiers(encodedAs:)`; SGR mouse uses different bits.
- Decode modifier bits:
  - shift: bit 4
  - alt: bit 8
  - control: bit 16
- Decode motion bit 32 combined with button code 0, 1, or 2 as `.drag(button)`.
- Decode motion bit 32 combined with button code 3 (no button pressed) as `.move`,
  unconditionally — regardless of which tracking granularity, if any, is currently
  enabled. A terminal can send motion reports Tessera did not ask for under
  `.buttonEvents`; yielding `.move` is strictly more robust than `.unknown(sequence)`. All
  other malformed/unknown policy is unchanged.
- Decode wheel bit 64 as scroll.
- Support vertical scroll codes 64 and 65. Support horizontal codes 66 and 67 if the
  chosen decoding table is tested.
- `M` means press, drag, scroll, or move. `m` means release.
- For release, prefer `.release(button)` when the button is identifiable and
  `.release(nil)` when the sequence only reports an unspecified release.
- Mouse-looking bytes inside bracketed paste remain paste payload.
- Mouse reports can arrive in high-volume drag, scroll, or motion streams. Keep SGR
  decoding single-pass over the accumulated CSI bytes and avoid per-event heap churn
  beyond the emitted semantic event.

Add parser tests for:

- left, middle, and right press
- button release with known button
- unspecified release if supported by the chosen decode table
- drag for each button
- motion with no button held decodes to `.move`
- scroll up and scroll down
- horizontal scroll if implemented
- shift, alt, control, and combined modifiers, including on a `.move` event
- multi-digit row and column values
- one-based to zero-based coordinate conversion
- zero row or column becomes `.unknown`
- byte-by-byte mouse sequence
- byte-by-byte `.move` sequence
- mouse between key events
- mouse between focus events
- `.move` interleaved with `.press` and `.drag` in one transcript
- mouse-looking sequence inside paste payload
- malformed reports follow existing unknown policy

Use inline snapshots for multi-event transcripts. Use direct assertions for individual
`MouseEvent` fields.

Acceptance:

- Parser tests cover all public mouse kinds, including `.move`.
- `.move` decodes the same way whether or not any-event tracking is enabled — the parser
  has no notion of which DECSET modes are active.
- No Win32 mouse record path is introduced.

### Step 1.3 — Add bounded motion coalescing to the input event buffer

- Files:
  - `Sources/TesseraTerminal/AsyncEventBuffer.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift` (`inputEvents` is declared at line 10
    and constructed at line 27)
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift` (the existing
    `AsyncEventBuffer` tests live at roughly lines 193-282; add the new tests beside them)
- The ownership thesis promises input "bounds noisy streams such as mouse movement"; this
  step is where that promise becomes real. The seam is `AsyncEventBuffer`, not the parser:
  the parser stays a pure byte-to-event decoder and never drops or merges events itself.
- Add an optional coalescing predicate to `AsyncEventBuffer`'s package initializer:

```swift
package init(
  coalescing: (@Sendable (_ buffered: Element, _ incoming: Element) -> Bool)? = nil
)
```

- In `yield`, when there are no waiters, the buffer is non-empty, and `coalescing` returns
  `true` for the LAST buffered element and the incoming element, replace the last buffered
  element with the incoming one instead of appending — the incoming (latest) value wins.
  When `coalescing` is `nil` (every existing call site except `TerminalSession`), behavior
  is unchanged: always append.
- Delivery to a waiting consumer is never coalesced: coalescing only bounds the pending
  backlog while nobody is consuming it. A waiter still receives every element `yield` is
  called with, one at a time, in order.
- `TerminalSession` constructs its input buffer (line 27) with a predicate that returns
  `true` only for:
  - buffered `.mouse(kind: .move, ...)` and incoming `.mouse(kind: .move, ...)` with equal
    modifiers
  - buffered `.mouse(kind: .drag(button), ...)` and incoming
    `.mouse(kind: .drag(button), ...)` — same button — with equal modifiers
  - and `false` for every other pairing, including any two events that are not both
    `.mouse`, mouse events of different `MouseEventKind` cases, drags with different
    buttons, and any pairing with different modifiers.
- Press, release, and scroll are never coalesced, and a press between two moves breaks the
  run: coalescing only merges a run of the SAME kind back-to-back. Position always takes
  the incoming (latest) value.
- Consider exposing the predicate as a small internal function shared by
  `TerminalSession.init` and its tests (rather than duplicating the same modifier/button
  comparison twice), since the tests below need to exercise the exact predicate
  `TerminalSession` installs.

Add `AsyncEventBuffer`/`TerminalSession` tests for:

- a buffered run of `.move` events with no waiters collapses to only the latest position
- a `.press` between two buffered `.move` events breaks the run into three separate
  elements, in order
- a `.drag(.left)` followed by a `.drag(.right)` does not coalesce; both remain buffered
- a waiter consuming faster than production still receives every individual event —
  coalescing never touches a value already handed to a waiter

Acceptance:

- `AsyncEventBuffer` coalescing is opt-in per instance and defaults to off; every
  non-mouse `AsyncEventBuffer` user is unaffected.
- Coalescing only ever shrinks the pending backlog under backpressure; a consumer that
  keeps up with production observes every event exactly as before.
- `TerminalSession`'s predicate never coalesces press, release, or scroll events, and
  never coalesces across `MouseEventKind` case or button boundaries.

## Phase 2 — Encoder and lifecycle support

**Goal**: Tessera can opt into either SGR mouse tracking granularity — button-event or
any-event — and reliably restore terminal selection and scrollback behavior on every exit
path, regardless of which granularity was active.

### Step 2.1 — Add exact SGR mouse control-sequence encoding

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Replace any `enableMouseTracking(Bool)` shape with a paired case, alphabetized into
  `ControlSequence`, following the existing `enterAltScreen`/`exitAltScreen` precedent
  because enable needs a granularity and disable is always defensive:

```swift
case disableMouseTracking
case enableMouseTracking(MouseTracking)
```

- Encode `enableMouseTracking(.buttonEvents)` as two CSI private-mode operations in this
  order:

```text
ESC [ ? 1002 h
ESC [ ? 1006 h
```

- Encode `enableMouseTracking(.anyEvent)` as:

```text
ESC [ ? 1003 h
ESC [ ? 1006 h
```

- Encode `disableMouseTracking` as the full defensive, idempotent triple, regardless of
  which granularity (if any) is currently enabled:

```text
ESC [ ? 1003 l
ESC [ ? 1002 l
ESC [ ? 1006 l
```

- This defensive shape is deliberate: disable always resets both granularities plus SGR
  encoding, so callers never need to remember which mode was active before tearing down.
  Name this choice in test names and comments (for example, a test named "disable mouse
  tracking always resets both granularities defensively").
- Add the new cases to every exhaustive encoder switch.

Acceptance:

- Exact byte tests pin `enableMouseTracking(.buttonEvents)`,
  `enableMouseTracking(.anyEvent)`, and `disableMouseTracking` byte order.
- A test name documents that `disableMouseTracking` is deliberately defensive and
  idempotent across granularities.
- Lifecycle code references only `ControlSequence.enableMouseTracking` and
  `ControlSequence.disableMouseTracking`; no raw `?1002`/`?1003`/`?1006` string literals
  leak outside `ControlSequence`.
- No call site or test anywhere in the codebase still refers to
  `enableMouseTracking(Bool)`.

### Step 2.2 — Enable, disable, and cleanup `.mouseTracking`

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Parameterize `Mode.mouseTracking` with a granularity and move it out of the unsupported
  path:

```swift
case mouseTracking(MouseTracking)
```

- Extend acquisition order after focus events: raw mode, alternate screen, bracketed
  paste, focus events, mouse tracking.
- Normalization: because modes live in a `Set<Mode>`, a requested configuration may
  contain BOTH `.mouseTracking(.buttonEvents)` and `.mouseTracking(.anyEvent)` at once.
  Broadest wins — if the set contains `.mouseTracking(.anyEvent)`, the session enables
  any-event tracking, and the duplicate `.buttonEvents` entry is subsumed, not an error.
  Document this rule at the call site and cover it with a test.
- Mechanical consequence of parameterizing `Mode.mouseTracking`: `acquisitionOrder`
  (`[Mode]`) and `supportedModes` (`Set<Mode>`), both defined at lines 26-27, currently
  detect mouse tracking with exact `Mode` equality —
  `modes.subtracting(Self.supportedModes)` at line 47, `modes.contains(mode)` at line 61,
  and `cleanupModes.contains(mode)` at line 81. A fixed literal such as
  `.mouseTracking(.buttonEvents)` in either collection would silently fail to match a
  request for `.mouseTracking(.anyEvent)` (and vice versa), so these membership checks
  cannot be left as-is once the case carries an associated value. The implementation needs
  a granularity-agnostic way to detect "the set contains some mouse tracking request,"
  apply the broadest-wins rule above, and extract which granularity to acquire — for
  example, an acquisition-slot helper such as
  `requestedMouseTracking(in:) -> MouseTracking?` that scans a `Set<Mode>` for either case
  and prefers `.anyEvent`. The exact shape is the implementer's choice; the problem itself
  is not optional to solve.
- Enable with `ControlSequence.enableMouseTracking(granularity)`; disable with
  `ControlSequence.disableMouseTracking`; both through `io.write` plus `io.flush()`.
- Normal teardown disables mouse before focus and bracketed paste by reverse acquisition
  order, always emitting the full `ControlSequence.disableMouseTracking` bytes (never a
  granularity-specific disable) whenever any mouse mode was requested or active.
- Emergency cleanup bytes include `ControlSequence.disableMouseTracking` whenever any
  mouse mode was requested or active.
- Rollback after partial startup emits `ControlSequence.disableMouseTracking` if mouse
  tracking, in either granularity, was enabled before the failure.

Add lifecycle tests for:

- explicit `.buttonEvents` startup emits button-event mouse enable bytes after focus
  enable
- explicit `.anyEvent` startup emits any-event mouse enable bytes after focus enable
- a configuration requesting both granularities normalizes to any-event and enables it
  exactly once (broadest wins)
- default startup does not enable mouse tracking
- teardown emits the full defensive mouse disable before focus and paste disables,
  regardless of which granularity was active
- cleanup bytes include mouse disable for mouse-enabled sessions of either granularity
- partial startup failure leaves no optional protocol mode active

Snapshot the lifecycle byte transcript for the all-modes case, including any-event mouse
tracking.

Acceptance:

- `.mouseTracking(.buttonEvents)` and `.mouseTracking(.anyEvent)` both work when
  requested.
- `.mouseTracking`, in either granularity, is absent from
  `TerminalApplicationConfiguration.default`.
- Every mouse teardown path — normal exit, rollback, and emergency cleanup — emits the
  same defensive `ControlSequence.disableMouseTracking` bytes, never a
  granularity-specific disable.

### Step 2.3 — Keep mouse tracking explicit, not default

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Keep `.default` at raw mode, alternate screen, bracketed paste, and focus events; no
  granularity of `.mouseTracking` is part of `.default`.
- Add a session integration test that constructs a configuration inserting
  `.mouseTracking(.buttonEvents)` and proves the setup/teardown bytes include button-event
  mouse tracking.
- Add a session integration test that constructs a configuration inserting
  `.mouseTracking(.anyEvent)` and proves the setup/teardown bytes include any-event mouse
  tracking.
- Add a session integration test that constructs a configuration inserting BOTH
  `.mouseTracking(.buttonEvents)` and `.mouseTracking(.anyEvent)` and proves the any-event
  enable bytes appear exactly once — broadest-wins normalization holds through
  `TerminalSession`, not only through `ModeLifecycle` directly.
- Add a companion test proving `.default` still omits mouse tracking in both
  granularities.

Acceptance:

- Users opt in by adding `.mouseTracking(.buttonEvents)` or `.mouseTracking(.anyEvent)` to
  configuration modes.
- Requesting both granularities together is not an error and enables any-event tracking
  exactly once.
- The example app opts into `.mouseTracking(.anyEvent)` because it has a mouse panel that
  shows live hover, not only clicks and drags.

## Phase 3 — Example app and validation

**Goal**: Reviewers can see live mouse event decoding, including hover motion, without
waiting for Phase 4 hit testing.

### Step 3.1 — Add the mouse panel to `Phase3ProtocolsDemo`

- Files:
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Examples/Package.swift` only if the target list needs updates from prior plans
- Run the demo with a configuration that includes `.mouseTracking(.anyEvent)` so reviewers
  see live hover, not only clicks, drags, and scroll.
- Add panel navigation: `1` paste, `2` focus, `3` mouse.
- Show latest mouse event kind (including `move`), position, button, scroll direction, and
  modifiers.
- Draw a small grid and mark the CURRENT pointer cell whenever it is inside the grid,
  driven by `.move` events while the pointer is merely hovering, not only by press or
  drag.
- Keep key and focus events in the shared log; because of Step 1.3's coalescing, the log
  naturally shows collapsed `.move` runs at the latest position rather than one entry per
  raw byte sequence.

Wireframe:

```text
Phase3ProtocolsDemo — Mouse                                      80x24
q quit · 1 paste · 2 focus · 3 mouse · move, click, drag, or scroll here

Latest mouse event
  kind: move
  position: column 14, row 8
  modifiers: none

Mouse grid
  columns →  0 1 2 3 4 5 6 7 8 9
          0 · · · · · · · · · ·
          1 · · · · ● · · · · ·
          2 · · · · · · · · · ·

Recent events
  0029 mouse move at 14,8 modifiers=none
  0030 mouse press(left) at 14,8 modifiers=shift+ctrl
  0031 mouse drag(left) at 15,8 modifiers=shift+ctrl
```

Acceptance:

- The panel updates for press, drag, release, scroll, and hover motion (`move`) in
  terminals that support SGR any-event mouse reporting.
- The pointer cell shown on the grid tracks `.move` events, not only button-driven events.
- In terminals that ignore mouse tracking, the app still renders and accepts keyboard
  navigation.

### Step 3.2 — Run narrow parser, encoder, lifecycle, session, and example checks

Run:

```fish
swift test --filter TesseraTerminalInputTests
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
```

Acceptance:

- Mouse tests pass, including `.move` decoding, coalescing, and any-event lifecycle
  behavior, with paste and focus tests still green.
- No public API exposes platform-specific mouse semantics.
