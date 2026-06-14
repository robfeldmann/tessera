---
name: Phase 2 Slice 5 Legacy Input Parser
description:
  Replace the walking-skeleton byte parser with durable semantic terminal input events, a
  stateful legacy escape-sequence parser, and session event streams.
status: in-progress
created: 2026-06-13
updated: 2026-06-13
---

## Progress

- [x] **Phase 1 — Public input event model and parser foundation**
  - [x] 1.1 Replace the minimal input API with durable key/event types
  - [x] 1.2 Implement parser ground state for controls, printable ASCII, and UTF-8
- [x] **Phase 2 — Legacy escape-sequence catalog**
  - [x] 2.1 Implement ESC ambiguity, Alt keys, CSI/SS3 state transitions, and unknown
        events
  - [x] 2.2 Cover the full Phase 2 legacy key catalog with parser tests
- [ ] **Phase 3 — Platform event stream integration**
  - [ ] 3.1 Change internal input reads to chunk-oriented parsing and expose
        `PlatformIO.events`
  - [ ] 3.2 Merge resize notifications into the semantic event stream
  - [ ] 3.3 Expose `TerminalSession.events` and keep `nextEvent()` as sugar
- [ ] **Phase 4 — Examples, cleanup, and validation**
  - [ ] 4.1 Update existing examples and add `InputInspector`
  - [ ] 4.2 Run slice validation and update this plan

## Review process

Do not push branches or create a GitHub PR for this slice unless explicitly asked. The
agent implements one step at a time, runs focused validation plus `just lint-changed`,
updates this plan, and pauses for user review. After the user approves the completed step,
commit the approved work locally before starting the next step. Do not start
implementation until this plan is reviewed and explicitly approved.

## Context loading for implementers

Before implementing any step, read this entire plan first. Then read the Phase 2 Slice 5
section of `docs/Spec.md` ("Legacy input parser") and enough nearby Phase 2 context to
understand how the walking skeleton, ANSI encoder, terminal lifecycle, and renderer feed
into this slice. Prefer existing source and tests before rereading broad spec sections.
Use direct assertions for parser/API behavior; snapshots are not expected for this slice.

## Overview

Phase 2 Slice 5 turns raw terminal input bytes into semantic events. The current code has
a temporary `InputParser.parse(_:)` that maps printable ASCII and special-cases `q` as a
quit event; this slice replaces that with stable public input types, a streaming state
machine, and an event stream integrated with terminal resize notifications. Scope remains
legacy terminal input only: bracketed paste, mouse, focus, and Kitty keyboard support stay
for Phase 3. The work is split so each production API or behavior change lands with its
usage/tests in the same review chunk.

## Current state

- `Sources/TesseraTerminalInput/InputEvent.swift` exposes only `.character(Character)` and
  `.quit`.
- `Sources/TesseraTerminalInput/InputParser.swift` is a stateless enum with
  `parse(_:) -> InputEvent?` for single bytes.
- `TerminalSession` pumps `PlatformIO.bytes` through the minimal parser into
  `nextEvent()`; there is no public `events` stream yet.
- `PlatformIO.bytes`, `TerminalDevice.bytes`, and `POSIXInputLoop.bytes` currently yield
  one `UInt8` at a time.
- `PlatformIO.sizeChanges` and `TerminalSession.sizeChanges` are separate from keyboard
  input.

## Phase 1 — Public input event model and parser foundation

**Goal**: Establish the durable input API and make the parser stateful before adding the
large escape-sequence table.

### Step 1.1 — Replace the minimal input API with durable key/event types

- Files:
  - `Sources/TesseraTerminalInput/InputEvent.swift`
  - `Sources/TesseraTerminalInput/Key.swift`
  - `Sources/TesseraTerminalInput/KeyCode.swift`
  - `Sources/TesseraTerminalInput/Modifiers.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Add public `InputEvent`, `Key`, `KeyCode`, and `Modifiers` types matching the stable
  Phase 2 shape, without phase/slice names.
- Remove the public `.quit` event; applications decide that `q` means quit.
- Prefer a shape that can extend in Phase 3, for example key, resize, and unknown events
  now, with paste/mouse/focus added later.
- Update existing tests to assert the new API shape for simple printable characters.
- Acceptance: `swift test --filter TesseraTerminalInputTests` and
  `swift test --filter TesseraTerminalTests/next\ event` pass.

### Step 1.2 — Implement parser ground state for controls, printable ASCII, and UTF-8

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalInput/InputParser.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Replace the stateless enum with a stateful `InputParser` value exposing `feed(_:)`,
  `feed(contentsOf:)`, and `flush()`.
- Implement ground-state handling for printable ASCII, Tab, Enter, Backspace, Ctrl-letter
  controls, Ctrl+Space, and UTF-8 multi-byte assembly.
- Add tests for control bytes, printable ASCII, UTF-8 split across feeds, invalid UTF-8,
  and `flush()` behavior outside escape states.
- Acceptance: `swift test --filter TesseraTerminalInputTests` passes.

## Phase 2 — Legacy escape-sequence catalog

**Goal**: Complete the Phase 2 parser catalog with deterministic behavior for partial
sequences, ESC ambiguity, modifiers, and unknown input.

### Step 2.1 — Implement ESC ambiguity, Alt keys, CSI/SS3 state transitions, and unknown events

- Files:
  - `Sources/TesseraTerminalInput/InputParser.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Implement parser states for `.escape`, `.csi`, and `.ss3`.
- Make bare ESC emit only from `flush()`, while ESC followed by printable input in the
  same ambiguity window emits Alt-modified keys.
