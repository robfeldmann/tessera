---
name: Phase 2 Slice 4 Width-Aware Renderer
description:
  Redesign terminal buffers for display-width correctness and replace full repaint
  rendering with stateful damage-tracked rendering transactions.
status: pending
created: 2026-06-10
updated: 2026-06-10
---

## Progress

- [x] **Phase 1 — Buffer model and Unicode-width invariants**
  - [x] 1.1 Redesign `Cell` around explicit content and diff policy
  - [x] 1.2 Implement display-width and control-character classification helpers
  - [x] 1.3 Rewrite `Buffer.write` for grapheme clusters, clipping, and orphan cleanup
  - [x] 1.4 Add buffer tests for wide, zero-width, combining, clipping, and orphan cases
- [x] **Phase 2 — Raw/opaque buffer regions**
  - [x] 2.1 Add `Rect` geometry
  - [x] 2.2 Implement `Buffer.writeRaw` and `markOpaque`
  - [x] 2.3 Add raw payload and opaque-region buffer tests
- [ ] **Phase 3 — Damage diff engine and byte encoding**
  - [x] 3.1 Extract render operations and row damage scanning
  - [ ] 3.2 Implement style emission and SGR delta helpers
  - [ ] 3.3 Implement cursor-position tracking and run coalescing
  - [ ] 3.4 Add focused diff, SGR, cursor, and raw/opaque renderer tests
- [ ] **Phase 4 — Stateful renderer actor and session integration**
  - [ ] 4.1 Replace static full-repaint renderer with a stateful `Renderer` actor
  - [ ] 4.2 Add render transactions, frame lifecycle, and synchronized-output policy
  - [ ] 4.3 Integrate `TerminalSession.draw` with the renderer actor and one flush per
        frame
  - [ ] 4.4 Add invalidate and resize-driven full-repaint behavior
- [ ] **Phase 5 — Snapshot and example validation**
  - [ ] 5.1 Add virtual-terminal snapshot tests for visual equivalence
  - [ ] 5.2 Update walking skeleton examples to use damage-tracked rendering behavior
  - [ ] 5.3 Document manual terminal sanity verification for interrupted renders
  - [ ] 5.4 Run full slice validation and update this plan
  - [ ] 5.5 Review public documentation for release-facing language

## Review process

Do not push branches or create a GitHub PR for this slice unless explicitly asked. The
agent implements one step at a time, runs focused validation plus `just lint-changed`,
updates this plan, and pauses for user review. After the user approves the completed step,
commit the approved work locally before starting the next step. Do not start
implementation until this plan is reviewed and explicitly approved.

## Context loading for implementers

Before implementing any step, read this entire plan first. Then read the Phase 2 Slice 4
section of `docs/Spec.md` ("Width-aware `Buffer` + damage-tracking renderer") and the
nearby Phase 2 intro enough to understand how Slice 4 fits after the snapshot harness,
ANSI encoder, and terminal lifecycle work. Do not reread the whole spec for every step;
after the first pass, use targeted searches in `docs/Spec.md`, existing source, tests, and
the referenced Ratatui files for the type or behavior being changed.

## Overview

Phase 2 Slice 4 replaces Tessera's ASCII-only buffer and full-repaint renderer with the
core terminal rendering model described in `docs/Spec.md`: display-width-aware cells,
explicit continuation cells, raw/opaque region policy, and a stateful damage-tracking
renderer. The slice should preserve `TerminalSession.draw {}` ergonomics while changing
internals from “render the whole buffer every frame” to “diff current vs previous buffer
and emit only necessary bytes.” Work is split to land buffer invariants first, then raw
region policy, then pure diff logic, and only then live session integration. Tests should
be weighted toward invariants and virtual-terminal visual equivalence because
damage-rendering bugs are easiest to miss by inspection.

## Current state

- `Sources/TesseraTerminalBuffer/Buffer.swift` stores a flat `[Cell]`, but `Cell` is
  `character/style/width` and `Buffer.write` enumerates Swift `Character`s as if each
  consumes one column.
