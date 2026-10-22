---
type: spec
description: "Slice 4: Width-aware Buffer + damage-tracking renderer"
---

# Slice 4: Width-aware `Buffer` + damage-tracking renderer

Slice 4 is the conceptual heart of `TesseraTerminal`. Everything before it was plumbing — bytes in, bytes out, modes managed. Slice 4 is where Tessera starts being _good_ at what it does. The buffer becomes faithful to the terminal's grid model (wide characters, combining marks, emoji), and the renderer learns to emit _only what changed_ — turning the Phase 1 "full repaint, visible flicker" into "smooth, responsive updates indistinguishable from a native app."

This is also the slice where snapshot tests start paying for themselves daily. Damage-tracking renderers are notoriously easy to break in subtle ways — an off-by-one in the diff produces a tearing artifact you'd never catch by reading the code, but a snapshot test catches instantly.

## The four problems this slice solves

1. **Width is not 1.** A buffer that assumes one character per column is correct for ASCII and lies about everything else. CJK characters are 2 cells wide. Emoji are 2 cells. A flag emoji is one grapheme made of two scalars and is 2 cells. The skin-toned thumbs-up "👍🏽" is one grapheme made of two scalars joined by a variation selector and is 2 cells. Getting this right is the difference between "looks fine in English" and "actually usable for real applications."

2. **Full repaint is unacceptable.** Phase 1's renderer flickers because it rewrites every cell every frame. A typing app updates one cell per keystroke; emitting bytes for 200×60 = 12,000 cells per keystroke is comically wasteful and visibly bad. The renderer needs to emit the bytes for the ~1 cell that actually changed.

3. **Naive diff is also wasteful.** Even per-cell diffing produces too many bytes if done naively: every cell change emits a cursor-move + SGR + character + SGR-reset. For a row of consecutive changes that's 4× the bytes it needs to be. The renderer needs to _coalesce_ — when adjacent cells change, batch them; when style is the same as the last cell emitted, skip the SGR; when the cursor is already where you want it, skip the move.

4. **Tearing.** Even with damage tracking, if the terminal redraws mid-update, you see a half-rendered frame. Synchronized Output (DEC 2026) solves this — wrap each frame in `enter`/`exit` synchronized output, and conformant terminals show the frame atomically.

These four problems compose into a single design: a buffer that tracks width per cell, a renderer that compares two buffers and emits a minimized byte stream, all wrapped in synchronized-output discipline.

## The width-aware `Buffer`

> [!note] Ratatui References
>
> - `Buffer` (`ratatui-core/src/buffer/buffer.rs`, line 67) is a flat `Vec<Cell>` keyed by `row * width + col` over a `Rect` area — the same layout choice Tessera bakes into its design. `set_stringn` (line 336) iterates graphemes via `unicode_segmentation`, advances by each grapheme's `cell_width()`, and resets trailing cells for multi-width graphemes (line 356) — the "continuation cell" pattern Tessera makes explicit with `.continuation`.
> - `Cell` (`ratatui-core/src/buffer/cell.rs`, line 37) stores `symbol: Option<CompactString>` (a grapheme cluster), `fg`, `bg`, `modifier`, and `diff_option`. Ratatui resets trailing cells to `Cell::EMPTY` (blank + Reset style) rather than using a dedicated continuation enum case — Tessera's `.continuation` variant is a stricter invariant that the type system enforces.
> - `CellWidth` trait (`ratatui-core/src/buffer/cell_width.rs`, line 19) computes display width via `unicode-width` with a correction for halfwidth katakana dakuten/handakuten (U+FF9E/U+FF9F) — Ratatui's answer to the "width is not 1" problem. Tessera uses `swift-displaywidth` for the same purpose.
> - `StyledGrapheme` (`ratatui-core/src/text/grapheme.rs`, line 12) pairs a `&str` symbol with a `Style` — Ratatui's intermediate representation between text and buffer, analogous to Tessera's `Cell.Content.grapheme(String)` + `Style`.

Building on Phase 1's minimal `Buffer`, we add width awareness at the _cell_ level, not the buffer level.

