---
name: Phase 2 Slice 2 ANSI Encoder
description:
  Implement the pure semantic ANSI control-sequence encoder with exact byte fixtures and
  Ghostty round-trip coverage.
status: in-progress
created: 2026-06-07
updated: 2026-06-07
---

## Progress

- [x] **Phase 1 — Lock the public shape**
  - [x] 1.1 Add semantic encoder model types
  - [x] 1.2 Add byte-building helpers and sequence dispatcher
  - [x] 1.3 Add test helpers for readable exact byte fixtures and Ghostty feeds
- [x] **Phase 2 — Cursor, erase, text, and raw sequences**
  - [x] 2.1 Implement cursor-control cases
  - [x] 2.2 Implement erase cases
  - [x] 2.3 Implement literal text, bell, and raw payload cases
- [x] **Phase 3 — SGR color and attributes**
  - [x] 3.1 Implement `Color` and `ANSIColor` foreground/background encoding
  - [x] 3.2 Implement attribute reset and boolean attribute cases
  - [x] 3.3 Extend virtual-terminal style inspection for dim and strikethrough
- [x] **Phase 4 — Modes and OSC title**
  - [x] 4.1 Implement alternate screen, synchronized output, and line-wrap modes
  - [x] 4.2 Implement window-title OSC encoding with string termination safety
- [ ] **Phase 5 — Integrate, demonstrate, and document**
  - [ ] 5.1 Rewrite renderer skeleton to use `ControlSequence`
  - [ ] 5.2 Add an ANSI encoder example app
  - [ ] 5.3 Update DocC and inline reference comments
  - [ ] 5.4 Run focused validation and lint

## Overview

Phase 2 slice 2 replaces ad-hoc escape strings with a pure `ControlSequence` model whose
`encode(into:)` appends exact bytes into a caller-owned buffer. The implementation should
stay intentionally dumb: no I/O, batching, diffing, clipping, or color capability policy.
To keep review easy, this plan builds the encoder in semantic clusters and requires each
cluster to include both byte-level fixtures and Ghostty-backed behavioral tests before
moving on. The renderer is only refactored after the encoder is tested in isolation. For
every concrete encoding mapping, keep a nearby source comment naming the relevant
standard/control family (e.g. ECMA-48 SGR, DEC private mode, OSC) and the wire form being
emitted; this makes byte choices reviewable without re-researching terminal lore.

## Phase 1 — Lock the public shape

**Goal**: Establish the reviewable API surface and test scaffolding before implementing
the catalog.

### Step 1.1 — Add semantic encoder model types

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Sources/TesseraTerminalANSI/ControlSequence.swift`,
  `Sources/TesseraTerminalANSI/EraseMode.swift`,
  `Sources/TesseraTerminalANSI/Color.swift`,
  `Sources/TesseraTerminalANSI/ANSIColor.swift`,
  `Sources/TesseraTerminalANSI/RawTerminalPayload.swift`.
- Replace the placeholder with separate public types:
  - `ControlSequence: Sendable, Equatable`
  - `EraseMode: Sendable, Equatable`
  - `Color: Sendable, Equatable`
  - `ANSIColor: Sendable, Equatable, CaseIterable`
  - `RawTerminalPayload: Sendable, Equatable`
- Keep `TesseraTerminalANSI` depending only on `TesseraTerminalCore`.
- Acceptance: `swift test --filter TesseraTerminalANSITests` builds with placeholder/no-op
  encodings only if needed; no I/O types are imported by `TesseraTerminalANSI`.

### Step 1.2 — Add byte-building helpers and sequence dispatcher

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Sources/TesseraTerminalANSI/ANSIByteEncoding.swift`.
- Add `ControlSequence.encode(into:)` and `ControlSequence.bytes`.
- Add small private helpers for ESC/CSI/OSC/SGR/string integer appending so cases stay
  readable and do not hand-assemble arrays everywhere.