- `Sources/TesseraTerminalRendering/Renderer.swift` is a static full-repaint encoder that
  moves home and emits every cell every frame.
- `Sources/TesseraTerminal/TerminalSession.swift` owns `PlatformIO` directly and calls
  `Renderer.render(frame.buffer)` followed by `PlatformIO.flush()`.
- `RawTerminalPayload`, `Color`, and `ControlSequence` already live in
  `TesseraTerminalANSI`; `TesseraTerminalBuffer` does not yet depend on that target, so
  `Package.swift` must change before `Cell.Content.raw(RawTerminalPayload)` or rich
  `Style` can compile. A text-attributes `OptionSet` is not present yet and should be
  added only if needed for `Style`.
- `TesseraTerminalRendering` does not yet depend on `TesseraTerminalIO`; if the renderer
  actor owns `PlatformIO`, add that target dependency deliberately and avoid cycles.
- `TerminalGeometry.swift` has `TerminalSize` and `TerminalPosition`; `Rect` is missing.
- `swift-displaywidth` is declared and attached to `TesseraTerminalBuffer`; inspect the
  local checkout before coding. Its API is `DisplayWidth` with `callAsFunction` overloads.
- Swift language mode is 6 with `NonisolatedNonsendingByDefault` enabled; do not paper
  over migration issues with broad `Sendable` or `@unchecked Sendable`.
- Snapshot support and `VirtualTerminal` already exist and should be used for renderer
  equivalence tests rather than adding a separate terminal emulator fixture.

## Implementation strategy

Preserve public ergonomics where possible, but treat `Cell`, `Style`, `Frame`, and
renderer internals as slice-level redesign points. Start with pure value types and direct
unit tests before touching actors or live `PlatformIO`. Keep the diff algorithm
package-testable so renderer behavior can be asserted without a real terminal. Add public
API only when it is part of the spec's user-facing model (`Cell.Content`,
`CellDiffPolicy`, `Frame.writeRaw`, `Frame.markOpaque`, renderer invalidation, and sync
output policy); prefer `package` helpers for implementation seams.

A key review point is scope control: this slice diffs whole buffers and emits better
bytes, but it does not add view layout, capability detection, input parsing, scrollback,
hardware scrolling, or color quantization policy.

## Critical corrections and guardrails

1. **Target dependencies are in scope.** This plan must update `Package.swift` when public
   types cross module boundaries:
   - `TesseraTerminalBuffer` needs `TesseraTerminalANSI` for `RawTerminalPayload` and
     `Color`; add or place a text-attributes `OptionSet` deliberately when `Style` grows.
   - `TesseraTerminalRendering` needs `TesseraTerminalIO` if `Renderer` owns `PlatformIO`
     and performs writes/flushes.
   - Tests may need new dependencies only when imports prove they are required.
2. **Do not send user drawing closures to another actor.** Keep `TerminalSession.draw` as
   the public render transaction that creates and lends `Frame`, runs the synchronous body
   without suspension, then sends a `Sendable` buffer snapshot to the renderer actor. This
   follows Swift 6 isolation guidance: keep non-`Sendable` borrowed capabilities in one
   isolation domain instead of making user closures or `Frame` broadly `Sendable`.
3. **Adopt the spec's borrowed-frame shape unless the compiler proves otherwise.** First
   attempt `Frame: ~Copyable, ~Escapable` with `borrowing` APIs. If a Swift 6.3 compiler
   limitation blocks this, document the exact diagnostic in this plan, keep the closure
   synchronous, and add a focused follow-up. Do not silently settle for an escapable
   class.
4. **No `@unchecked Sendable` in this slice.** `Buffer`, `Cell`, `Style`, geometry, raw
   payloads, render operations, and policies should be value-semantic and derive
   `Sendable`. `Renderer`, `PlatformIO`, and `TerminalSession` are actors. If a diagnostic
   suggests `@unchecked Sendable`, fix the isolation boundary instead.