```swift
public enum CellDiffPolicy: Sendable, Equatable {
    /// Normal cell: diff by equality and emit when changed.
    case normal

    /// Foreign/opaque cell: skip during ordinary diffing because something outside
    /// Tessera's grapheme model owns this screen region.
    case opaque

    /// Emit even when equal to the previous buffer. Use to reclaim or refresh regions
    /// that may have been affected by raw terminal payloads or external drawing.
    case alwaysRepaint
}

public struct Cell: Sendable, Equatable {
    public enum Content: Sendable, Equatable {
        case grapheme(String)       // 1- or 2-cell-wide grapheme cluster
        case raw(RawTerminalPayload) // bytes Tessera does not semantically model
        case continuation           // right half of a wide grapheme/raw region
        case blank                  // empty cell, no styling baggage
    }

    public var content: Content
    public var style: Style
    public var diffPolicy: CellDiffPolicy

    public init(
        content: Content = .blank,
        style: Style = Style(),
        diffPolicy: CellDiffPolicy = .normal
    )

    public var width: Int {
        switch content {
        case .grapheme(let g): return g.terminalWidth  // from swift-displaywidth
        case .raw(let payload): return payload.declaredWidth ?? 0
        case .continuation: return 0                   // not "1" — it's a phantom
        case .blank: return 1
        }
    }
}
```

A few design choices worth pinning down:

- **A wide character occupies two cells, not one.** Cell `[r, c]` holds the grapheme; cell `[r, c+1]` holds `.continuation`. This makes width a _property of the grid_, not just of the data — which is correct, because the terminal _does_ allocate two display columns for it.
- **Continuation cells are first-class.** Reading `[r, c+1]` doesn't error and doesn't lie; it tells you "this column is the right half of the grapheme at column c." Renderer logic depends on this.
- **`Content.grapheme` holds a `String`, not a `Character`.** Swift's `Character` is a grapheme cluster _as defined by Swift's Unicode tables_, which doesn't always match the terminal's notion of "one printable unit." Storing the raw grapheme `String` (e.g., `"👨‍👩‍👧"` as a 5-scalar ZWJ sequence) preserves what we got. The encoder writes whatever bytes UTF-8 produces.
- **`Content.raw` is the compatibility escape hatch, not the normal path.** It anchors raw bytes in the grid so the renderer can emit them at a known cursor position and pair them with `diffPolicy`. First-class Tessera features should graduate to semantic content or control-sequence cases.
- **Width is computed, not stored.** Recomputing on access is cheap and avoids "what if `style` changes but `width` doesn't update" bugs. `swift-displaywidth` is built for this and is one of the spec's load-bearing dependencies. Raw payload width comes from an explicit declaration because byte length and display width are unrelated.

The buffer mutation API gets one new responsibility: maintaining the cell/continuation invariant.

```swift
public extension Buffer {
    /// Writes a string starting at `point`, advancing by each grapheme's width.
    /// Wide graphemes write both the grapheme cell and the continuation cell.
    /// Writes past the right edge are clipped at the row boundary (no wrap).
    public mutating func write(_ string: String, at position: TerminalPosition, style: Style)

    /// Writes a single grapheme at `point`, returning the next column.
    /// Returns `nil` if the grapheme doesn't fit.
    public mutating func write(
        grapheme: String,
        at position: TerminalPosition,
        style: Style
    ) -> Int?

    /// Anchors raw terminal bytes at `position` and marks `occupied` as foreign to normal
    /// diffing. The anchor cell stores `.raw(payload)`; the remaining occupied cells are
    /// `.continuation`/`.blank` with `.opaque` policy.
    public mutating func writeRaw(
        _ payload: RawTerminalPayload,
        at position: TerminalPosition,
        occupying occupied: Rect,
        repaintPolicy: CellDiffPolicy = .alwaysRepaint
    )

    /// Marks a region as foreign without emitting bytes in this buffer. Useful when an
    /// app-level subsystem drew an image or protocol payload through `writeRaw` and wants
    /// Tessera to leave the covered cells alone until explicitly reclaimed.
    public mutating func markOpaque(_ region: Rect)
}
```

The "no wrap" behavior is deliberate. The view layer (Phase 4) handles wrapping as a layout concern; the buffer is a _grid_, and grids don't wrap, they clip. Decoupling the two means `HStack` and `VStack` can do their work without fighting the buffer.

### The edge cases that will bite you

