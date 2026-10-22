---
kind: primitive
status: ready
---

# Leading rail

`.leadingRail(style:role:)` is a modifier that draws a vertical rule down the leading edge
of its content, in one semantic role. It reserves two columns: the rail in column 0, then
one blank gap column, so content starts at column 2. It is stateless: no focus, no
bindings, no key or pointer handling. [Callout](../widgets/callout.md) uses it for the
kind rail. [Markdown](../widgets/markdown.md) uses it for block quote rails, one per
nesting level.

## Prior art

- omp2 Callout reserves two columns for its rail at
  [#L153-L166](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L153-L166)
  and paints the kind-coloured rail beside each body row at
  [#L314-L329](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L314-L329).
  Copy the one-column rail in the kind's colour, the gap before the body, and the rail on
  every wrapped row: a hanging prefix is layout, so the rail holds it (key I2), and the
  kind names become hue roles (key J5). Reject the left-edge `▎` rail of `Charset::rail`
  ([context.rs#L235-L240](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L235-L240);
  owner decision, omp2 review, 2026-10). The rail is a light `│` in column 0; the earlier
  centre-under-the-header-icon rule is dropped, and the rail never moves with the icon
  (owner decision, 2026-10-18).
- omp2 Quote,
  [quote.rs#L12-L13](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/quote.rs#L12-L13),
  draws `quote_rail`'s `│` and a blank column
  ([context.rs#L177-L183](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L177-L183))
  beside each wrapped row, in `muted`
  ([#L66-L73](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/quote.rs#L66-L73)).
  Copy the light vertical, its ASCII `|`, and the one-column gap; rails use the `light`,
  `heavy`, and `ascii` verticals (key K7). omp2's `muted` is the `secondary` role (key
  J1), but Markdown's quote rail passes `border` ([Markdown](../widgets/markdown.md)).
- omp2 Input's focus rail,
  [input.rs#L442-L454](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L442-L454),
  is `▎` in `accent` when focused and `▏` in `border` otherwise. Reject it: focus is the
  `focus` role and the focus border (key E2), and the leading rail holds no focus state.
- SwiftUI has no leading-rule modifier. The nearest form is an overlay on a leading
  `Rectangle`; the primitive replaces that with a glyph-drawn rail so it works in a
  terminal cell grid.

## Anatomy

A rail beside three lines of content. The rail sits in column 0, the content starts at
column 2.

```wireframe 24x3
│ The rail sits here
│ in column 0, then a
│ gap; text starts at 2.
```

```text
Leading rail (24x3, 0-based):
1. r0-r2 c0   Rail -- light vertical `│`, the role passed to `role:`
2. r0-r2 c1   Gap -- one blank column
3. r0-r2 c2   Content -- the modified view, starting at column 2
```

```text
── chars ──
│ The rail sits here
│ in column 0, then a
│ gap; text starts at 2.
── style ──
A.......................
A.......................
A.......................
── legend ──
A  fg=info -- the rail, in the caller's role (here info)
.  default
```

The rail is always column 0 (owner decision, 2026-10-18). Under a one-cell header icon it
shares the icon's column. Under a two-cell icon (a wide emoji or Nerd Font glyph) it sits
under the icon's left edge. Under the ASCII charset it is column 0 too, because bracketed
icons cannot be centred over it. There is no centre-cell rule: the rail never moves with
the icon's width.

## Variants

The rail glyph comes from the border glyph table in
[tokens.md](../tokens.md#divider-glyphs).

| Style   | Glyph | Notes                                                          |
| ------- | ----- | -------------------------------------------------------------- |
| `light` | `│`   | default                                                        |
| `heavy` | `┃`   | ships in 1.0 (owner decision, 2026-10-10); same column         |
| `ascii` | `\|`  | degradation target; the ASCII charset selects it automatically |

`role:` takes the caller's role. Callout passes its kind role (`info`, `success`,
`warning` or `error`; [hue roles](../tokens.md#hue-roles)). Markdown quotes pass `border`.

```swift
public enum LeadingRailStyle: Sendable {
    case light, heavy
}

extension View {
    public func leadingRail(style: LeadingRailStyle = .light, role: Style) -> some View
}
```

The rail's style and role are parameters of the modifier. `role:` takes the caller's role
as a complete `Style` (key J1); how an app names a role is deferred to plan 032 step 9.1
([Style modifiers](style-modifiers.md#open-questions)), while Callout and Markdown pass
resolved roles.

Heavy and ASCII fixtures, each beside the same three lines of content (the rail stays in
column 0 and the content in column 2):

```wireframe 24x3
┃ The rail sits here
┃ in column 0, then a
┃ gap; text starts at 2.
```

```wireframe 24x3
| The rail sits here
| in column 0, then a
| gap; text starts at 2.
```

## Sizing

Schema: [README](../../design.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal     | Result                                                    | Rule                                               |
| ------------ | --------------------------------------------------------- | -------------------------------------------------- |
| nil x nil    | Width is content width plus 2; height is content height   | The rail takes column 0 and the gap takes column 1 |
| 2 x any      | Rail and gap only; content gets no columns                | Content gets zero width and draws nothing          |
| under 2      | Not a supported floor: the parent clips the rendered rows | No layout is specified below 2 columns             |
| over-maximum | Content takes the proposed width minus 2                  | The rail does not grow                             |

## Environment

- Rail glyphs `│`, `┃`, `|`: [tokens.md](../tokens.md#divider-glyphs).
- Rail role: the caller's role. Kind roles are the [hue roles](../tokens.md#hue-roles).
  The Markdown quote rail is `border`, as [Markdown](../widgets/markdown.md) defines it
  ([border role](../tokens.md#text-roles)).

## Requirements

- `leading rail light style draws a vertical in column 0 and leaves column 1 blank`
  (Anatomy)
- `leading rail content starts at column 2` (Anatomy; sizing: nil x nil, over-maximum)
- `leading rail heavy style draws the heavy vertical in the same column` (Variants: heavy
  fixture)
- `leading rail ASCII charset draws a pipe at column 0` (Variants: ASCII fixture)
- `leading rail draws in the caller's role` (Variants)

## Degradation

- ASCII-only: the rail is `|` at column 0; the glyph is selected from the
  [degradation ladder](../tokens.md#degradation-ladder).
- `NO_COLOR`: the rail glyph stays and its role colour is lost.
- 16-colour: the rail takes its role's `slots` column ([roles](../tokens.md#roles);
  [degradation ladder](../tokens.md#degradation-ladder)).

## Primitive dependencies

None. Consumers: [Callout](../widgets/callout.md), [Markdown](../widgets/markdown.md).

## Open questions

- Resolved: reviewed against the [Phase 4 theses](../../spec/phase-4.md). The leading rail
  is a unary layout wrapper plus a render decoration, like Border; its glyph and role come
  from tokens and the environment, and its geometry is deterministic integer-cell output.

## Inspiration

- None yet.