- Keep a single exhaustive `switch` over `ControlSequence`.
- Acceptance: tests can assert `.bytes`; implementation contains no terminal writes, async
  APIs, platform checks, or state caches.

### Step 1.3 — Add test helpers for readable exact byte fixtures and Ghostty feeds

- Files: `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`, `Package.swift`.
- Add `TesseraTerminalSnapshotSupport` as a test-only dependency of
  `TesseraTerminalANSITests` so encoder tests can use `VirtualTerminal` without making the
  ANSI target depend on the harness.
- Add local helpers such as `expectBytes(_:_:sourceLocation:)`, `utf8(_:)`, and
  `feed(_ sequences: [ControlSequence], into:)`.
- Organize tests by semantic area using Swift Testing suites or sentence-style backticked
  test names.
- Acceptance: existing placeholder test is replaced by one failing/pending exact byte
  fixture that proves helpers produce readable failures.

## Phase 2 — Cursor, erase, text, and raw sequences

**Goal**: Implement the non-SGR core sequences first, because they prove coordinate
conversion, literal UTF-8 output, and raw escape handling without style complexity.

### Step 2.1 — Implement cursor-control cases

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Cases: `cursorPosition(TerminalPosition)`, `cursorUp(Int)`, `cursorDown(Int)`,
  `cursorForward(Int)`, `cursorBack(Int)`, `cursorVisible(Bool)`, `cursorSave`,
  `cursorRestore`.
- Encode absolute positions as 0-based Swift model → 1-based wire format (`CSI row;colH`).
  Relative moves emit exactly the requested integer; do not clamp or special-case zero.
- Exact byte tests: pin every byte sequence, including
  `cursorPosition(0,0) == ESC [ 1 ; 1 H`.
- Ghostty tests: assert cursor position changes for absolute/relative moves, save/restore
  restores a prior position, and visibility sequences are accepted without corrupting
  text/cursor.
- Acceptance: `swift test --filter TesseraTerminalANSITests` passes.

### Step 2.2 — Implement erase cases

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Cases: `eraseInDisplay(EraseMode)`, `eraseInLine(EraseMode)`.
- Display mapping: `.toEnd -> CSI J`, `.toBeginning -> CSI 1J`, `.all -> CSI 2J`,
  `.allAndScrollback -> CSI 3J`.
- Line mapping: `.toEnd -> CSI K`, `.toBeginning -> CSI 1K`, `.all -> CSI 2K`. Decide
  explicitly whether `.allAndScrollback` preconditions, aliases `.all`, or is made
  unrepresentable for line erase before coding.
- Exact byte tests: one fixture per mode.
- Ghostty tests: set up visible text, erase from known cursor positions, assert resulting
  screen text.
- Acceptance: ambiguity around line scrollback is resolved in code and tests; focused ANSI
  tests pass.

### Step 2.3 — Implement literal text, bell, and raw payload cases

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Cases: `text(String)`, `bell`, `raw(RawTerminalPayload)`.
- `text` appends UTF-8 bytes exactly; `bell` appends `0x07`; `raw` appends payload bytes
  exactly and preserves `declaredWidth` as metadata only.
- Exact byte tests: ASCII, Unicode scalar/grapheme text, bell, raw OSC-like zero-width
  payload, raw visible payload.
- Ghostty tests: text appears, bell and zero-width raw do not move cursor unexpectedly,
  visible raw payload affects cells according to terminal bytes.
- Acceptance: no escaping/sanitization is performed by `text` or `raw`; tests document
  that callers are responsible for raw payload safety.

## Phase 3 — SGR color and attributes

**Goal**: Pin the color model and attribute toggles, where most long-term regressions are
likely.

