---
kind: primitive
status: ready
---

# Box

`Box` is a stateless composition primitive: a border ring, one cell of content padding,
and an optional title around a single child. Its public direction is
`Box(title:border:content:)` with a `rounded` border default. Box composes the
[Border](border.md), [Padding](padding.md), [Text](text.md), [style](style-modifiers.md),
and [Frame](frame.md) contracts rather than introducing private layout or input machinery.

## Prior art

- Ratatui `Block`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy
  bounded titled chrome and explicit border configuration. Reject unstructured app state
  or input handling inside static decoration.
- Ratatui `Block` padding:
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block/padding.rs` — contrast for
  title and chrome spacing; Tessera keeps generic [Padding](padding.md) as the
  authoritative content-inset primitive and adds only one base cell of chrome padding.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns the public API and the default rounded-border direction.

## Anatomy

An untitled box wraps its child in a `rounded` ring plus one cell of padding, so the
chrome insets the child by two cells on every edge. The child here has an eight-by-two
ideal.

```wireframe 12x6
╭──────────╮
│          │
│ Content  │
│          │
│          │
╰──────────╯
```

```text
Callouts (12x6, 0-based):
1. r0, r5   Border -- `rounded` top and bottom ring from the Border contract
2. c0, c11  Border -- `rounded` leading and trailing ring
3. r1, r4   Padding -- one reserved chrome-padding row inside the ring
4. c1, c10  Padding -- one reserved chrome-padding column inside the ring
5. r2-r3 c2-c9 Content -- clipped child frame after ring and padding
```

A title interrupts the top border; it never adds a second row or overlays a live cell.

```wireframe 14x5
╭─ Title ────╮
│            │
│  Content   │
│            │
╰────────────╯
```

```text
Callouts (14x5, 0-based):
1. r0 c0     Border -- `rounded` top-left corner
2. r0 c3-c7  Title -- Text drawn on the top border, one space inside each end
3. r0 c9-c12 Border -- remaining top `light`/`rounded` horizontal glyphs to the corner
4. r1, r3    Padding -- chrome-padding rows
5. r2 c3-c10 Content -- clipped child frame
```

A title longer than the top border is tail-truncated grapheme-safe with the
[`truncation.mark`](../tokens.md#truncation), keeping at least one trailing glyph and the
corner.

```wireframe 16x3
╭─ Long titl… ─╮
│              │
╰──────────────╯
```

```text
Callouts (16x3, 0-based):
1. r0 c3-c12 Title -- truncated Text ending in the `truncation.mark`
2. r0 c14    Border -- one trailing horizontal glyph preserved before the corner
3. r1 c2-c13 Content -- clipped child frame
```

### Declared minimum

Below two cells on an axis the chrome collapses through the Border contract. A `1x1` box
paints only the top-left corner; a zero-area box paints nothing, and any title is dropped
before it could overwrite a corner.

```wireframe 1x1
╭
```

```text
Callouts (1x1, 0-based):
1. r0 c0  Collapsed corner -- the sole cell paints the `rounded` top-left corner
```

## Public API

The candidate spelling, owned by
[Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration):

```swift
public struct Box<Content: View>: View {
  public init(
    title: String? = nil,
    border: BorderStyle = .rounded,
    @ViewBuilder content: () -> Content
  )
}
```

`border` accepts any [`BorderStyle`](border.md); Box forwards it to the Border modifier
and never redraws a ring itself. `title` is optional plain text placed on the top border.
Box applies exactly one base cell of content padding through [Padding](padding.md);
further inset is ordinary child `.padding` composition, not a second Box parameter.

## Sizing

Schema: [README](../README.md#sizing-table). The child measured here has an eight-by-two
ideal; chrome adds two cells on each edge (one border, one padding).

| Proposal  | Result | Rule                                                                     |
| --------- | ------ | ------------------------------------------------------------------------ |
| nil x nil | 12x6   | child ideal (8x2) plus the border ring and one padding cell on each edge |
| 12x6      | 12x6   | tight fit: interior content proposes 8x2 after chrome is reserved        |
| 1x1       | 1x1    | under-minimum: chrome collapses through Border; only the corner paints   |
| 40x20     | 12x6   | over-proposed: child measures its ideal; parent slack is unused          |

## Environment

- Border sets resolve exactly as in the [Border](border.md) contract; Box adds no border
  token of its own.
- When Box handles delegated focus appearance, it retains its declared `BorderStyle` and
  title position, paints only the foreground of border glyphs with the focus color (bold),
  leaves their backgrounds transparent, skips title cells, and does not consume the
  focus-owner-only `focus.border` rounded switch.
- Delegated appearance paints after descendants. A descendant ScrollView therefore keeps
  its own key ownership and, when it overflows, its edge-riding indicator; only the Box
  ring receives the primary focus foreground overlay.
- The title uses `semantic.primary` through the ambient
  [`defaultStyle`](style-modifiers.md) and the
  [`truncation.mark`](../tokens.md#truncation) for tail truncation.
- Content padding is one cell from the [Padding](padding.md) contract; the child inherits
  the ambient style across the chrome boundary.

## Requirements

- `untitled box insets its child by border and one padding cell` (anatomy: untitled;
  sizing: nil x nil, 12x6)
- `title interrupts the top border without adding a row` (anatomy: titled)
- `overlong title truncates with the mark before the corner` (anatomy: title truncation)
- `box forwards the border style to the border contract` (public API: `border`)
- `child content is clipped inside the ring and padding` (anatomy: content region; sizing:
  40x20)
- `one by one box paints only the corner and drops the title` (anatomy: declared minimum;
  sizing: 1x1)
- `zero area box paints nothing` (anatomy: declared minimum)
- `ascii degradation renders the ascii ring and truncation mark` (degradation: ASCII-only)
- `delegated focus repaints only the foreground of declared box border glyphs after descendants and excludes the title`
  (environment: delegated focus appearance; decisions: edge-riding scroll indicator)

## Degradation

Per the [degradation ladder](../tokens.md#degradation-ladder), Box inherits Border's ring
degradation and Text's truncation degradation: `NO_COLOR` and 16-color keep the geometry,
ASCII-only swaps in the `ascii` ring and the `~` truncation mark.

```wireframe 16x3
+- Long titl~ -+
|              |
+--------------+
```

```text
Callouts (16x3, 0-based):
1. r0 c0, r0 c15 Border -- `ascii` corners
2. r0 c3-c12 Title -- truncated Text ending in the `ascii` `~` mark
3. r1 c2-c13 Content -- clipped child frame
```

## Decisions

Box is Border plus one base cell of content padding plus an optional title, not a new
layout engine. The title interrupts the top border in place and is grapheme-safe
tail-truncated, so it can never desynchronize the ring or spill past a corner. Box keeps
the standalone [Border](border.md) modifier for the no-padding, no-title case; the two are
not merged.

The default content padding is fixed at one cell; applications needing more inset compose
an ordinary `.padding` on the child rather than a second Box padding parameter. This keeps
[Padding](padding.md) the single authoritative inset primitive.

Reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): Box is static
chrome composed from existing primitives, appearance comes from shared tokens, and
geometry is deterministic integer-cell output. It remains a primitive, not a focusable
panel widget.

Box also anchors an edge-riding scroll indicator: a scrollable descendant may mount a
[ScrollIndicator](scroll-indicator.md) in `onBorder` placement so its thumb rides the Box
border edge, treating the border line as the track and reserving no interior cell. The Box
chrome is otherwise unchanged; only the thumb cells on the border edge are overpainted.

## Open questions

- Box chrome is decorative: hit testing follows the Box final frame and child clip, and
  title or border cells do not intercept pointer input unless a descendant installs a
  handler. A future interactive-title affordance would need a separate widget contract;
  its routing is deferred to [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Inspiration

Box is static terminal chrome for grouping content. It must remain a primitive, not a
focusable panel widget.
