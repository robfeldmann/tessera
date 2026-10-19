---
kind: primitive
status: wireframed
---

# Leading rail

`.leadingRail(style:role:)` is a modifier that draws a vertical rule down the leading edge
of its content, in one semantic role. It reserves two columns: the rail in column 0, then
one blank gap column, so content starts at column 2. It is stateless: no focus, no
bindings, no key or pointer handling. [Callout](../widgets/callout.md) uses it for the
kind rail. [Markdown](../widgets/markdown.md) uses it for block quote rails, one per
nesting level.

## Prior art

- omp2 Callout paints its kind-coloured rail beside the body at
  [#L153-L166](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L153-L166).
  Copy the one-column rail in the kind's colour and the gap before the body. Reject the
  left-edge `▎` rail: owner decision, omp2 review, 2026-10, centres the rail under the
  header icon instead.
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
A  fg=role (the rail; the caller's role)
.  default
```

The rail column is the centre cell of the header icon it sits under. For a one-cell icon
that is column 0. Under the ASCII charset the rail is always column 0, because bracketed
icons cannot be centred over it (owner decision, 2026-10-10).

## Variants

The rail glyph comes from the border glyph table in
[tokens.md](../tokens.md#divider-glyphs).

| Style   | Glyph | Notes                                                          |
| ------- | ----- | -------------------------------------------------------------- |
| `light` | `│`   | default                                                        |
| `heavy` | `┃`   | ships in 1.0 (owner decision, 2026-10-10); same column         |
| `ascii` | `\|`  | degradation target; the ASCII charset selects it automatically |

`role:` takes the caller's semantic role. Callout passes its kind role (token pending plan
032 step 5.3). Markdown quotes pass `muted`.

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal     | Result                                                    | Rule                                               |
| ------------ | --------------------------------------------------------- | -------------------------------------------------- |
| nil x nil    | Width is content width plus 2; height is content height   | The rail takes column 0 and the gap takes column 1 |
| 2 x any      | Rail and gap only; content gets no columns                | Content clips to zero width                        |
| under 2      | Not a supported floor: the parent clips the rendered rows | No layout is specified below 2 columns             |
| over-maximum | Content takes the proposed width minus 2                  | The rail does not grow                             |

## Environment

- Rail glyphs `│`, `┃`, `|`: [tokens.md](../tokens.md#divider-glyphs).
- Rail role: the caller's semantic role. Kind roles are token pending plan 032 step 5.3.
  The Markdown quote role is `muted`, as [Markdown](../widgets/markdown.md) defines it.

## Requirements

- `leading rail light style draws a vertical in column 0 and leaves column 1 blank`
  (Anatomy)
- `leading rail content starts at column 2` (Anatomy; Callout States: Mobile)
- `leading rail heavy style draws the heavy vertical in the same column` (Callout States:
  Heavy rail)
- `leading rail ASCII charset draws a pipe at column 0` (Callout States: ASCII)
- `leading rail draws in the caller's role` (Variants)

## Degradation

- ASCII-only: the rail is `|` at column 0; the glyph is selected from the
  [degradation ladder](../tokens.md#degradation-ladder).
- `NO_COLOR`: the rail glyph stays and its role colour is lost.
- 16-colour: roles follow their token rows once plan 032 step 5.3 defines them.

## Primitive dependencies

None. Consumers: [Callout](../widgets/callout.md), [Markdown](../widgets/markdown.md).

## Open questions

- Rail column when the header icon is wider than one cell (Nerd Font glyphs): column 0 or
  the centre cell. Unblocks: Label icon width rules and this primitive's `ready` state.

## Inspiration

- None yet.