### Step 3.1 — Implement `Color` and `ANSIColor` foreground/background encoding

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Cases: `setForeground(Color)`, `setBackground(Color)`.
- Mapping:
  - `.default` → SGR 39/49
  - `.ansi(.black ... .white)` → SGR 30–37 / 40–47
  - `.ansi(.brightBlack ... .brightWhite)` → SGR 90–97 / 100–107
  - `.indexed(n)` → SGR `38;5;n` / `48;5;n`
  - `.rgb(r,g,b)` → SGR `38;2;r;g;b` / `48;2;r;g;b`
- Exact byte tests: all 16 ANSI colors for foreground and background, default,
  representative indexed values including 0/15/255, and RGB edge values.
- Negative tests: prove `.ansi(.red)` differs from `.indexed(1)`, and `.default` differs
  from black.
- Ghostty tests: assert representative foreground/background colors via `RenderedColor`.
- Add source comments near the mapping helpers naming ECMA-48 SGR and documenting why
  default, 16-color, indexed, and truecolor use different parameter ranges.
- Acceptance: focused ANSI tests pass; color policy/downsampling is absent, and SGR byte
  choices are documented next to the encoding code.

### Step 3.2 — Implement attribute reset and boolean attribute cases

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Cases: `resetAttributes`, `setBold(Bool)`, `setDim(Bool)`, `setItalic(Bool)`,
  `setUnderline(Bool)`, `setReverse(Bool)`, `setStrikethrough(Bool)`.
- Mapping: reset `0`, bold `1`/`22`, dim `2`/`22`, italic `3`/`23`, underline `4`/`24`,
  reverse `7`/`27`, strikethrough `9`/`29`.
- Document in source near the mapping that bold and dim share `22` for disabling
  intensity; diff/reapply policy belongs to the renderer, not the encoder.
- Exact byte tests: on/off for every attribute and reset.
- Ghostty tests: assert representative attributes apply and reset; include the bold/dim
  shared-off behavior.
- Acceptance: focused ANSI tests pass, and each attribute mapping has nearby source
  documentation for its SGR parameter.

### Step 3.3 — Extend virtual-terminal style inspection for dim and strikethrough