5. **Actor state advances only after a successful frame.** The renderer must not update
   `lastDrawnBuffer`, believed cursor position, or believed style until frame bytes have
   been flushed successfully. If bytes may have been partially written before an error,
   invalidate renderer assumptions so the next successful draw is conservative.
6. **Implementation comments should cite the local design source.** For non-obvious rules
   (orphan cleanup, zero-width/control filtering, raw/opaque policy, VS16 trailing clears,
   SGR reset-at-end, synchronized-output no-op bracketing, resize invalidation), add a
   concise doc or code comment naming `docs/Spec.md` Slice 4 and the relevant Ratatui
   reference file/function. Do not paste large spec excerpts into source.
7. **Public mutation APIs should preserve buffer invariants.** A public mutable subscript
   can create orphan continuations or invalid raw regions. Prefer a public read-only
   subscript plus mutation methods, with any invariant-bypassing setter kept `package` and
   documented as low-level test/internal support.

## Phase 1 — Buffer model and Unicode-width invariants

**Goal**: Make `Buffer` accurately model a terminal grid for grapheme clusters and wide
characters, with explicit continuation cells and deterministic write semantics.

### Step 1.1 — Redesign `Cell` around explicit content and diff policy

- Files: `Package.swift`, `Sources/TesseraTerminalBuffer/Buffer.swift`, possibly new
  `Sources/TesseraTerminalBuffer/Cell.swift` and `Style.swift`.
- Add `TesseraTerminalANSI` as a dependency of `TesseraTerminalBuffer`.
- Replace `Cell.character`/stored `width` with:
  - `public enum CellDiffPolicy: Equatable, Sendable` with `normal`, `opaque`, and
    `alwaysRepaint` cases.
  - `public struct Cell` containing `Content`, `Style`, and `diffPolicy`.
  - `public enum Cell.Content` with `blank`, `continuation`, `grapheme(String)`, and
    `raw(RawTerminalPayload)` cases.
- Expand `Style` only to fields already encodable by `TesseraTerminalANSI`: foreground,
  background, and attributes corresponding to existing SGR cases. Add a small attributes
  `OptionSet` if needed, but do not add fields that cannot be emitted yet.
- Keep source compatibility conveniences where cheap, e.g. `.blank` and initializers for
  normal grapheme/blank cells, but do not preserve APIs that hide the continuation model.
- Revisit `Buffer` subscript access: callers should be able to inspect cells, but ordinary
  public writes should go through invariant-preserving APIs rather than arbitrary cell
  assignment.
- Add doc comments on `Cell.Content`, `CellDiffPolicy`, and `Style` explaining the Slice 4
  grid/diff policy in terms of `docs/Spec.md` and Ratatui's `CellDiffOption`.
- Sort protocol conformances alphabetically.
- Acceptance: `swift test --filter TesseraTerminalBufferTests` compiles far enough to show
  intentional test updates are needed, with target dependency changes checked in.

### Step 1.2 — Implement display-width and control-character classification helpers

- Files: `Sources/TesseraTerminalBuffer/TerminalWidth.swift`, plus helper tests.
- Use `DisplayWidth` from `swift-displaywidth` for normal grapheme width queries. Inspect
  `.build/checkouts/swift-displaywidth` before coding and do not guess API names.
- Implement `Cell.width` as computed:
  - `.grapheme` -> terminal display width clamped to supported cell widths (`0`, `1`, or
    `2`). Unsupported `>2` graphemes should be deliberately dropped by write helpers until
    a future policy exists.
  - `.raw` -> `payload.declaredWidth ?? 0`, with negative values impossible by API.
  - `.continuation` -> `0`.
  - `.blank` -> `1`.
- Add package helpers to classify and drop control graphemes. The buffer is for
  displayable content; C0/C1 controls and tab are not stored as cells in this slice.
- Add package helpers to drop isolated zero-width graphemes while preserving complex
  grapheme clusters that have terminal width `1` or `2` because of their non-zero-width
  components.
