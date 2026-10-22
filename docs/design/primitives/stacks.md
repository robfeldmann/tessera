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
[Slice 2 stack algorithm](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#the-stack-algorithm-normative).
This document fixes fixture-grade outcomes and composition expectations rather than
restating that algorithm.

## Prior art

- Ratatui `Layout`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/layout/layout.rs` —
  copy explicit integer allocation and deterministic ordering. Reject solver-driven
  constraints and implicit fractional rounding.
- Apple SwiftUI [HStack](https://developer.apple.com/documentation/swiftui/hstack) and
  [Spacer](https://developer.apple.com/documentation/swiftui/spacer) — copy familiar
  composition vocabulary. Reject a platform-dependent default gap; Tessera defaults to 0.
- Tessera [Slice 2](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md) — owns
  public APIs, priority tiers, flexibility probes, rounding, and overflow policy.
- omp2 `Col`
  ([col.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/col.rs#L15-L21)),
  `Row`
  ([row.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L13-L23)),
  and `Spacer`
  ([hr.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L300-L304))
  are the counterparts. Their attributes take the
  [translation key](../translation-key.md#b-attributes)'s forms: `gap` is `spacing:`,
  `align` and `valign` are `alignment:`, `justify` is Spacers between children, and `sep`
  is explicit `Divider()` children (key B4); `grow` is a `Spacer()` in a stack or
  `.flex(.fill(n))` in [Flex](flex.md) (keys B2 and G5), and `w=40%` is Flex's
  `.percentage(_:)` (key G8). Copy the gap-between-visible-children rule of omp2's
  [`stack_place`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L33-L60).
  Reject Row's default cross-axis stretch (key G7), its `wrap` mode (key G6), and a row
  cap on a stack (key B8); see
  [Decisions and deferred scope](#decisions-and-deferred-scope).

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

`VStack` rows stack with no gap at the default `spacing: 0`, and `.leading` keeps every
child at the left edge:

```wireframe 13x3
Build started
pass core
warn 2 lints
```

```text
Callouts (13x3, 0-based):
1. r0 c0-c12 Leading child -- first row at the main-axis origin.
2. r1 c0-c8 Next child -- placed directly below; spacing 0 adds no row.
3. r2 c0-c11 Trailing child -- last row; `.leading` pins every child to column 0.
```

Two equal-priority Spacers split the leftover main-axis cells, and the earliest Spacer
takes the odd cell:

```wireframe 40x1
left             middle            right
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c3   Leading child -- `left`, rigid four cells.
2. r0 c4-c16  First Spacer -- 13 cells; receives the one-cell remainder.
3. r0 c17-c22 Middle child -- `middle`, rigid six cells.
4. r0 c23-c34 Second Spacer -- 12 cells.
5. r0 c35-c39 Trailing child -- `right`, rigid five cells.
```

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
[catalog layout decisions](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#catalog-layout-decisions).

Children keep their measured cross-axis extent: a stack places each child at the size it
reports and positions it with `alignment`; it never stretches a child across the cross
axis. omp2's Row stretches its children to the tallest by default
([row.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L239-L274));
Tessera rejects that as a container default (key G7). A child that fills the cross axis
does so itself, as [Divider](divider.md) does.

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

Linear stacks consume no environment token and have no mutable state model. Each stack
establishes `stackAxis` as layout context for its subtree during its layout pass. The
nearest enclosing linear stack wins; the value is not application-visible state. Divider
is the first consumer.

| Container | Published `stackAxis` | Descendant rule                               |
| --------- | --------------------- | --------------------------------------------- |
| `HStack`  | `.horizontal`         | Divider renders a vertical cross-axis rule.   |
| `VStack`  | `.vertical`           | Divider renders a horizontal cross-axis rule. |

Child priority, measured ideal/minimum sizes, final frames, and clipping intersections are
derived for each layout pass and never stored (key D10).

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
- `linear stack publishes its axis to descendant layout context` (environment: `HStack`
  and `VStack` rows).

## Degradation

Stacks, Spacer, priority, and alignment have no glyph or style dependency. Every terminal
capability mode preserves integer distribution, source order, and parent-frame clipping.

## Decisions and deferred scope

Negative spacing and `minLength` use the pre-layout `precondition` diagnostics in
[catalog layout decisions](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#catalog-layout-decisions).
Baseline alignment is explicitly excluded from Phase 4 pending the scoped
[deferred baseline alignment](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#deferred-baseline-alignment)
proposal; it must not appear as an undocumented enum case.

Two equal Spacers share the remainder by source order: the earliest Spacer takes the extra
cell (owner decision, 2026-10-10). omp2's `<spacer>` is a `grow=1` child
([markup.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L515-L517)),
and its track solver gives each surplus cell to the best-scoring grow track, breaking ties
toward the later one
([layout.rs](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L153-L164)),
so the 40-column anatomy row gets gaps of 12 and 13 cells. Tessera keeps the
earliest-Spacer rule, as the allocation fixtures above state, under the normative
[Slice 2 stack algorithm](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#the-stack-algorithm-normative).

Flow layout (a row that wraps children onto new lines when the width runs out) is not an
HStack mode. `HStack` never wraps and gains no `wrap` argument. omp2's `wrap` row (key G6)
is Tessera's [flow layout](flow.md), specified in
[Flow layout and ViewThatFits](../../spec/phase-4/slice-06-grid-table-and-fitting.md#flow-layout-and-viewthatfits)
and built in plan 032 step 14.1; it sits outside the Slice 2 stack contract.

Stacks take no row cap and no press or focus behaviour. omp2's `max-rows` and its
`... N more` footer become `.maxRows(_:)` only on views whose doc defines the footer; an
overflowing stack goes in a ScrollView (key B8). A `col` with `focus` and `id` that emits
`Pressed` is a `Button` with a custom label, and a container that wants keys is
`.focusable(_:)` and handles them with `.onKey` (keys B10 and C12). A stack names no hit
regions of its own (key F1).

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): stacks are value
descriptions lowered to layout nodes, allocation is deterministic integer math that
`dump()` shows, they hold no state, and they touch no terminal capability.

## Inspiration

A terminal stack is readable integer allocation, not a constraint solver. Remainder order
is part of the visual contract because one cell is observable in snapshots.
