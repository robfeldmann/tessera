---
kind: primitive
status: ready
---

# ViewThatFits

`ViewThatFits` is a stateless layout container. It holds candidate arrangements of the same content, in order of preference, and shows exactly one of them: the first whose ideal size fits the proposal on the tested axes, or the last when none fits. It works the choice out again from the proposal on every layout pass and stores nothing. It draws no cells, handles no input and takes no focus; the chosen candidate does all of that. It is Tessera's one mechanism for changing an arrangement with the space available ([fitting](../../spec/phase-4/slice-06-grid-table-and-fitting.md#flow-layout-and-viewthatfits); key G10 of the [translation key](../translation-key.md)). A component that switches between layouts does it with `ViewThatFits`, not with a rule of its own. [Flow](flow.md) is its companion: `ViewThatFits` chooses between arrangements, and Flow wraps items within one.

## Prior art

- Apple SwiftUI [ViewThatFits](https://developer.apple.com/documentation/swiftui/viewthatfits) -- copy the selection model whole. Children are evaluated "in the order you provide them", and the view "selects the first child whose ideal size on the constrained axes fits within the proposed size". `init(in:content:)` constrains both axes by default, and an empty axis set uses the first child. Apple's reference does not say what happens when no child fits; Tessera states it (the last candidate) and adds the identity, focus and measurement-cost rules below.
- omp2 Fact ([fact.rs#L74-L114](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/fact.rs#L74-L114)) decides inline or stacked inside the component: inline when the label, one cell and the value's minimum width fit. Copy the outcome, one arrangement per layout pass decided by measurement. Reject the per-component rule (key G10) and the minimum-width test: `ViewThatFits` tests ideal size (see [Open questions](#open-questions)).
- omp2 Tabs ([tabs.rs#L153-L200](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L153-L200)) keeps full-label chips while the bar fits one row, collapses inactive chips to icons when it does not, and wraps the chips if even that overflows. Tessera splits that one function in two: the collapse is a candidate list, and the wrap is [Flow](flow.md).
- omp2 Status ([status.rs#L48-L70](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/status.rs#L48-L70)) returns no layout when its segment groups do not fit, and its caller drops trailing segments whole. In Tessera a segment that may drop is a `ViewThatFits` whose last candidate shows nothing, and `.layoutPriority(_:)` on the siblings decides which drops first.
- Tessera [Linear stacks](stacks.md) and [Flex](flex.md) own the priority tiers and `.layoutPriority(_:)`, the only priority API. `ViewThatFits` adds none.

## Anatomy

The Region fixture offers a one-row arrangement and a stacked one, and tests width only:

```swift
ViewThatFits(in: .horizontal) {
  HStack(spacing: 1) { Text("Region"); Text("Frankfurt") }
  VStack { Text("Region"); Text("Frankfurt") }
}
```

At 16 columns the first candidate's ideal width, `6 + 1 + 9 = 16`, fits:

```wireframe 16x1 id=beside
Region Frankfurt
```

```text
Callouts (16x1, 0-based):
1. r0 c0-c15  Chosen candidate -- candidate 0, the HStack. Its 16-cell ideal width fits the
              16-cell proposal, so it is placed at the container's origin.
2. r0 c6      Spacing cell -- the HStack's own `spacing: 1`; ViewThatFits adds no cells.
3. no cells   Unchosen candidate -- candidate 1, the VStack, is never placed: a zero-size
              frame, nothing rendered, no hit testing, no focus.
```

At 15 columns the HStack no longer fits, and the VStack's ideal width, 9, does:

```wireframe 15x2 id=stacked
Region
Frankfurt
```

```text
Callouts (15x2, 0-based):
1. r0-r1 c0-c8  Chosen candidate -- candidate 1, the VStack; its 9-cell ideal width fits 15.
2. no cells     Unchosen candidate -- candidate 0, the HStack: measured, rejected, not placed.
3. r0-r1 c9-c14 Unused width -- ViewThatFits reports the chosen candidate's 9x2 and fills
                nothing.
```

`ViewThatFits` has no floor of its own; its candidates do. This fixture keeps every word whole down to nine columns, the widest word of its last candidate:

```wireframe 9x2 id=min
Region
Frankfurt
```

```text
Callouts (9x2, 0-based):
1. r0-r1 c0-c8  Chosen candidate -- candidate 1 at its ideal width; `Frankfurt` fills r1.
```

Below that no candidate fits, so the last one is chosen anyway, and its Text breaks the words between grapheme clusters ([Text](text.md#wrapping)):

```wireframe 5x4 id=under-minimum
Regio
n
Frank
furt
```

```text
Callouts (5x4, 0-based):
1. r0-r3 c0-c4  Chosen candidate -- candidate 1, the last, chosen although its ideal width
                (9) does not fit. Nothing is clipped.
2. r0-r1        `Region` -- content, wraps: its first five cells, then `n`.
3. r2-r3        `Frankfurt` -- content, wraps: broken into `Frank` and `furt`.
```

The Deploying fixture tests height only, so a candidate wraps at the proposed width before its rows are compared:

```swift
ViewThatFits(in: .vertical) {
  Text("Deploying to Frankfurt")
  Text("Deploying")
}
```

```wireframe 12x2 id=vertical-wraps
Deploying to
Frankfurt
```

```text
Callouts (12x2, 0-based):
1. r0-r1 c0-c11 Chosen candidate -- candidate 0 measured at 12 x nil is two rows, and two
                rows fit the two-row proposal. Width is not tested, so its 22-cell ideal
                width does not matter; content, wraps.
```

```wireframe 12x1 id=vertical-shorter
Deploying
```

```text
Callouts (12x1, 0-based):
1. r0 c0-c8   Chosen candidate -- candidate 1: candidate 0 needs two rows at 12 columns,
              and candidate 1 needs one.
2. no cells   Unchosen candidate -- candidate 0, not placed.
```

## Variants

| Configuration | Tested axes | Fit-test proposal | Behavior |
| --- | --- | --- | --- |
| `ViewThatFits { … }` | width and height (`.all`, the default) | nil x nil | A candidate fits when its ideal width and its ideal height both fit. |
| `ViewThatFits(in: .horizontal) { … }` | width | nil x incoming height | The unwrapped ideal width is compared; the height passes through and is not compared. |
| `ViewThatFits(in: .vertical) { … }` | height | incoming width x nil | Content wraps at the incoming width, and its rows are compared. |
| `ViewThatFits(in: []) { … }` | none | incoming proposal | The first candidate is always chosen. |
| one candidate | as configured | as configured | That candidate is always chosen. |
| no candidates | -- | -- | Reports `0x0` and places nothing. |
| `EmptyView()`, an absent `if` branch, or an empty ForEach | -- | -- | Contributes no candidate. A candidate that shows nothing is a child that measures `0x0`. |
| `.layoutPriority(_:)` on a candidate | -- | -- | Ignored: source order alone ranks candidates. Priority is read by a parent stack or Flex only. |

The candidates are the content's direct children, enumerated as a stack enumerates its children: each element of the builder block, each `ForEach` element, and the present branch of a conditional. A candidate meant to show nothing must still be a child, for example `EmptyView().frame(width: 0, height: 0)`.

```swift
public struct ViewThatFits<Content: View>: View {
  public init(in axes: Axis.Set = .all, @ViewBuilder content: () -> Content)
}
```

`ViewThatFits` is a `View`, like `HStack` and `Flex`. Its algorithm uses only the public [Layout protocol](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#the-protocol) (`Subview.sizeThatFits` and `place`), so a third party could write the same container.

## Selection rule

This rule is normative. `sizeThatFits` and `placeSubviews` both run it, so measurement and placement always agree. For an incoming proposal `P` and tested axes `A`:

1. **Fit-test proposal.** `T` is `P` with every tested axis replaced by nil. A nil axis asks for the ideal (key G1), so `T` asks each candidate for its ideal size on the tested axes and passes the untested axes through.
2. **Fit test.** In source order, measure candidate `i` at `T`. It fits when, on every tested axis, `P` is nil there or the measured extent is at most `P`'s. A nil incoming axis always fits.
3. **Choice.** The first candidate that fits is chosen. If none fits, the last candidate is chosen. Candidates after the chosen one are not measured.
4. **Size.** `ViewThatFits` reports the chosen candidate measured at `P`. When `P` is nil on every tested axis, `T` equals `P`, and this is the measurement step 2 already made. When no candidate fits, the result can be larger than `P`; the parent clips it as it clips any overflow.
5. **Placement.** `placeSubviews` repeats steps 1 to 3 with its own proposal, places the chosen candidate at the top-leading corner of its bounds with that proposal, and does not place the others. A subview that is not placed is hidden with a zero rectangle ([the protocol](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#the-protocol)).

The choice is stable under its own size. A parent that measures `ViewThatFits` at one proposal and then re-proposes the size it reported, as a linear stack does between its share and its allocation, gets the same candidate: every earlier candidate's ideal still exceeds the smaller proposal, and the chosen candidate still fits the size it reported. The [allocation fixtures](#allocation-fixtures) pin this.

## Measurement cost and purity

- Every measurement goes through `Subview.sizeThatFits`, which the graph memoizes per node and proposal within a layout pass ([the protocol](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#the-protocol)).
- For one incoming proposal, `ViewThatFits` makes at most `k + 1` distinct child measurements, where `k` is the chosen candidate's 1-based position: `k` at `T` and one at `P`. Candidates after the chosen one cost nothing, and placement reruns the rule from memoized results.
- A parent's probes often share one `T`. An `HStack` probes a child at `(nil, h)` for its ideal and at `(0, h)` for its minimum; with width tested, both probes give `T = (nil, h)`, so each candidate is fit-tested once for both.
- Nesting adds only distinct proposals: an inner `ViewThatFits` receives the outer `T` and `P`, and makes at most its own `k + 1` measurements for each.
- Measurement is pure. Measuring a candidate never changes its `NodeState` ([runtime ownership invariant](../../design.md#state-model-table)), and the choice is never stored, so there is no cache to invalidate. Anything that sets `needsLayout`, a resize included, reruns the rule.

## Layout priority

Candidate order is source order. `.layoutPriority(_:)` on a candidate does nothing here; as in [Linear stacks](stacks.md#variants), only an enclosing stack or Flex reads priority.

`.layoutPriority(_:)` on the `ViewThatFits` itself is read by its parent like any child's. To that parent a `ViewThatFits` is flexible. Its ideal is the first candidate's ideal, because a nil tested axis always fits. Its minimum is the last candidate measured at zero, because zero fits only a candidate whose ideal is zero on that axis. The parent allocates by its own rules ([stack algorithm](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#the-stack-algorithm-normative), [Flex remainder and priority](flex.md#remainder-and-priority)), and the `ViewThatFits` then chooses at its allocation. A sibling with higher priority is allocated first and so keeps its preferred candidate longer. That composition is priority fitting: one shared mechanism instead of per-component drop rules (plan 032 step 14.1, owner decision 2).

### Allocation fixtures

`HStack(spacing: 1)` with two children, A and B:

```swift
let a = ViewThatFits(in: .horizontal) { Text("Downloading"); Text("DL") }
let b = ViewThatFits(in: .horizontal) { Text("model weights"); Text("weights") }
```

A's ideal is 11 and B's is 13; both minimums are 0, so both are flexible.

| Stack proposal and children | Child frames | Rule |
| --- | --- | --- |
| `20x1`: `a`, `b` | A: `(0,0) 2x1` `DL`; B: `(3,0) 13x1` | Equal priority: the stack offers A `ceil(19 / 2) = 10` cells, where only `DL` fits. B is offered the remaining 17 and keeps `model weights`. |
| `20x1`: `a.layoutPriority(1)`, `b` | A: `(0,0) 11x1` `Downloading`; B: `(12,0) 7x1` | A's tier is allocated first and keeps `Downloading`. B is offered the remaining 8 cells, where only `weights` fits. |
| `30x1`: `a`, `b` | A: `(0,0) 11x1`; B: `(12,0) 13x1` | Both first candidates fit: A is offered 15, B the remaining 18. |
| `8x1`: `a`, `b` | A: `(0,0) 2x1` `DL`; B: `(3,0) 5x1` `weig…` | A is offered 4 and shows `DL`. B is offered 5, where neither candidate fits, so the last draws: `weights` under a one-row budget ends in the mark ([Text](text.md#row-budget)). |

In every row the stack re-measures each child at its allocation and gets the same candidate.

```wireframe 20x1 id=equal-priority
DL model weights
```

```text
Callouts (20x1, 0-based):
1. r0 c0-c1   A -- `DL`: at its 10-cell share `Downloading` does not fit.
2. r0 c3-c15  B -- `model weights`: its first candidate fits the remaining 17 cells.
3. r0 c16-c19 Unused width -- the stack reports 16 cells.
```

```wireframe 20x1 id=priority
Downloading weights
```

```text
Callouts (20x1, 0-based):
1. r0 c0-c10  A -- `Downloading`: priority 1 is allocated first, from all 19 cells.
2. r0 c12-c18 B -- `weights`: only the last candidate fits the remaining 8 cells.
```

## Identity, state, and focus

Every candidate is a structural child of the `ViewThatFits` with its own identity ([identity model](../../spec/phase-4/identity-model.md)): its position in the builder block, a `ForEach` element's id, or a branch. The graph builds and updates every candidate on every update, chosen or not, because measuring a candidate needs its node. Choosing is a layout decision over nodes that already exist: switching candidates creates and destroys no node and moves no state.

Schema: [README](../../design.md#state-model-table).

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| chosen candidate | derived | `Int`, the candidate's position | Recomputed from the proposal in every `sizeThatFits` and `placeSubviews`; never stored, so nothing resets or clamps. `ViewThatFits` itself has no `NodeState`. |
| candidate state | NodeState | each candidate's own `NodeState` | Lives on the candidate's node while the `ViewThatFits` and the candidate keep their identity. A switch neither resets nor transfers it; the candidate applies its own clamp rule on its next layout as the chosen one (a ScrollView clamps its offset). |
| focus membership | derived | `Bool` for each `.focusable` node | Recomputed after every layout pass: only focusable nodes inside the chosen candidate are in `focusableIDs`. |

Each candidate's `NodeState` has exactly one owner, its own node. A view repeated in two candidates is two nodes with two states. State that must survive a switch lives above the `ViewThatFits`, in the widget's own `NodeState` or in a `Binding`.

How the graph's passes treat the candidates:

| Pass | Chosen candidate | Unchosen candidates |
| --- | --- | --- |
| update | built and reconciled | built and reconciled; they are live nodes |
| layout | measured at `T` and `P`, then placed | measured at `T` only if they come before the chosen one; never placed |
| render | renders into its frame | render nothing: a zero-size frame |
| hit testing | hit-tested normally | never hit |
| focus order | its focusable nodes are listed | their focusable nodes are left out |
| key routing | routed while focused | never focused, so never routed |
| terminal requirements | contributes | contributes: the union covers every live node, so a switch never toggles a terminal mode |
| `dump()` | proposal, size, and frame | a zero-size frame at the container's origin |

Focus follows the [focus model](../../spec/phase-4/slice-04-focus-and-key-routing.md#focus-model). Focus is held as a `FocusID`, and the focus order is the depth-first order of `.focusable` nodes after layout. When the focused node leaves that order, focus clears to nil, the graph records it in `statistics`, and no neighbour is guessed. A switch is checked after every layout pass, a resize included, not only after an update.

| Arrangement change | Focus before | Focus after | Rule |
| --- | --- | --- | --- |
| none: the same candidate stays chosen | `id` | `id` | Nothing moves. |
| the newly chosen candidate also holds a focusable with the same `id` | `id` | `id`, now on the new candidate's node | The focus manager holds a `FocusID`, not a node. That node's `NodeState` is its own, not the old one's. |
| the newly chosen candidate holds no focusable with `id` | `id` | nil, recorded in `statistics` | The focused node left the focus order; no neighbour is guessed. |
| the focusable sits outside the `ViewThatFits`, around the whole choice | `id` | `id` | The recommended shape for widgets: a switch never touches focus. |
| focus traversal while a candidate is unchosen | any | skips the unchosen candidates | Unplaced nodes are not in `focusableIDs`. |

An app that puts the same focusable in two candidates gives it the same `FocusID` in each. Only the chosen one is in the focus order, so the ID is never listed twice.

## Sizing

Schema: [README](../../design.md#sizing-table). The Region and Deploying fixtures are the ones in [Anatomy](#anatomy).

| Proposal | Result | Rule |
| --- | --- | --- |
| Region, nil x nil | 16x1 | A nil width always fits, so candidate 0 is chosen and reports its ideal. |
| Region, 16x1 | 16x1 | Tight: candidate 0's ideal width equals the proposal. |
| Region, 20 x nil | 16x1 | Candidate 0 fits, and the HStack does not stretch to 20. |
| Region, 15 x nil | 9x2 | Candidate 0 needs 16 cells; candidate 1's ideal width, 9, fits. |
| Region, 9 x nil | 9x2 | Minimum: candidate 1 at its ideal width keeps every word whole. |
| Region, 5 x nil | 5x4 | Under-minimum: no candidate fits, so the last is chosen, and its words break between grapheme clusters. |
| Region, 0 x nil | 0x2 | The last candidate at zero width: each Text is `0x1` and paints nothing. |
| Region, 80x24 | 16x1 | Over-maximum: candidate 0 fits, and extra width and height stretch nothing. |
| Deploying, nil x nil | 22x1 | A nil height always fits; candidate 0 reports its one-row ideal. |
| Deploying, 12 x nil | 12x2 | A nil height always fits; candidate 0 wraps at 12 columns into two rows. |
| Deploying, 12x2 | 12x2 | Tight: candidate 0 at 12 x nil is two rows, which fit two. Width is not tested. |
| Deploying, 12x1 | 9x1 | Candidate 0 needs two rows; candidate 1 at 12 x nil needs one. |
| Deploying, 5x1 | 5x1 | Under-minimum: both candidates need more than one row at five columns, so the last is chosen; its one-row budget ends in the mark, `Depl…`. |
| Deploying, 40x24 | 22x1 | Over-maximum: candidate 0 is one row and stretches nothing. |

## Environment

`ViewThatFits` consumes no token and no environment value, and it passes its environment to every candidate unchanged. It publishes no `stackAxis`: a candidate sees the axis of the nearest enclosing stack, and a stack inside a candidate publishes its own ([Linear stacks](stacks.md#environment)). Every candidate counts toward the graph's [terminal requirements](../../spec/phase-4/slice-04-focus-and-key-routing.md#terminal-requirements-aggregation), chosen or not (see the passes table above).

| Value | Source | Default | Effect |
| --- | --- | --- | --- |
| `Subview.priority` | `.layoutPriority(_:)` on a candidate | 0 | ignored; the `ViewThatFits`'s own priority is read by its parent |
| descendant `stackAxis` | the nearest enclosing stack, unchanged | -- | `ViewThatFits` publishes none; a stack inside a candidate publishes its own |

## Consumers

Each arrangement choice below is a `ViewThatFits`. The consumer's doc owns its candidates and what each reports as its ideal, which is exactly what the fit test reads.

- [Form](../widgets/form.md#sizing): `ViewThatFits(in: .horizontal) { sideBySide; stacked }` over the whole field list. The side-by-side candidate's ideal width is its widest row, measured unwrapped, so the form stays side by side while every row fits and stacks before any value wraps; for the anatomy fixture the switch falls between 18 and 17 columns ([Narrow](../widgets/form.md#narrow-17-columns)). Stacked is last, so it is also the under-minimum arrangement. A validation message that wraps under its value has to stay out of the side-by-side ideal, or a long message would stack the form.
- [Picker title](../widgets/picker.md#title), for the inline row, the segmented control and the radio group, and the same in [MultiPicker](../widgets/multi-picker.md): `ViewThatFits(in: .horizontal) { HStack(spacing: 1) { title; control }; VStack { title; control } }`. The beside candidate's ideal is the title's unwrapped width, one gap cell, and the control's natural width (for the radio group, all chips on one [Flow](flow.md) line). The stacked candidate is last, and its title wraps at the full width.
- [Picker descriptions](../widgets/picker.md#menu-with-descriptions), and MultiPicker's, one choice per menu: `ViewThatFits(in: .horizontal) { alignedColumn; ownRows }`. The aligned candidate's ideal is the four prefix cells, the widest label, two cells and the widest description, unwrapped: `4 + 8 + 2 + 23 = 37` for the fixture, which fits 40. The choice belongs inside the menu's scrolling content, so the scroll offset sits above it and survives a switch; Picker's cursor is the Picker's own `NodeState` and is untouched.
- [ProgressView](../widgets/progress-view.md#narrow-24-and-16-columns) proposes `width ?? readableWidth` to `ViewThatFits(in: .horizontal) { oneRow; ViewThatFits(in: .vertical) { stacked; oneRow } }`. The one-row form's ideal width is the label, one cell, the four-cell minimum bar, one cell and the percent (34 for the fixture), and its bar fills any finite width. At 40 columns the one-row form fits. At 24 x nil the inner choice takes the stacked form, because a nil height always fits. At 24x1 the stacked form needs three rows, so the inner choice falls to its last candidate, the one-row form under a one-row budget ([Fixed one-row height](../widgets/progress-view.md#fixed-one-row-height-24-and-16-columns)). The one-row form appears twice and so is two nodes; ProgressView keeps no `NodeState`, so nothing is lost.
- [LabeledContent](../widgets/labeled-content.md) chooses inline or stacked through `ViewThatFits` too. Its widest-word criterion is the open question below.
- [TabView](../widgets/tab-view.md#api-direction): `ViewThatFits(in: .horizontal) { fullBar; collapsedBar }`, each bar a [Flow](flow.md) of chips two cells apart. The full bar's ideal width is its one-line Flow, so it stays while every label fits one line; otherwise inactive chips collapse to icons ([Minimum: icon collapse](../widgets/tab-view.md#minimum-icon-collapse-24x5)). The collapsed bar is last, so it is also the under-minimum arrangement, and its Flow wraps only when even it overflows.

## Requirements

Schema: [README](../../design.md#requirements-list).

- `view that fits chooses the first candidate whose ideal fits on the tested axes` (selection rule: steps 1 to 3; sizing: Region, 16x1 and Region, 15 x nil)
- `view that fits proposes nil on tested axes and passes the others through` (selection rule: step 1; sizing: Deploying, 12x2)
- `view that fits treats a nil incoming axis as fitting` (sizing: Region, nil x nil and Deploying, 12 x nil)
- `view that fits chooses the last candidate when none fits` (sizing: Region, 5 x nil and Deploying, 5x1; anatomy: under-minimum)
- `view that fits reports the chosen candidate measured at the incoming proposal` (selection rule: step 4; sizing: Region, 20 x nil and Region, 80x24)
- `view that fits with an empty axis set always chooses the first candidate` (variants: `ViewThatFits(in: [])`)
- `view that fits without candidates reports zero and places nothing` (variants: no candidates)
- `empty views and absent branches contribute no candidate` (variants: `EmptyView()`, an absent `if` branch, or an empty ForEach)
- `view that fits places only the chosen candidate at its top leading corner` (selection rule: step 5; anatomy: beside)
- `view that fits stops measuring at the chosen candidate` (selection rule: step 3; measurement cost)
- `view that fits measures each candidate once per fit test proposal in a layout pass` (measurement cost: `k + 1` measurements and shared probes)
- `view that fits keeps its choice when a stack re-proposes its reported size` (allocation fixtures: every row)
- `stack allocation at equal priority decides which view that fits gives way` (allocation fixtures: `20x1`: `a`, `b`; anatomy: equal-priority)
- `higher layout priority keeps a view that fits on its first candidate` (allocation fixtures: `20x1`: `a.layoutPriority(1)`, `b`; anatomy: priority)
- `view that fits ignores layout priority on its candidates` (variants: `.layoutPriority(_:)` on a candidate)
- `view that fits stores no node state` (state model: chosen candidate)
- `switching candidates creates and destroys no nodes` (state model: candidate state; passes table: update)
- `view that fits publishes no stack axis` (environment: descendant `stackAxis`)

### Focus

- `an unchosen candidate keeps its node state until it is chosen again` (state model: candidate state)
- `unchosen candidates are left out of the focus order` (focus table: traversal row; state model: focus membership)
- `focus stays on a focus id that the newly chosen candidate also holds` (focus table: same `id` row)
- `focus clears when the newly chosen candidate lacks the focused id` (focus table: no focusable with `id` row)
- `unchosen candidates still contribute terminal requirements` (passes table: terminal requirements)
- `a switch that drops the focused id clears focus without guessing a neighbour and records it in statistics` (Identity, state, and focus: focus table, no focusable with id row)
- `a focusable around the whole choice keeps focus across a switch` (Identity, state, and focus: focus table)
- `a focus id held by two candidates is listed once for the chosen one` (Identity, state, and focus: focus table; state model: focus membership)

### Pointer

- `unchosen candidates get a zero frame and render and hit test nothing` (passes table: render, hit testing, and `dump()`; anatomy: unchosen candidate)
- `view that fits takes no focus and handles no input of its own` (Identity, state, and focus)

### Scroll

- `a chosen-again scroll view candidate clamps its kept offset on its next layout` (state model: candidate state)

## Degradation

`ViewThatFits` draws nothing and reads no terminal capability. Its choice is a function of the candidates' measured sizes, so where a candidate measures differently at a lower rung of the [degradation ladder](../tokens.md#degradation-ladder) (a two-cell Nerd Font glyph and its one-cell fallback, say), the same tree can choose differently at different rungs. That is intended: each rung chooses by its own measurement, and `ViewThatFits` has no capability-specific rule.

## Decisions

- **Ideal size is the only test.** A candidate fits when its ideal size fits on the tested axes, as in SwiftUI. There is no minimum-width test and no custom fit predicate, so every component's fitting reads the same way ([fitting](../../spec/phase-4/slice-06-grid-table-and-fitting.md#flow-layout-and-viewthatfits)).
- **The last candidate is the last resort.** When none fits, the last is chosen. Consumers put their most compact arrangement last: Form's stacked layout, Picker's own-rows descriptions.
- **Source order ranks candidates.** Priority acts only through the parent's allocation; `ViewThatFits` adds no priority API ([Flex decisions](flex.md#decisions)).
- **Top-leading placement, no alignment parameter.** The chosen candidate is placed at the top-leading corner of the bounds, with the incoming proposal. `ViewThatFits` reports that candidate's size, so a parent rarely gives it more; an app that wants other placement composes `.frame(alignment:)`. Terminal UIs read top-leading ([catalog layout decisions](../../spec/phase-4/slice-02-layout-protocol-and-stacks.md#catalog-layout-decisions)).
- **Every candidate is a live node, and the choice is derived.** Measuring a candidate needs its node, so all candidates are reconciled; the choice is recomputed and never stored.
- **Focus is kept by `FocusID`, otherwise cleared.** This applies the focus model's disappearance rule after every layout pass rather than adding a rule of its own.
- **Terminal requirements count every candidate.** Requirements are a union over live nodes, recomputed at reconciliation before layout chooses, so a resize that switches candidates never changes a terminal mode.

This contract was reviewed against the [Phase 4 theses](../../spec/phase-4.md). Views stay values: candidates are view values, and the choice is a pure function of them and the proposal. The runtime tree is explicit: every candidate is a node in `dump()`, and the choice shows as frames. State stays the app's: `ViewThatFits` has no `NodeState` and moves none between candidates. Terminal authority stays in the session: it draws nothing, and the graph aggregates requirements as it always does.

## Open questions

- **LabeledContent's fit criterion (owner).** LabeledContent's rule (owner decision, 2026-10-10) keeps the label beside the value while the label, one cell and the widest value word fit, and lets a longer value wrap beside the label; omp2's Fact tests the value's minimum width the same way. `ViewThatFits` tests ideal size, so a LabeledContent built on it stacks whenever its value would wrap, as Form does (owner decision, 2026-10-18). Should LabeledContent follow Form and stack before its value wraps, or should Tessera add a widest-word measurement that a candidate can report as its ideal? Text declares no minimum today ([Text](text.md#sizing)). Deferred to [Flow layout and ViewThatFits](../../spec/phase-4/slice-06-grid-table-and-fitting.md#flow-layout-and-viewthatfits) (plan 032 step 14.1). Either answer leaves the selection rule here unchanged: the first needs nothing new, and the second adds a measurement that only LabeledContent's inline candidate uses.

## Inspiration

The [inbox](../inbox.md) entry of 2026-08-24 noted that stacks and Flex redistribute extents on every pass, while arrangement changes were breakpoint arithmetic in app code. With `ViewThatFits` a status line can say "the long form while it fits, then the short form, then nothing" as three candidates, and the stack around it decides with `.layoutPriority(_:)` which segment gives way first.