> [!note] Ratatui References
>
> - `Buffer::set_stringn` (`ratatui-core/src/buffer/buffer.rs`, line 336) handles clipping at the row boundary by checking `remaining_width` before each grapheme (line 348) — wide graphemes that don't fit are silently dropped. The orphan rule is implicit: trailing cells of a previous wide grapheme are `Cell::EMPTY` (reset by `set_stringn`, line 356), so overwriting half a wide grapheme leaves the other half as blank — which is correct, but not enforced by the type system the way Tessera's `.continuation` is.

These are worth pinning down in the spec because they're where bugs hide:

1. **Writing a wide grapheme at the last column.** No room for the continuation cell. The cell stays as it was; the write reports clipping. Don't write half a grapheme.

2. **Overwriting one half of an existing wide grapheme.** If `[r, 5]` is a wide grapheme with continuation at `[r, 6]`, and you write a normal character at `[r, 6]`, what happens to `[r, 5]`? Answer: `[r, 5]` becomes `.blank`. You can't leave a half-grapheme; that's incoherent. This is the "orphan" rule and it applies symmetrically: writing to `[r, 5]` orphans `[r, 6]` if it was a continuation.

3. **Combining marks.** "é" can be one scalar (U+00E9) or two ("e" + U+0301). Swift's grapheme clustering merges these, so `string.unicodeScalars` may have multiple scalars per `Character`. We rely on this — `Content.grapheme` stores the whole cluster as a `String`, and the terminal handles rendering. We do _not_ try to apply combining marks to a cell that already has content.

4. **Zero-width characters in isolation.** A bare ZWJ or variation selector with no base character is technically a grapheme of width 0. Treat as blank; don't put a width-0 grapheme in a cell. (`swift-displaywidth`'s API will tell you the width; we trust it.)

5. **Control characters.** Anything below 0x20 except possibly tab — the buffer doesn't store them. Writes silently drop. Document this clearly: the buffer is for _displayable_ content; control sequences are the encoder's job.

## The damage-tracking renderer

> [!note] Ratatui References
>
> - `Terminal` (`ratatui-core/src/terminal.rs`, line 398) maintains a double-buffered pair of `Buffer`s. `flush()` (`ratatui-core/src/terminal/buffers.rs`, line 97) runs `diff_iter` and passes the resulting iterator to `Backend::draw()`. `swap_buffers()` (line 121) resets the inactive buffer — the same invalidate-and-redraw discipline Tessera's `Renderer.invalidate()` implements.
> - `Backend::draw()` (`ratatui-core/src/backend.rs`, line 166) takes an iterator of `(u16, u16, &'a Cell)` triples — the backend receives exactly the changed cells, not a full buffer. In Ratatui the concrete backend (crossterm, termion) is responsible for cursor moves, SGR emission, and character output; in Tessera this logic lives in the `Renderer` itself since there is no separate backend abstraction.

The renderer's job: given a previous `Buffer` and a current `Buffer`, emit the minimum bytes that transform the terminal's display from the previous state to the current one.

```swift
/// The damage-tracking diff engine. Deliberately NOT an actor: it is a synchronous,
/// non-Sendable value owned by the TerminalSession actor, which already serializes
/// draws. Making it an actor would buy no additional safety and cost an actor hop
/// per frame; as a plain mutable value it is also trivially testable
/// (buffers in, bytes out — no mocks, no async).
package struct Renderer {
    package init()

    /// Encodes the minimal bytes that transform the terminal from `previous` to
    /// `current`, updating internal SGR/cursor/raw state. Pure with respect to IO.
    /// `previous == nil` means the screen is unknown: erase, then full repaint.
    package mutating func encodeFrame(
        previous: Buffer?,
        current: Buffer,
        wrapInSynchronizedOutput: Bool,
        into bytes: inout [UInt8]
    )

    /// Discards cached terminal assumptions (SGR state, cursor belief) and arms a
    /// pending erase so the next frame repaints conservatively. The session's
    /// invalidateRenderer() additionally clears its own lastDrawnBuffer. Used after
    /// resize, after alt-screen reentry, or on demand.
    package mutating func invalidate()
}

extension TerminalSession {
    /// Opens one render transaction. The borrowed frame cannot be stored, returned,
    /// or captured by an escaping task. The session runs the body over the back
    /// buffer, asks the renderer to encode the diff, writes through PlatformIO, and
    /// flushes once.
    public func draw<R>(
        _ body: (borrowing Frame) throws -> sending R
    ) async throws -> sending R

    /// Invalidates the renderer so the next draw repaints from scratch.
    public func invalidateRenderer()
}

public struct Frame: ~Copyable, ~Escapable {
    public var size: TerminalSize { get }  // accessors on a ~Escapable type borrow implicitly
    public borrowing func write(_ string: String, at position: TerminalPosition, style: Style)
    public borrowing func writeRaw(
        _ payload: RawTerminalPayload,
        at position: TerminalPosition,
        occupying occupied: Rect,
        repaintPolicy: CellDiffPolicy = .alwaysRepaint
    )
    public borrowing func markOpaque(_ region: Rect)
}
```