- Preserve captured bytes for unrecognized escape sequences as `.unknown` events.
- Add focused tests for split feeds, bare ESC, Alt+letter, and representative unknown
  sequences.
- Acceptance: `swift test --filter TesseraTerminalInputTests` passes.

### Step 2.2 — Cover the full Phase 2 legacy key catalog with parser tests

- Files:
  - `Sources/TesseraTerminalInput/InputParser.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Implement table-driven lookup for:
  - CSI arrows, Home/End, Insert/Delete, PageUp/PageDown, Shift+Tab.
  - VT220 tilde function keys F1-F12.
  - CSI modifier forms for arrow/home/end and tilde-style special keys.
  - SS3 F1-F4 and SS3 application-mode arrows.
- Add per-sequence golden tests for every catalog entry and modifier mask.
- Add multi-byte split tests such as Ctrl+Up delivered across several `feed` calls.
- Acceptance: `swift test --filter TesseraTerminalInputTests` passes.

## Phase 3 — Platform event stream integration

**Goal**: Move parsing into platform/session event streams without retaining a hot
per-byte pipeline.

### Step 3.1 — Change internal input reads to chunk-oriented parsing and expose `PlatformIO.events`

- Files:
  - `Sources/TesseraTerminalIO/POSIXInputLoop.swift`
  - `Sources/TesseraTerminalIO/TerminalDevice.swift`
  - `Sources/TesseraTerminalIO/PlatformIO.swift`
  - `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift`
  - `Tests/TesseraTerminalIOTests/PlatformIOInputTests.swift`
- Change the package-internal byte stream seam from per-byte `AsyncStream<UInt8>` to
  chunk-oriented input, e.g. `AsyncStream<[UInt8]>`, and feed chunks into `InputParser`.
- Add package-level `PlatformIO.events: AsyncStream<InputEvent>` with configurable
  package-internal ESC timeout for deterministic tests.
- Ensure the event task yields semantic events, not one continuation yield per input byte.
- Update POSIX and in-memory tests to assert chunk delivery and parsed event delivery.
- Acceptance: `swift test --filter TesseraTerminalIOTests/PlatformIOInputTests` passes.

### Step 3.2 — Merge resize notifications into the semantic event stream

- Files:
  - `Sources/TesseraTerminalInput/InputEvent.swift`
  - `Sources/TesseraTerminalIO/PlatformIO.swift`
  - `Tests/TesseraTerminalIOTests/PlatformIOInputTests.swift`
  - `Tests/TesseraTerminalIOTests/TerminalResizeRegistryTests.swift`
- Emit `InputEvent.resize(TerminalSize)` from `PlatformIO.events` when
  `TerminalDevice.sizeChanges()` yields.
- Keep existing `sizeChanges` access available unless removing it is clearly safe and
  localized.
- Add tests that deterministic size-change streams produce resize events alongside key
  events.
- Acceptance: `swift test --filter TesseraTerminalIOTests` passes.

### Step 3.3 — Expose `TerminalSession.events` and keep `nextEvent()` as sugar

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Add public `TerminalSession.events: AsyncStream<InputEvent>` and make `nextEvent()` read
  from the same semantic event pipeline.
- Preserve existing cancellation behavior for pending `nextEvent()` calls.
- Update session tests for arrows, Escape-to-exit style handling, repeated events, input
  closure, and resize events.
- Acceptance: `swift test --filter TesseraTerminalTests` passes.

## Phase 4 — Examples, cleanup, and validation

**Goal**: Finish the slice by updating demos and running the required validation loop.

### Step 4.1 — Update existing examples and add `InputInspector`

- Files:
  - `Examples/Package.swift`
  - `Examples/Sources/HelloTessera/HelloTessera.swift`
  - `Examples/Sources/InputInspector/InputInspector.swift`
  - `Examples/Sources/LifecycleModesDemo/LifecycleModesDemo.swift`
  - `Examples/Sources/RendererDemo/RendererDemo.swift`
- Replace `.quit` handling in existing examples with `InputEvent.key` matching for `q`.
- Add `InputInspector`, a diagnostic example for the semantic input API:
  - Read from `TerminalSession.events`.
  - Show the latest event and terminal size.
  - Show raw unknown-sequence bytes as readable hex.
  - Let arrow keys move a marker so semantic navigation keys have visible behavior.
  - Keep paste ungrouped: pasted text appears as individual key events, matching Slice 5
    parser behavior before bracketed paste lands in Phase 3.
  - Make the event log scrollable without mouse support: use PageUp/PageDown for coarse
    scrolling, Up/Down or Ctrl+Up/Ctrl+Down for line scrolling if those keys are
    available, and Home/End to jump to the oldest/newest log entries.
- Keep examples dependent on public `TesseraTerminal`/`Tessera` products only.
- Acceptance: `just examples-list` includes `InputInspector`; targeted
  `swift build --package-path Examples --product InputInspector` and
  `swift build --package-path Examples` pass.

### Step 4.2 — Run slice validation and update this plan

- Files:
  - `.agents/plans/011-phase-2-slice-5-legacy-input-parser.md`
- Run focused test targets first, then `just lint-changed`, `just lint`, and `swift test`.
- Run `just examples` or equivalent example validation required by the repository.
- Update progress checkboxes and `updated` date.
- Acceptance: all validation passes, no unreviewed follow-up items remain, and the plan is
  marked completed.

## References

- `docs/Spec.md` — Phase 2 Slice 5: Legacy input parser.
- Crossterm parser references named in the spec:
  `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/src/event/sys/unix/parse.rs`.
- Existing walking-skeleton input code: `Sources/TesseraTerminalInput/`,
  `Sources/TesseraTerminalIO/`, and `Sources/TesseraTerminal/TerminalSession.swift`.
