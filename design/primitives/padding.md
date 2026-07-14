---
kind: primitive
status: specified
---

# Padding

`padding` is a stateless layout modifier that reserves empty cells around one child. It
reduces the child's proposal by its insets, reports the child's measured size plus those
insets, and places the child at the inset origin. It draws nothing, owns no input, and
never creates Button-specific content insets; a padded Button label therefore composes as
`Button { Text("Save").padding(1) }` to render `[ Save ]`.

## Prior art

- Ratatui `Layout`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/layout.rs` —
  copy explicit integer-cell constraints and rectangle partitioning. Reject a separate
  visual chrome concept for ordinary content insets.
- Apple SwiftUI
  [View.padding](<https://developer.apple.com/documentation/swiftui/view/padding(_:)>) —
  copy a composable modifier that changes layout rather than its child's content model.
- Tessera [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers) —
  `padding` is one public layout modifier; parent-frame clipping remains normative there.

## Anatomy

A one-cell all-edge inset around `Text("Go")`:

```wireframe 4x3

 Go

```

```text
Callouts (4x3, 0-based):
1. r0, r2, c0, c3 Inset cells -- allocated empty cells owned by Padding; no glyph is drawn.
2. r1 c1-c2 Child region -- child receives origin (1, 1) and its reduced proposal.
```

## Variants

| Configuration                                                      | Insets                             | Behavior                                                        |
| ------------------------------------------------------------------ | ---------------------------------- | --------------------------------------------------------------- |
| `.padding()` / `.padding(1)`                                       | top, leading, bottom, trailing = 1 | Default uniform one-cell inset.                                 |
| `.padding(n)`                                                      | every edge = `n`                   | `n` is a non-negative integer; it reserves `2n` cells per axis. |
| `.padding(EdgeInsets(top: t, leading: l, bottom: b, trailing: r))` | explicit `t`, `l`, `b`, `r`        | Each non-negative edge is independently applied.                |

Nested Padding composes outside-in: each modifier reserves its own cells, reduces the next
child proposal, and adds its own insets to the resulting size. There is no margin-collapse
rule.

## Sizing

For `Text("Go").padding(1)`, the intrinsic child is `2x1`. Padding subtracts horizontal
and vertical inset totals from finite proposals without allowing a negative child
proposal; it reports the child's measured size plus the totals. A too-small parent
allocation is not silently shrunk: the parent assigns its final frame and clipping hides
the excess.

| Proposal  | Result | Rule                                                                                                           |
| --------- | ------ | -------------------------------------------------------------------------------------------------------------- |
| nil x nil | 4x3    | Ideal is the intrinsic `2x1` child plus one cell on all four edges.                                            |
| 4x3       | 4x3    | Tight fit leaves the child its exact `2x1` reduced proposal.                                                   |
| 1x1       | 4x3    | Insets reduce the child proposal to `0x0`; intrinsic measurement still reports the uncompressed layout extent. |
| 80x24     | 4x3    | Extra proposal does not stretch Padding or its non-flexible Text child.                                        |

Placement offsets the child's absolute origin by `(leading, top)`. Padding's own final
frame, rather than the child's intrinsic bounds, is the region inherited by later
rendering and hit-testing clipping. This follows the
[Slice 2 placement contract](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers).

## Environment

Padding consumes no environment token and has no state model. `EdgeInsets`, alignment, and
final allocated frames are layout values supplied by Slice 2, not environment
configuration.

## Requirements

- `uniform padding reports child size plus all insets` (sizing: nil x nil).
- `padding reduces a finite child proposal without going negative` (sizing: 1x1).
- `padding offsets its child by leading and top insets` (anatomy: Child region).
- `nested padding preserves each inset layer` (variants: nested Padding).
- `parent frame clips padded content outside its allocation` (sizing: 1x1).
- `padding inside a button label creates compact interior space` (overview: `[ Save ]`
  composition).

## Degradation

Padding has no glyph, style, color, or capability dependency. ASCII-only, `NO_COLOR`, and
reduced-color terminals preserve the same integer geometry and clipping.

## Open questions

- Validate whether public `EdgeInsets` rejects negative values or clamps them to zero
  while finalizing the Slice 2 API. This document requires that negative insets never
  produce a negative proposal or inverted frame.

## Inspiration

Use Padding to separate semantic content from structural whitespace. A Button style may
draw brackets around a padded label, but it must not duplicate this modifier's geometry.
