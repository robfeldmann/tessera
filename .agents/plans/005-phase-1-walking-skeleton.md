---
name: Phase 1 Walking Skeleton
description: Build the Phase 1 Tessera walking skeleton.
status: in-progress
created: 2026-06-05
updated: 2026-06-05
---

## Progress

- [x] **Phase 1 — Buffer and geometry primitives**
  - [x] 1.1 Replace placeholder geometry with Phase 1 terminal geometry types
  - [x] 1.2 Implement `Style`, `Cell`, and `Buffer`
  - [x] 1.3 Add buffer tests for init, indexing, writing, and clipping
- [ ] **Phase 2 — Naive render bytes**
  - [x] 2.1 Implement the Phase 1 full-repaint renderer
  - [ ] 2.2 Add renderer golden-byte tests
- [ ] **Phase 3 — Minimal input parsing**
  - [ ] 3.1 Implement printable-byte and quit parsing
  - [ ] 3.2 Add input parser tests
- [ ] **Phase 4 — POSIX PlatformIO**
  - [ ] 4.1 Implement terminal size detection and stdout writes
  - [ ] 4.2 Implement raw mode and alt-screen enter/exit
  - [ ] 4.3 Implement blocking stdin byte stream
  - [ ] 4.4 Add testable PlatformIO seams and non-interactive tests
- [ ] **Phase 5 — HelloTessera executable**
  - [ ] 5.1 Add the `HelloTessera` executable target
  - [ ] 5.2 Wire the walking-skeleton run loop
  - [ ] 5.3 Manually verify interactive behavior on macOS/Linux as available

## Overview

This plan implements Phase 1 from `docs/Spec.md`: a deliberately crude walking skeleton
that proves Tessera can render a buffer to an alternate terminal screen, read raw
keystrokes, update the screen, and exit cleanly on `q`. The work avoids Phase 2
abstractions such as signal handling, a real ANSI encoder, diff rendering, resize
handling, and a view protocol. The implementation should stay small and biased toward
learning: concrete bytes, simple value types, minimal parser, direct POSIX I/O, and a tiny
example app.

## Phase 1 — Buffer and geometry primitives

**Goal**: Replace scaffolding with the minimal value types that all later layers use.

### Step 1.1 — Replace placeholder geometry with Phase 1 terminal geometry types

- File: `Sources/TesseraTerminalCore/TerminalGeometry.swift`
- Replace `TerminalGeometry` placeholder with `TerminalSize` and `TerminalPosition`
  structs.
- Use `columns`/`rows` and `column`/`row` integer fields matching `docs/Spec.md`.
- Acceptance: `swift test --filter TesseraTerminalCoreTests` passes after updating
  existing placeholder tests if needed.

### Step 1.2 — Implement `Style`, `Cell`, and `Buffer`

- File: `Sources/TesseraTerminalBuffer/Buffer.swift`
- Replace `Buffer` placeholder with:
  - empty `Style: Sendable, Equatable`
  - `Cell: Sendable, Equatable` with `character`, `style`, and Phase 1 `width`
  - `Buffer: Sendable, Equatable` with `size`, flat private cells, subscript by
    `row, column`, `clear`, and `write(_:at:style:)`
- Keep width handling intentionally naive at `1` column per character.
- Acceptance: package compiles and no view/render/input abstractions are introduced.

### Step 1.3 — Add buffer tests for init, indexing, writing, and clipping

- File: `Tests/TesseraTerminalBufferTests/BufferTests.swift`
- Cover buffer initialization with blank cells, subscript get/set, string writing at a
  position, and clipping when text extends past the right edge or bottom.
- Acceptance: `swift test --filter TesseraTerminalBufferTests` passes.

## Phase 2 — Naive render bytes

**Goal**: Convert a `Buffer` into deterministic full-screen repaint bytes without diffing.

### Step 2.1 — Implement the Phase 1 full-repaint renderer

- File: `Sources/TesseraTerminalRendering/Renderer.swift`
- Replace `Renderer` placeholder with a small renderer that emits bytes for:
  - cursor home: `ESC [ H`
  - every cell character in row-major order
  - CR/LF between rows
- Prefer a pure byte-producing API in this target so renderer tests do not need terminal
  I/O; the example can pass those bytes to `PlatformIO.write`.
- Acceptance: rendering target compiles without depending on `TesseraTerminalIO`.

### Step 2.2 — Add renderer golden-byte tests

