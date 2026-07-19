---
kind: widget
status: specified
---

# Table

A columnar, selectable, scrollable data view: List's structured sibling. Controlled
throughout, per
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase):
the app supplies immutable data, selection, and sort order; selection and sort order use
bindings, while Table derives rows from its data input on every update. Table owns only a
scroll offset in `NodeState`. Table renders chrome (header, rule, selection, scrollbar)
but never invents data, selection, or ordering.

Provisional API shape (vocabulary, not a commitment):

```swift
public struct Table<Data: RandomAccessCollection, ID: Hashable>: View
where Data.Element: Identifiable, Data.Element.ID == ID {
    public init(
        _ data: Data,
        selection: Binding<ID?>,
        sortOrder: Binding<[SortDescriptor<Data.Element>]>? = nil,
        columns: [TableColumn<Data.Element>],
        onActivate: ((Data.Element) -> Void)? = nil
    )
}
```

## Prior art

- Ratatui `Table`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/table.rs` -- copy
  the column-constraint vocabulary (fixed / min / fill) and the highlight-selected-row
  rendering; reject the stateful-`TableState`-passed-by-hand ergonomics, which Tessera
  replaces with bindings plus `NodeState`.
- Bubbles `table` -- good interaction feel for keyboard navigation; reject its ownership
  model (the widget owns rows and cursor), which is exactly the coupling the controlled
  rule exists to prevent.
- SwiftUI `Table` -- copy the `TableColumn` + `sortOrder: Binding<[SortDescriptor]>` API
  vocabulary; reject its macOS-scale feature set (column reordering, multi-select) for v1.
- Scrollbar geometry: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs`.

## Anatomy

```wireframe 46x9
 Name              Size  Modified
──────────────────────────────────────────────
 Spec.md         372 KB  2026-07-06          █
▌Package.swift    12 KB  2026-07-01          █
 README.md       2.6 KB  2026-06-28          █
 CHANGELOG.md    8.8 KB  2026-06-28          │
 CONTRIBUTING…    13 KB  2026-06-27          │
 LICENSE         1.1 KB  2026-06-20          │
 row 2 of 12
```

```text
Callouts (46x9, 0-based):
1. r0       Header row -- Text per column, `semantic.primary` plus bold by default;
            `TableStyle` may override; pinned, never scrolls
2. r0 c1    Header cell -- one per column; click target for sorting
3. r1       Header rule -- Divider, token `divider.light`, full width
4. r3 c0    Selection bar -- token `selection.bar`; row also gets `selection.fill`
5. r2-r7    Data row -- one row per visible element; 6 of 12 visible here
6. r6 c14   Truncation -- Text `tail` policy, `truncation.mark`, grapheme-safe
7. c45      Scrollbar -- output-only ScrollIndicator; track `scrollbar.track`, thumb
            `scrollbar.thumb`, thumb = max(1, visible/total x track) = 3 of 6
8. r8       Footer -- app-provided slot, NOT Table chrome (see Open questions)
```

Region names for the mouse table: header row, header cell, data row, selection bar (part
of data row), scrollbar.

## States

Mobile (40x16): the Modified column is dropped by column priority; Name gets the slack. 13
of 20 rows visible.

```wireframe 40x16
 Name                         Size
────────────────────────────────────────
 Spec.md                    372 KB     █
▌Package.swift               12 KB     █
 README.md                  2.6 KB     █
 CHANGELOG.md               8.8 KB     █
 CONTRIBUTING.md             13 KB     █
 LICENSE                    1.1 KB     █
 CODE_OF_CONDUCT.md         5.3 KB     █
 Brewfile                    531 B     █
 Justfile                    721 B     █
 UpdatingGhosttyVT.md       4.2 KB     │
 WindowsFrostVM.md         13.5 KB     │
 LocalDevelopmentState.md   4.6 KB     │
 a-very-long-filename-ex…     1 KB     │
 row 2 of 20
```

Min (24x5, the declared floor): only the highest-priority column survives; below this
width Table renders truncated single-column rows rather than failing.

```wireframe 24x5
 Name
────────────────────────
▌Package.swift         █
 README.md             │
 row 2 of 12
```

Empty (46x5): header and rule stay; the body shows the app-provided empty message (default
"No files" here) centered.

```wireframe 46x5
 Name              Size  Modified
──────────────────────────────────────────────

                   No files

```

