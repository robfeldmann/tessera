---
kind: primitive
status: ready
---

# Text

`Text` is Tessera's stateless leaf for rendering an immutable `String` into its allocated
rectangle. It measures display-cell width at extended-grapheme-cluster boundaries,
preserves source line breaks, and writes top-leading into its `RenderRegion`. It has no
focus, binding, `NodeState`, key handling, pointer handling, scrolling, border, padding,
title, or alignment policy. Those concerns compose through layout, decoration, styling,
ScrollView, and widgets.

The accepted public direction is `Text(_ content: String)`. Text is a leaf
(`Body == Never`) and has no mutable business or ephemeral state. Its content, wrapping
mode, and truncation mode are immutable view configuration; callers replace the value and
reconcile the graph.

## Prior art

- Ratatui Paragraph: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/paragraph.rs` —
  copy grapheme-aware text rendering and explicit wrap policy. Reject combining text,
  alignment, scrolling, a surrounding Block, and widget-local style into Tessera's `Text`:
  they compose separately as layout, ScrollView, decoration, and style modifiers.
- Apple SwiftUI [Text](https://developer.apple.com/documentation/swiftui/text) — copy the
  immutable value-view model and composition with modifiers. Reject treating Text as an
  input control; editable text belongs to TextField.
- Tessera
  [Slice 1](../../docs/Spec.md#slice-1-tesseracore--view-viewgraph-reconciliation-text) —
  copy the leaf seam, top-leading `RenderRegion` rendering, and no-wrap initial delivery.
  Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration)
  supplies wrapping, truncation, style inheritance, and decoration composition.

## Anatomy

Natural single-line fixture:

```wireframe 14x1
Hello, Tessera
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13 Text content -- immutable source graphemes, rendered top-leading at their
   display-cell width with the resolved full Style.
```

Text measures terminal cells, not Unicode scalar count. Wide CJK and emoji-presentation
clusters occupy two cells; a combining sequence stays attached to its base and occupies
the base's width.

```wireframe 9x1
東京 👩🏽‍💻 é
```

```text
Callouts (9x1, 0-based):
1. r0 c0-c3 Wide text -- `東京` occupies four cells.
2. r0 c5-c6 Emoji cluster -- `👩🏽‍💻` is one extended grapheme cluster and occupies two cells.
3. r0 c8 Combining sequence -- `é` occupies one cell; the combining mark never gains a cell.
```

Source `\r\n` normalizes to one source newline at `Text` initialization; a lone `\r`
remains literal source content. Text does not invent line breaks while `.none` wrapping is
selected.

```wireframe 8x2
release
notes
```

```text
Callouts (8x2, 0-based):
1. r0-r1 c0-c6 Source rows -- the normalized newline separates two independently measured
   and rendered source lines; trailing cells remain untouched by Text.
```

### Constrained fixtures

At Slice 1, `.none` wrapping preserves ideal measurement and the final allocated
`RenderRegion` clips the visible suffix rather than wrapping it:

```wireframe 8x1
Ship one
```

```text
Callouts (8x1, 0-based):
1. r0 c0-c7 Unwrapped clip -- the assigned width is eight cells; the clipped suffix does
   not create a second row.
```

At Slice 3, `.word` wrapping uses a finite width proposal to reflow at word boundaries:

```wireframe 8x2
Ship one
thing
```

```text
Callouts (8x2, 0-based):
1. r0 c0-c7 First wrapped row -- the assigned width is eight cells.
2. r1 c0-c4 Wrapped continuation -- `.word` moves `thing` to the next row rather than
   breaking a word that fits intact.
```

Also at Slice 3, `.truncation(.tail)` makes overflow explicit without changing height:

```wireframe 8x1
release…
```

```text
Callouts (8x1, 0-based):
1. r0 c0-c7 Tail truncation -- `truncation.mark` replaces the invisible suffix at a
   grapheme-safe boundary.
