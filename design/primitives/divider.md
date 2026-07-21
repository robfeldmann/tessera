---
kind: primitive
status: ready
---

# Divider

A one-cell-thick rule separating content along the enclosing stack's cross axis: `─`
inside a vertical stack, `│` inside a horizontal stack. Divider draws glyphs and
participates in layout; it does nothing else. It has no focus, no state, no events.
Interactive separators (a draggable split handle) are a widget concern (SplitView) that
_renders_ a Divider but owns the behavior itself.

## Prior art

- SwiftUI `Divider` -- copy the sizing semantics: fixed (1) on its own axis, fills the
  proposal on the perpendicular axis, and infers orientation from the enclosing stack.
  Reject the pixel-era details (hairline thickness, inset behavior); cells have no
  hairlines.
- Ratatui -- has no standalone divider; separation comes from `Block` borders. Glyph
  vocabulary reference: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs`
  and `borders.rs`. Copy the glyph discipline (named sets, not ad hoc codepoints), reject
  the coupling of separation to a surrounding block.
- Bubbles -- no divider primitive; apps hand-render `strings.Repeat("─", w)`. That gap is
  the argument for having one: every app reinvents it slightly differently.

## Anatomy

Horizontal, inside a vertical stack:

```wireframe 24x5
 Inbox (3)
────────────────────────
 a-note.md
 b-note.md

```

```text
Callouts (24x5, 0-based):
1. r1   Rule -- glyph from `divider.light`, repeated across the full proposed width
```

Vertical, inside a horizontal stack:

```wireframe 24x4
 Folders  │ From: Ada
 Inbox    │ Subject: Hi
 Sent     │ Sent: Jul 6
 Drafts   │
```

```text
Callouts (24x4, 0-based):
1. c10   Rule -- glyph from `divider.light`, repeated down the full proposed height
```

## Variants

Orientation is derived from the nearest enclosing stack's `stackAxis` layout context:

| Context  | Resolved `stackAxis` | Divider orientation |
| -------- | -------------------- | ------------------- |
| `HStack` | `.horizontal`        | vertical            |
| `VStack` | `.vertical`          | horizontal          |
| no stack | absent               | horizontal fallback |

This keeps the ordinary initializer axis-free while preserving deterministic bare
measurement and rendering.

Glyph per style and axis comes from the
[divider glyph table](../tokens.md#divider-glyphs): `light` (default), `heavy`, `double`,
`dashed`, `ascii`. Divider has no labeled variant; a section label composes Text and
Divider as a separate higher-level primitive.

## Sizing

Axis below means the divider's own axis (the one it is thin on). A horizontal divider's
own axis is vertical: height 1.

| Proposal           | Result | Rule                                           |
| ------------------ | ------ | ---------------------------------------------- |
| nil x nil          | 1x1    | no information: minimum footprint on both axes |
| 24 x nil           | 24x1   | fills perpendicular proposal; own axis is 1    |
| 24 x 5             | 24x1   | own-axis proposal is ignored; always 1         |
| 0 x nil            | 0x1    | zero perpendicular proposal renders nothing    |
| nil x 5 (vertical) | 1x5    | same rules with axes swapped                   |

The `nil x nil` result of 1x1 is a deliberate departure from SwiftUI (which reports an
arbitrary 10pt): in integer cells there is no natural ideal length, and stacks always
propose a concrete perpendicular extent, so the nil case only appears in bare measurement
contexts where minimal is least surprising.

## Environment

- `divider.style` -- selects the glyph row from [tokens.md](../tokens.md#divider-glyphs);
  defaults to `light`.
- Foreground color inherits from the ambient style; no divider-specific color token.
- `stackAxis` -- layout context established by an enclosing linear stack; absent context
  uses the horizontal fallback.

## Requirements

- `horizontal divider fills proposed width at height one` (sizing: 24 x nil)
- `vertical divider fills proposed height at width one` (sizing: nil x 5)
- `divider ignores own axis proposal` (sizing: 24 x 5)
- `unproposed divider measures one by one` (sizing: nil x nil)
- `divider renders style glyph across its full extent` (anatomy: r1)
- `divider clips at its assigned extent without changing thickness` (sizing: 0 x nil and
  24 x 5)
- `ascii degradation replaces glyph without size change` (degradation wireframe)
- `divider inside a horizontal stack renders the vertical rule` (variants: `HStack` row;
  anatomy: 24x4 vertical wireframe)
- `bare divider falls back to the horizontal rule` (variants: no stack row)

## Degradation

Only the glyph changes, never the geometry:

```wireframe 24x2
 Inbox (3)
------------------------
```

Per the [degradation ladder](../tokens.md#degradation-ladder): `NO_COLOR` and 16-color are
unchanged; ascii-only swaps in the `ascii` glyph row.

## Decisions

Divider follows the normative [Slice 2 orientation contract](../../docs/Spec.md#divider):
an enclosing stack publishes `stackAxis`, and Divider renders across that stack's cross
axis. A bare Divider falls back to horizontal, matching its `1x1` unconstrained
measurement. No public orientation argument is added.

Divider has no labeled variant. A future section-heading primitive may compose Text and
Divider, but labels do not add text layout, truncation, or alignment state to this
primitive.

This contract was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): orientation
is declarative layout context, appearance comes from shared tokens, and geometry remains
deterministic integer-cell output.

## Inspiration

(empty -- triage destination)