- Adopt Ratatui's lesson from `cell_width.rs`: explicitly test halfwidth katakana
  dakuten/handakuten (`U+FF9E`, `U+FF9F`). If `swift-displaywidth` reports them as
  zero-width when terminals render them as width one, add a small Tessera wrapper
  correction and document why.
- Acceptance: focused helper tests or `Cell.width` direct tests cover ASCII, CJK, emoji,
  ZWJ emoji, flags, skin-tone emoji, combining marks, halfwidth dakuten/handakuten,
  isolated zero-width/control input, raw payload width, blank width, and continuation
  width.

### Step 1.3 — Rewrite `Buffer.write` for grapheme clusters, clipping, and orphan cleanup

- Files: `Sources/TesseraTerminalBuffer/Buffer.swift`.
- Make `Buffer.write(_:at:style:)` iterate grapheme clusters as `String` values and
  advance by display width, not scalar count or `Character` count.
- Add `public mutating func write(grapheme:at:style:) -> Int?` that writes one printable
  grapheme and returns the next column, or `nil` if it does not fit.
- Add package helpers such as `clearCluster(at:)`, `prepareCellForWrite(at:)`, and
  `rowBounds` as needed; keep flat row-major storage and avoid 2D arrays.
- Enforce invariants before every write:
  - Writing over the leading cell of a wide/raw region clears its continuation cells.
  - Writing over a continuation cell clears the leading cell and any related
    continuations.
  - A wide grapheme at the last column is dropped without writing a half-grapheme.
  - Negative columns clip by skipping graphemes until a printable grapheme starts within
    the row; do not render only the visible half of a wide grapheme.
  - Writes do not wrap to the next row.
  - `clear(fill:)` resets content and diff policy consistently.
- Acceptance: `Buffer.write` tests prove wide grapheme layout, continuation placement,
  clipping at left/right edges, row bounds, no wrapping, `clear`, and symmetric orphan
  cleanup.

### Step 1.4 — Add buffer tests for wide, zero-width, combining, clipping, and orphan cases

- Files: `Tests/TesseraTerminalBufferTests/BufferTests.swift`,
  `Sources/TesseraTerminalTestSupport/BufferCustomDump.swift` if snapshots need updating.
- Update existing ASCII tests to the new `Cell.Content` model.
- Add direct assertions for:
  - ASCII text still fills one cell per grapheme.
  - `你好`, emoji, ZWJ family emoji, flag emoji, and skin-tone emoji occupy two cells with
    continuation.
  - Precomposed and decomposed combining examples store the full grapheme and consume one
    cell when display width is one.
  - Bare zero-width/control graphemes are ignored according to the helper policy from step
    1.2.
  - Halfwidth dakuten/handakuten behavior matches the wrapper policy.
  - Overwriting either half of a previous wide grapheme clears the orphaned half.
  - Style-only writes and blank cells retain enough style information for backgrounds to
    render later.
- Prefer direct cell assertions for invariants; use snapshots only for compact whole-row
  readability.
- Acceptance: `swift test --filter TesseraTerminalBufferTests` passes.

## Phase 2 — Raw/opaque buffer regions

**Goal**: Add the raw payload escape hatch in a way that remains visible to rendering,
snapshotting, and damage policy.

### Step 2.1 — Add `Rect` geometry

- Files: `Sources/TesseraTerminalCore/TerminalGeometry.swift`,
  `Tests/TesseraTerminalCoreTests/TerminalGeometryTests.swift`.
- Add a minimal public `Rect` with origin (`TerminalPosition`) and size (`TerminalSize`)
  or equivalent scalar fields, plus row/column containment, intersection, clipping to a
  terminal size, and row/column range helpers needed by buffer region operations.
- Decide and test non-negative geometry invariants. `TerminalSize` currently accepts any
  `Int`; either precondition non-negative dimensions or ensure all buffer/rect entry
  points safely normalize invalid sizes before allocation.
- Keep the type small and value-semantic; view layout can expand it later.
- Add doc comments that identify this as the Phase 2 Slice 4 rectangle used by buffer
  raw/opaque regions.