Note what `Frame` does **not** have: a `render(_ view:)` method. `TesseraTerminal` must never know the `View` protocol — that would invert the package's dependency direction. The Phase 4 view layer renders _into_ a frame (its `RenderRegion` wraps the frame's buffer); the frame stays a dumb write surface. Likewise the `Renderer` diff engine is package-internal; the only public rendering entry point is `TerminalSession.draw`. `Rect` (used by `writeRaw`/`markOpaque`) lands in `TesseraTerminalCore` in this slice; Phase 4's Geometry section gives its full definition.

The render body is intentionally synchronous. `draw` may suspend to enter the session actor, but the borrowed-frame closure itself is not `async`. It batches related frame mutations in one actor job and avoids actor-reentrancy windows while a borrowed frame is live. Async work updates app state and requests display/layout invalidation before or after a render transaction; it does not happen while holding `Frame`.

These operations should be impossible:

```swift
let leaked = try await session.draw { frame in frame }        // cannot return frame
try await session.draw { frame in Task { frame } }            // cannot escape frame
struct Stored { let frame: Frame }                            // cannot store frame
```

`writeRaw` is intentionally inside the borrowed frame capability. It lets advanced users emit bytes Tessera does not understand, but it preserves render serialization, teardown, snapshot visibility, and damage-tracking policy. It is not equivalent to exposing `PlatformIO.write`.

State is split by who can guarantee it:

- The last-drawn buffer (`Buffer?` — `nil` triggers erase + full repaint) is owned by `TerminalSession`, which passes it as `previous` and commits `lastDrawnBuffer = current` only after write and flush both succeed. Ownership lives with the session because only the session knows whether the frame actually reached the terminal.
- The currently active `Style` on the terminal (so we know whether SGR needs re-emitting) is renderer-internal.
- The currently believed cursor position (so we know whether `cursorPosition` needs emitting) is renderer-internal, along with a pending-erase flag set by `invalidate()`.

### The diff algorithm

> [!note] Ratatui References
>
> - `BufferDiff` (`ratatui-core/src/buffer/diff.rs`, line 10) is a zero-allocation iterator that yields `(x, y, &Cell)` for changed cells. It handles multi-width skip (line 78), VS16 trailing-cell explicit clears (line 88), and `CellDiffOption` directives — the same row-by-row, multi-width-aware diff strategy Tessera describes in its pseudocode.
> - `CellDiffOption` (`ratatui-core/src/buffer/cell.rs`, line 12) provides `Skip`, `AlwaysUpdate`, and `ForcedWidth` — Ratatui's mechanism for telling the diff iterator how to treat cells covered by escape sequences (images, links). `ForcedWidth` is how Ratatui handles wide-grapheme trailing cells during diffing without a continuation enum.

Row-by-row, with run coalescing. Pseudocode:

```text
for each row r:
    if rows are equal and no cells are .alwaysRepaint: skip
    find the first column c0 where cells differ or policy forces repaint
    find the last column c1 where cells differ or policy forces repaint
    emit cursor-position(r, c0)
    for each column c in c0...c1:
        if cell.diffPolicy == .opaque: continue
        if cell(r, c).style != currentTerminalStyle:
            emit SGR delta to reach cell.style
            currentTerminalStyle = cell.style
        emit bytes for cell.content
        (raw cells: emit RawTerminalPayload bytes)
        (continuation cells: emit nothing — the previous grapheme/raw payload owns them)
```

Properties of this approach:

- **One cursor move per dirty row** instead of per dirty cell.
- **SGR is only emitted when style changes**, so a row of cells in the same style emits a single SGR up front and then just text.
- **Continuation cells emit nothing** — they're not "drawn," they're consumed by the wide grapheme or raw payload to their left.
- **Opaque cells are deliberately skipped.** This is the opt-in contract that lets raw protocols own a region without Tessera immediately repainting over them.
- **Always-repaint cells pierce equality.** This lets Tessera reclaim areas touched by raw protocols or external drawing even when the structural buffer value looks unchanged.
- **Equal rows skip entirely** unless a forced-repaint policy is present. For a screen where one row changes per frame (e.g., a status line update), one row's worth of work happens; everything else is a row-comparison and a skip.

