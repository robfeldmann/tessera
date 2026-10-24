---
kind: primitive
status: ready
---

# Divider

A one-cell-thick rule separating content along the enclosing stack's cross axis: `─` inside a vertical stack, `│` inside a horizontal stack. A horizontal rule can carry a text label docked at its leading edge, centre, or trailing edge. Divider draws glyphs and participates in layout; it does nothing else. It has no focus, no state, no events. Interactive separators (a draggable split handle) are a widget concern (SplitView) that _renders_ a Divider but owns the behavior itself.

## Prior art

- SwiftUI `Divider` -- copy the sizing semantics: fixed (1) on its own axis, fills the proposal on the perpendicular axis, and infers orientation from the enclosing stack. Reject the pixel-era details (hairline thickness, inset behavior); cells have no hairlines.
- Ratatui -- has no standalone divider; separation comes from `Block` borders. Glyph vocabulary reference: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` and `borders.rs`. Copy the glyph discipline (named sets, not ad hoc codepoints), reject the coupling of separation to a surrounding block.
- Bubbles -- no divider primitive; apps hand-render `strings.Repeat("─", w)`. That gap is the argument for having one: every app reinvents it slightly differently.
- omp2 `Hr`, Divider's counterpart in the [translation key](../translation-key.md#coverage) ([hr.rs][hr]) -- copy the docked label (start, center, or end), its spacing (two rule cells before a leading label and after a trailing one, a space on each side of the label), its rule that the outermost rule cell on each side is never covered, its tail truncation with `…` (the `truncation.mark`, key I2), and its `border` colour for the rule (key J1). Its rule glyphs are the [divider glyphs](../tokens.md#divider-glyphs) (key K7; [rule][omp2-rule]), and it fills its stack's cross axis itself rather than through a row stretch ([stretch_in_row][hr-stretch], key G7). Reject its `title`/`label` dual spelling and its join to an adjacent border column ([join][hr-join]; Tessera's blended junctions below cover that).

[hr]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L129-L252
[hr-stretch]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L113-L115
[hr-join]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L159-L177
[omp2-rule]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L158-L175

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

Labeled, at the `mobile` width (owner decision, omp2 review, 2026-10). The rule keeps the `border` role; the label keeps the ambient text style:

```wireframe 40x4
── Output ──────────────────────────────
──────────────── Build ─────────────────
─────────────────────────────── Tests ──
─ A label far too long for a narrow r… ─
```

```text
Callouts (40x4, 0-based):
1. r0 c2-c9    Leading label -- `Divider("Output")`; two rule cells, a space, the label,
               a space, then rule to the trailing edge
2. r1 c16-c22  Centred label -- `alignment: .center`; the label block (spaces included)
               starts at `floor((width - block) / 2)`
3. r2 c31-c37  Trailing label -- `alignment: .trailing`; the block ends two rule cells
               before the trailing edge
4. r3 c1-c38   Truncated label -- the label cuts at its tail with `truncation.mark`; the
               outermost rule cell on each side is never covered
```

```text
── chars ──
── Output ──────────────────────────────
──────────────── Build ─────────────────
─────────────────────────────── Tests ──
─ A label far too long for a narrow r… ─
── style ──
BB........BBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBB.......BBBBBBBBBBBBBBBBB
BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB.......BB
B......................................B
── legend ──
.  default
B  fg=border
```

Labeled, at the declared minimum for a labeled rule. Below three cells the label is dropped and the plain rule draws:

```wireframe 14x4
── Output ────
─── Build ────
───── Tests ──
─ A label f… ─
```

```text
Callouts (14x4, 0-based):
1. r0-r2  Docked labels -- the same placement rules at 14 columns
2. r3     Truncated label -- one rule cell, a space, the cut label with its mark, a
          space, one rule cell