- Files: `Sources/TesseraTerminalSnapshotSupport/RenderedCell.swift`,
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`, snapshot support
  tests as needed.
- Add `dim` and `strikethrough` to `RenderedCell` so the Phase 3.2 Ghostty tests can
  assert every Phase 2 attribute.
- Update `.blank` and any snapshots/custom dumps affected by the new fields.
- Acceptance: `swift test --filter TesseraTerminalSnapshotSupportTests` and
  `swift test --filter TesseraTerminalANSITests` pass.

## Phase 4 — Modes and OSC title

**Goal**: Finish the non-rendering terminal modes while keeping tests honest about what
Ghostty can and cannot observe.

### Step 4.1 — Implement alternate screen, synchronized output, and line-wrap modes

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Cases: `enterAltScreen`, `exitAltScreen`, `enterSynchronizedOutput`,
  `exitSynchronizedOutput`, `enableLineWrap(Bool)`.
- Mapping: alt screen `CSI ? 1049 h/l`, synchronized output `CSI ? 2026 h/l`, line wrap
  `CSI ? 7 h/l`.
- Add source comments near the mode mapping naming the DEC private modes (`1049`, `2026`,
  `7`) and what each toggles.
- Exact byte tests: exact bytes for every mode.
- Ghostty tests: alt screen round-trip isolates/restores visible text; line wrap
  enabled/disabled changes wrapping behavior; synchronized output is accepted without
  mutating visible state.
- Acceptance: focused ANSI tests pass, and DEC private-mode byte choices are documented
  next to the encoding code.

### Step 4.2 — Implement window-title OSC encoding with string termination safety

- Files: `Sources/TesseraTerminalANSI/ANSIEncoder.swift`,
  `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`.
- Case: `setWindowTitle(String)`.
- Encode as OSC 2 (or document if choosing OSC 0) using `ESC ] 2 ; <title> BEL`.
- Add a source comment near the encoder naming OSC 2 and the chosen string terminator.
- Add tests for ordinary UTF-8 title bytes and an embedded BEL/ESC decision. Prefer a
  deliberate sanitizer or documented precondition over accidentally allowing malformed OSC
  termination.
- Ghostty test: feed title sequence and assert visible text/cursor are unchanged.
- Acceptance: title encoding policy is explicit in documentation and exact byte tests.

## Phase 5 — Integrate, demonstrate, and document

**Goal**: Prove the encoder is usable downstream, provide a concrete runnable example, and
make the sequence catalog discoverable.

### Step 5.1 — Rewrite renderer skeleton to use `ControlSequence`

- Files: `Sources/TesseraTerminalRendering/Renderer.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererTests.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`.
- Replace hardcoded `ESC [ H` with `.cursorPosition(TerminalPosition(column: 0, row: 0))`
  and row text with `.text(...)` encodings.
- Keep the renderer's current full-repaint behavior; do not introduce diffing, style
  state, or synchronized output yet unless required by existing tests.
- Acceptance: renderer tests still pass, and snapshots show identical output bytes except
  for any intentional home-sequence spelling difference documented in test names.

### Step 5.2 — Add an ANSI encoder example app

- Files: `Examples/Package.swift`, `Examples/Sources/ANSIEncoderDemo/main.swift`.
- Add an executable example, similar in spirit to `Examples/Sources/HelloTessera`, that
  directly demonstrates Phase 2 Slice 2:
  - enters raw mode and alternate screen through `PlatformIO`
  - builds visible output with `[ControlSequence]`
  - uses cursor movement, colors, attributes, erase, synchronized output, title, and
    literal text
  - shows a small interactive affordance, such as pressing keys to change the displayed
    ANSI color/style and `q` to quit
  - exits cleanly and restores terminal modes
- Keep the example small and inspectable; it should demonstrate the encoder API rather
  than prefigure the Slice 4 damage renderer.
- Acceptance: `cd Examples && swift run ANSIEncoderDemo` runs manually, and
  `cd Examples && swift build --target ANSIEncoderDemo` passes.

### Step 5.3 — Update DocC and inline reference comments

- Files: `Sources/TesseraTerminalANSI/TesseraTerminalANSI.docc/TesseraTerminalANSI.md`,
  ANSI source files.
- Add documentation comments to public cases/types with references to ECMA-48/xterm/DEC
  behavior and notes copied from local Ratatui/crossterm findings where useful.
- DocC page should list `ControlSequence`, `Color`, `ANSIColor`, `EraseMode`, and
  `RawTerminalPayload`.
- Acceptance: generated symbol docs expose the encoder API; comments explain non-obvious
  choices such as 1-based cursor wire coordinates, `39`/`49`, and bold/dim `22`.

### Step 5.4 — Run focused validation and lint

- Files: none expected unless fixes are needed.
- Run:
  - `swift test --filter TesseraTerminalANSITests`
  - `swift test --filter TesseraTerminalRenderingTests`
  - `swift test --filter TesseraTerminalSnapshotSupportTests`
  - `swift build`
  - `cd Examples && swift build --target ANSIEncoderDemo`
  - `just lint-changed`
- Acceptance: all focused validations pass. If markdown changes are made, also run
  `pnpx markdownlint-cli <changed-md-path>`.

## References

- `docs/Spec.md`, Phase 2 Slice 2, lines 1048–1508.
- `~/Developer/ratatui/ratatui/main/ratatui-core/src/backend.rs` — `Backend` contract.
- `~/Developer/ratatui/ratatui/main/ratatui-crossterm/src/lib.rs` — draw loop, color
  conversion, modifier diff.
- `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/src/cursor.rs`
  — cursor sequence bytes.
- `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/src/terminal.rs`
  — erase and alternate-screen bytes.
- `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/src/style.rs`
  and `src/style/types/*` — SGR command mappings.