```

## Variants

| Configuration                    | Earliest slice | Behavior                                                                                                               |
| -------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `.wrapped(.none)`                | Slice 1        | Default. Source newlines are preserved; no additional rows are invented; rendering clips at the allocated region edge. |
| `.wrapped(.word)`                | Slice 3        | Reflows at Unicode word boundaries for a finite width. A word wider than the region falls back to character wrapping.  |
| `.wrapped(.character)`           | Slice 3        | Reflows at extended-grapheme-cluster boundaries for a finite width. It never splits a grapheme cluster.                |
| `.truncation(.tail)`             | Slice 3        | Replaces the invisible suffix with `truncation.mark` at a grapheme-safe boundary.                                      |
| `.truncation(.head)` / `.middle` | Slice 3        | The public `TruncationMode` is `.clip`, `.tail`, `.head`, and `.middle`; each policy keeps whole grapheme clusters.    |

Wrapping and truncation are mutually resolved by the chosen layout policy: wrapping
controls how Text measures and produces rows; truncation applies when a rendered source or
wrapped row still exceeds its assigned rectangle. Text never changes its own height merely
to reveal a truncated suffix.

## Sizing

`.none` reports its intrinsic unwrapped extent even when a parent later assigns a smaller
rectangle; `RenderRegion` clipping is the final rendering boundary. Finite-width wrapping
instead uses that width to determine both result width and row count. Height proposals
never stretch Text or add blank content rows.

| Configuration and proposal               | Result | Rule                                                                                    |
| ---------------------------------------- | ------ | --------------------------------------------------------------------------------------- |
| `Text("Hello")`, nil x nil               | 5x1    | Ideal is the display width of the longest source line and the source line count.        |
| `Text("Hello")`, 5x1                     | 5x1    | Tight allocation preserves the natural single-line fixture.                             |
| `Text("Hello")`, 3x1, `.none`            | 5x1    | No-wrap measurement remains intrinsic; a parent-assigned 3-cell region clips rendering. |
| `Text("Hello")`, 80x24                   | 5x1    | Extra proposal does not stretch Text or create blank rows.                              |
| `Text("release\nnotes")`, nil x nil      | 7x2    | Width is the longest source row; height is the source row count.                        |
| `Text("a\r\nb")`, nil x nil              | 1x2    | Public initialization normalizes CRLF to two one-cell source rows.                      |
| `Text("Ship one thing")`, 8xnil, `.word` | 8x2    | Word wrapping uses the finite proposal and reports the reflowed rows.                   |
| `Text("東京")`, nil x nil                | 4x1    | Two wide graphemes each occupy two terminal cells.                                      |
| `Text("")`, nil x nil                    | 0x1    | Empty content occupies one source row but paints no cells.                              |

## Environment

| Input            | Text behavior                                                                                                                       |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| inherited Style  | `defaultStyle` arrives with Slice 3; nearest ancestor wins per attribute, then explicit Text attributes win.                        |
| shared modifiers | `.foreground`, `.background`, `.bold`, `.italic`, `.underline`, and `.style` are shared Slice 3 modifiers; Text has no private API. |
| background fill  | `background` fills Text's allocated rectangle while foreground and attributes apply only to written cells.                          |
| truncation mark  | `truncation.mark` supplies `…`; ASCII-only output substitutes `~`.                                                                  |

## Progressive slice sequence

1. **After Slice 1:** `Text` measures source lines by grapheme display width, renders
   top-leading through `RenderRegion`, preserves source newlines, and clips in its
   allocated region. It has no wrapping, truncation marker, inherited style API, focus, or
   input.
2. **After Slice 2:** Text composes with [linear stacks](stacks.md), [Frame](frame.md),
   [Padding](padding.md), alignment, and explicit allocated rectangles. Those wrappers own
   placement and insets; Text remains a leaf.
3. **After Slice 3:** Text gains wrapping, truncation, inherited full Styles, and
   decoration composition. Word and character wrapping, tail/head/middle truncation, and
   ASCII marker degradation become fixture-backed behavior.
4. **After Slice 4 and later:** Text remains noninteractive. TextField, List, Button, and
   other widgets compose Text labels/content while owning focus, bindings, and input.

## Input routing

Text installs no responder. These explicit no-op rows make the routing contract
fixture-testable without giving a leaf focus or state.

| Key                      | Precondition | Effect                                  | Consumed |
| ------------------------ | ------------ | --------------------------------------- | -------- |
| printable characters     | always       | installs no handler; dispatch continues | no       |
| Enter                    | always       | installs no handler; dispatch continues | no       |
| Up / Down / Left / Right | always       | installs no handler; dispatch continues | no       |

| Event      | Region       | Precondition | Effect                                  | Consumed |
| ---------- | ------------ | ------------ | --------------------------------------- | -------- |
| click      | Text content | always       | installs no handler; dispatch continues | no       |
| drag       | Text content | always       | installs no handler; dispatch continues | no       |
| wheel-up   | Text content | always       | installs no handler; dispatch continues | no       |
| wheel-down | Text content | always       | installs no handler; dispatch continues | no       |

## Requirements

- `text measures natural width in terminal display cells` (anatomy: Text content; sizing:
  `Text("Hello")`, nil x nil).
- `text measures wide emoji and combining graphemes without splitting clusters` (anatomy:
  Wide text, Emoji cluster, and Combining sequence).
- `text preserves normalized source newline rows` (anatomy: Source rows; sizing:
  `Text("a\r\nb")`, nil x nil).
- `unwrapped text reports intrinsic size and clips in a constrained region` (anatomy:
  Unwrapped clip; sizing: `Text("Hello")`, 3x1, `.none`).
- `word-wrapped text reflows at a finite proposal` (anatomy: First wrapped row and Wrapped
  continuation; sizing: `Text("Ship one thing")`, 8xnil, `.word`).
- `character-wrapped text does not split an extended grapheme cluster` (variants:
  `.wrapped(.character)`).
- `tail-truncated text uses the truncation mark at a grapheme-safe boundary` (anatomy:
  Tail truncation; variants: `.truncation(.tail)`).
- `text does not stretch for excess proposal` (sizing: `Text("Hello")`, 80x24).
- `empty text measures zero by one and paints no cells` (sizing: `Text("")`, nil x nil).
- `text merges inherited and explicit styles by attribute precedence` (environment:
  inherited Style).
- `text background fills its allocated rectangle` (environment: background fill).
- `text substitutes ascii truncation mark without changing geometry` (environment:
  truncation mark; degradation: ASCII-only).
- `text never consumes keyboard or pointer input` (key table: printable characters, Enter,
  and Up / Down / Left / Right; mouse table: click, drag, wheel-up, and wheel-down).

## Degradation

| Capability or space        | Text behavior                                                                                                                                                                                                 |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Full capability            | Uses the resolved full Style; wide and combining grapheme geometry remains exact; tail truncation uses `…`.                                                                                                   |
| `NO_COLOR`                 | Preserves text and geometry; resolved Styles degrade to their attributes per the [degradation ladder](../tokens.md#degradation-ladder).                                                                       |
| 16-color                   | Preserves text geometry and resolves the inherited full Style to the indexed palette.                                                                                                                         |
| ASCII-only                 | Preserves source ASCII text; borderless Text needs no glyph substitution; tail truncation changes from `…` to `~`. Unicode source text is rendered only when the active terminal capability can represent it. |
| Narrow or short allocation | `.none` clips; wrapped modes reflow only for a finite width; truncating modes use their selected marker. Text never creates scroll state or focus.                                                            |

## Deferred scope

Rich text segments, localized interpolation, and formatted values are excluded from Phase
4 1.0; the exact deferred boundary is
[Catalog text boundary decisions](../../docs/Spec.md#catalog-text-boundary-decisions).
They require a separate text-composition proposal and must not turn Text into a mutable
document model.

## Inspiration

The Showcase Core specimen should render ordinary, wide, combining, multiline,
constrained, wrapped, and truncated Text fixtures before it introduces focusable controls.
Text has no Showcase-only behavior; the specimen proves the public leaf through a real
`ViewGraph` and `Frame`.