```

> Wrap exception (rule 1): the docked label stays on one row and tail-truncates. A second row would break the border line it sits in. (owner decision, 2026-10-18)

## Variants

Orientation is derived from the nearest enclosing stack's `stackAxis` layout context:

| Context  | Resolved `stackAxis` | Divider orientation |
| -------- | -------------------- | ------------------- |
| `HStack` | `.horizontal`        | vertical            |
| `VStack` | `.vertical`          | horizontal          |
| no stack | absent               | horizontal fallback |

This keeps the ordinary initializer axis-free while preserving deterministic bare measurement and rendering.

Glyph per style and axis comes from the [divider glyph table](../tokens.md#divider-glyphs): `light` (default), `heavy`, `double`, `dashed`, `dotted`, `ascii`.

A label is a `Text` docked with a `HorizontalAlignment`:

```swift
Divider()                                     // plain rule
Divider("Output")                             // leading label (default)
Divider("Build", alignment: .center)
Divider(Text("Tests").bold(), alignment: .trailing)
```

| Label placement | Block position (block = space + label + space) |
| --- | --- |
| `.leading` | starts after two rule cells |
| `.center` | starts at `floor((width - block) / 2)` |
| `.trailing` | ends two rule cells before the trailing edge |
| any, too long | label cuts at its tail with `truncation.mark`; one rule cell stays on each side |

At small widths the spaces collapse before the label disappears: with `interior = width - 2`, the leading space shows when `interior >= 2` and the trailing space when `interior >= 3`. Below three cells the label is dropped. A label never changes the rule's size, and only horizontal rules draw one: a labeled Divider inside an `HStack` draws the plain vertical rule, because orientation comes from layout context, not the type.

The label Text is chrome, one row: Divider applies `.lineLimit(1)` and `.truncationMode(.tail)` directly on it, so an app's inherited `lineLimit` and `truncationMode` never reach it.

## Sizing

Axis below means the divider's own axis (the one it is thin on). A horizontal divider's own axis is vertical: height 1.

| Proposal           | Result | Rule                                           |
| ------------------ | ------ | ---------------------------------------------- |
| nil x nil          | 1x1    | no information: minimum footprint on both axes |
| 24 x nil           | 24x1   | fills perpendicular proposal; own axis is 1    |
| 24 x 5             | 24x1   | own-axis proposal is ignored; always 1         |
| 0 x nil            | 0x1    | zero perpendicular proposal renders nothing    |
| nil x 5 (vertical) | 1x5    | same rules with axes swapped                   |

The `nil x nil` result of 1x1 is a deliberate departure from SwiftUI (which reports an arbitrary 10pt): in integer cells there is no natural ideal length, and stacks always propose a concrete perpendicular extent, so the nil case only appears in bare measurement contexts where minimal is least surprising.

## Environment

- `divider.style` -- selects the glyph row from [tokens.md](../tokens.md#divider-glyphs); defaults to `light`.
- The rule draws in the `border` role ([text roles](../tokens.md#text-roles); owner decision, 2026-10-10). A label keeps the ambient text style, and styling on its `Text` (for example `.bold()`) applies to the label only, as omp2's `fg` and `bold` attributes become style modifiers (key B6).
- `stackAxis` -- layout context established by an enclosing linear stack; absent context uses the horizontal fallback.

## Requirements

- `horizontal divider fills proposed width at height one` (sizing: 24 x nil)
- `vertical divider fills proposed height at width one` (sizing: nil x 5)
- `divider ignores own axis proposal` (sizing: 24 x 5)
- `unproposed divider measures one by one` (sizing: nil x nil)
- `divider renders style glyph across its full extent` (anatomy: r1)
- `divider clips at its assigned extent without changing thickness` (sizing: 0 x nil and 24 x 5)
- `divider rule draws in the border role` (anatomy: labeled styled grid)
- `leading label starts after two rule cells` (anatomy: 40x4 r0)
- `centred label block starts at floor of the remaining width over two` (anatomy: 40x4 r1)
- `trailing label ends two rule cells before the edge` (anatomy: 40x4 r2)
- `overlong label truncates at its tail and keeps one rule cell on each side` (anatomy: 40x4 r3 and 14x4 r3)
- `label stays on one row and never wraps, whatever the height proposal` (anatomy: Wrap exception; sizing: 24 x 5)
- `label spaces collapse before the label is dropped below three cells` (variants: label placement)
- `label never changes divider size` (sizing: 24 x nil)
- `vertical divider ignores its label` (variants: label placement)
- `ascii degradation replaces glyph without size change` (degradation wireframe)
- `divider inside a horizontal stack renders the vertical rule` (variants: `HStack` row; anatomy: 24x4 vertical wireframe)
- `bare divider falls back to the horizontal rule` (variants: no stack row)

### Pointer

- `divider takes no focus and handles no key or pointer events` (Overview; Blended junctions)

## Degradation

Only the glyph changes, never the geometry:

```wireframe 24x2
 Inbox (3)
