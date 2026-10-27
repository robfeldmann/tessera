---
kind: primitive
status: ready
---

# Box

`Box` is a stateless composition primitive: a border ring, one column of content padding on each side, and an optional title around a single child. Its public direction is `Box(title:border:content:)` with a `rounded` border default, and the title is a view with a `String` convenience (key A7). Box composes the [Border](border.md), [Padding](padding.md), [Text](text.md), [style](style-modifiers.md), and [Frame](frame.md) contracts rather than introducing private layout or input machinery.

## Prior art

- Ratatui `Block`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy bounded titled chrome and explicit border configuration. Reject unstructured app state or input handling inside static decoration.
- Ratatui `Block` padding: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block/padding.rs` — contrast for title and chrome spacing; Tessera keeps generic [Padding](padding.md) as the authoritative content-inset primitive and adds only one column of chrome padding on each side.
- Tessera [Slice 3](../../spec/phase-4/slice-03-styling-and-decoration.md) — owns the public API and the default rounded-border direction.
- omp2 `Boxed`, Box's counterpart in the [translation key](../translation-key.md#coverage) ([boxed.rs][boxed]): a bordered child stack. Its markup defaults to a `square` ring and `pad-x=1` with no vertical padding ([markup.rs][box-markup]), and its title is a string or a live title child laid out on the top border, which can host a spinner or a time badge ([title child][boxed-title], [title placement][boxed-title-rect], [title measure][boxed-measure]). Copy the title child as Box's `@ViewBuilder` title slot with a `String` convenience (key A7), the horizontal-only padding, and the title counting toward the box's natural width. Reject its border `footer` (key B5: Box draws a title only), `title-align` and `title-pad` (key B5: label alignment is Divider's), dashed rings (key K4), and its press on Enter or click when focusable (key C12; a container that acts is a Button). Its focused box looks the same as an unfocused one ([focus prop][boxed-focus]); the focus look here is Tessera's own, see [Focus](#focus). An unstyled omp2 border falls back to the theme's `border` colour ([component.rs][omp2-border-colour]); Box's ring draws in the `border` role (key J1).

[boxed]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L14-L209
[box-markup]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L506-L514
[boxed-title]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L14-L20
[boxed-title-rect]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L45-L60
[boxed-measure]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L124-L135
[boxed-focus]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L179-L208
[omp2-border-colour]: https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1199-L1210

## Anatomy

An untitled box wraps its child in a `rounded` ring plus one column of padding on each side, so the chrome insets the child by two columns on each side and one row above and below. The child here has an eight-by-two ideal.

```wireframe 12x4
╭──────────╮
│ Content  │
│          │
╰──────────╯
```

```text
Callouts (12x4, 0-based):
1. r0, r3   Border -- `rounded` top and bottom ring from the Border contract
2. c0, c11  Border -- `rounded` leading and trailing ring
3. c1, c10  Padding -- one reserved chrome-padding column inside the ring on each side
4. r1-r2 c2-c9 Content -- child frame after ring and padding; content, wraps
```

Padding is horizontal only, as in the accepted [Focus](#focus) wireframes and omp2's `<box>` default (`pad-x=1`, no `pad-y`; see [Prior art](#prior-art)).

A title interrupts the top border; it never adds a second row or overlays a live cell. The title is a view. Box proposes it one row and the top border's free run, the box width less six cells (the two corners, and a rule cell and a space on each side of the title), and draws it from c3 at its measured width, clipped to that run. A title that measures zero cells wide leaves the top border unbroken.

```wireframe 14x3
╭─ Title ────╮
│ Content    │
╰────────────╯
```

```text
Callouts (14x3, 0-based):
1. r0 c0     Border -- `rounded` top-left corner
2. r0 c3-c7  Title -- the title view on the top border, one space inside each end; chrome, one row
3. r0 c9-c12 Border -- remaining top `rounded` horizontal glyphs to the corner
4. c1, c12   Padding -- chrome-padding columns
5. r1 c2-c11 Content -- child frame; content, wraps
```

A title longer than the top border is tail-truncated grapheme-safe with the [`truncation.mark`](../tokens.md#truncation), keeping at least one trailing glyph and the corner.

```wireframe 16x3
╭─ Long titl… ─╮
│              │
╰──────────────╯
```

```text
Callouts (16x3, 0-based):
1. r0 c3-c12 Title -- a `Text` title truncated, ending in the `truncation.mark`; chrome, one row
2. r0 c14    Border -- one trailing horizontal glyph preserved before the corner
3. r1 c2-c13 Content -- child frame; content, wraps
```

> Wrap exception (rule 1): the title stays on one row and tail-truncates. A second row would break the top border line it sits in. (owner decision, 2026-10-18) Box applies `.lineLimit(1)` and `.truncationMode(.tail)` to the title view's subtree, so a `Text` title truncates with the mark and any other title view is clipped to its one row.

### Declared minimum

Below two cells on an axis the chrome collapses through the Border contract. A `1x1` box paints only the top-left corner; a zero-area box paints nothing, and any title is dropped before it could overwrite a corner.

```wireframe 1x1
╭
```

```text
Callouts (1x1, 0-based):
1. r0 c0  Collapsed corner -- the sole cell paints the `rounded` top-left corner
```

## Public API

The candidate spelling; [Slice 3](../../spec/phase-4/slice-03-styling-and-decoration.md) owns it, and plan 032 step 9.3 lands it:

```swift
public struct Box<Title: View, Content: View>: View {
  public init(
    border: BorderStyle = .rounded,
    @ViewBuilder content: () -> Content,
    @ViewBuilder title: () -> Title
  )
}

