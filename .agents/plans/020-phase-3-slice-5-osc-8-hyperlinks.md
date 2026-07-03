---
name: Phase 3 Slice 5 OSC 8 Hyperlinks
description:
  Add semantic OSC 8 hyperlink styling, encoder support, renderer state transitions,
  hyperlink-aware snapshots, and a demo panel.
status: pending
created: 2026-07-02
updated: 2026-07-03
---

## Progress

- [ ] **Phase 1 — Hyperlink model and cell styling**
  - [ ] 1.1 Add a validated `Hyperlink` value type
  - [ ] 1.2 Store hyperlink metadata in `Style` and buffer snapshots
- [ ] **Phase 2 — OSC 8 encoder and renderer integration**
  - [ ] 2.1 Add exact OSC 8 open and close encoding
  - [ ] 2.2 Render hyperlink transitions independently from SGR state
  - [ ] 2.3 Keep hyperlink changes in damage tracking and invalidation
- [ ] **Phase 3 — Snapshot support, example app, and validation**
  - [ ] 3.1 Add hyperlink-aware virtual-terminal snapshots
  - [ ] 3.2 Add the links panel to `Phase3ProtocolsDemo`
  - [ ] 3.3 Run narrow buffer, encoder, renderer, snapshot, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 5. OSC 8 hyperlinks are output metadata:
visible text is still ordinary cells, while a style field tells the renderer to surround
those cells with OSC 8 open/close sequences.

Do not model hyperlinks as raw terminal payloads. Raw payloads intentionally bypass
semantic validation and snapshot support; links are a first-class style feature.

## Phase 1 — Hyperlink model and cell styling

**Goal**: buffers can carry link metadata safely, and link metadata participates in style
equality and damage tracking.

### Step 1.1 — Add a validated `Hyperlink` value type

- Files:
  - new `Sources/TesseraTerminalANSI/Hyperlink.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or a focused new
    `HyperlinkTests.swift` in the same test target
- Add a public value:

```swift
public struct Hyperlink: Equatable, Hashable, Sendable {
  public let uri: String
  public let id: String?
}
```

- Use a throwing initializer or failable initializer. Pick one style and keep tests
  explicit about failure cases.
- Validate `uri`:
  - non-empty
  - no C0 controls
  - no `DEL`
  - no `ESC`
  - no BEL
  - no string-terminator byte sequence
- Validate `id` when present:
  - non-empty
  - no C0 controls
  - no `DEL`
  - no semicolon, because it lives in the OSC 8 params section
- Do not parse or restrict URL schemes in this slice. `file:`, `https:`, editor links, and
  terminal-specific links should remain possible.
- Add tests for accepted ordinary links, accepted ids, and every rejected control-byte
  case.

Acceptance:

- Unsafe OSC payload delimiters cannot enter the semantic hyperlink model.
- Raw byte escape hatches remain available only through `RawTerminalPayload`.

### Step 1.2 — Store hyperlink metadata in `Style` and buffer snapshots

- Files:
  - `Sources/TesseraTerminalBuffer/Style.swift`
  - `Sources/TesseraTerminalBuffer/Cell.swift`
  - `Sources/TesseraTerminalTestSupport/BufferSnapshotting.swift`
  - `Tests/TesseraTerminalBufferTests/BufferTests.swift`
- Add `public var hyperlink: Hyperlink?` to `Style`.
- Update `Style.init` with default `hyperlink: nil`.
- Ensure `Style` remains `Equatable, Sendable`.
- Because `Cell` equality already includes style, hyperlink changes should automatically
  dirty affected cells through `BufferDiff`. Add a test that proves a style-only hyperlink
  change is visible in buffer or diff snapshots.
- Update reusable buffer snapshots to include a readable link suffix for non-default
  style, such as `link=https://example.com` or `link=id:docs`.
- Avoid changing width, grapheme, raw payload, or opaque-cell semantics.

Acceptance:

- Writing text with a hyperlink-bearing style stores the same visible characters with link
  metadata.
- Buffer snapshots make hyperlink metadata reviewable.

## Phase 2 — OSC 8 encoder and renderer integration

**Goal**: renderer output opens, switches, and closes hyperlinks exactly where cell style
requires, without conflating OSC 8 with SGR state.

### Step 2.1 — Add exact OSC 8 open and close encoding

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Sources/TesseraTerminalANSI/ANSIByteEncoding.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Add control sequences:

```swift
case openHyperlink(Hyperlink)
case closeHyperlink
```

- Encode open with OSC 8 and string terminator:

```text
ESC ] 8 ; params ; uri ESC \
```

- Encode close with:

```text
ESC ] 8 ; ; ESC \
```

- If `id` exists, encode params as `id=<id>`. Keep params empty otherwise.
- Add a helper to append OSC with ST termination; do not reuse BEL-terminated
  `setWindowTitle` behavior unless the helper explicitly supports both terminators.
- Add exact byte tests for:
  - open without id
  - open with id
  - close
  - rejected hyperlink data never reaches encoder through `Hyperlink`

Acceptance:

- Encoder bytes match OSC 8 with ST termination exactly.
- Encoder helpers keep OSC termination policy explicit.

### Step 2.2 — Render hyperlink transitions independently from SGR state

- Files:
  - `Sources/TesseraTerminalRendering/Renderer.swift`
  - `Sources/TesseraTerminalRendering/StyleEncoding.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererVisualEquivalenceTests.swift`