This is roughly the algorithm Ratatui uses, extended with Tessera's explicit raw-payload and opaque-region policy.

### SGR delta emission

> [!note] Ratatui References
>
> - `Style` (`ratatui-core/src/style.rs`, line 239) is an incremental style with `fg`, `bg`, `add_modifier`, and `sub_modifier` fields — styles compose via patch, not replace. `Modifier` (line 104) is a bitflag enum (BOLD, DIM, ITALIC, UNDERLINED, SLOW_BLINK, RAPID_BLINK, REVERSED, HIDDEN, CROSSED_OUT). This matches Tessera's SGR delta approach where only changed attributes are emitted.

The naive approach is "if styles differ, reset and re-set everything." Better: emit only the SGR codes for the attributes that actually changed. Concretely:

```swift
package func sgrDelta(from old: Style, to new: Style, into bytes: inout [UInt8]) {
    // If the new style strictly *adds* attributes, emit just the additions.
    // If anything was *removed*, emit reset (SGR 0) then full new style.
    // This is the right tradeoff: removal is rare, reset+set is short anyway.
}
```

For the first frame and after `Renderer.invalidate()`, the "previous style" is `nil` and we emit a reset followed by the full style. This handles startup correctly without special-casing.

There's a subtle invariant: **after `draw` returns, the terminal's SGR state must match a known value, and the renderer must remember that value.** If you let the terminal end a frame in arbitrary SGR state, the next frame's delta computation breaks. The standard discipline: end every frame with `resetAttributes` and remember "current style is the default." Costs a few bytes per frame; eliminates a whole class of bugs.

### Cursor positioning optimization

> [!note] Ratatui References
>
> - `Terminal` tracks `last_known_cursor_pos` (`ratatui-core/src/terminal.rs`, line 434) as a best-effort record of where it last wrote. `flush()` (`ratatui-core/src/terminal/buffers.rs`, line 104) updates it from the last diffed cell. Ratatui doesn't use this to skip cursor moves during diff emission — that optimization lives in the backend's `draw()` implementation, not in the diff layer.

After emitting the bytes for cell `[r, c]`, the terminal cursor is at `[r, c+width]`. If the next cell to emit is exactly there, no cursor-position emission is needed. The renderer tracks "believed cursor position" and only emits `cursorPosition` when it doesn't match the next write target.

In practice this matters most for the "first dirty cell in a row" — if the previous row's last write left the cursor at the start of the next row, you may not need a cursor move. Modest byte savings, but free if you're already tracking position.

### Frame-driven cursor visibility

The application cursor is frame-local render intent, not a global app flag. A frame hides the cursor by default; if a widget needs an insertion point, it requests one for that frame:

```swift
try await terminal.draw { frame in
    frame.write(text, at: fieldOrigin)
    frame.setCursorPosition(cursorPosition)
}
```

After the buffer diff is encoded, Tessera applies cursor state:

- no requested cursor position → emit `cursorVisible(false)`
- requested cursor position → emit `cursorVisible(true)` and `cursorPosition(position)`

This mirrors Ratatui's `Frame::set_cursor_position` model: most TUI screens never show the terminal cursor, while focused text-input widgets opt in every frame. Direct session-level show/hide APIs are lower-level escape hatches and should not be mixed with frame-driven cursor control. Normal and emergency teardown must emit `cursorVisible(true)` so a hidden cursor never leaks out of the scoped terminal session.

### Synchronized Output wrapping

> [!note] Ratatui References
>
> - Synchronized Output (DEC 2026) is not implemented in Ratatui — no `enter_sync`/`exit_sync` methods exist on any backend. Tessera supporting it is a design decision without a Ratatui precedent.

When synchronized output is enabled by session policy, every frame is wrapped:

```text
enter synchronized output
... diff bytes ...
exit synchronized output
```

Policy notes:

- **Phase 2 may use an optimistic default**, because unsupported DEC private modes are generally ignored by terminals that do not implement them. Keep this configurable so a user can disable sync output in a problematic environment.
- **Phase 3 capability detection can refine the default** to enabled/detected, enabled/assumed, or disabled by user policy. The renderer should ask session policy rather than hardcoding unconditional wrapping.
- **If wrapping is enabled, emit it even when no cells changed.** A "no-op" frame should still bracket itself; that's how terminals with synchronized output learn "the previous frame ended." Sending just `enter; exit` is a few bytes and harmless.
- **If wrapping is disabled or unavailable, rendering still works.** It may flicker more, but startup and drawing must not fail because DEC 2026 is unavailable.

## Resize handling

> [!note] Ratatui References
>
> - `Terminal::resize()` (`ratatui-core/src/terminal/resize.rs`, line 23) updates buffer sizes, clears the viewport, and resets the previous buffer so the next draw is a full repaint — matching Tessera's "discard last-drawn buffer" discipline. `autoresize()` (line 64) checks the backend size during every render pass and calls `resize()` when it changes.
> - `Terminal::clear()` (`ratatui-core/src/terminal/buffers.rs`, line 136) emits `ClearType::All` for fullscreen viewports — the same "eraseInDisplay(.all)" Tessera emits after resize.

When `PlatformIO.sizeChanges` yields a new size, the renderer needs to:

1. Discard its last-drawn buffer (next frame is a full repaint).
2. The view layer (Phase 4) re-lays out at the new size and produces a new buffer.
3. The renderer draws it fresh.

For slice 4 — pre-view-layer — resize just invalidates the renderer; the example app is responsible for noticing and producing a new buffer of the new size. This is awkward and that's fine; Phase 4 makes it elegant.

One sharp edge: **after resize, the terminal's screen may contain garbage from the old size.** The renderer's first post-resize frame should emit `eraseInDisplay(.all)` before drawing. Build this into `Renderer.invalidate()` — invalidating renderer state means "assume the screen is unknown, paint everything, including erasing first."

## Testing strategy for the renderer

This is where slice 1's snapshot harness shines. Every renderer change ships with a snapshot test of the form: "given previous buffer X and current buffer Y, the renderer emits bytes B; feeding B to `VirtualTerminal` (starting in state matching X) produces a terminal state matching Y." End-to-end correctness, automated.

Plus targeted unit tests:

- **Pure diff tests.** Two buffers in, byte sequence out, golden fixture. Catches the "wrong bytes" case directly.
- **Equal-row skip test.** Two identical rows produce no bytes for that row.
- **SGR delta tests.** Style A → Style B emits the expected minimal SGR.
- **Cursor optimization tests.** Two consecutive cells in the same row don't emit an intermediate cursor move.
- **Wide-grapheme tests.** Writing "你好" produces a buffer with cells laid out correctly (grapheme, continuation, grapheme, continuation), and the rendered bytes are what we expect.
- **Orphan-rule tests.** Overwriting half a wide grapheme blanks the other half; rendered bytes reflect this.
- **Invalidate test.** After `Renderer.invalidate()`, next frame is a full repaint including erase.
- **Raw payload tests.** A raw payload emits exactly at its anchor position; opaque cells are skipped by normal diffing; always-repaint cells emit even when equal; reclaiming an opaque region with normal text repaints the covered cells.
- **Synchronized-output policy tests.** Enabled policy brackets frames; disabled policy emits no DEC 2026 bytes; no-op frames bracket only when the policy says they should.

Roughly 30-40 tests for slice 4, weighted toward the snapshot end. The library's reliability rests on these.

## Performance posture

> [!note] Ratatui References
>
> - `Buffer` stores cells as a flat `Vec<Cell>` (`ratatui-core/src/buffer/buffer.rs`, line 73) indexed by `row * width + col` — the same cache-friendly layout Tessera chooses. `CellWidth` (`ratatui-core/src/buffer/cell_width.rs`, line 19) computes width on access from the stored symbol string, matching Tessera's "width is computed, not stored" principle.

For Phase 2, the target is "good enough that you can't see the difference." Concretely:

- 200×60 cell buffer, one cell changed per frame: well under 1 KB of bytes emitted, well under 1 ms of renderer work. Easy.
- 200×60 cell buffer, full repaint: ~30-50 KB of bytes, a few ms. Acceptable; only happens on resize/invalidate.
- 200×60 cell buffer, ~10% cells changed (e.g., scrolling a log view): a few KB, well under 1 ms. Easy.

