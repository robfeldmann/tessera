---
kind: primitive
status: ready
---

# Background

`background(@ViewBuilder:)` is a stateless wrapper that preserves its primary child's
measurement and identity. It gives the background layer the primary child's final bounds,
clips it there, paints that layer first, and paints the primary child over it; it is not a
second independently sized container. Alignment uses the [ZStack](z-stack.md) vocabulary.
This view-builder API is distinct from the style-fill
[style modifiers](style-modifiers.md) `.background(Color)` API. Both are owned by
[Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration).

## Prior art

- Ratatui `Clear`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/clear.rs`
  intersects the requested rectangle with the buffer before each bounded write. Background
  copies that clipping discipline, but does not reset cells or clear terminal-global
  state.
- Tessera [ZStack](z-stack.md) supplies the shared alignment vocabulary, explicit
  clipping, and ordered layer composition. Background reverses the visible layer order
  while keeping the primary child as the sole size owner.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration)
  establishes the view-builder API and its relationship to style modifiers.
- omp2 has no background component; the [translation key](../translation-key.md#coverage)
  maps its `bg`, `on`, and `bleed` attributes ([vocab][omp2-bg-attrs],
  [bleed][omp2-bleed]), which `Cached` paints as chrome across a component's rectangle,
  inside its border unless `bleed` is set ([background fill][omp2-bg-fill]). A colour fill
  is the [style modifiers](style-modifiers.md) `.background(Color)` (key B6), and `bleed`
  is modifier order (key B5): `.border().background { … }` lays the background under the
  ring, and `.background { … }.border()` only inside it. Copy chrome as a wrapper node
  around the content (key G3). Reject `bg` gradient ramps (key B13) and the
  `paints_background` opt-out: a view without a background simply has no wrapper.

[omp2-bg-attrs]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L75-L78
[omp2-bleed]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L47-L48
[omp2-bg-fill]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1078-L1103

## Anatomy

An opaque background exactly matches a small primary child's final `5x3` bounds. Shaded
cells are fixture evidence of the background layer; `OK` is primary content painted over
it.

```wireframe 5x3
░░░░░
░OK░░
░░░░░
```

```text
Callouts (5x3, 0-based):
1. r0c0-r2c4    primary final bounds and clipped background layer
2. r1c1-c2       primary content
3. r0c0-r2c4    revealed opaque background cells outside primary content
```

An oversized background view is still visible only inside the primary child's `5x2` final
bounds.

```wireframe 5x2
░░░░░
░P░░░
```

```text
Callouts (5x2, 0-based):
1. r0c0-r1c4    primary final bounds and background clip
2. r1c1         primary content
3. r0c0-r1c4    visible portion of the oversized background layer
```

With `.bottomTrailing` alignment, a smaller primary rendering is placed at the trailing
bottom of its `7x3` final bounds. Alignment changes that placement only; the background
continues to fill the primary bounds.

```wireframe 7x3
░░░░░░░
░░░░░░░
░░░░KEY
```

```text
Callouts (7x3, 0-based):
1. r0c0-r2c6    primary final bounds and aligned background layer
2. r2c4-c6       bottom-trailing primary content
3. r0c0-r2c6    revealed background cells outside primary content
```

A sparse background paints only the cells its own view emits. Its untouched interior cells
remain untouched; the wrapper does not synthesize a fill.

```wireframe 5x3
░ ░ ░
  MID
░ ░ ░
```

```text
Callouts (5x3, 0-based):
1. r0c0, r0c2, r0c4, r2c0, r2c2, r2c4    sparse background cells
2. r0c1, r0c3, r1c0-c1, r2c1, r2c3        untouched interior cells
3. r1c2-c4                                primary content
```

At `1x1`, the primary paints over the single background cell.

```wireframe 1x1
X
```

```text
Callouts (1x1, 0-based):
1. r0c0    primary final bounds, background layer, and primary content
```

A zero-area primary has no drawable bounds, so neither layer paints a cell.

## Public API

Candidate spelling:

```swift
public struct Background<Primary: View, BackgroundLayer: View>: View {
  public init(
    alignment: Alignment = .topLeading,
    @ViewBuilder background: () -> BackgroundLayer,
    @ViewBuilder content: () -> Primary
  )
}