- Acceptance: direct geometry tests cover containment, intersection, clipping to a
  terminal size, empty or out-of-bounds regions, negative origins, and
  `Equatable`/`Hashable`/`Sendable` API shape.

### Step 2.2 — Implement `Buffer.writeRaw` and `markOpaque`

- Files: `Sources/TesseraTerminalBuffer/Buffer.swift`.
- Add:
  - `writeRaw(_:at:occupying:repaintPolicy:)`
  - `markOpaque(_:)`
- `writeRaw` should store `.raw(payload)` at the anchor cell, mark the requested clipped
  occupied region using `.continuation`/`.blank` plus `.opaque` or `.alwaysRepaint`
  policy, and clear any prior wide/raw region that intersects the new region.
- `markOpaque` should mark a clipped region as foreign without emitting bytes or changing
  visible grapheme content unnecessarily.
- Normal `write` should be able to reclaim an opaque/raw region by clearing affected cells
  and writing normal content with `.normal` policy.
- Decide and document the zero-width raw payload rule before renderer work. If
  `declaredWidth` is `nil` or `0`, the raw payload emits at its anchor and does not
  advance the cursor; tests must show how this interacts with the anchor cell's previous
  visible content.
- Harden `RawTerminalPayload.declaredWidth`: it is currently `Int?`, so either reject
  negative widths with a precondition or change the API to make negative widths
  unrepresentable.
- Acceptance: buffer tests cover raw anchor width, continuation/opaque markings,
  out-of-bounds clipping, overlap with existing wide graphemes, multi-row occupied
  regions, zero-width payloads, and normal content reclaiming opaque regions.

### Step 2.3 — Add raw payload and opaque-region buffer tests

- Files: `Tests/TesseraTerminalBufferTests/BufferTests.swift`.
- Add direct tests for raw payloads with declared width `nil`, `0`, `1`, `2`, and wider
  than the remaining row.
- Add region tests for partially off-screen rectangles, empty rectangles, multiple-row
  opaque regions, anchor outside bounds, and overlapping raw regions.
- Add tests that `clear(fill:)` removes opaque/always-repaint policy and continuations.
- Prefer direct cell assertions for these invariants; snapshots are not needed at the
  buffer layer.
- Acceptance: `swift test --filter TesseraTerminalBufferTests` and
  `swift test --filter TesseraTerminalCoreTests` pass.

## Phase 3 — Damage diff engine and byte encoding

**Goal**: Build the pure renderer core that compares buffers and emits minimal terminal
bytes without involving actors or live I/O.

### Step 3.1 — Extract render operations and row damage scanning

- Files: `Sources/TesseraTerminalRendering/Renderer.swift`, possibly new
  `Sources/TesseraTerminalRendering/BufferDiff.swift` and `RenderOperation.swift`.
- Introduce package-internal render operations or a diff iterator that yields row runs of
  changed cells. Keep this testable without `PlatformIO`.
- Prefer a Ratatui-like iterator/run scanner over building large intermediate arrays.
- Implement row-by-row scanning:
  - Skip equal rows with no `.alwaysRepaint` cells.
  - Find first/last changed or forced-repaint columns in each dirty row.
  - Split runs around `.opaque` cells so emission can reposition after skipped regions.
  - Treat `.continuation` as non-emitting but still part of changed-region decisions when
    needed to clear/reclaim stale wide/raw content.
  - Treat mismatched buffer sizes as a full repaint path rather than a partial diff.
  - Preserve Ratatui's VS16 lesson: emoji presentation sequences may need explicit
    trailing-cell clears when replacing or restyling them.
- Acceptance: pure diff tests cover identical buffers, one changed cell, changed run,
  equal-row skip, forced repaint piercing equality, opaque skip and gaps, size mismatch,
  style-only changes, wide-grapheme continuation behavior, and VS16 trailing-cell clears.

### Step 3.2 — Implement style emission and SGR delta helpers

- Files: `Sources/TesseraTerminalBuffer/Style.swift`,
  `Sources/TesseraTerminalRendering/Renderer.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererTests.swift`.