extension Box where Title == Text {
  public init(
    title: String,
    border: BorderStyle = .rounded,
    @ViewBuilder content: () -> Content
  )
}

extension Box where Title == EmptyView {
  public init(
    border: BorderStyle = .rounded,
    @ViewBuilder content: () -> Content
  )
}
```

```swift
Box(title: "Deploy") { DeployControls() }
Box { DeployControls() } title: {
  Text("Deploy ") + Text("3 replicas").italic()
}
```

The title is a named `@ViewBuilder` slot with a `String` convenience (key A7), the form of Section's `header:`, so a title can carry styled runs, a badge, or a motion view. The `String` initializer keeps the `Box(title:border:content:)` spelling of key B5, and an untitled box is `Title == EmptyView`, as in SwiftUI's `GroupBox`. The title view is an ordinary child: it keeps its own identity and reads the same environment as the content.

`border` accepts any [`BorderStyle`](border.md); Box forwards it to the Border modifier and never redraws a ring itself. Box applies exactly one column of content padding on each side through [Padding](padding.md); further inset is ordinary child `.padding` composition, not a second Box parameter.

The focus-within tint switch is the environment value `focusWithinBorder: Bool`, default `true`, and the modifier `.focusWithinBorder(false)`. `.focusSection()` sets it to `false` for its whole subtree (owner decision, 2026-10-10).

## Sizing

Schema: [README](../../design.md#sizing-table). The child measured here has an eight-by-two ideal; chrome adds two columns on each side (one border, one padding) and one row above and below (the border). A title counts toward the ideal width, as Boxed's does: an unconstrained box is at least six cells wider than its title's ideal, so the title shows whole whenever the width is the box's to choose.

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil | 12x4 | child ideal (8x2) plus the ring on every edge and one padding column on each side |
| 12x4 | 12x4 | tight fit: interior content proposes 8x2 after chrome is reserved |
| 1x1 | 1x1 | under-minimum: chrome collapses through Border; only the corner paints |
| 40x20 | 12x4 | over-proposed: child measures its ideal; parent slack is unused |
| 8x nil | 8 wide; child's wrapped height plus 2 | interior proposes 4 columns and a nil height; wrapping content gets every row (rules 1 and 2) |
| nil x nil, titled | 23x4 | a 17-cell title plus six chrome cells is wider than the child's 12: the ideal fits the whole title |

## State model

Box stores no focus state. Each row names an input owned by the focus system or the environment.

| State | Owner | Type | Reset |
| --- | --- | --- | --- |
| Self focus | Focus system: this Box's `.focusable(id)` holds focus | `Bool`, derived | Recomputed as focus moves; false when focus leaves |
| Focus within | Focus system: a focused descendant sits under this Box | `Bool`, derived | Recomputed as focus moves; ignored when the switch is off |
| Nearest bordered ancestor | Layout tree: first bordered Box above the focused control | derived | Recomputed each frame; outer Boxes stay plain |
| Tint switch | Environment `focusWithinBorder`; `.focusWithinBorder(false)`; `.focusSection()` subtree | `Bool`, default `true` | Set by the environment; focus moves do not change it |

## Focus

Owner decision, omp2 review, 2026-10. The look follows the [Focus border](border.md#focus-border) rules: one `focus` role colour, with weight set by rule. The three states below are the accepted wireframes. A Box joins focus only through an explicit `.focusable(id)` (key B10), and draws focus in the `focus` role rather than omp2's `accent` (key E2).

Focus colour: `focus` is the terminal's default foreground in bold, foreground-only, with no hue and no background (owner decision, 2026-10-19; [tokens.md#focus](../tokens.md#focus)). Apps may set an explicit colour ([overrides](../tokens.md#overrides)).

### Self focus

A Box marked `.focusable(id)` that holds focus paints its ring in the `focus` role with the `heavy` set (rule 1). Geometry does not move. The unfocused box beside it keeps `single`.

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
3. r4 c2-c37     Child -- default style inside the padding columns; the ring alone carries focus
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

A bordered container with a focused descendant tints its nearest bordered ring in the `focus` role at normal weight (rule 2). The focused control shows its own focus: the Deploy button fills with `solid(focus)`, a default-foreground chip. The sibling box stays plain.

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
4. r6 c12-c19    Deploy button -- the focused control: `contrast` bold on the `focus` fill (`solid(focus)`)
5. r6 c2-c9      Cancel button -- unfocused secondary action: tinted, `faint(secondary)` fill
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
M  fg=secondary
B  fg=faint(secondary)
b  fg=secondary bg=faint(secondary)
P  fg=focus
p  fg=contrast bg=focus bold
```