- Add renderer state for the currently believed hyperlink, separate from `currentStyle`.
- Before emitting a cell, compute hyperlink transition from current hyperlink to target
  `cell.style.hyperlink`:
  - nil → link: open hyperlink
  - link A → same link A: emit nothing
  - link A → link B: close then open B
  - link → nil: close hyperlink
- SGR changes still use existing style delta helpers.
- End every rendered frame with `closeHyperlink` if a hyperlink is active, then reset the
  renderer's believed hyperlink state to nil.
- Full repaint and damage-diff paths must both obey the same transition helper.
- Do not close and reopen links for every linked cell when adjacent cells share the same
  link.

Add renderer tests for:

- one linked text run opens once and closes once
- adjacent same-link cells do not churn OSC 8 sequences
- switching between two links closes then opens
- linked-to-unlinked transition closes
- style-only hyperlink changes repaint affected cells
- full repaint and diff repaint end in the same visible screen state

Prefer `VirtualTerminal` snapshots for final screen state and exact byte assertions only
where the transition count or sequence order is the subject of the test.

Acceptance:

- OSC 8 state is independent from SGR state.
- Rendering one linked run does not emit per-cell open/close churn.

### Step 2.3 — Keep hyperlink changes in damage tracking and invalidation

- Files:
  - `Sources/TesseraTerminalRendering/Renderer.swift`
  - `Sources/TesseraTerminalRendering/BufferDiff.swift` if needed
  - `Tests/TesseraTerminalRenderingTests/RendererVisualEquivalenceTests.swift`
- Verify `BufferDiff` sees hyperlink changes through `Cell` equality. If it does not, fix
  the equality source instead of adding hyperlink-specific damage code.
- `Renderer.invalidate()` must forget current hyperlink state along with cursor and style
  state.
- Erase-before-next-repaint paths must close any believed hyperlink before erasing or
  resetting state.

Add tests for:

- changing only a hyperlink URI repaints affected cells
- changing only a hyperlink id repaints affected cells
- `invalidate()` followed by linked content emits a safe open sequence
- erasing after linked content does not leave subsequent text linked

Acceptance:

- Hyperlink metadata participates in damage tracking without a special-case parallel diff.
- Invalidation and erase paths cannot leak a link into later text.

## Phase 3 — Snapshot support, example app, and validation

**Goal**: tests can inspect link metadata semantically, and reviewers can see link output
in the demo app.

### Step 3.1 — Add hyperlink-aware virtual-terminal snapshots

- Files:
  - `Sources/TesseraTerminalSnapshotSupport/RenderedCell.swift`
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`
  - `Sources/TesseraTerminalTestSupport/VirtualTerminalSnapshotting.swift`
  - `Tests/TesseraTerminalSnapshotSupportTests/VirtualTerminalTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`
- Add `public let hyperlinkURI: String?` or a small `RenderedHyperlink?` to
  `RenderedCell`. Use the smaller URI field unless Ghostty exposes stable id data too.
- Update `.blank`, equality, and snapshots.
- Extend the Ghostty bridge at `currentRenderedCell()` to read hyperlink metadata if the C
  API exposes it in the linked version. If the backing API cannot expose URI metadata,
  keep the Swift field nil and add exact renderer byte tests for OSC 8. Do not fake
  hyperlink metadata.
- Add a readable snapshot helper for links, for example:

```text
── chars ──
Docs  Plain
── links ──
AAAA  .....
A = https://example.com/docs
```

- Add a raw virtual-terminal smoke test that feeds OSC 8 bytes and inspects the rendered
  hyperlink field when supported.

Acceptance:

- Snapshot tests can review hyperlink placement without reading raw escape bytes when the
  backing terminal exposes metadata.
- Unsupported snapshot metadata is explicit in tests, not silently fabricated.

### Step 3.2 — Add the links panel to `Phase3ProtocolsDemo`

- File: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Add panel navigation: `1` paste, `2` focus, `3` mouse, `4` keys, `5` links.
- Render a few labeled links using `Style(hyperlink:)`.
- Also render plain fallback text so unsupported terminals still show useful content.
- Do not ask the example to detect click support. OSC 8 click behavior belongs to the
  terminal emulator.

Wireframe:

```text
Phase3ProtocolsDemo — Links                                      80x24
q quit · 1 paste · 2 focus · 3 mouse · 4 keys · 5 links

OSC 8 hyperlink samples
  Docs:    Tessera Spec
  Issue:   GH-123 terminal protocols
  File:    Sources/TesseraTerminalANSI/ControlSequence.swift

Plain fallback
  The visible text above remains readable even when OSC 8 is unsupported.

Recent events
  0061 key code=character("5") modifiers=none kind=press
```

Acceptance:

- The panel renders visible text in every terminal.
- Terminals with OSC 8 support expose clickable links over only the intended text.

### Step 3.3 — Run narrow buffer, encoder, renderer, snapshot, and example checks

Run:

```fish
swift test --filter TesseraTerminalBufferTests
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalRenderingTests
swift test --filter TesseraTerminalSnapshotSupportTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
```

Acceptance:

- Hyperlink style, encoding, rendering, damage tracking, and snapshots are covered.
- Existing color, attribute, raw payload, and opaque-cell tests still pass.
