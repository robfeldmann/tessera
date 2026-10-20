---
kind: primitive
status: specified
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
- omp2 `Boxed`: bordered container with a `focus` prop whose focused box looks the same as
  an unfocused one
  (`https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L14-L209`,
  focus prop at `boxed.rs#L183` and `#L202`). The focus look here is Tessera's own; see
  [Focus](#focus).

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
5. r2-r3 c2-c9 Content -- child frame after ring and padding; content, wraps
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
2. r0 c3-c7  Title -- Text drawn on the top border, one space inside each end; chrome, one row
3. r0 c9-c12 Border -- remaining top `light`/`rounded` horizontal glyphs to the corner
4. r1, r3    Padding -- chrome-padding rows
5. r2 c3-c10 Content -- child frame; content, wraps
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
1. r0 c3-c12 Title -- truncated Text ending in the `truncation.mark`; chrome, one row
2. r0 c14    Border -- one trailing horizontal glyph preserved before the corner
3. r1 c2-c13 Content -- child frame; content, wraps
```

> Wrap exception (rule 1): the title stays on one row and tail-truncates. A second row
> would break the top border line it sits in. (owner decision, 2026-10-18)

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

The focus-within tint switch is the environment value `focusWithinBorder: Bool`, default
`true`, and the modifier `.focusWithinBorder(false)`. `.focusSection()` sets it to `false`
for its whole subtree (owner decision, 2026-10-10).

## Sizing

Schema: [README](../README.md#sizing-table). The child measured here has an eight-by-two
ideal; chrome adds two cells on each edge (one border, one padding).

| Proposal  | Result                                | Rule                                                                                          |
| --------- | ------------------------------------- | --------------------------------------------------------------------------------------------- |
| nil x nil | 12x6                                  | child ideal (8x2) plus the border ring and one padding cell on each edge                      |
| 12x6      | 12x6                                  | tight fit: interior content proposes 8x2 after chrome is reserved                             |
| 1x1       | 1x1                                   | under-minimum: chrome collapses through Border; only the corner paints                        |
| 40x20     | 12x6                                  | over-proposed: child measures its ideal; parent slack is unused                               |
| 8x nil    | 8 wide; child's wrapped height plus 4 | interior proposes 4 columns and a nil height; wrapping content gets every row (rules 1 and 2) |

## State model

Box stores no focus state. Each row names an input owned by the focus system or the
environment.

| State                     | Owner                                                                                   | Type                   | Reset                                                     |
| ------------------------- | --------------------------------------------------------------------------------------- | ---------------------- | --------------------------------------------------------- |
| Self focus                | Focus system: this Box's `.focusable(id)` holds focus                                   | `Bool`, derived        | Recomputed as focus moves; false when focus leaves        |
| Focus within              | Focus system: a focused descendant sits under this Box                                  | `Bool`, derived        | Recomputed as focus moves; ignored when the switch is off |
| Nearest bordered ancestor | Layout tree: first bordered Box above the focused control                               | derived                | Recomputed each frame; outer Boxes stay plain             |
| Tint switch               | Environment `focusWithinBorder`; `.focusWithinBorder(false)`; `.focusSection()` subtree | `Bool`, default `true` | Set by the environment; focus moves do not change it      |

## Focus

Owner decision, omp2 review, 2026-10. The look follows the
[Focus border](border.md#focus-border) rules: one `focus` role colour, with weight set by
rule. The three states below are the accepted wireframes.

Owner decision, 2026-10-10: the focus colour is violet (16-colour magenta 5/13) for now,
foreground-only, bold, with no background. Tessera picks the default; developers can set
their own colour. The `focus` token row stays pending plan 032 step 5.3.

### Self focus

A Box marked `.focusable(id)` that holds focus paints its ring in the `focus` role with
the `heavy` set (rule 1). Geometry does not move. The unfocused box beside it keeps
`single`.

```wireframe 40x6
┌──────────────────────────────────────┐
│ first box, unfocused                 │
└──────────────────────────────────────┘
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ second box, focused                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

```text
Callouts (40x6, 0-based):
1. r0-r2 c0-c39  Unfocused box -- `single` set in the `border` role; no focus
2. r3-r5 c0-c39  Focused box -- `heavy` set in the `focus` role; geometry unchanged (rule 1)
3. r4 c1-c38     Child -- default style; the ring alone carries focus
```

```text
── chars ──
┌──────────────────────────────────────┐
│ first box, unfocused                 │
└──────────────────────────────────────┘
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ second box, focused                  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
── style ──
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
A......................................A
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
P......................................P
PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
── legend ──
.  default
A  fg=border
P  fg=focus
```

### Focus within

A bordered container with a focused descendant tints its nearest bordered ring in the
`focus` role at normal weight (rule 2). The focused control shows its own focus: the
Deploy button fills with the focus colour. The sibling box stays plain.

```wireframe 40x8
┌─ Build ──────────────────────────────┐
│ 12 steps, last run 4 minutes ago     │
│ ▐Rerun▌  ▐Logs▌                      │
└──────────────────────────────────────┘
┌─ Deploy ─────────────────────────────┐
│ production, 3 replicas               │
│ ▐Cancel▌  ▐Deploy▌                   │
└──────────────────────────────────────┘
```

```text
Callouts (40x8, 0-based):
1. r0-r3 c0-c39  Sibling box (Build) -- `single` set in `border`; not an ancestor of the focus
2. r4-r7 c0-c39  Focus-within box (Deploy) -- `single` set in `focus` at normal weight (rule 2)
3. r4 c2-c9      Title -- bold `focus` label
4. r6 c12-c19    Deploy button -- the focused control: `contrast` on `focus` fill, bold
5. r6 c2-c9      Cancel button -- unfocused secondary action: tinted, `faint(secondary)*` fill
```

```text
── chars ──
┌─ Build ──────────────────────────────┐
│ 12 steps, last run 4 minutes ago     │
│ ▐Rerun▌  ▐Logs▌                      │
└──────────────────────────────────────┘
┌─ Deploy ─────────────────────────────┐
│ production, 3 replicas               │
│ ▐Cancel▌  ▐Deploy▌                   │
└──────────────────────────────────────┘
── style ──
AATTTTTTTAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
A.MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM.....A
A.BbbbbbB..BbbbbB......................A
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
PPFFFFFFFFPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
P.MMMMMMMMMMMMMMMMMMMMMM...............P
P.BbbbbbbB..PppppppP...................P
PPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPP
── legend ──
.  default
A  fg=border
F  fg=focus bold
T  fg=primary bold
M  fg=muted
B  fg=faint(secondary)*
b  fg=secondary bg=faint(secondary)*
P  fg=focus
p  fg=contrast bg=focus bold
```

### Nested

Only the nearest bordered ancestor of the focused control tints. The outer Release box and
the sibling api box stay plain, so enclosing frames do not all light up at once.

```wireframe 40x8
┌─ Release ────────────────────────────┐
│ two services ship together           │
│ ┌─ api ──────────┐┌─ worker ───────┐ │
│ │ v2.4.0         ││ v1.9.2         │ │
│ │ ▐Pin▌          ││ ▐Pin▌          │ │
│ │                ││                │ │
│ └────────────────┘└────────────────┘ │
└──────────────────────────────────────┘
```

```text
Callouts (40x8, 0-based):
1. r0-r7 c0-c39  Outer box (Release) -- `single` set in `border`; stays plain; title bold `primary`
2. r2-r6 c2-c19  Sibling box (api) -- plain; not an ancestor of the focus
3. r2-r6 c20-c37 Nearest bordered ancestor (worker) -- `single` set in `focus`, normal weight
4. r2 c22-c29    Worker title -- bold `focus` label
5. r4 c22-c26    Pin button (worker) -- the focused control: `contrast` on `focus` fill, bold
6. r4 c4-c8      Pin button (api) -- unfocused secondary action: tinted, `faint(secondary)*` fill
```

```text
── chars ──
┌─ Release ────────────────────────────┐
│ two services ship together           │
│ ┌─ api ──────────┐┌─ worker ───────┐ │
│ │ v2.4.0         ││ v1.9.2         │ │
│ │ ▐Pin▌          ││ ▐Pin▌          │ │
│ │                ││                │ │
│ └────────────────┘└────────────────┘ │
└──────────────────────────────────────┘
── style ──
AATTTTTTTTTAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
A.MMMMMMMMMMMMMMMMMMMMMMMMMM...........A
A.AATTTTTAAAAAAAAAAAPPFFFFFFFFPPPPPPPP.A
A.A.MMMMMM.........AP.MMMMMM.........P.A
A.A.BbbbB..........AP.PpppP..........P.A
A.A................AP................P.A
A.AAAAAAAAAAAAAAAAAAPPPPPPPPPPPPPPPPPP.A
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
── legend ──
.  default
A  fg=border
F  fg=focus bold
T  fg=primary bold
M  fg=muted
B  fg=faint(secondary)*
b  fg=secondary bg=faint(secondary)*
P  fg=focus
p  fg=contrast bg=focus bold
```

## Environment

- Border sets resolve exactly as in the [Border](border.md) contract; Box adds no border
  token of its own.
- The focus colour is the `focus` role; its value is token pending plan 032 step 5.3. Box
  adds no focus token; the rules are in the [Focus border](border.md#focus-border)
  section.
- Focus paints only the foreground of border glyphs and the title text, leaves backgrounds
  transparent, and keeps the declared `BorderStyle` and title position.
- Delegated focus appearance paints after descendants. A descendant ScrollView therefore
  keeps its own key ownership and, when it overflows, its edge-riding indicator; only the
  Box ring takes the focus-role foreground.
- The focus-within tint is on by default for bordered containers. The environment value
  `focusWithinBorder` (default `true`) and `.focusWithinBorder(false)` turn it off;
  `.focusSection()` sets it to `false` for its whole subtree (owner decision, 2026-10-10).
  See the [state model](#state-model).
- Unfocused secondary actions in the wireframes are tinted buttons (Button's default
  emphasis) with a `faint(secondary)` fill: token pending plan 032 step 5.3. The focused
  button keeps the focus fill.
- The title uses `semantic.primary` through the ambient
  [`defaultStyle`](style-modifiers.md) and the
  [`truncation.mark`](../tokens.md#truncation) for tail truncation. Box applies
  `.lineLimit(1)` and `.truncationMode(.tail)` directly on the title Text (chrome, one
  row), so an app's inherited `lineLimit` and `truncationMode` reach the child content and
  never the title.
- Content padding is one cell from the [Padding](padding.md) contract; the child inherits
  the ambient style across the chrome boundary.

## Requirements

- `untitled box insets its child by border and one padding cell` (anatomy: untitled;
  sizing: nil x nil, 12x6)
- `title interrupts the top border without adding a row` (anatomy: titled)
- `overlong title truncates with the mark before the corner` (anatomy: title truncation)
- `title stays on one row and never wraps, whatever the height proposal` (anatomy: Wrap
  exception; title truncation)
- `box forwards the border style to the border contract` (public API: `border`)
- `child content stays inside the ring and padding; wrapping content re-lays out at the interior width`
  (anatomy: content region; sizing: 8x nil, 40x20)
- `one by one box paints only the corner and drops the title` (anatomy: declared minimum;
  sizing: 1x1)
- `zero area box paints nothing` (anatomy: declared minimum)
- `ascii degradation renders the ascii ring and truncation mark` (degradation: ASCII-only)
- `self focus paints the heavy set in the focus role without moving the ring` (focus: self
  focus; focus border: rule 1)
- `focus within tints the nearest bordered ring at normal weight` (focus: focus within;
  focus border: rule 2)
- `focus within title takes the bold focus role` (focus: focus within)
- `nested focus tints only the nearest bordered ancestor` (focus: nested)
- `box with nothing focusable inside never changes` (focus: focus within)
- `focus within is off under focusSection or focusWithinBorder(false)` (state model: tint
  switch)

## Degradation

Per the [degradation ladder](../tokens.md#degradation-ladder), Box inherits Border's ring
degradation and Text's truncation degradation: `NO_COLOR` and 16-color keep the geometry,
ASCII-only swaps in the `ascii` ring and the `~` truncation mark. ASCII focus shows in
bold, since ASCII has no heavier ring (focus border rule 6). Below the floor the docked
title is dropped before it could overwrite a corner; child Text wraps at the interior
width and breaks words between graphemes rather than clipping.

```wireframe 16x3
+- Long titl~ -+
|              |
+--------------+
```

```text
Callouts (16x3, 0-based):
1. r0 c0, r0 c15 Border -- `ascii` corners
2. r0 c3-c12 Title -- truncated Text ending in the `ascii` `~` mark
3. r1 c2-c13 Content -- child frame; content, wraps
```

## Decisions

Box is Border plus one base cell of content padding plus an optional title, not a new
layout engine. The title interrupts the top border in place and is grapheme-safe
tail-truncated, so it can never desynchronize the ring or spill past a corner. The docked
title is a documented wrap exception, not content (owner decision, 2026-10-18; see
[Anatomy](#anatomy)). Box keeps the standalone [Border](border.md) modifier for the
no-padding, no-title case; the two are not merged.

The default content padding is fixed at one cell; applications needing more inset compose
an ordinary `.padding` on the child rather than a second Box padding parameter. This keeps
[Padding](padding.md) the single authoritative inset primitive.

Reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): Box is static
chrome composed from existing primitives, appearance comes from shared tokens, and
geometry is deterministic integer-cell output.

Focus is an owner decision (omp2 review, 2026-10). A Box marked `.focusable(id)` paints
the self-focus ring; a Box with a focused descendant tints its nearest bordered ring; a
Box with nothing focusable inside never changes. The look follows the
[Focus border](border.md#focus-border) rules. Box owns no key routing.

Box also anchors an edge-riding scroll indicator: a scrollable descendant may mount a
[ScrollIndicator](scroll-indicator.md) in border placement
(`.scrollIndicatorPlacement(.border)`) so its thumb rides the Box border edge, treating
the border line as the track and reserving no interior cell. The Box chrome is otherwise
unchanged; only the thumb cells on the border edge are overpainted.

Owner decision, 2026-10-10: Box hit testing is deferred to
[Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing), together with whether an
interactive bordered child needs a distinct decorative-versus-hit region.

## Open questions

None.

## Inspiration

Box is static terminal chrome for grouping content. It must remain a primitive: it may
take focus for its look, never for key handling.