### Nested

Only the nearest bordered ancestor of the focused control tints. The outer Release box and the sibling api box stay plain, so enclosing frames do not all light up at once.

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
5. r4 c22-c26    Pin button (worker) -- the focused control: `contrast` bold on the `focus` fill (`solid(focus)`)
6. r4 c4-c8      Pin button (api) -- unfocused secondary action: tinted, `faint(secondary)` fill
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
M  fg=secondary
B  fg=faint(secondary)
b  fg=secondary bg=faint(secondary)
P  fg=focus
p  fg=contrast bg=focus bold
```

## Environment

- Border sets and the ring's `border` role resolve exactly as in the [Border](border.md) contract; Box adds no border token of its own.
- The focus colour is the `focus` role; its value is the terminal's default foreground in bold ([tokens.md#focus](../tokens.md#focus)). Box adds no focus token; the rules are in the [Focus border](border.md#focus-border) section.
- Focus paints only the foreground of border glyphs and the title, leaves backgrounds transparent, and keeps the declared `BorderStyle` and title position.
- Delegated focus appearance paints after descendants. A descendant ScrollView therefore keeps its own key ownership and, when it overflows, its edge-riding indicator; only the Box ring takes the focus-role foreground.
- The focus-within tint is on by default for bordered containers. The environment value `focusWithinBorder` (default `true`) and `.focusWithinBorder(false)` turn it off; `.focusSection()` sets it to `false` for its whole subtree (owner decision, 2026-10-10). See the [state model](#state-model).
- Unfocused secondary actions in the wireframes are tinted buttons (Button's default emphasis) with a `faint(secondary)` fill ([composite styles](../tokens.md#composite-styles)). The focused button keeps the focus fill (`solid(focus)`).
- The title view renders over a bold `primary` ambient style through [`defaultStyle`](style-modifiers.md), or bold `focus` under focus within, as the styled grids show; styling on the title view applies over it. A `Text` title tail-truncates with the [`truncation.mark`](../tokens.md#truncation). Box applies `.lineLimit(1)` and `.truncationMode(.tail)` directly on the title view (chrome, one row), so an app's inherited `lineLimit` and `truncationMode` reach the child content and never the title.
- Content padding is one column on each side from the [Padding](padding.md) contract; the child inherits the ambient style across the chrome boundary.

## Requirements

- `untitled box insets its child by the ring and one padding column on each side` (anatomy: untitled; sizing: nil x nil, 12x4)
- `untitled box draws an unbroken top border` (public API: `Title == EmptyView`; anatomy: untitled)
- `title interrupts the top border without adding a row` (anatomy: titled)
- `title view is proposed one row and the top border width less six cells` (anatomy: titled; public API: title slot)
- `string title renders the same cells as a text title view` (public API: `String` convenience)
- `titled box ideal width fits the whole title` (sizing: nil x nil, titled)
- `overlong title truncates with the mark before the corner` (anatomy: title truncation)
- `title stays on one row and never wraps, whatever the height proposal` (anatomy: Wrap exception; title truncation)
- `box forwards the border style to the border contract` (public API: `border`)
- `child content stays inside the ring and padding; wrapping content re-lays out at the interior width` (anatomy: content region; sizing: 8x nil, 40x20)
- `one by one box paints only the corner and drops the title` (anatomy: declared minimum; sizing: 1x1)
- `zero area box paints nothing` (anatomy: declared minimum)
- `ascii degradation renders the ascii ring and truncation mark` (degradation: ASCII-only)

### Focus

- `self focus paints the heavy set in the focus role without moving the ring` (focus: self focus; focus border: rule 1)
- `focus within tints the nearest bordered ring at normal weight` (focus: focus within; focus border: rule 2)
- `focus within title takes the bold focus role` (focus: focus within)
- `nested focus tints only the nearest bordered ancestor` (focus: nested)
- `box with nothing focusable inside never changes` (focus: focus within)
- `focus within is off under focusSection or focusWithinBorder(false)` (state model: tint switch)
- `box joins focus only through an explicit focusable id` (focus: self focus; state model)
- `focus paints only the foreground of the ring and title and leaves backgrounds and title position unchanged` (focus: self focus; Decisions)
- `focusable box owns no key routing and gains no press behaviour` (State model; Decisions)

### Pointer

- `box names no hit region` (Decisions: hit testing deferred to Slice 5)

## Degradation

Per the [degradation ladder](../tokens.md#degradation-ladder), Box inherits Border's ring degradation and Text's truncation degradation: `NO_COLOR` and 16-color keep the geometry, ASCII-only swaps in the `ascii` ring and the `~` truncation mark. ASCII focus shows in bold, since ASCII has no heavier ring (focus border rule 6). Below the floor the docked title is dropped before it could overwrite a corner; child Text wraps at the interior width and breaks words between graphemes rather than clipping.

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

Box is Border plus one column of content padding on each side plus an optional title view, not a new layout engine. The title interrupts the top border in place and is grapheme-safe tail-truncated, so it can never desynchronize the ring or spill past a corner. The docked title is a documented wrap exception, not content (owner decision, 2026-10-18; see [Anatomy](#anatomy)). Box keeps the standalone [Border](border.md) modifier for the no-padding, no-title case; the two are not merged.

The title is a named `@ViewBuilder` slot with a `String` convenience (key A7), the counterpart of Boxed's live title child; plan 032 step 9.3 calls for a Box whose title is a view. Box draws a title only: omp2's border `footer` is rejected (key B5), the title docks leading because label alignment belongs to Divider's labelled rule (key B5), dashed rings are rejected (key K4), and a focusable Box gains no press behaviour (key C12).

The content padding is fixed at one column on each side and none above or below; applications needing more inset compose an ordinary `.padding` on the child rather than a second Box padding parameter. This keeps [Padding](padding.md) the single authoritative inset primitive. Plan 032 step 7.1 corrected the padding from every edge to horizontal only, to match the accepted [Focus](#focus) wireframes (owner decision, omp2 review, 2026-10), the in-border fixtures of [ScrollView](../widgets/scroll-view.md) and [ScrollIndicator](scroll-indicator.md), and omp2's `<box>` default.

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): Box is static chrome composed from existing primitives, its title is an ordinary child view rather than a string attribute, appearance comes from shared tokens, and geometry is deterministic integer-cell output.

Focus is an owner decision (omp2 review, 2026-10). A Box marked `.focusable(id)` paints the self-focus ring; a Box with a focused descendant tints its nearest bordered ring; a Box with nothing focusable inside never changes. The look follows the [Focus border](border.md#focus-border) rules. Box owns no key routing.

Box also anchors an edge-riding scroll indicator: under `.scrollIndicatorPlacement(.border)` a scrollable descendant's thumb rides Box's right ring, which serves as the track, and no interior cell is reserved. Key G4 keeps every view inside its own region, so Box paints those thumb cells over its ring after its descendants, as it paints delegated focus. The Box chrome is otherwise unchanged. How the descendant's resolved indicator geometry reaches Box is deferred to plan 032 step 9.4 ([ScrollIndicator](scroll-indicator.md#open-questions)).

Owner decision, 2026-10-10: Box hit testing is deferred to [Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md), together with whether an interactive bordered child needs a distinct decorative-versus-hit region (key F1: the Mouse table of an interactive view names its hit regions; Box has none).

## Open questions

None.

## Inspiration

Box is static terminal chrome for grouping content. It must remain a primitive: it may take focus for its look, never for key handling.