We're not benchmarking yet — that's Phase 5 polish work. But the design should not preclude future perf work. The two things that _would_ preclude it: storing the buffer as a 2D Array of Arrays (cache-hostile) and recomputing widths on every comparison (wasted CPU). Counter-decisions baked into the design: flat `[Cell]` indexed as `row * cols + col`, and width as a cheap computed property over already-stored grapheme strings.

## Definition of done for slice 4

1. `Cell` redesigned with `Content` enum (`grapheme`/`raw`/`continuation`/`blank`), `CellDiffPolicy`, and computed `width`.
2. `Buffer.write(_:at:style:)` correctly handles wide graphemes, continuation cells, the orphan rule, and clipping at row boundaries.
3. `Buffer.writeRaw` and `markOpaque` correctly anchor raw payloads, mark occupied regions, and allow normal content to reclaim those regions later.
4. `swift-displaywidth` added as a dependency and used for all normal grapheme width queries.
5. `Renderer` as a synchronous package struct owned by `TerminalSession`, with `encodeFrame`, `invalidate()`, internal SGR/cursor/raw state tracking, row-by-row diff with run coalescing, and policy-controlled synchronized output wrapping. `TerminalSession.draw {}` is the public scoped transaction over it.
6. The session integrates renderer output with `PlatformIO`: buffered writes per frame, one `flush` at end of frame.
7. Phase 1 walking skeleton is updated to use the real renderer. Visible result: no more flicker; typing feels instant.
8. ~30-40 tests covering: width handling, orphan rule, diff correctness, SGR minimization, cursor optimization, raw payload/opaque-region behavior, synchronized-output policy, invalidate behavior. Mix of unit tests and snapshot tests through `VirtualTerminal`.
9. The resilience story still holds: a `kill -INT` during a render leaves the terminal sane (verified manually), via the in-process emergency handler, with documented per-platform recovery as the last-resort fallback.

## What's not in this slice

- **Scrollback handling.** The renderer assumes alt screen, where scrollback doesn't apply. Inline (non-alt-screen) rendering is a separate concern for Phase 5+.
- **Partial repaints triggered by view changes.** Slice 4 diffs whole buffers. The view layer in Phase 4 may eventually want to _invalidate regions_ for efficiency, but for now the diff is the optimization.
- **Hardware scrolling.** Some renderers detect "row 5 is now what row 4 used to be" and emit scroll-region commands instead of redrawing. We don't. The complexity isn't worth it for TUI apps, which rarely scroll-shift the whole screen.
- **Reflow on resize.** The renderer just invalidates and asks for a new buffer. The view layer handles re-layout.
- **Full capability-aware color quantization.** The encoder remains pure and will emit the color it is asked to emit. Phase 3 slice 6 owns the policy seam that resolves app colors through `NO_COLOR`, environment hints, and user configuration before encoding.

## Four things to flag

1. **The `Cell.Content` design with `.continuation` as a first-class case** is the most architecturally consequential decision in slice 4. The alternative — storing wide graphemes "spanning" two cells via some marker on the right cell — is what some libraries do, and it ends up being more error-prone. Making continuation an enum case means the type system forces you to handle it explicitly, which is exactly what you want for a tricky invariant.

2. **Synchronized output belongs behind policy, not hidden renderer behavior.** An optimistic default is reasonable in Phase 2, but the renderer should ask session policy whether to wrap a frame so Phase 3 capability detection and user configuration can turn DEC 2026 on or off without rewriting the diff algorithm.

3. **The raw payload escape hatch must stay scoped.** If raw bytes start appearing as ad-hoc strings in view code, lifecycle code, or tests, the design has failed. Raw payloads are anchored in frames, paired with opaque/repaint policy, and covered by virtual-terminal tests.

4. **The renderer is deliberately NOT an actor.** The actor census in `TesseraTerminal` is `TerminalSession`, `ModeLifecycle`, and `PlatformIO` — each guarding genuinely shared mutable state (the live terminal, mode state, file descriptors). The diff engine guards nothing shared: it is only ever touched by the session actor that owns it, so making it a fourth actor would add an actor hop per frame and an async seam in tests while buying zero safety. Keeping it a synchronous `package struct` makes the core renderer property — two buffers in, minimal bytes out — testable as a pure function. If you ever feel pressure to make it an actor, that is a sign something other than the session has acquired a reference to it, which is the actual bug.

---
