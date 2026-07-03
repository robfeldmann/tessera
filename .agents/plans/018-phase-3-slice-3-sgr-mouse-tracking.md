---
name: Phase 3 Slice 3 SGR Mouse Tracking
description:
  Add SGR button-event mouse tracking with semantic mouse events, mode lifecycle cleanup,
  parser coverage, and an interactive demo panel.
status: pending
created: 2026-07-02
updated: 2026-07-03
---

## Progress

- [ ] **Phase 1 — Mouse event API and parser coverage**
  - [ ] 1.1 Add semantic mouse event types
  - [ ] 1.2 Decode SGR mouse reports through the CSI parser
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
app-facing event stream reports terminal coordinates, mouse kind, button identity, and
modifiers.

Use button-event tracking plus SGR encoding:

- enable button-event tracking: `ESC [ ? 1002 h`
- enable SGR mouse encoding: `ESC [ ? 1006 h`
- disable button-event tracking: `ESC [ ? 1002 l`
- disable SGR mouse encoding: `ESC [ ? 1006 l`

Mouse remains opt-in for now. It changes terminal selection and scrollback behavior, so it
must not silently become part of `TerminalApplicationConfiguration.default` in this slice.

## Phase 1 — Mouse event API and parser coverage

**Goal**: SGR mouse byte sequences become semantic `.mouse(MouseEvent)` values while all
existing key, paste, focus, resize, and unknown behavior stays intact.

### Step 1.1 — Add semantic mouse event types

- Files:
  - `Sources/TesseraTerminalInput/InputEvent.swift`
  - new `Sources/TesseraTerminalInput/MouseEvent.swift`
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

- Keep coordinates zero-based in `TerminalPosition`, matching buffers and rendering.
- Extend parser event-log snapshot formatting to render mouse events compactly.

Acceptance:

- Mouse event values are simple `Equatable, Sendable` data.
- No mouse-specific key codes are added.

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
- Decode motion bit 32 as drag.
- Decode wheel bit 64 as scroll.
- Support vertical scroll codes 64 and 65. Support horizontal codes 66 and 67 if the
  chosen decoding table is tested.
- `M` means press, drag, or scroll. `m` means release.
- For release, prefer `.release(button)` when the button is identifiable and
  `.release(nil)` when the sequence only reports an unspecified release.
- Mouse-looking bytes inside bracketed paste remain paste payload.
- Mouse reports can arrive in high-volume drag or scroll streams. Keep SGR decoding
  single-pass over the accumulated CSI bytes and avoid per-event heap churn beyond the
  emitted semantic event.

Add parser tests for:

- left, middle, and right press
- button release with known button
- unspecified release if supported by the chosen decode table
- drag for each button
- scroll up and scroll down
- horizontal scroll if implemented
- shift, alt, control, and combined modifiers
- multi-digit row and column values
- one-based to zero-based coordinate conversion
- zero row or column becomes `.unknown`
- byte-by-byte mouse sequence
- mouse between key events
- mouse between focus events
- mouse-looking sequence inside paste payload
- malformed reports follow existing unknown policy

Use inline snapshots for multi-event transcripts. Use direct assertions for individual
`MouseEvent` fields.

Acceptance:

- Parser tests cover all public mouse kinds.
- No Win32 mouse record path is introduced.

## Phase 2 — Encoder and lifecycle support

**Goal**: Tessera can opt into SGR mouse tracking and reliably restore terminal selection
and scrollback behavior on every exit path.

### Step 2.1 — Add exact SGR mouse control-sequence encoding

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add `case enableMouseTracking(Bool)` to `ControlSequence`.
- Encode enable as two CSI private-mode operations in this order:

```text
ESC [ ? 1002 h
ESC [ ? 1006 h
```

- Encode disable as:

```text
ESC [ ? 1002 l
ESC [ ? 1006 l
```

- Add the new case to every exhaustive encoder switch.
- If the implementation defensively disables `?1000` or `?1003`, pin that choice in test
  names and comments. Do not add those bytes silently.

Acceptance:

- Exact byte tests pin enable and disable order.
- Lifecycle code references only `ControlSequence.enableMouseTracking`.

### Step 2.2 — Enable, disable, and cleanup `.mouseTracking`

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Move `.mouseTracking` out of the unsupported path.
- Extend `acquisitionOrder` after focus events: raw mode, alternate screen, bracketed
  paste, focus events, mouse tracking.
- Enable/disable with `ControlSequence.enableMouseTracking(true/false)` and `io.write`
  plus `io.flush()`.
- Normal teardown disables mouse before focus and bracketed paste by reverse acquisition
  order.
- Emergency cleanup bytes include mouse disable when mouse tracking was requested or
  active.
- Rollback after partial startup disables mouse if it was enabled.

Add lifecycle tests for:

- explicit startup emits mouse enable bytes after focus enable
- default startup does not enable mouse tracking
- teardown emits mouse disable before focus and paste disables
- cleanup bytes include mouse disable for mouse-enabled sessions
- partial startup failure leaves no optional protocol mode active

Snapshot the lifecycle byte transcript for the all-modes case.

Acceptance:

- `.mouseTracking` works when requested.
- `.mouseTracking` is absent from `TerminalApplicationConfiguration.default`.

### Step 2.3 — Keep mouse tracking explicit, not default

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Keep `.default` at raw mode, alternate screen, bracketed paste, and focus events.
- Add a session integration test that constructs a configuration inserting
  `.mouseTracking` and proves the setup/teardown bytes include mouse tracking.
- Add a companion test proving `.default` still omits mouse tracking.

Acceptance:

- Users opt in by adding `.mouseTracking` to configuration modes.
- The example app opts in only because it has a mouse panel.

## Phase 3 — Example app and validation

**Goal**: Reviewers can see live mouse event decoding without waiting for Phase 4 hit
testing.

### Step 3.1 — Add the mouse panel to `Phase3ProtocolsDemo`

- Files:
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Examples/Package.swift` only if the target list needs updates from prior plans
- Run the demo with a configuration that includes `.mouseTracking`.
- Add panel navigation: `1` paste, `2` focus, `3` mouse.
- Show latest mouse event kind, position, button, scroll direction, and modifiers.
- Draw a small grid and mark the last reported mouse position when it is inside the grid.
- Keep key and focus events in the shared log.

Wireframe:

```text
Phase3ProtocolsDemo — Mouse                                      80x24
q quit · 1 paste · 2 focus · 3 mouse · click, drag, or scroll here

Latest mouse event
  kind: press(left)
  position: column 14, row 8
  modifiers: shift+ctrl

Mouse grid
  columns →  0 1 2 3 4 5 6 7 8 9
          0 · · · · · · · · · ·
          1 · · · · ● · · · · ·
          2 · · · · · · · · · ·

Recent events
  0029 mouse press(left) at 14,8 modifiers=shift+ctrl
  0030 mouse drag(left) at 15,8 modifiers=shift+ctrl
  0031 mouse scroll(up) at 15,8 modifiers=none
```

Acceptance:

- The panel updates for press, drag, release, and scroll in terminals that support SGR
  mouse.
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

- Mouse tests pass with paste and focus tests still green.
- No public API exposes platform-specific mouse semantics.
