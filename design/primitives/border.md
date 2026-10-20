---
kind: primitive
status: specified
---

# Border

`border` is a stateless unary layout-and-render modifier. It reserves one cell on every
edge, draws a `BorderStyle` glyph ring in the retained inset, and proposes the interior
frame to its child. It composes with Frame and Padding but is not a Box: Border has no
title and adds no content padding beyond the one-cell ring.

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

The `single` style reserves the ring and proposes the interior to the child. Here the
child is an eight-by-two label inside a `12x4` frame.

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
5. r1-r2 c1-c10 Interior -- child frame; Text content wraps at these columns, non-text geometry clips to these cells
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
2. r1-r2 c1-c10 Interior -- unchanged child frame
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

| Proposal  | Result                                | Rule                                                                                |
| --------- | ------------------------------------- | ----------------------------------------------------------------------------------- |
| nil x nil | 12x4                                  | reports the child ideal (10x2) plus one border cell on each edge                    |
| 12x4      | 12x4                                  | tight fit: interior proposes 10x2; the ring fills reserved edges                    |
| 1x1       | 1x1                                   | under-minimum: interior clamps to 0x0; only the corner paints                       |
| 40x20     | 12x4                                  | over-proposed: child measures its ideal; parent slack is unused                     |
| 6x nil    | 6 wide; child's wrapped height plus 2 | interior proposes 4 columns and a nil height; Text content wraps and gets every row |