------------------------
```

Per the [degradation ladder](../tokens.md#degradation-ladder): `NO_COLOR` and 16-color are unchanged; ascii-only swaps in the `ascii` glyph row and the `~` truncation mark, and a label keeps its placement:

```wireframe 40x1
-- Output ------------------------------
```

## Blended junctions

Specified 2026-08-17 (prompted by NavigationSplitView's header rule crossing SplitView divider columns); not yet implemented. Blending lets two crossing rules render a junction glyph (`┼`, `├`, `┤`, `┬`, `┴`) instead of the later rule overwriting the earlier one -- Monodraw's "blended" line setting is the visual model.

Junction glyphs come from the `light` junction column of [border sets](../tokens.md#border-sets) (`├ ┤ ┬ ┴ ┼`; ASCII `+`) and draw in `border`, or in `focus` where a focused line meets them.

- **Opt-in:** a `divider.blending` environment value, default `.replace`. `.blended` requests arm-union rendering for the Divider (and for widget-rendered dividers such as SplitView's, which enable it for their divider cells).
- **Semantics:** writing a blended line glyph into a cell whose existing content is a box-drawing line glyph from the same glyph family stores the union of both glyphs' directional arms (`─` into `│` is `┼`; `─` ending at `│` is `├` or `┤`). Union is commutative, so paint order never changes the result. When the existing content is not a recognized line glyph, or the union has no glyph in the active family, the incoming glyph replaces.
- **Scope:** v1 covers the `light` and `ascii` families only. Every `ascii` union is `+`. `heavy`, `double`, `dashed`, and `dotted` replace rather than blend (dashed and dotted have no junction forms; mixed-weight unions are not worth their glyph table yet).
- **Seam:** `FrameRegion` is a write-only surface with no public cell read. The read-modify-write lives inside `TesseraTerminalBuffer.Buffer`, mirroring the existing `FrameRegion._mergeStyle` -> `Buffer.mergeStyle` precedent: a merge-line operation on `FrameRegion` delegates the arm-union to the buffer, and no cell-read API is exposed to higher layers.
- **Geometry is untouched:** blending changes glyph selection only; sizing, orientation, and degradation geometry are exactly the base Divider contract.

A blended horizontal rule crossing a vertical `SplitView` divider:

```wireframe 24x4
 Folders  │ From: Ada
──────────┼─────────────
 Inbox    │ Subject: Hi
 Sent     │ Sent: Jul 6
```

```text
Callouts (24x4, 0-based):
1. r1 c10  Junction -- `┼`, the arm-union of the blended rule and the divider column
2. r1      Blended rule -- `divider.light` glyphs; ascii degradation renders `+` at c10
```

Requirements (traced to the crossing wireframe; gated on the buffer merge seam):

- `blended horizontal rule crossing a vertical divider renders a junction glyph` (crossing wireframe: r1 c10)
- `blending is commutative across paint order` (crossing wireframe: r1 c10)
- `non-line content under a blended rule is replaced not merged` (semantics bullet; crossing wireframe rows r0, r2-r3 keep text intact)
- `ascii blending renders plus at every junction` (crossing wireframe callout 2)

## Decisions

Divider follows the normative [Slice 2 orientation contract](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#divider): an enclosing stack publishes `stackAxis`, and Divider renders across that stack's cross axis. A bare Divider falls back to horizontal, matching its `1x1` unconstrained measurement. No public orientation argument is added.

Divider carries an optional `Text` label docked leading, centred, or trailing (owner decision, omp2 review, 2026-10). The label adds placement and tail truncation only; it never changes the rule's size. The docked label is a documented wrap exception, not content: it stays on one row and tail-truncates (owner decision, 2026-10-18; see [Anatomy](#anatomy)). A label that is any `View` rather than `Text` is post-1.0.

Key B5 makes omp2's labelled rule a Divider and leaves the label and its alignment to Divider, so the label stays a `String` or `Text` rather than key B11's `@ViewBuilder label:` (the owner decision above). Divider fills its stack's cross axis itself (key G7), and its glyphs are omp2's rules (key K7); dashes exist only as divider glyphs, never as a box (key K4).

This contract was reviewed against the [Phase 4 theses](../../spec/phase-4.md): orientation is declarative layout context, appearance comes from shared tokens, and geometry remains deterministic integer-cell output.

## Open questions

None. Blended junctions wait on the buffer merge seam specified above, an implementation step, not a design question.

## Inspiration

(empty -- triage destination)
