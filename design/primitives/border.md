---
kind: primitive
status: ready
---

# Border

`border` is a stateless unary layout-and-render modifier. It reserves one cell on every
edge, draws a `BorderStyle` glyph ring in the retained inset, and clips its child to the
interior frame. It composes with Frame and Padding but is not a Box: Border has no title
and adds no content padding beyond the one-cell ring.

## Prior art

- Ratatui `Block`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy
  explicit border glyph selection and edge-aware rendering. Reject coupling title,
  padding, and all decoration configuration into the simple Border modifier.
- Ratatui border glyph support:
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/borders.rs` — reference for named
  box-drawing sets and custom glyph sets; Tessera names sets in
  [tokens.md](../tokens.md#border-sets) rather than as ad hoc codepoints.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns `BorderStyle`, the public modifier signature, and the one-cell-inset direction.

## Anatomy

The `single` style reserves the ring and clips the child to the interior. Here the child
is an eight-by-two label inside a `12x4` frame.

```wireframe 12x4
┌──────────┐
│ Content  │
│          │
└──────────┘
```

```text
Callouts (12x4, 0-based):
1. r0       Top border -- corners plus `light` horizontal glyph across c1-c10
2. r0-r3 c0 Leading border -- `light` vertical glyph down the reserved leading column
3. r0-r3 c11 Trailing border -- `light` vertical glyph down the reserved trailing column
4. r3       Bottom border -- corners plus `light` horizontal glyph across c1-c10
5. r1-r2 c1-c10 Interior -- clipped child frame; content is clipped to these cells
```

The remaining named styles change only the glyph family; the reserved ring and interior
are identical.

```wireframe 12x4
╭──────────╮
│ Content  │
│          │
╰──────────╯
```

```text
Callouts (12x4, 0-based):
1. r0 c0, r0 c11, r3 c0, r3 c11 Corners -- `rounded` corner glyphs
2. r1-r2 c1-c10 Interior -- unchanged clipped child frame
```

```wireframe 12x4
┏━━━━━━━━━━┓
┃ Content  ┃
┃          ┃
┗━━━━━━━━━━┛
```

```text
Callouts (12x4, 0-based):
1. r0, r3   Horizontal border -- `heavy` corners and `━` glyph
2. c0, c11  Vertical border -- `heavy` `┃` glyph
```

```wireframe 12x4
╔══════════╗
║ Content  ║
║          ║
╚══════════╝
```

```text
Callouts (12x4, 0-based):
1. r0, r3   Horizontal border -- `double` corners and `═` glyph
2. c0, c11  Vertical border -- `double` `║` glyph
```

A custom glyph set draws whatever the caller supplies; the geometry never changes.

```wireframe 12x4
*==========*
: Content  :
:          :
*==========*
```

```text
Callouts (12x4, 0-based):
1. r0 c0, r0 c11, r3 c0, r3 c11 Corners -- caller-supplied corner glyph
2. r0, r3   Horizontal border -- caller-supplied horizontal glyph
3. c0, c11  Vertical border -- caller-supplied vertical glyph
```

### Declared minimum

Below two cells on an axis the interior clamps to zero and the ring collapses. A `1x1`
frame paints only the top-left corner; a zero-area frame paints nothing.

```wireframe 1x1
┌
```

```text
Callouts (1x1, 0-based):
1. r0 c0  Collapsed corner -- the sole cell paints the top-left corner glyph
```

## Public API

The candidate spelling, owned by
[Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration):

```swift
public enum BorderStyle: Equatable, Sendable {
  case single
  case rounded
  case double
  case heavy
  case ascii
  case custom(BorderGlyphs)
}

