---
kind: primitive
status: ready
---

# Linear stacks

`HStack`, `VStack`, `Spacer`, and `layoutPriority` form one stateless linear-layout
contract. HStack lays children left-to-right with vertical cross-axis alignment; VStack is
the transposed top-to-bottom form with horizontal alignment. Spacer is a flexible empty
child whose minimum main-axis length is `minLength`. `layoutPriority` is immutable view
configuration read by stacks, not widget state.

The normative distribution algorithm remains
[Slice 2 stack algorithm](../../docs/Spec.md#the-stack-algorithm-normative). This document
fixes fixture-grade outcomes and composition expectations rather than restating that
algorithm.

## Prior art

- Ratatui `Layout`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/layout.rs` —
  copy explicit integer allocation and deterministic ordering. Reject solver-driven
  constraints and implicit fractional rounding.
- Apple SwiftUI [HStack](https://developer.apple.com/documentation/swiftui/hstack) and
  [Spacer](https://developer.apple.com/documentation/swiftui/spacer) — copy familiar
  composition vocabulary. Reject a platform-dependent default gap; Tessera defaults to 0.
- Tessera [Slice 2](../../docs/Spec.md#slice-2-the-layout-protocol-and-stack-containers) —
  owns public APIs, priority tiers, flexibility probes, rounding, and overflow policy.

## Anatomy

An `HStack(spacing: 1) { Text("A"); Spacer(); Text("B") }` assigned width nine:

```wireframe 9x1
A       B
```

```text
Callouts (9x1, 0-based):
1. r0 c0 Leading child -- rigid child placed first at the main-axis origin.
2. r0 c1-c7 Gap and Spacer region -- one spacing cell follows the leading child; Spacer consumes the remaining five cells.
3. r0 c8 Trailing child -- rigid child placed after Spacer at the final main-axis cell.
```

`VStack` uses the same semantics after transposition: `spacing` is rows, Spacer consumes
rows, and `.leading` / `.center` / `.trailing` align each child on the horizontal axis.

## Variants

| Component                       | Default                             | Main axis                                | Cross-axis alignment                              |
| ------------------------------- | ----------------------------------- | ---------------------------------------- | ------------------------------------------------- |
| `HStack`                        | `alignment: .top`, `spacing: 0`     | left-to-right columns                    | `.top`, `.center`, `.bottom`                      |
| `VStack`                        | `alignment: .leading`, `spacing: 0` | top-to-bottom rows                       | `.leading`, `.center`, `.trailing`                |
| `Spacer()`                      | `minLength: 0`                      | flexible empty extent                    | no rendered cross-axis content                    |
| `Spacer(minLength: n)`          | non-negative `n`                    | flexible extent, never below `n`         | no rendered cross-axis content                    |
| `.layoutPriority(p)`            | `p = 0` absent modifier             | groups descending by integer `p`         | consumed only by a parent linear stack            |
| Invalid `spacing` / `minLength` | none                                | rejected by `precondition` before layout | neither creates an overlap or negative allocation |

Spacing occurs only between adjacent children: an empty stack has no spacing and a
one-child stack has no leading or trailing spacing. `Spacer` is a child, so spacing on
each side of it is still ordinary inter-child spacing. Negative spacing and negative
`Spacer.minLength` are rejected by `precondition` before layout; neither can create an
overlap or negative allocation. See
[catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions).

## Sizing

For `HStack(spacing: 1) { Text("A"); Text("B") }`, both Text children are rigid `1x1`. The
stack's ideal is their main-axis sum plus one inter-child spacing cell; it never adds
outer padding. A narrow proposal does not force a child below its reported minimum: the
stack retains its layout extent and the parent's final frame clips the trailing content.

| Proposal  | Result | Rule                                                                                   |
| --------- | ------ | -------------------------------------------------------------------------------------- |
| nil x nil | 3x1    | Ideal is two rigid `1x1` children plus one inter-child spacing cell.                   |
| 3x1       | 3x1    | Tight proposal fits both rigid children and the gap exactly.                           |
| 2x1       | 3x1    | Rigid children keep their minimum widths; overflow clips trailing placement.           |
| 80x24     | 3x1    | Extra main- or cross-axis proposal does not stretch a stack without flexible children. |

## Allocation fixtures

| Stack proposal and children                                      | Child frames                                        | Rule                                                                                  |
| ---------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `HStack`, `9x1`: `A`, `Spacer()`, `B`, spacing 1                 | `A: (0,0) 1x1`; `Spacer: (2,0) 5x1`; `B: (8,0) 1x1` | The single flexible Spacer consumes the post-spacing remainder.                       |
| `HStack`, `5x1`: `Spacer()`, `Spacer()`                          | first: `(0,0) 3x1`; second: `(3,0) 2x1`             | The earliest equal-priority flexible child receives the one-cell integer remainder.   |
| `HStack`, `4x1`: `Spacer().layoutPriority(1)`, `Spacer()`        | first: `(0,0) 4x1`; second: `(4,0) 0x1`             | Descending priority tiers receive allocation before lower-priority flexible children. |
| `VStack`, `3x5`: `Text("A")`, `Spacer()`, `Text("B")`, spacing 1 | `A: (0,0) 1x1`; `Spacer: (0,2) 1x1`; `B: (0,4) 1x1` | The algorithm transposes and preserves one spacing row between each adjacent child.   |
| `HStack`, `2x1`: `Text("A")`, `Text("B")`, `Text("C")`           | `A: (0,0) 1x1`; `B: (1,0) 1x1`; `C: (2,0) 1x1`      | No allocation is negative or below minimum; only trailing overflow is clipped.        |
| `HStack`, `3x1`: `Text("A")`, spacing 2                          | `A: (0,0) 1x1`                                      | A single child receives no leading or trailing spacing.                               |
| Empty `HStack`, `9x1`, spacing 2                                 | no child frames                                     | An empty stack has no inter-child spacing, reports `0x0`, and paints nothing.         |

Each listed origin is absolute after the parent origin is added. A custom Layout may read
priority through `Subviews`; only a linear stack consumes it according to this contract.

## Environment

Linear stacks consume no environment token and have no mutable state model. Child
priority, measured ideal/minimum sizes, final frames, and clipping intersections are
derived for each layout pass.

## Requirements

- `hstack reports rigid children plus inter-child spacing` (sizing: nil x nil).
- `hstack preserves rigid child minima under a narrow proposal` (sizing: 2x1).
- `stack rejects negative spacing and spacer minima before layout` (variants: Invalid
  `spacing` / `minLength`).
- `spacer consumes the remaining main-axis allocation` (allocation fixtures: `HStack`,
  `9x1`: `A`, `Spacer()`, `B`, spacing 1).
- `equal-priority flexible children give the extra cell to the earliest child` (allocation
  fixtures: `HStack`, `5x1`: `Spacer()`, `Spacer()`).
- `higher layout priority allocates before lower priority` (allocation fixtures: `HStack`,
  `4x1`: `Spacer().layoutPriority(1)`, `Spacer()`).
- `vstack transposes spacer allocation and cross-axis placement` (allocation fixtures:
  `VStack`, `3x5`: `Text("A")`, `Spacer()`, `Text("B")`, spacing 1).
- `linear stack clips trailing overflow without negative allocation` (allocation fixtures:
  `HStack`, `2x1`: `Text("A")`, `Text("B")`, `Text("C")`).
- `single-child stack introduces no spacing` (allocation fixtures: `HStack`, `3x1`:
  `Text("A")`, spacing 2).
- `empty stack introduces no spacing and paints nothing` (allocation fixtures: Empty
  `HStack`, `9x1`, spacing 2).

## Degradation

Stacks, Spacer, priority, and alignment have no glyph or style dependency. Every terminal
capability mode preserves integer distribution, source order, and parent-frame clipping.

## Decisions and deferred scope

Negative spacing and `minLength` use the pre-layout `precondition` diagnostics in
[catalog layout decisions](../../docs/Spec.md#catalog-layout-decisions). Baseline
alignment is explicitly excluded from Phase 4 pending the scoped
[deferred baseline alignment](../../docs/Spec.md#deferred-baseline-alignment) proposal; it
must not appear as an undocumented enum case.

## Inspiration

A terminal stack is readable integer allocation, not a constraint solver. Remainder order
is part of the visual contract because one cell is observable in snapshots.