Border reduces the child proposal by two cells on each axis, flooring the interior at
zero. It reports the child's measured size plus the ring; it never stretches to fill slack
a `Frame` should own. Border adds no text of its own and truncates nothing: Text inside
wraps at the interior width or marks its own cut under a row budget (see
[Text](text.md#row-budget)); the ring clips only non-text geometry.

## Environment

- Border sets `light`, `rounded`, `heavy`, `double`, and `ascii` come from
  [tokens.md](../tokens.md#border-sets); the `BorderStyle` case selects the row.
- `lineStyle` is a complete [`Style`](style-modifiers.md); with the empty default the ring
  inherits `semantic.primary` through the ambient `defaultStyle`.
- Focus presentation follows the [Focus border](#focus-border) rules. The owning bordered
  view chooses the set and `lineStyle` through this modifier; the primitive itself has no
  focus state.

## Focus border

Owner decision, omp2 review, 2026-10. Box, Button, Stepper, SplitView, and Table each
settled their focus look in their own review. This section gathers those looks so they can
be checked together, and it replaces the `focus.border` direction in
[tokens.md](../tokens.md#focus). Every look uses one colour, the `focus` role, whose
provisional default is violet (see Focus colour below).

Summary of the accepted focus looks: one specimen per rule, with the rules following the
grid.

```wireframe 40x12
┏━━━━━━━━━━━━━━━━━━━━━━┓
┃ selectable card      ┃
┗━━━━━━━━━━━━━━━━━━━━━━┛

┌─ Deploy ─────────────┐
│ ▐Cancel▌ ▐Deploy▌    │
└──────────────────────┘

❯ Replicas    ◂ 4 ▸
  Timeout     ◂ 30 ▸

 Files ┃ main.swift
```

```text
Callouts (40x12, 0-based):
1. r0-r2 c0-c23  Self-focused box -- rule 1: `heavy` set in the `focus` role
2. r4-r6 c0-c23  Focus-within box -- rule 2: nearest bordered ring at normal weight
3. r5 c11-c18    Deploy button -- the control's own focus: `focus` fill, bold (rule 2)
4. r8 c0, c2-c9  Focused cursor row -- rule 3: `❯` cursor and bold `focus` label
5. r9 c14-c19    Unfocused stepper -- rule 3: arrows kept
6. r11 c7        Divider -- rule 4: `focus` heavy vertical line; joints turn heavy
7. r5 c2-c9     Cancel button -- unfocused secondary action: `.tinted`, `secondary` label on a
   faint `secondary` fill (`faint(secondary)`, token pending plan 032 step 5.3)
```

```text
── chars ──
┏━━━━━━━━━━━━━━━━━━━━━━┓
┃ selectable card      ┃
┗━━━━━━━━━━━━━━━━━━━━━━┛

┌─ Deploy ─────────────┐
│ ▐Cancel▌ ▐Deploy▌    │
└──────────────────────┘

❯ Replicas    ◂ 4 ▸
  Timeout     ◂ 30 ▸

 Files ┃ main.swift
── style ──
PPPPPPPPPPPPPPPPPPPPPPPP
PTTTTTTTTTTTTTTTTTTTTTTP
PPPPPPPPPPPPPPPPPPPPPPPP
........................
PPPFFFFFFPPPPPPPPPPPPPPP
P.BbbbbbbB.PppppppP....P
PPPPPPPPPPPPPPPPPPPPPPPP
........................
PPFFFFFFFFFFFFMMGMM
..TTTTTTTTTTTTMMGGMM
........................
TTTTTTTPTTTTTTTTTTT
── legend ──
.  default
P  fg=focus
F  fg=focus bold
T  fg=primary
M  fg=muted
p  fg=contrast bg=focus bold
B  fg=faint(secondary)*
b  fg=secondary bg=faint(secondary)*
G  fg=warning
```

Rules, owner decision, omp2 review, 2026-10:

1. **Self focus.** A bordered view that takes focus itself paints its ring in the `focus`
   role with the `heavy` set. Rounded and single rings change set; the geometry is the
   same. Heavy and double rings change colour only (rule 6).
2. **Focus within.** The nearest bordered ancestor of a focused control paints its ring in
   the `focus` role at normal weight, and the control shows its own focus. This is on by
   default; `.focusSection()` and the `focusWithinBorder` environment switch turn it off.
   Outer bordered ancestors stay plain.
3. **Cursor rows.** Form rows, Stepper host rows, Picker menu rows, and the TabView bar
   take the `❯` cursor and a bold `focus` label. An unfocused stepper keeps its arrows.
   List and Table show focus through their selection tokens instead.
4. **Split dividers.** A SplitView divider paints in the `focus` role as a heavy line, and
   its joints turn heavy to match.
5. **Tables.** A bordered table takes rule 1 or rule 2 on its outer border.
6. **Heavy, double, ASCII.** Heavy and double rings keep their weight and change colour
   only. ASCII has no heavier line, so focus shows in bold.

**Focus colour.** Owner decision, 2026-10-10: `focus` is violet (16-colour magenta 5/13),
foreground-only, bold, with no background. Keeping the role foreground-only leaves rule 6
possible on heavy rings, since a colour-only change can carry focus there. Violet is a
provisional default; the owner is not yet settled that it is the official colour. Ideally
Tessera picks a good default, and developers can set their own focus colour; the override
surface is not specified here.

## Requirements

- `single border renders the light glyph set around the interior` (anatomy: single;
  environment: border sets)
- `rounded heavy and double borders render their token corner glyphs` (anatomy: rounded,
  heavy, double)
- `custom border glyphs render the supplied set at the same geometry` (anatomy: custom;
  public API: `.custom`)
- `border reports child size plus one cell on every edge` (sizing: nil x nil, 12x4)
- `child text wraps at the interior width, and Border clips only non-text geometry`
  (anatomy: single interior; sizing: 6x nil, 40x20)
- `one by one frame paints only the top left corner` (anatomy: declared minimum; sizing:
  1x1)
- `zero area frame paints nothing` (anatomy: declared minimum; sizing: 1x1 rule)
- `custom glyph wider than one cell fails a precondition` (public API: `.custom`)
- `ascii degradation substitutes the ascii border set` (degradation: ASCII-only)
- `self focus paints a heavy ring in the focus role without moving the ring` (focus
  border: summary, rule 1)
- `focus within tints the nearest bordered ring at normal weight` (focus border: rule 2)
- `focused row shows the cursor and a bold focus label` (focus border: rule 3)
- `split divider and joints take the focus role as heavy lines` (focus border: rule 4)
- `bordered table outer ring follows the self or within focus rule` (focus border: rule 5)
- `heavy and double rings change colour only on focus` (focus border: rule 6)
- `ascii focus renders bold on the ascii ring` (focus border: rule 6; degradation:
  ASCII-only)

## Degradation

Per the [degradation ladder](../tokens.md#degradation-ladder), borders keep their geometry
at `NO_COLOR` and 16-color; only `lineStyle` color resolves through its semantic role.
ASCII-only swaps in the `ascii` set (`+` corners, `-` horizontal, `|` vertical). Focus in
ASCII is bold, since ASCII has no heavier line (focus border rule 6).

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
3. r1-r2 c1-c10 Interior -- unchanged child frame; content, wraps at the interior width
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

The focus look uses one colour, the `focus` role, and the weight rules in the
[Focus border](#focus-border) section (owner decision, omp2 review, 2026-10). Border holds
no focus state: the owning view chooses the set and `lineStyle` through this modifier.
Heavy and double rings change colour only, since no heavier line exists; ASCII shows focus
in bold.

Reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): Border is a
unary layout wrapper plus a render decoration, appearance comes from shared tokens, and
geometry is deterministic integer-cell output.

Owner decision, 2026-10-10: an interactive bordered child's decorative-versus-hit question
is deferred to [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing). The border
ring is decorative; hit testing follows the wrapped child's final frame and clip.

The border edge also serves as an edge-riding scroll-indicator track: a scrollable
descendant may mount a [ScrollIndicator](scroll-indicator.md) in `.border` placement
(`.scrollIndicatorPlacement(.border)`) whose thumb overpaints the ring cells at the
resolved thumb rows, reserving no extra cell. The `.border` thumb weight paints over
`lineStyle`; the ring geometry is unchanged.

## Open questions

- The `focus` colour token is pending plan 032 step 5.3.
  [tokens.md](../tokens.md#semantic-styles) still records `semantic.focus` as ANSI black
  on dark yellow, which conflicts with the violet default in
  [Focus border](#focus-border). Until plan 032 settles the token, the violet default
  stays provisional and this doc stays `specified`. The `focus.border` row in
  [tokens.md](../tokens.md#focus) is superseded by the Focus border section.

## Inspiration

Border is the canonical example of a modifier that is both ordinary layout geometry and a
small render decoration.
