---
kind: primitive
status: ready
---

# Readable width

Readable width keeps prose to a comfortable line length on wide terminals. It is two
pieces (owner decision, 2026-10-18): an environment value, `readableWidth`, measured in
cells (default 72, settable per subtree), and a stateless layout modifier,
`.readableWidth()`, that is a maximum width only. It behaves exactly like
`.frame(maxWidth: readableWidth)` with the value read from the environment (owner
decision, 2026-10-18). Above the readable width the view is capped and its parent places
it with the parent's normal alignment; at or below it the modifier has no effect. It does
not fill the proposal and does not position its child. It is a SwiftUI-style analogue of
UIKit's `readableContentGuide`. It draws nothing, holds no state, and has no focus,
bindings, or input handling.

```swift
extension EnvironmentValues {
    public var readableWidth: Int { get set }   // cells; default 72
}

extension View {
    public func readableWidth() -> some View    // same as .frame(maxWidth: readableWidth)
}

// Per subtree:
content.environment(\.readableWidth, 60)
```

ContentUnavailableView applies `.readableWidth()` to its content column and Markdown to
its body prose by default; other components and apps opt in (owner decision, 2026-10-18).
ProgressView reads the environment value directly: its nil-width ideal is the readable
width.

## Prior art

- UIKit
  [`readableContentGuide`](https://developer.apple.com/documentation/uikit/uiview/readablecontentguide)
  — copy the idea of a readable measure that caps a text column's width. Reject its
  font-size-dependent width, its layout-guide object, and its built-in centring: Tessera
  measures in cells, expresses the cap as a modifier, and leaves placement to the parent.
- SwiftUI `.frame(maxWidth:)` — copy it exactly: the modifier is that frame with the
  readable width as its maximum. Centring a capped view is the parent's job, as in
  SwiftUI.
- Tessera [Frame](frame.md) — copy its max-only rule: a finite capped proposal is
  forwarded (even when the incoming proposal is nil), a smaller child is not stretched,
  and the frame reports the child's width.
- omp2 has no readable-width modifier. The nearest is the `max` width attribute
  ([vocab/lib.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L37-L38)),
  a per-component cap that the [translation key](../translation-key.md#b-attributes) maps
  to `.frame(maxWidth:)` (key B2). Readable width is that frame with its cap read from the
  environment, the key's form for presentation that cascades to descendants (key B1).

## Anatomy

A leading-aligned `VStack(spacing: 1)` holds a heading and a 263-cell paragraph `p`.
`.readableWidth()` is applied once, to the stack, and the stack sits in
`.frame(width: 100, alignment: .top)`, which centres it horizontally. The stack is
proposed at most 72 cells, the paragraph wraps at 72, and the stack reports 71 cells, its
widest row. The outer frame, not the modifier, places the capped stack in the 100 cells,
so heading and paragraph share one left edge.

```wireframe 100x6
              Readable width

              Readable width keeps long lines of prose to a comfortable measure. On a
              wide terminal the text stops at seventy-two cells, and the parent
              decides where the capped block sits, so a centred layout spares the eye
              a trip across the whole screen to find the next line.
```

```text
Callouts (100x6, 0-based):
1. r0-r5 c0-c13   Leading slack -- the outer Frame's slack, `floor((100 - 71) / 2)` cells;
                  not part of the modifier's size
2. r0-r5 c14-c84  Capped view -- the stack after `.readableWidth()`: proposed
                  `min(100, readableWidth)` = 72 cells, reports its 71-cell widest row
3. r0 c14-c27     Heading -- Text in the stack; content, wraps
4. r2-r5 c14-c84  Paragraph -- Text in the stack, wrapped at 72 cells; content, wraps
5. r0-r5 c85-c99  Trailing slack -- the outer Frame's remaining slack, 15 cells
```

Applying `.readableWidth()` to each child instead would cap each one separately, and a
centring parent would then centre each child on its own width, so their left edges would
differ. A shared left edge comes from capping one leading-aligned container.

## Variants

| Configuration                      | Behavior                                                                                                                       |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `.readableWidth()`                 | `.frame(maxWidth: readableWidth)` with the environment's value: caps the child's width proposal and reports the child's width. |
| `.environment(\.readableWidth, n)` | Sets the cap for a subtree; nearest ancestor wins, and nested `.readableWidth()` modifiers in that subtree all use `n`.        |
| `readableWidth` below 1            | Rejected: the modifier traps before layout, like Frame's invalid bounds.                                                       |

Behavior, in cells throughout:

- **Cap:** the child is proposed `min(W, readableWidth)` for a finite width proposal `W`,
  and `readableWidth` for a nil width (Frame's max-only rule never forwards an
  unconstrained proposal). A wide grapheme counts two cells, so a CJK paragraph gets 36
  characters a row at the default.
- **Size:** the modifier reports the child's width, never more than the cap. It does not
  fill the proposal: a short child stays short.
- **Placement:** none. The parent places the capped view with its normal alignment; a
  centred stack or a `.top`/`.center` frame centres it, a leading stack keeps it at the
  left edge.
- **At or below the cap:** a proposal of `readableWidth` cells or fewer reaches the child
  unchanged, so the modifier has no effect.
- **Height:** the height proposal passes through unchanged and the modifier reports the
  child's height. It never adds rows.
- **Nesting:** a nested `.readableWidth()` sees a proposal no wider than the outer cap, so
  it adds nothing unless a subtree sets a smaller value.

## Sizing

Schema: [README](../../design.md#sizing-table). `p` is the 263-cell paragraph from
Anatomy; the default `readableWidth` is 72 unless a row says otherwise.

| Configuration and proposal                                                    | Result | Rule                                                                                                                |
| ----------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------- |
| `Text(p).readableWidth()`, nil x nil                                          | 71x4   | A nil width proposes the 72-cell readable width; the paragraph wraps at 72 and reports its widest row.              |
| `Text(p).readableWidth()`, 72xnil                                             | 71x4   | Tight: a proposal equal to the cap reaches the child unchanged; the modifier has no effect.                         |
| `Text(p).readableWidth()`, 40xnil                                             | 40x7   | Under the cap: the 40-cell proposal reaches the child unchanged and the paragraph wraps at 40.                      |
| `Text(p).readableWidth()`, 100xnil                                            | 71x4   | Over the cap: the child is proposed 72 cells; the modifier reports 71 and does not fill the 100.                    |
| `Text(p).readableWidth().frame(width: 100, alignment: .top)`, 100xnil         | 100x4  | The outer Frame, not the modifier, centres the 71-cell view at c14-c84; odd slack gives the trailing side 15 cells. |
| `Text("Hi").readableWidth()`, 100xnil                                         | 2x1    | A child narrower than the cap is not stretched.                                                                     |
| `Text(p).readableWidth()`, 100x2                                              | 72x2   | The height passes through as a two-row budget; the last visible row is cut to 72 cells and ends in the mark.        |
| `Text(p).readableWidth()`, 200x50                                             | 71x4   | Extra height never stretches the child, and extra width is the parent's space.                                      |
| `Text(p).readableWidth()`, 0xnil                                              | 0x1    | A zero width reaches the child unchanged; the child reports what a zero width gives it.                             |
| `.environment(\.readableWidth, 40)` above, `Text(p).readableWidth()`, 100xnil | 40x7   | The subtree's 40-cell value caps the proposal at 40.                                                                |

## Environment

Readable width consumes no token. It reads one environment value, `readableWidth` (`Int`,
cells, default 72), which apps set per subtree with `.environment(\.readableWidth, n)`.
Consumers that size themselves from the value without the modifier (ProgressView's
nil-width ideal) read the same value, so one override moves every cap in the subtree.

## Requirements

- `readable width caps a wide proposal and reports the child's width` (sizing:
  `Text(p).readableWidth()`, 100xnil).
- `readable width never fills the proposal or stretches a short child` (sizing:
  `Text(p).readableWidth()`, 100xnil and `Text("Hi").readableWidth()`, 100xnil).
- `the parent places a capped view with its own alignment` (anatomy: Capped view; sizing:
  `Text(p).readableWidth().frame(width: 100, alignment: .top)`, 100xnil).
- `one cap on a leading container gives its children a shared left edge` (anatomy: Heading
  and Paragraph).
- `readable width has no effect at or below the cap` (sizing: `Text(p).readableWidth()`,
  72xnil and 40xnil).
- `a nil width proposes the readable width` (sizing: `Text(p).readableWidth()`, nil x
  nil).
- `readable width passes the height proposal through unchanged` (sizing:
  `Text(p).readableWidth()`, 100x2 and 200x50).
- `a subtree readable width overrides the default` (variants:
  `.environment(\.readableWidth, n)`; sizing: `.environment(\.readableWidth, 40)` above).
- `readable width counts cells not characters` (Variants: cap).
- `readable width below one traps before layout` (variants: `readableWidth` below 1).
- `zero-width proposal reaches the child unchanged` (sizing: `Text(p).readableWidth()`,
  0xnil).

## Degradation

Readable width draws no glyphs and consumes no style or terminal capability. Its integer
sizing is unchanged in ASCII-only, 16-color, and `NO_COLOR` modes. On a terminal narrower
than the readable width it has no effect.

## Decisions

- **Two pieces, one value (owner decision, 2026-10-18):** an environment value in cells,
  default 72, app-settable per subtree, and a modifier. ContentUnavailableView's content
  column and Markdown body prose apply it by default; ProgressView's nil-width ideal is
  the value (owner decision, 2026-10-18).
- **Maximum only (owner decision, 2026-10-18):** `.readableWidth()` is
  `.frame(maxWidth: readableWidth)`. It does not fill the proposal or place its child; the
  parent's alignment places the capped view, and a shared left edge comes from capping one
  leading-aligned container rather than each child.
- **Its own primitive, not a Frame overload:** the modifier reads the environment, which
  Frame does not. Its layout is Frame's max-only rule, so Frame's `ready` contract is
  unchanged.

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): the modifier is a value
description that reads `readableWidth` through the
[environment](../../spec/phase-4/slice-01-tesseracore.md#environment) and lowers to
Frame's max-only wrapper node, so `dump()` shows its capped proposal and size; the cap is
an app-set environment value, not state; and it touches no terminal capability.

## Inspiration

On a 120-column terminal, unbroken prose runs past the point where the eye can find the
next line. Typographers keep body text to about 45-75 characters a line; 72 cells sits at
the top of that range and matches the long-standing convention for plain-text email and
commit message bodies.