- Use the Phase 1 `Style` fields that map to existing `ControlSequence` SGR cases. Avoid
  adding style fields not encodable by `TesseraTerminalANSI`.
- Implement `sgrDelta(from:to:into:)` as package-internal logic:
  - First frame or unknown old style emits reset plus full new style.
  - Pure additions emit only additions.
  - Removals emit reset plus full new style.
  - Foreground/background default changes use the encoder's default color semantics.
  - End every frame with reset and remember default style.
- Acceptance: SGR tests assert exact bytes for default-to-style, style additions,
  removals, foreground/background color changes, attribute combinations, default color
  reset, final frame reset, and no redundant SGR for adjacent same-style cells.

### Step 3.3 — Implement cursor-position tracking and run coalescing

- Files: `Sources/TesseraTerminalRendering/Renderer.swift`.
- Track believed cursor position while emitting a frame.
- Emit at most one cursor move for a contiguous dirty run unless a skipped opaque cell,
  non-contiguous changed run, row change, or unknown cursor state requires repositioning.
- Avoid cursor moves between adjacent emitted cells when the terminal cursor is already at
  the next cell.
- Correctly advance cursor by display width for graphemes/raw payloads and by zero for
  continuations. Raw payloads use `declaredWidth ?? 0` rather than byte count.
- Do not rely on newline wrapping for row transitions; use explicit cursor positioning.
- Acceptance: exact-byte tests prove adjacent same-row cells coalesce, separate rows move
  once per dirty run, opaque gaps force repositioning when needed, zero-width raw payloads
  do not advance the cursor, and wide cells advance the believed cursor correctly.

### Step 3.4 — Add focused diff, SGR, cursor, and raw/opaque renderer tests

- Files: `Tests/TesseraTerminalRenderingTests/RendererTests.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`,
  `Sources/TesseraTerminalTestSupport/RendererCustomDump.swift`.
- Update existing full-repaint tests to either target explicit invalidation/full repaint
  or the new first-frame behavior.
- Add exact-byte tests where small and stable; use snapshots for larger grouped render
  cases humans inspect as a whole.
- Include raw payload rendering and opaque-region skip tests before actor integration.
- Add tests for first frame, identical second frame, style-only damage, clearing previous
  wide content with blanks, raw always-repaint equality, and blank-vs-space visual
  equivalence if the chosen equality policy supports it.
- Acceptance: `swift test --filter TesseraTerminalRenderingTests` passes.

## Phase 4 — Stateful renderer actor and session integration

**Goal**: Route terminal drawing through a stateful renderer that owns cached render state
and writes/flushed bytes exactly once per successful frame.

### Step 4.1 — Replace static full-repaint renderer with a stateful `Renderer` actor

- Files: `Package.swift`, `Sources/TesseraTerminalRendering/Renderer.swift`.
- Add `TesseraTerminalIO` as a dependency of `TesseraTerminalRendering` if the actor owns
  `PlatformIO`.
- Introduce `public actor Renderer` or a `public` type with `package` initializers as
  needed by `TerminalSession`.
- Internal state should include:
  - last drawn `Buffer?` (`nil` means full repaint),
  - current terminal `Style`,
  - believed cursor position,
  - an “erase before next repaint” flag set by invalidation/resize,
  - synchronized-output policy.
- The actor should accept a completed `Buffer` value from `TerminalSession`; it should not
  run the user drawing closure or expose a borrowed `Frame` across actors.
- Preserve package-testable pure functions so most renderer tests do not need actors.
- Acceptance: actor-level tests can render two buffers through an in-memory output seam
  and observe that the second successful draw emits only damage bytes.

### Step 4.2 — Add render transactions, frame lifecycle, and synchronized-output policy

- Files: `Sources/TesseraTerminal/Frame.swift`,
  `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`,
  `Sources/TesseraTerminalRendering/Renderer.swift`.
- First attempt to harden `Frame` to the spec's `~Copyable, ~Escapable` borrowed shape. If
  this cannot land in this slice, document the compiler blocker and keep the synchronous
  closure as a temporary containment boundary.
