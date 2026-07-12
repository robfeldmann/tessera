---
name: Phase 3 Slice 1 Bracketed Paste Mode
description:
  Add bracketed paste as the first modern terminal protocol mode, with parser isolation,
  lifecycle cleanup, tests, and the initial Phase 3 demo app.
status: complete
created: 2026-07-02
updated: 2026-07-03
---

## Progress

- [x] **Phase 1 — Public event and parser mode**
  - [x] 1.1 Add the paste event case and parser event-log test helpers
  - [x] 1.2 Add bracketed-paste parser state and edge-case coverage
- [x] **Phase 2 — Encoder and lifecycle support**
  - [x] 2.1 Add exact bracketed-paste control-sequence encoding
  - [x] 2.2 Enable, disable, and cleanup `.bracketedPaste`
  - [x] 2.3 Make bracketed paste part of the default application terminal
- [x] **Phase 3 — Example app and validation**
  - [x] 3.1 Add the Phase 3 demo app with the paste panel
  - [x] 3.2 Run narrow parser, encoder, lifecycle, session, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 1. Bracketed paste lets Tessera tell the
difference between characters typed one at a time and text pasted as one operation.

The feature is intentionally small, but it establishes the Phase 3 pattern:

- public semantic event
- parser mode or CSI decode
- semantic `ControlSequence`
- `ModeLifecycle` support and cleanup bytes
- unit and snapshot-style tests next to the affected code
- one reviewable example-app panel

## Phase 1 — Public event and parser mode

**Goal**: `InputParser` emits one `.paste(String)` event for a complete bracketed paste
and never emits partial key events for paste payload bytes.

### Step 1.1 — Add the paste event case and parser event-log test helpers

- Files:
  - `Sources/TesseraTerminalInput/InputEvent.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Add `case paste(String)` to `InputEvent`.
- Keep the event enum order readable and stable. At this slice the public cases should be
  `key`, `paste`, `resize`, then `unknown`.
- Add a small test helper in `InputParserTests.swift` that renders `[InputEvent]` into a
  deterministic event log string for inline snapshots. Use it for multi-event parser
  behavior where one snapshot is easier to review than several scalar assertions.
- Keep direct `#expect` assertions for one-event scalar behavior.

Acceptance:

- Existing parser tests compile after the event enum grows.
- New event-log helper has one small coverage test proving stable formatting.

### Step 1.2 — Add bracketed-paste parser state and edge-case coverage

- File: `Sources/TesseraTerminalInput/InputParser.swift`.
- Add a `State.bracketedPaste(matchedEndMarkerBytes:)` case. Keep the growing payload in a
  private parser buffer and store only bounded end-marker match state in the enum.
- Start marker: `ESC [ 200 ~`.
- End marker: `ESC [ 201 ~`.
- The start marker arrives through the existing CSI path as tilde parameter `200`.
- Parameter `201` outside paste mode is malformed and follows the existing unknown policy.
- While in paste mode, every byte is payload unless it advances the exact end marker.
  Broken partial-marker bytes are replayed into the payload.
- Keep the paste hot path allocation-conscious: no payload copies through enum state, no
  per-byte marker candidate arrays, and no `bytes.flatMap { feed($0) }` bulk parser loop.
- Decode completed paste payload with replacement characters using Swift's lossy UTF-8
  decoding. This matches terminal-library precedent and prevents invalid paste bytes from
  crashing the parser. Unterminated paste on `flush()` remains `.unknown` with the start
  marker plus accumulated bytes and any pending end-marker prefix.
- `flushPendingEscape()` must keep its current guard: only a bare `.escape` state flushes.
  Idle chunks must not disturb an in-progress paste.

Add parser tests for:

- complete paste in one feed
- paste split byte-by-byte
- start marker split across feeds
- end marker split across feeds
- multiline paste
- UTF-8 paste
- invalid UTF-8 paste uses replacement characters
- ANSI-looking bytes inside paste payload remain paste payload
- empty paste payload
- start marker inside active paste payload
- consecutive bracketed pastes
- ordinary key parsing before and after paste
- incomplete paste emits no partial key events
- idle `flushPendingEscape()` during paste emits nothing
- `flush()` on unterminated paste emits `.unknown`

Use inline snapshots for event sequences such as key → paste → key. Example snapshot:

```text
key character("a") modifiers=none
paste chars=17 lines=2 text="hello\nworld"
key character("b") modifiers=none
```

Acceptance:

- `InputParser` never emits `.key` events for bytes inside a completed paste.
- Existing ESC, CSI, SS3, UTF-8, and unknown-sequence tests still pass unchanged.

## Phase 2 — Encoder and lifecycle support

**Goal**: Tessera enables bracketed paste when configured, disables it during every
cleanup path, and never writes raw bracketed-paste escape strings outside the encoder.

### Step 2.1 — Add exact bracketed-paste control-sequence encoding

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add `case enableBracketedPaste(Bool)` to `ControlSequence`.
- Encode in the mode helper with DEC private mode `2004`:
  - enable: `ESC [ ? 2004 h`
  - disable: `ESC [ ? 2004 l`
- Add the new case to every exhaustive encoder switch.
- Add exact byte tests beside the existing mode/cursor tests.
- If a virtual-terminal smoke test is useful, keep it small; exact bytes are the main
  contract for this encoder case.

Acceptance:

- Encoder tests prove both enable and disable bytes exactly.
- No lifecycle file contains a string literal for `?2004`.

### Step 2.2 — Enable, disable, and cleanup `.bracketedPaste`

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Move `.bracketedPaste` out of the unsupported path.
- Extend `acquisitionOrder` to place `.bracketedPaste` after `.altScreen`.
- Enable/disable by encoding `ControlSequence.enableBracketedPaste(true/false)`, buffering
  with `io.write`, and calling `io.flush()`.
- Install cleanup bytes after successful entry. Cleanup should include bracketed-paste
  disable before alternate-screen exit and cursor-show bytes.
- Rollback should disable bracketed paste if startup fails after it was enabled.
- Keep `exit()` idempotent and continue cleaning later modes even when an earlier disable
  fails.

Add lifecycle tests for:

- startup emits bracketed-paste enable after alternate screen
- teardown emits bracketed-paste disable before alternate-screen/raw-mode cleanup
- rollback disables bracketed paste when a later enable fails
- cleanup bytes include bracketed-paste disable
- repeated `exit()` does not duplicate bytes

Prefer snapshot-style lifecycle transcripts for recorded events and flushed bytes. A
reviewable transcript is better than several disconnected `#expect` calls.

Acceptance:

- `.bracketedPaste` no longer throws `unsupportedModes`.
- Cleanup bytes are updated when bracketed paste is active or requested.

### Step 2.3 — Make bracketed paste part of the default application terminal

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Update `.default` to include `.bracketedPaste` with `.rawMode` and `.altScreen`.
- Add session integration coverage proving default application terminal setup records or
  flushes bracketed-paste enable/disable bytes through the package test seam.
- Keep non-default configurations possible for tests and apps that need exact mode sets.

Acceptance:

- `TerminalApplicationConfiguration.default.modes` contains `.bracketedPaste`.
- A default `TerminalSession.withApplicationTerminal` cleanup path disables paste mode.

## Phase 3 — Example app and validation

**Goal**: Add the Phase 3 demo shell with a paste panel reviewers can run immediately.

### Step 3.1 — Add the Phase 3 demo app with the paste panel

- Files:
  - `Examples/Package.swift`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
- Add a new executable product and target named `Phase3ProtocolsDemo`.
- Follow the existing examples: depend on `ExampleSupport` and `TesseraTerminal`, guard
  non-interactive runs with `TerminalExampleSupport`, and draw directly with `Frame`.
- Start with one panel selected by default: bracketed paste.
- Keep a recent event log capped to a fixed count.
- Show typed keys separately from paste events.
- Do not add a view abstraction or reusable widget layer.
- On very small terminals, show a wrapped resize message instead of drawing a clipped
  panel.

Wireframe:

```text
Phase3ProtocolsDemo — Paste                                      80x24
q quit · paste text from your clipboard

Last event
  paste chars=42 lines=3

Paste payload preview
┌────────────────────────────────────────────────────────────────────┐
│ first pasted line                                                   │
│ second pasted line                                                  │
│ third pasted line                                                   │
└────────────────────────────────────────────────────────────────────┘

Recent events
  0001 key character("a") modifiers=none
  0002 paste chars=42 lines=3
  0003 key enter modifiers=none
```

Acceptance:

- `swift build --package-path Examples --product Phase3ProtocolsDemo` succeeds.
- Running the app in a real terminal shows pasted content as one event.

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

- Every new parser, encoder, lifecycle, session, and example check passes.
- No Phase 4 view-layer code exists.