- File: `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
- Cover an empty buffer and a buffer containing text, asserting exact emitted bytes.
- Acceptance: `swift test --filter TesseraTerminalRenderingTests` passes.

## Phase 3 — Minimal input parsing

**Goal**: Parse only the raw bytes needed for the walking skeleton.

### Step 3.1 — Implement printable-byte and quit parsing

- File: `Sources/TesseraTerminalInput/InputEvent.swift`
- Replace placeholder with a Phase 1 event type and parser:
  - `q` byte (`0x71`) maps to quit
  - other printable ASCII bytes map to character events
  - non-printable/non-ASCII bytes are ignored
- Do not implement escape-sequence state machines, modifiers, arrows, or key names.
- Acceptance: input target compiles and parser behavior matches Phase 1 spec.

### Step 3.2 — Add input parser tests

- File: `Tests/TesseraTerminalInputTests/InputParserLegacyTests.swift`
- Replace placeholder tests with coverage for quit, printable ASCII, ignored control
  bytes, and ignored non-ASCII bytes.
- Acceptance: `swift test --filter TesseraTerminalInputTests` passes.

## Phase 4 — POSIX PlatformIO

**Goal**: Provide the minimum POSIX-only terminal I/O needed by the example app.

### Step 4.1 — Implement terminal size detection and stdout writes

- File: `Sources/TesseraTerminalIO/PlatformIO.swift`
- Under `#if os(macOS) || os(Linux)`, implement terminal size with one `TIOCGWINSZ` call
  at startup/use time and implement direct stdout writes using `write(2)`.
- Provide a clear unavailable/error path for unsupported platforms.
- Acceptance: `swift test --filter TesseraTerminalIOTests` passes on the local platform.

### Step 4.2 — Implement raw mode and alt-screen enter/exit

- File: `Sources/TesseraTerminalIO/PlatformIO.swift`
- Save current termios, disable `ICANON` and `ECHO`, apply raw mode, restore on request.
- Enter/exit alt screen with hardcoded `ESC [?1049 h/l` bytes.
- Preserve the Phase 1 constraint: no signal handling and no lifecycle manager.
- Acceptance: non-interactive tests can validate emitted alt-screen bytes and raw-mode
  methods compile on POSIX.

### Step 4.3 — Implement blocking stdin byte stream

- File: `Sources/TesseraTerminalIO/PlatformIO.swift`
- Expose an async byte stream backed by blocking single-byte reads from stdin in a `Task`.
- Keep behavior minimal: no polling, no cancellation sophistication beyond what is needed
  for clean app exit.
- Acceptance: package compiles under Swift 6 concurrency settings.

### Step 4.4 — Add testable PlatformIO seams and non-interactive tests

- Files:
  - `Sources/TesseraTerminalIO/PlatformIO.swift`
  - `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`
- Add small injectable seams where needed so stdout byte emission and terminal-size
  decoding can be tested without requiring an interactive TTY.
- Avoid tests that put CI into raw mode or require keyboard input.
- Acceptance: `swift test --filter TesseraTerminalIOTests` passes in CI/non-interactive
  shells.

## Phase 5 — HelloTessera executable

**Goal**: Wire every Phase 1 layer into a tiny runnable program.

### Step 5.1 — Add the `HelloTessera` executable target

- Files:
  - `Package.swift`
  - `Sources/HelloTessera/main.swift`
- Add an executable target depending on `TesseraTerminalBuffer`, `TesseraTerminalCore`,
  `TesseraTerminalInput`, `TesseraTerminalIO`, and `TesseraTerminalRendering`.
- Acceptance: `swift run HelloTessera` builds and starts the executable.

### Step 5.2 — Wire the walking-skeleton run loop

- File: `Sources/HelloTessera/main.swift`
- Implement the loop from `docs/Spec.md`: enter raw mode, enter alt screen, render
  greeting and last key, read bytes, update on printable input, exit on `q`, and restore
  alt screen/raw mode with `defer`.
- Use direct buffer writes; do not introduce a `View` protocol.
- Acceptance: `swift run HelloTessera` shows `Hello, Tessera. Press q to quit.` and
  updates `You pressed: X`.

### Step 5.3 — Manually verify interactive behavior on macOS/Linux as available

- Files: no code changes expected unless verification reveals issues.
- Verify:
  - typing letters updates the second line
  - pressing `q` exits cleanly
  - terminal returns from alt screen with prompt sane and scrollback intact
- Acceptance: document any platform caveats in the plan progress notes or a follow-up
  investigation if needed.

## References

- `docs/Spec.md`, Phase 1: The Walking Skeleton, starting near line 266.
- Existing scaffolding targets in `Package.swift`.
- Local Ratatui/crossterm references listed in `AGENTS.md` if implementation details need
  confirmation.