extension View {
  public func border(
    _ style: BorderStyle = .single,
    _ lineStyle: Style = Style()
  ) -> some View
}
```

`BorderStyle` cases map one-to-one onto the [border sets](../tokens.md#border-sets):
`.single` renders the `light` set, and `.rounded`, `.double`, `.heavy`, and `.ascii`
render the identically named sets. The public case stays `single` while the token family
stays `light`; there is one user-facing default per surface — the modifier defaults to
`.single` and [Box](box.md) defaults to `.rounded`. `.custom(BorderGlyphs)` supplies four
corner glyphs plus a horizontal and vertical glyph; each must be a single extended
grapheme cluster of display width one, and an empty or wide glyph fails a precondition at
construction. `lineStyle` defaults to the inherited ambient style; a caller or the focus
system may pass an explicit `Style`.

## Sizing

Schema: [README](../README.md#sizing-table). The child measured here has an eight-by-two
ideal.

| Proposal  | Result | Rule                                                             |
| --------- | ------ | ---------------------------------------------------------------- |
| nil x nil | 12x4   | reports the child ideal (10x2) plus one border cell on each edge |
| 12x4      | 12x4   | tight fit: interior proposes 10x2; the ring fills reserved edges |
| 1x1       | 1x1    | under-minimum: interior clamps to 0x0; only the corner paints    |
| 40x20     | 12x4   | over-proposed: child measures its ideal; parent slack is unused  |

Border reduces the child proposal by two cells on each axis, flooring the interior at
zero. It reports the child's measured size plus the ring; it never stretches to fill slack
a `Frame` should own.

## Environment

- Border sets `light`, `rounded`, `heavy`, `double`, and `ascii` come from
  [tokens.md](../tokens.md#border-sets); the `BorderStyle` case selects the row.
- `lineStyle` is a complete [`Style`](style-modifiers.md); with the empty default the ring
  inherits `semantic.primary` through the ambient `defaultStyle`.
- [`focus.border`](../tokens.md#focus) is the system focus presentation a bordered widget
  applies through this same modifier: it switches the set to `rounded` and the line to
  `semantic.focus` without changing geometry. The primitive itself has no focus state.

## Requirements

- `single border renders the light glyph set around a clipped interior` (anatomy: single;
  environment: border sets)
- `rounded heavy and double borders render their token corner glyphs` (anatomy: rounded,
  heavy, double)
- `custom border glyphs render the supplied set at the same geometry` (anatomy: custom;
  public API: `.custom`)
- `border reports child size plus one cell on every edge` (sizing: nil x nil, 12x4)
- `child content is clipped to the interior frame` (anatomy: single interior; sizing:
  40x20)
- `one by one frame paints only the top left corner` (anatomy: declared minimum; sizing:
  1x1)
- `zero area frame paints nothing` (anatomy: declared minimum; sizing: 1x1 rule)
- `custom glyph wider than one cell fails a precondition` (public API: `.custom`)
- `ascii degradation substitutes the ascii border set` (degradation: ASCII-only)
- `focus presentation switches set and line without moving the ring` (environment:
  `focus.border`)

## Degradation

Per the [degradation ladder](../tokens.md#degradation-ladder), borders keep their geometry
at `NO_COLOR` and 16-color; only `lineStyle` color resolves through its semantic role.
ASCII-only swaps in the `ascii` set (`+` corners, `-` horizontal, `|` vertical).

```wireframe 12x4
+----------+
| Content  |
|          |
+----------+
```

```text
Callouts (12x4, 0-based):
1. r0, r3   Horizontal border -- `ascii` `+` corners and `-` glyph
2. c0, c11  Vertical border -- `ascii` `|` glyph
3. r1-r2 c1-c10 Interior -- unchanged clipped child frame
```

## Decisions

The Spec's `single` spelling and the token table's `light` name are reconciled by mapping:
the public `BorderStyle.single` case renders the `light` glyph set. Each surface exposes
exactly one default — `.single` for the bare modifier, `.rounded` for Box — so no surface
presents two competing defaults.

Custom glyphs are validated at construction (single-cell clusters only) and render at the
same reserved ring, so a malformed set cannot desynchronize the corners from the edges.
Degenerate frames clamp rather than crash: below two cells on an axis the interior is
zero, `1x1` paints the top-left corner, and a zero-area frame paints nothing.

Reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): Border is a
unary layout wrapper plus a render decoration, appearance comes from shared tokens, and
geometry is deterministic integer-cell output.

The border edge also serves as an edge-riding scroll-indicator track: a scrollable
descendant may mount a [ScrollIndicator](scroll-indicator.md) in `onBorder` placement
whose thumb overpaints the ring cells at the resolved thumb rows, reserving no extra cell.
The `onBorder` thumb weight paints over `lineStyle`; the ring geometry is unchanged.

## Open questions

- Whether an interactive bordered child needs a distinct decorative-versus-hit region is
  deferred to [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing); the border ring
  is decorative and hit testing follows the wrapped child's final frame and clip.

## Inspiration

Border is the canonical example of a modifier that is both ordinary layout geometry and a
small render decoration.