- Add a package API for `TerminalSession` to extract or consume the completed buffer after
  the synchronous body returns. Do not expose mutable buffer storage publicly.
- Add `Frame.writeRaw` and `Frame.markOpaque` forwarding to the buffer.
- Add a small `SynchronizedOutputPolicy` value (`enabled`/`disabled` is enough for
  Slice 4) in a target that avoids dependency cycles, and store it on
  `TerminalApplicationConfiguration`.
- Emit enter/exit synchronized output around every frame when policy enables it, including
  no-op frames.
- Acceptance: tests cover frame raw/opaque forwarding, sync enabled exact bytes, sync
  disabled exact bytes, no-op frame bracketing behavior, and the chosen `Frame` API shape.

### Step 4.3 — Integrate `TerminalSession.draw` with the renderer actor and one flush per frame

- Files: `Sources/TesseraTerminal/TerminalSession.swift`,
  `Sources/TesseraTerminalRendering/Renderer.swift`,
  `Tests/TesseraTerminalTests/TerminalSessionTests.swift`.
- Store a renderer on `TerminalSession` and construct it from the same `PlatformIO` and
  configuration policy.
- Keep `TerminalSession.draw` API stable: query size, create a frame, run the synchronous
  body without suspension, render the completed buffer through the renderer, and flush
  once per successful frame.
- Ensure body errors do not render partial frames; render errors propagate; flush errors
  preserve `PlatformIO` buffering semantics from Slice 3.
- Ensure renderer cached state updates only after successful flush; on render/flush
  failure, invalidate assumptions or leave them unchanged so the next successful draw is
  conservative.
- Acceptance: terminal-session tests prove body return value, no render on body throw,
  render/flush error propagation, one flush per successful draw, no actor hop while the
  frame body runs, and conservative behavior after a failed flush.

### Step 4.4 — Add invalidate and resize-driven full-repaint behavior

- Files: `Sources/TesseraTerminalRendering/Renderer.swift`,
  `Sources/TesseraTerminal/TerminalSession.swift`,
  `Tests/TesseraTerminalRenderingTests/RendererTests.swift`.
- Implement renderer invalidation (`invalidateRendererState()`) and a session forwarding
  API if needed.
- Invalidation should discard previous buffer assumptions and cause the next draw to emit
  `eraseInDisplay(.all)` before repainting.
- Wire resize notifications to renderer invalidation only if this can be done with a
  stored, cancellable task that does not capture borrowed frame state or leak session
  lifetime. If not, document the temporary pre-view-layer behavior and expose explicit
  invalidation for examples/tests.
- Acceptance: tests prove invalidate causes erase + full repaint, subsequent draw returns
  to damage tracking, horizontal/size changes repaint conservatively, and resize-triggered
  invalidation is covered or intentionally deferred with a documented reason.

## Phase 5 — Snapshot and example validation

**Goal**: Prove the damage renderer is visually equivalent to full repaint behavior and
update runnable examples to exercise the real renderer.

### Step 5.1 — Add virtual-terminal snapshot tests for visual equivalence

- Files: `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`,
  `Sources/TesseraTerminalTestSupport/` if helpers are useful.
- For representative previous/current buffer pairs, feed emitted damage bytes into
  `VirtualTerminal` initialized to the previous screen state and assert the final screen
  matches the current buffer.
- Cover ASCII, styled text, wide graphemes, row changes, raw payloads where the virtual
  terminal can model the visible result, invalidation/full repaint, sync wrappers, opaque
  skips, zero-width raw payloads, and failed-frame recovery if representable.
- Acceptance: snapshot tests are deterministic and lint-clean; no test depends on terminal
  timing or a live TTY.

### Step 5.2 — Update walking skeleton examples to use damage-tracked rendering behavior

- Files: `Examples/`, `README.md` or docs only if existing examples describe repaint
  behavior.
- Ensure examples still compile after renderer/session API changes.
- If a demo can cheaply show incremental updates without adding flaky sleeps or real
  input, update it to exercise multiple draws.