extension View {
  public func background<BackgroundLayer: View>(
    alignment: Alignment = .topLeading,
    @ViewBuilder background: () -> BackgroundLayer
  ) -> some View
}
```

`Alignment` is the same value vocabulary as [ZStack](z-stack.md). The wrapper retains the
original view as the primary child; it never substitutes an identity, introduces a second
measurement owner, or adds a view-layer style type. The fluent style API remains buffer
`Style`; `.background(Color)` remains the style-fill operation described by
[style modifiers](style-modifiers.md).

## Sizing

The first four rows use a primary fixture with ideal `4x2`; its background fixture
declares an oversized `9x4` layer. The zero-area row uses a zero-area primary. In every
row, the primary child is the only measurement owner and the background never enlarges the
result.

| Proposal                | Result | Rule                                                                |
| ----------------------- | ------ | ------------------------------------------------------------------- |
| nil x nil               | 4x2    | The primary child's ideal is the wrapper's unconstrained ideal.     |
| 4x2                     | 4x2    | The tight proposal is resolved by the primary child alone.          |
| 2x1                     | 4x2    | The primary retains its noncompressible minimum; a parent may clip. |
| 8x6                     | 4x2    | Extra proposal does not make either layer grow.                     |
| 0x0 (zero-area primary) | 0x0    | No primary bounds exist, so the background has no drawable bounds.  |

After primary measurement resolves, the wrapper proposes those final primary bounds to the
background and intersects all of its writes with those bounds. It then paints the
background first and the primary second. A background layer can be larger, smaller,
opaque, or sparse; none of those properties changes the primary child's reported size.

## Environment

Background consumes no token and introduces no state. It forwards the same environment to
both layers, including any descendant use of `primary`, `secondary`, `accent`, `disabled`,
or `destructive`. The wrapper itself owns no glyph, color, or style; descendants resolve
styles through the single buffer `Style` type.

## Requirements

- `background reports the primary child ideal without measuring background as a container`
  (sizing: nil x nil)
- `background preserves the primary child result under a tight proposal` (sizing: 4x2)
- `background never enlarges the primary child under an undersized or oversized proposal`
  (sizing: 2x1 and 8x6)
- `background clips an oversized background layer to primary final bounds` (anatomy:
  oversized background view)
- `background paints background cells before primary content` (anatomy: opaque background;
  primary content)
- `background aligns primary content without shrinking its background bounds` (anatomy:
  bottom-trailing primary content; primary final bounds and aligned background layer)
- `background leaves cells untouched when its background view is sparse` (anatomy: sparse
  background cells; untouched interior cells)
- `background paints the primary over the background in one by one bounds` (anatomy: 1x1
  primary final bounds, background layer, and primary content)
- `background paints nothing when the primary has zero area` (sizing: 0x0 zero-area
  primary)
- `decorative backgrounds require explicit allows hit testing false` (anatomy: opaque
  background; primary final bounds and clipped background layer)

## Degradation

Background has no glyph, color, or capability token of its own. Its integer bounds,
alignment, clipping, and paint order are unchanged at every tier of the
[degradation ladder](../tokens.md#degradation-ladder); each descendant degrades its own
content and `Style`.

## Decisions

- Decorative view-builder backgrounds must opt out explicitly with
  `.allowsHitTesting(false)` when they are not meant to participate in hit testing. There
  is no implicit decorative hit-testing default.
- A sparse background's untouched cells are not auto-filled by this wrapper. Use
  `.background(Color)` from [style modifiers](style-modifiers.md) to fill every cell;
  view-builder background paint order remains background-view-first in all cases.
- omp2's `bleed` has no flag: modifier order decides whether a background reaches under a
  border ring (key B5; see [Prior art](#prior-art)).
- Reviewed against the
  [Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): Background
  is a wrapper node that lowers into the runtime tree, keeps the primary child as its only
  measurement owner, holds no state, and paints into the region it is given.

## Open questions

None. Exact hit-routing and dispatch precedence are deferred to
[Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Inspiration

Background decorates bounded content from behind without turning that component into a
terminal-wide canvas or a second layout container.