Degraded ascii/no-color (46x6): geometry identical, glyphs swapped per the
[degradation ladder](../tokens.md#degradation-ladder). Unfocused looks the same but uses
`selection.inactive` instead of `selection.fill`.

```wireframe 46x6
 Name              Size  Modified
----------------------------------------------
 Spec.md         372 KB  2026-07-06          #
>Package.swift    12 KB  2026-07-01          #
 README.md       2.6 KB  2026-06-28          |
 row 2 of 12
```

## State model

| State                 | Owner       | Type                                      | Reset or clamp rule                                                                                                 |
| --------------------- | ----------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| rows                  | derived     | immutable `Data` (RandomAccessCollection) | recomputed from the data input on every update; never stored or bound                                               |
| selection             | Binding     | `Element.ID?`                             | Table never invents a value; if the ID vanishes from data, selection renders nowhere but the binding is not mutated |
| sort order            | Binding     | `[SortDescriptor<Element>]?`              | Table only marks the header; the app re-sorts data itself                                                           |
| scroll offset         | NodeState   | `Int` (first visible row)                 | clamps to `0...maximum scroll offset` on every update; keeps selection visible after selection-moving keys          |
| maximum scroll offset | derived     | `Int`                                     | recomputed as `max(0, count - visible)` on every update and layout pass; never stored                               |
| column widths         | derived     | `[Int]`                                   | recomputed per layout pass from column policy; never stored                                                         |
| header styling        | Environment | `semantic.primary` plus bold              | default header style; `TableStyle` may override                                                                     |
| selection style       | Environment | `selection.*` tokens                      | active vs inactive chosen by focus                                                                                  |

The "selection ID vanished" rule is this widget's version of Slice 7's mandatory "app
mutated data under the widget" case: Table must render sanely and must not write to the
binding to "fix" it -- the app owns that decision.

## Key table

| Key   | Precondition               | Effect                                                | Consumed |
| ----- | -------------------------- | ----------------------------------------------------- | -------- |
| Down  | focused                    | moves selection to next row via binding               | yes      |
| Up    | focused                    | moves selection to previous row via binding           | yes      |
| PgDn  | focused                    | moves selection down by visible-row count via binding | yes      |
| PgUp  | focused                    | moves selection up by visible-row count via binding   | yes      |
| Home  | focused                    | moves selection to first row via binding              | yes      |
| End   | focused                    | moves selection to last row via binding               | yes      |
| Enter | focused, selection is set  | calls `onActivate` with the selected element          | yes      |
| Down  | focused, selection not set | sets selection to first visible row via binding       | yes      |

Every selection-moving effect also updates the `NodeState` scroll offset per its clamp
rule so the selection stays visible.

## Mouse table

| Event        | Region      | Precondition                          | Effect                                            | Consumed |
| ------------ | ----------- | ------------------------------------- | ------------------------------------------------- | -------- |
| click        | data row    | always                                | sets selection to that row's ID via binding       | yes      |
| double-click | data row    | always                                | sets selection, then calls `onActivate`           | yes      |
| click        | header cell | sort order binding set                | toggles that column's sort descriptor via binding | yes      |
| wheel-down   | data row    | scroll offset < maximum scroll offset | increments NodeState scroll offset                | yes      |
| wheel-up     | data row    | scroll offset > 0                     | decrements NodeState scroll offset                | yes      |

Wheel scrolling moves the viewport without touching selection (selection may scroll out of
view; the bar and fill simply are not rendered until it returns). The ScrollIndicator is
output-only and has no drag interaction.

## Sizing

Table is greedy on both axes when proposed; its ideal is content-driven.

| Proposal  | Result | Rule                                                                                                                                                                              |
| --------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 45x14  | ideal: all 12 rows fit, so there is no ScrollIndicator or scrollbar reservation; content-resolved columns are 45 wide; height = header + rule + all 12 rows (no footer: app slot) |
| 46 x 9    | 46x9   | fills the proposal exactly; rows beyond the viewport scroll                                                                                                                       |
| 24 x 5    | 24x5   | fills; column priority drops columns to fit (min state)                                                                                                                           |
| 10 x 3    | 10x3   | fills; single truncated column, no scrollbar below width 12                                                                                                                       |
| 200 x 50  | 200x50 | fills; fill-policy columns absorb the slack, rows below content stay blank                                                                                                        |

Numbers in the nil x nil row are for the anatomy example's data set; the rule, not the
numbers, is normative.

Column width policy (baseline, pending the shared solver): each `TableColumn` declares
`fixed(n)`, `min(n)`, or `fill(weight:)`; fixed first, then min at their minimums, then
remaining slack distributed to fill columns by weight, integer remainders leading-first.
Columns also carry a drop priority for narrow viewports (mobile state). See Open
questions: this is Grid's solver.

## Environment

- `semantic.primary` plus bold -- default header text style; `TableStyle` may override it
- `selection.bar`, `selection.fill`, `selection.inactive`, `selection.ascii`
- `divider.light` for the header rule
- `scrollbar.track`, `scrollbar.thumb` for the output-only ScrollIndicator
- `truncation.mark`

## Primitive dependencies

- [Divider](../primitives/divider.md) -- header rule. Exists (`specified`).
- [Text truncation policies](../primitives/text.md#variants) -- `tail`, grapheme-safe;
  specified. Blocks `ready` until Slice 3 delivers the linked wrapping/truncation
  contract.
- [ScrollIndicator](../primitives/scroll-indicator.md) -- shared with ScrollView and List;
  output-only, so Table supplies its viewport state but does not route pointer input to
  it. Exists (`wireframed`); its API spelling and style protocol must graduate before
  `ready`.
- Column width distribution -- consumes the ready shared [Flex](../primitives/flex.md)
  constraint vocabulary; Slice 6 Grid and Table delegate to its one resolver rather than
  designing a second allocator.

## Requirements

- `rows recompute from immutable data input on every update without a binding` (state
  model: rows)
- `selection stays visible when moved past the viewport edge` (key table: Down; state:
  scroll offset)
- `wheel scrolling moves viewport without changing selection` (mouse table: wheel-down)
- `scroll indicator is output-only and has no drag interaction` (anatomy: callout 7; mouse
  table)
- `selection binding survives app reordering rows` (state model: selection)
- `vanished selection id renders no selection and does not mutate the binding` (state
  model: selection)
- `scroll offset clamps when app shrinks data` (state model: scroll offset; maximum scroll
  offset)
- `default header uses bold semantic.primary and TableStyle can override it` (state model:
  header styling)
- `header click toggles sort descriptor through binding` (mouse table: header cell)
- `enter activates the selected element` (key table: Enter)
- `column narrower than content renders ellipsis not overflow` (anatomy: callout 6)
- `cjk cell content truncates on grapheme boundary` (anatomy: callout 6; Slice 7 mandatory
  case)
- `columns drop by priority at mobile width` (states: mobile)
- `table fills its proposal on both axes` (sizing: 46 x 9)
- `nil x nil fits all rows without an indicator or scrollbar reservation` (sizing: nil x
  nil)
- `empty data renders header and empty message` (states: empty)
- `ascii degradation preserves geometry` (states: degraded)

## Degradation

- `NO_COLOR`: selection falls back to reverse video; header to bold.
- 16-color: indexed equivalents of the accent; geometry unchanged.
- ASCII-only: degraded wireframe above -- `-` rule, `>` selection, `|`/`#` scrollbar, `~`
  truncation mark.
- Below `min` width (24): single truncated column, scrollbar dropped below width 12, never
  a layout failure.

## Open questions

- Column width solver: final `fixed/min/fill(weight:)` semantics must be decided jointly
  with Grid (Slice 6). Baseline above is the working assumption; promotion of either doc
  to `ready` requires the shared decision.
- Footer/status line: keep as pure app slot (current position) or offer an optional
  `statusText` convenience? Lean app slot; the wireframes show it only to fix the vertical
  rhythm.
- Multi-select (`Binding<Set<ID>>`): deliberately out of v1; revisit after List and Table
  ship single-select with identical semantics.
- Keyboard sorting (without a mouse): header cells are not focusable in this design.
  Possible later: a `Ctrl-s` cycling chord or focusable header mode. Needs a use case.
- Horizontal overflow: mobile drops columns instead of scrolling horizontally. Is a
  horizontal-scroll mode (wrapping Table in ScrollView `.horizontal`) sufficient for wide
  data sets? Test with a real 10-column dataset before deciding.

## Inspiration

- 2026-07-06 -- Anatomy, states, and tables in this doc were developed as the process
  exemplar; see [README](../README.md) for the conventions they exercise.