- Acceptance: `swift build --package-path Examples` passes and examples do not call
  deprecated static full-repaint APIs.

### Step 5.3 — Document manual terminal sanity verification for interrupted renders

- Files: `CONTRIBUTING.md` or `.agents/investigations/`.
- Update the existing terminal lifecycle manual verification notes to include rendering
  interruption during a draw, synchronized output policy, post-flush-error recovery, and
  expected `tessera-reset` recovery behavior.
- Keep documentation concise and avoid duplicating the full spec.
- Acceptance: `pnpx markdownlint-cli <changed markdown files>` passes.

### Step 5.4 — Run full slice validation and update this plan

- Commands:
  - `swift test --filter TesseraTerminalBufferTests`
  - `swift test --filter TesseraTerminalCoreTests`
  - `swift test --filter TesseraTerminalRenderingTests`
  - `swift test --filter TesseraTerminalTests`
  - `swift test --enable-code-coverage`
  - `swift build --package-path Examples`
  - `just test-linux-vm`
  - `just lint-changed`
- Update this plan's progress and `updated` date as phases complete.
- Acceptance: all commands pass or any platform-specific deferral is documented with a
  concrete follow-up.

### Step 5.5 — Review public documentation for release-facing language

- Files: public source doc comments touched by this slice.
- Review public-facing docs and remove implementation-plan language such as phase/slice
  numbers, internal review notes, or references that require knowledge of Tessera's
  development process.
- Keep internal comments that cite `docs/Spec.md` where the implementation plan explicitly
  asks for them, but do not expose those details as public API documentation.
- Acceptance: public API docs describe stable behavior for users, not project history.

## Risks and decisions to review before implementation

1. **Noncopyable `Frame` timing.** The spec wants `Frame: ~Copyable, ~Escapable`. This
   plan now requires trying that first. A class fallback is acceptable only with a
   recorded compiler/API blocker and a follow-up.
2. **Zero-width raw payload semantics.** A raw operation with `declaredWidth == nil` or
   `0` still needs an anchor cell. Decide exactly how that operation coexists with visible
   content at the anchor before renderer tests are written.
3. **`Style` expansion scope.** Damage rendering needs meaningful SGR deltas, but style
   should not grow beyond what `ControlSequence` can encode and tests can inspect.
4. **Raw payload region semantics.** The exact cell policy for raw occupied cells must be
   nailed down before renderer tests: which cells are `.opaque`, which are
   `.alwaysRepaint`, and how normal writes reclaim them.
5. **Failed flush recovery.** A flush failure can mean the terminal saw a prefix of the
   frame. Renderer state must not believe the full frame succeeded. Existing `PlatformIO`
   buffering preserves unwritten bytes, so tests must pin down whether the next draw
   retries, invalidates, or both.
6. **Resize invalidation ownership.** Session-owned resize listeners can create lifetime
   and cancellation complexity. Prefer explicit invalidation if automatic wiring is not
   clean in this slice.
7. **Snapshot granularity.** Use snapshots for visual equivalence and grouped byte
   streams, but keep small scalar invariants as direct assertions.

## References

- `docs/Spec.md` — Phase 2, Slice 4: Width-aware `Buffer` + damage-tracking renderer.
- `.agents/plans/006-phase-2-slice-1-snapshot-harness.md`
- `.agents/plans/007-phase-2-slice-2-ansi-encoder.md`
- `.agents/plans/008-phase-2-slice-3-terminal-lifecycle.md`
- Swift 6 concurrency skill:
  `~/Documents/pfw-concurrency-skill/skills/swift6-concurrency-migration/`
- Ratatui local reference: `~/Developer/ratatui/ratatui/main/ratatui-core/src/buffer/`
- Ratatui local reference: `~/Developer/ratatui/ratatui/main/ratatui-core/src/terminal/`
- Ratatui local reference: `~/Developer/ratatui/ratatui/main/ratatui-crossterm/src/lib.rs`
