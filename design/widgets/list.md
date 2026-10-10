---
kind: widget
status: specified
---

# List

`List` is Tessera's controlled, focusable collection widget: a vertical run of
app-supplied rows with optional [Section](section.md) grouping, an app-owned selection,
and shared overflow geometry. The app owns the data (`RandomAccessCollection` of
`Identifiable` elements), the selection (`Binding<Data.Element.ID?>`), and every section's
expansion (`Binding<Bool>` on the Section); List owns only an ephemeral scroll offset in
`NodeState`, per
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
List renders chrome (selection gutter, section spacing, scrollbar) but never invents data,
selection, or expansion.

Row content is an app-supplied row builder, not a column model: file lists, message
timelines, and navigation sidebars are all the same widget with different row views.
Accessories and badges are ordinary row composition (trailing `Text` styled
`semantic.secondary`), not a dedicated List API.

Provisional API shape (vocabulary, not a commitment):

```swift
public struct List<Data: RandomAccessCollection, ID: Hashable, Row: View>: View
where Data.Element: Identifiable, Data.Element.ID == ID {
    public init(
        _ data: Data,
        selection: Binding<ID?>? = nil,
        onActivate: ((Data.Element) -> Void)? = nil,
        @ViewBuilder row: @escaping (Data.Element) -> Row
    )
}

// Builder form for Section grouping; rows keep the same identity rules.
List(selection: $selection) {
    Section("Mailboxes", isExpanded: $mailboxes) { ForEach(boxes) { box in row(box) } }
    Section("Tags") { ForEach(tags) { tag in row(tag) } }
}
```

The selection parameter is outer-optional, following SwiftUI's `Binding<SelectionValue?>?`
shape: passing a binding opts into selection (gutter, selection keys, activation);
omitting it yields a display list (timeline, log) that reserves no gutter and scrolls like
[ScrollView](scroll-view.md). Selection presence is a structural choice made at init,
never a runtime mode.

## Prior art

- Ratatui `List`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/list.rs`,
  `list/state.rs`, `list/rendering.rs` -- copy the offset/selected state split and the
  render-owns-offset reveal model; copy whole-row offset granularity. Reject index
  arithmetic with `usize::MAX` sentinels (Tessera selection is ID-keyed), reject the
  `WhenSelected` highlight-spacing default (Ratatui's own docs admit the reflow is worse
  UX -- Tessera always reserves the gutter), and reject its absent section model, which
  forces every app to hand-roll headers that arrow keys then land on.
- Textual `OptionList`/`ListView`/`Tree` -- copy the data-not-widgets rendering model
  (`OptionList` virtualizes rows; `ListView`'s widget-per-row measured ~10 s to load 1000
  rows) and the focused/blurred cursor token-pair convention. Reject the three-widget
  fragmentation: one List with an optional selection binding covers all three.
- Bubbles `list` -- good keyboard feel; reject the kitchen-sink bundling (filter,
  paginator, spinner, help baked into one model) and the widget-owned cursor. Filtering
  and status lines are app composition in Tessera.
- SwiftUI `List` -- copy the outer-optional selection binding shape, the
  `Section(isExpanded:)` vocabulary, and row identity rules (`Identifiable`, stable IDs,
  constant view count per row). Reject `EditMode` (touch-only workaround) and
  `swipeActions` (no touch surface).
- Tessera [Table](table.md) -- reuse controlled selection, the selection token set, the
  clamp rules, and the shared ScrollIndicator contract; List must not inherit Table's
  column model.

## Anatomy

A sectioned mail sidebar with a selection binding present. Section headers come from
[Section](section.md); the badge is row content, not List chrome.

```wireframe 26x12
▾ Mailboxes              ┃
   Inbox              12 ┃
▌  Drafts              3 ┃
   Sent                  ┃
   Junk                  ┃
                         ┃
▸ Projects               ┃
                         ┃
▾ Tags                   │
   urgent                │
   later                 │
   review                │
```

```text
Callouts (26x12, 0-based):
1. r0       Section header -- Section chrome; disclosure `disclosure.expanded` in the
            gutter column, title `semantic.secondary`; not selectable, not focusable
