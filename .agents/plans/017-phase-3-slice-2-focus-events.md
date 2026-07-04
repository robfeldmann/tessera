---
name: Phase 3 Slice 2 Focus Events
description:
  Add terminal focus gained/lost events using CSI focus tracking, sharing the Phase 3 mode
  lifecycle and preserving bracketed-paste isolation.
status: complete
created: 2026-07-02
updated: 2026-07-04
---

## Progress

- [x] **Phase 1 — Focus event parsing**
  - [x] 1.1 Add public focus event cases
  - [x] 1.2 Decode focus CSI reports without breaking paste mode
- [x] **Phase 2 — Encoder and lifecycle support**
  - [x] 2.1 Add exact focus-tracking control-sequence encoding
  - [x] 2.2 Enable, disable, and cleanup `.focusEvents`
  - [x] 2.3 Keep focus enabled in the default application terminal
- [x] **Phase 3 — Example app and validation**
  - [x] 3.1 Add the focus panel to `Phase3ProtocolsDemo`
  - [x] 3.2 Run narrow parser, encoder, lifecycle, session, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 2. Focus events report whether the
terminal emulator considers the app focused. They are not view focus, widget focus, or
shortcut routing.

Focus tracking uses:

- enable: `ESC [ ? 1004 h`
- disable: `ESC [ ? 1004 l`
- focus gained: `ESC [ I`
- focus lost: `ESC [ O`

This slice depends on plan 016. Focus reports must be decoded in normal parser mode and
preserved as literal payload when they appear inside bracketed paste.

## Phase 1 — Focus event parsing

**Goal**: `InputParser` emits top-level focus events and never confuses pasted
focus-looking bytes for terminal focus changes.

### Step 1.1 — Add public focus event cases

- Files:
  - `Sources/TesseraTerminalInput/InputEvent.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
- Add `case focusGained` and `case focusLost` to `InputEvent`.
- Keep the final public case order readable and stable: `focusGained`, `focusLost`, `key`,
  `paste`, `resize`, `unknown`.
- Update parser test event-log formatting from plan 016 to render focus events.
- Update the example app's event-description helper so focus events are visible in the
  log.

Acceptance:

- Existing key, paste, resize, and unknown tests still compile.
- Event-log snapshots can show `focus gained` and `focus lost` without custom per-test
  code.

### Step 1.2 — Decode focus CSI reports without breaking paste mode

- File: `Sources/TesseraTerminalInput/InputParser.swift`.
- Decode `ESC [ I` as `.focusGained` only when CSI parameters are empty.
- Decode `ESC [ O` as `.focusLost` only when CSI parameters are empty.
- Existing `csiCode(finalByte:params:)` returns `Key?`; this slice should either widen the
  CSI dispatch helper to return `InputEvent?` or handle final bytes `I` and `O` inside
  `parseCSI` before key fallback.
- `ESC [ I` or `ESC [ O` with parameters follows the existing unknown-sequence policy.
- Duplicate focus events are surfaced as received. The parser does not store `isFocused`.
- Focus-looking bytes inside `State.bracketedPaste` are payload, not focus events.

- Focus reports are tiny CSI events. Do not add a new parser mode or regress the optimized
  bracketed-paste bulk feed path while widening CSI dispatch. Add parser tests for:

- focus gained in one feed
- focus lost in one feed
- focus gained split byte-by-byte
- focus lost split byte-by-byte
- focus event between ordinary key events
- repeated focus events are emitted repeatedly
- malformed focus CSI sequences emit `.unknown`
- `ESC [ I` inside paste payload remains `.paste`
- `ESC [ O` inside paste payload remains `.paste`

Prefer inline snapshots for event streams such as key → focus lost → key. Use direct
assertions for one focus event.

Acceptance:

- Parser tests prove focus decoding does not depend on read chunk boundaries.
- Bracketed-paste tests prove parser mode determines interpretation.

## Phase 2 — Encoder and lifecycle support

**Goal**: Tessera can enable focus tracking, disable it on every exit path, and include it
in default application mode setup.

### Step 2.1 — Add exact focus-tracking control-sequence encoding

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add `case enableFocusTracking(Bool)` to `ControlSequence`.
- Encode as DEC private mode `1004`:
  - enable: `ESC [ ? 1004 h`
  - disable: `ESC [ ? 1004 l`
- Add the new case to every exhaustive encoder switch.
- Add exact byte tests next to the bracketed-paste mode tests.

Acceptance:

- Encoder tests pin enable and disable bytes exactly.
- Lifecycle code does not contain raw `?1004` string literals.

### Step 2.2 — Enable, disable, and cleanup `.focusEvents`

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Move `.focusEvents` out of the unsupported path.
- Extend `acquisitionOrder` so focus follows bracketed paste: raw mode, alternate screen,
  bracketed paste, focus events.
- Enable/disable through `ControlSequence.enableFocusTracking(true/false)` and `io.write`
  plus `io.flush()`.
- Normal teardown disables focus before bracketed paste if the reverse acquisition order
  is used.
- Emergency cleanup bytes include focus disable whenever focus was requested or active.
- Rollback disables focus if a later mode fails after focus was enabled.

Add lifecycle tests for:

- startup emits focus enable after bracketed-paste enable
- teardown emits focus disable before bracketed-paste disable
- cleanup bytes include focus disable and bracketed-paste disable
- rollback after focus acquisition leaves no optional mode active
- disabled focus cleanup is idempotent

Use snapshot-style lifecycle transcripts for the ordered bytes and events.

Acceptance:

- `.focusEvents` no longer throws `unsupportedModes`.
- Teardown leaves neither focus tracking nor bracketed paste enabled.

### Step 2.3 — Keep focus enabled in the default application terminal

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Add `.focusEvents` to `TerminalApplicationConfiguration.default`.
- Add session integration coverage proving default setup emits paste and focus enables,
  and default teardown emits focus then paste disables.

Acceptance:

- The default application terminal includes raw mode, alternate screen, bracketed paste,
  and focus events.
- Focus event parsing is independent from mode configuration; valid bytes still decode
  even in parser-only tests.

## Phase 3 — Example app and validation

**Goal**: Reviewers can switch the demo app to a focus panel and watch terminal focus
state change as they move between windows or tabs.

### Step 3.1 — Add the focus panel to `Phase3ProtocolsDemo`

- File: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Add panel navigation if it does not already exist: `1` paste, `2` focus.
- Derive focus state in the example app from `.focusGained` and `.focusLost` events. Do
  not move focus-state storage into `InputParser`.
- Keep all events in the shared recent-event log.

Wireframe:

```text
Phase3ProtocolsDemo — Focus                                      80x24
q quit · 1 paste · 2 focus

Terminal focus
  state: focused
  last transition: focus gained at event 0017

Try it
  Switch to another terminal tab/window, then return here.
  Some terminals only report focus while the alternate screen is active.

Recent events
  0015 key character("2") modifiers=none
  0016 focus lost
  0017 focus gained
```

Acceptance:

- The panel updates from focus events without affecting parser semantics.
- If the terminal does not send focus events, the app still renders and logs other input.

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

- New focus behavior and all prior paste behavior pass together.
- No Windows-specific focus event path exists.