2. r1-r4    Data row -- one per visible row; text from the app row builder at c3
            (Section's two-column row indent; sectionless rows start at c1)
3. r2 c0    Selection bar -- token `selection.bar`; row also gets `selection.fill`
4. r1 c22   Badge -- row-content convention: trailing Text, `semantic.secondary`,
            right-aligned by the app's row builder; not a List API
5. r5, r7   Section spacer -- List chrome, one blank row between adjacent sections
6. r6       Collapsed header -- `disclosure.collapsed`; the section's rows are hidden
7. c25      Scrollbar -- output-only ScrollIndicator; 12 of 18 flattened rows visible
            (six more Tags rows below); thumb = max(1, floor(12x12/18)) = 8
8. r0-r11   Viewport -- wheel target; every flattened row scrolls, headers included
```

Region names for the mouse table: data row, section header, viewport.

## States

Mobile (40x16): a message list -- the second canonical use case. Two-line rows from the
row builder (sender plus time, then a `semantic.secondary` preview line); the selection
bar paints on every line of the selected row. Mid-scroll: rows 4-11 of 20 visible, so
thumb = max(1, floor(16x16/40)) = 6 starting at floor(8x(16-6)/(40-16)) = 3.

```wireframe 40x16
 Maya Chen                       09:41 │
  Fixed the split view divider drag    │
▌Build Bot                       09:37 │
▌ tessera CI: 734 tests passed on main ┃
 Rob                             09:12 ┃
  Can List sections collapse in v1?    ┃
 Priya Patel                     08:58 ┃
  Monodraw snippet library feedback    ┃
 Deploy Bot                      08:30 ┃
  showcase preview deployed to staging │
 Maya Chen                       07:55 │
  Scroll indicator thumb rounding      │
 Linh Tran                       07:41 │
  Table column solver notes            │
 Rob                             07:02 │
  Weekend plan: list + section pass    │
```

Min (12x3, the declared floor): gutter, truncated rows, scrollbar. Below this width List
renders truncated single-column rows rather than failing; the scrollbar drops below
width 8.

```wireframe 12x3
▌Inbox     ┃
 Drafts    │
 Sent      │
```

Degraded ascii/no-color (26x5, the anatomy's top slice): geometry identical, glyphs
swapped per the [degradation ladder](../tokens.md#degradation-ladder) -- `>` selection,
`-`/`+` disclosure, `|`/`#` scrollbar. Unfocused looks the same in any capability but uses
`selection.inactive` instead of `selection.fill`.

```wireframe 26x5
- Mailboxes              #
   Inbox              12 #
>  Drafts              3 #
   Sent                  |
+ Projects               |
```

Empty data renders the List's static structure (declared Section headers) and zero rows;
List invents no placeholder message. Loading, empty, and error presentations are app child
states, composed beside or instead of the List.

## State model

| State                 | Owner       | Type                           | Reset or clamp rule                                                                                                                                                                                                                                          |
| --------------------- | ----------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| rows                  | derived     | flattened visible presentation | recomputed from data, section structure, and expansion bindings on every update; collapsed sections contribute only their header; never stored                                                                                                               |
| selection             | Binding     | `Element.ID?` (optional param) | List never invents a value; if the ID vanishes from data or its section collapses, selection renders nowhere and the binding is not mutated                                                                                                                  |
| selection presence    | derived     | `Bool`                         | structural: binding supplied at init reserves the gutter and enables selection keys; absent binding reserves no gutter and arrows scroll                                                                                                                     |
| section expansion     | Binding     | `Bool` per collapsible Section | forwarded to each [Section](section.md); List reads it to flatten rows and writes it only for the Left/Right and header-click rows below                                                                                                                     |
| scroll offset         | NodeState   | `Int` (first visible row)      | addresses whole flattened rows; top row renders fully, the bottom row may clip mid-row; clamps to `0...maximum scroll offset` on every update; selection-moving keys keep the selected row's full extent visible (top-aligned when taller than the viewport) |
| maximum scroll offset | derived     | `Int`                          | recomputed per layout pass from flattened row heights and viewport height; never stored                                                                                                                                                                      |
| header styling        | Environment | `semantic.secondary`           | Section header default; see [Section](section.md)                                                                                                                                                                                                            |
| selection style       | Environment | `selection.*` tokens           | active vs inactive chosen by focus                                                                                                                                                                                                                           |

The "selection ID vanished" rule is Slice 7's mandatory "app mutated data under the
widget" case, and collapsing the selected row's section is deliberately the same case:
render sanely, never write the binding to "fix" it. Re-expanding renders the selection
again without auto-scrolling; the next selection-moving key applies the visibility clamp.

The scroll offset has exactly one runtime owner: if `List` handles events as a stateful
leaf it uses `LeafView.handleEvent` with the same `NodeState` read by layout and
rendering, and never mirrors the offset into `_ResponderView.ResponderState`.

List is one focus stop: rows are not individually focusable, and Tab moves past the whole
widget. Focus presentation rides the selection tint swap; when hosted in a
focus-appearance host (for example [Box](../primitives/box.md)) the host paints
`focus.border`. A selection-less List follows [ScrollView's](scroll-view.md) delegated
focus appearance.

## Key table

With a selection binding, arrows auto-commit through the binding -- no Enter or Space to
confirm ([NavigationSplitView sidebar contract](navigation-split-view.md)). Traversal
visits selectable rows only: section headers and collapsed content are skipped by
construction, never by caller-side skip loops.

| Key   | Precondition                                               | Effect                                                         | Consumed |
| ----- | ---------------------------------------------------------- | -------------------------------------------------------------- | -------- |
| Down  | focused, selection binding present, selection set          | moves selection to next visible selectable row via binding     | yes      |
| Up    | focused, selection binding present, selection set          | moves selection to previous visible selectable row via binding | yes      |
| Down  | focused, selection binding present, selection not set      | sets selection to first visible selectable row via binding     | yes      |
| PgDn  | focused, selection binding present                         | moves selection down by visible-row count via binding          | yes      |
| PgUp  | focused, selection binding present                         | moves selection up by visible-row count via binding            | yes      |
| Home  | focused, selection binding present                         | moves selection to first selectable row via binding            | yes      |
| End   | focused, selection binding present                         | moves selection to last selectable row via binding             | yes      |
| Enter | focused, selection is set                                  | calls `onActivate` with the selected element                   | yes      |
| Left  | focused, selection set, its section collapsible, expanded  | collapses the selection's section via its expansion binding    | yes      |
| Right | focused, selection set, its section collapsible, collapsed | expands the selection's section via its expansion binding      | yes      |
| Down  | focused, selection binding absent, offset below maximum    | increments NodeState scroll offset                             | yes      |
| Up    | focused, selection binding absent, offset above 0          | decrements NodeState scroll offset                             | yes      |

Up and Down at the first and last selectable row saturate and stay consumed (Table
parity): selection keys never leak to ancestors while the List is focused. A hidden
selection (collapsed section) stays the traversal anchor: Down and Up move to the nearest
visible selectable row after or before its flattened position. Without a selection
binding, boundary arrows follow ScrollView: unchanged offset, not consumed, for ancestor
routing. Every selection-moving effect also updates the `NodeState` scroll offset per its
clamp rule.

## Mouse table

| Event        | Region         | Precondition                          | Effect                                           | Consumed |
| ------------ | -------------- | ------------------------------------- | ------------------------------------------------ | -------- |
| click        | data row       | selection binding present             | sets selection to that row's ID via binding      | yes      |
| double-click | data row       | selection binding present             | sets selection, then calls `onActivate`          | yes      |
| click        | section header | header collapsible                    | toggles that section's expansion via its binding | yes      |
| click        | section header | header not collapsible                | none -- noninteractive label                     | no       |
| wheel-down   | viewport       | scroll offset < maximum scroll offset | increments NodeState scroll offset               | yes      |
| wheel-up     | viewport       | scroll offset > 0                     | decrements NodeState scroll offset               | yes      |

Wheel scrolling moves the viewport without touching selection (the bar and fill simply are
not rendered until the row returns). Boundary wheel events are not consumed so a
scrollable ancestor can continue (ScrollView routing parity). The ScrollIndicator is
output-only and has no drag interaction.

## Sizing

List is greedy on both axes when proposed; its ideal is content-driven. Numbers use the
anatomy's data set (18 flattened rows); the rule, not the numbers, is normative.

| Proposal  | Result | Rule                                                                                 |
| --------- | ------ | ------------------------------------------------------------------------------------ |
| nil x nil | 11x18  | ideal: widest flattened row's ideal width; all 18 rows fit, no indicator reservation |
| 26 x 12   | 26x12  | fills the proposal exactly; flattened rows beyond the viewport scroll                |
| 12 x 3    | 12x3   | fills; truncated rows at the declared floor                                          |
| 6 x 2     | 6x2    | fills; truncated rows, scrollbar dropped below width 8, never a layout failure       |
| 200 x 50  | 200x50 | fills; rows keep their content height, rows below content stay blank                 |

## Environment

- `selection.bar`, `selection.fill`, `selection.inactive`, `selection.ascii`
- `disclosure.expanded`, `disclosure.collapsed`, `disclosure.ascii` -- collapsible Section
  headers ([tokens](../tokens.md#disclosure))
- `semantic.secondary` -- Section header default and the badge/preview row-content
  convention
- `scrollbar.track`, `scrollbar.thumb`, `scrollbar.ascii` for the output-only
  ScrollIndicator
- `truncation.mark`
- `focus.border` / `focus.content` -- only via a delegating focus-appearance host; List
  adds no focus ring of its own

## Primitive dependencies

- [Section](section.md) -- companion widget owning header anatomy and expansion
  presentation; specified in the same pass.
- [ScrollIndicator](../primitives/scroll-indicator.md) -- shared with ScrollView and
  Table; output-only, List supplies viewport state but routes no pointer input to it.
  Ready.
- [Text truncation policies](../primitives/text.md#variants) -- `tail`, grapheme-safe;
  blocks `ready` until Slice 3 delivers the linked truncation contract.
- Slice 5 mouse routing -- row hit testing (position to row ID) and wheel routing come
  from the framework hit-testing contract, never a private rect map (the gap Ratatui
  cannot close; issue #273).

## Requirements

- `rows recompute from data and expansion bindings on every update without storage` (state
  model: rows)
- `arrow selection auto-commits through the binding without enter` (key table: Down)
- `down with no selection selects the first visible selectable row` (key table: Down,
  selection not set)
- `selection traversal skips section headers by construction` (key table: Down; anatomy:
  callout 1)
- `selection stays visible when moved past the viewport edge` (key table: Down; state:
  scroll offset)
- `wheel scrolling moves viewport without changing selection` (mouse table: wheel-down)
- `boundary wheel events pass to ancestors unconsumed` (mouse table: wheel-down
  precondition)
- `vanished selection id renders no selection and does not mutate the binding` (state
  model: selection)
- `collapsing the selected rows section hides selection without mutating the binding`
  (state model: selection; key table: Left)
- `arrows from a hidden selection move to the nearest visible selectable row` (key table:
  Down)
- `left collapses and right expands the selections section via its binding` (key table:
  Left, Right)
- `re-expansion renders the preserved selection without auto-scrolling` (state model:
  selection)
- `scroll offset clamps when app shrinks data` (state model: scroll offset)
- `selected multi-line row paints the bar on every line` (states: mobile)
- `absent selection binding reserves no gutter and arrows scroll` (state model: selection
  presence; key table: Down, binding absent)
- `enter activates the selected element` (key table: Enter)
- `double click selects then activates` (mouse table: double-click)
- `click on a data row selects it through the binding` (mouse table: click)
- `click on a collapsible header toggles expansion through its binding` (mouse table:
  section header)
- `list fills its proposal on both axes` (sizing: 26 x 12)
- `nil x nil fits all rows without an indicator reservation` (sizing: nil x nil)
- `unfocused selection renders the inactive tint` (state model: selection style)
- `ascii degradation preserves geometry` (states: degraded)

## Degradation

- `NO_COLOR`: selection falls back to reverse video; headers to dim.
- 16-color: indexed equivalents; geometry unchanged.
- ASCII-only: degraded wireframe above -- `>` selection, `-`/`+` disclosure, `|`/`#`
  scrollbar, `~` truncation mark.
- Below `min` (12x3): truncated rows, scrollbar dropped below width 8, never a layout
  failure.

## Open questions

- `listSelectionStyle` spelling and scope: deferred to the
  [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration)
  style/environment contract; v1 consumes the `selection.*` tokens directly with no
  parallel style protocol (ScrollView precedent).
- Context menus: out of v1. Unblocked by extending the catalog's
  [mouse-event vocabulary](../README.md#mouse-table) with a secondary-click event plus
  Slice 5 routing; the target API shape is SwiftUI's
  `contextMenu(forSelectionType:menu:primaryAction:)`, whose menu closure receives the
  selection so empty-space and on-row menus differ.
- Multi-select `Binding<Set<ID>>`: deliberately out of v1, shared decision with
  [Table](table.md#open-questions); revisit after both ship single-select with identical
  semantics.
- A `.badge(_:)` convenience modifier: v1 uses row composition; revisit with Form post-1.0
  if the convention proves repetitive.
- Bulk expand/collapse chords (Shift-Left/Right): needs a use case; the expansion bindings
  already let apps implement it.

## Inspiration

A List should make application data and selection obvious, not hide them behind a widget
state object. Scrolling is an implementation detail; selected identity remains app state.
Sections earn their keep by making headers unselectable by construction -- the single
clearest lesson from Ratatui's ecosystem, where every app re-implements header-skipping
arrow loops.
