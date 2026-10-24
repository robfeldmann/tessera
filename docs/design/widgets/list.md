---
kind: widget
status: ready
---

# List

`List` is Tessera's controlled, focusable collection widget: a vertical run of app-supplied rows with optional [Section](section.md) grouping, an app-owned selection, and shared overflow geometry. The app owns the data (`RandomAccessCollection` of `Identifiable` elements), the selection (`Binding<Data.Element.ID?>`), and every section's expansion (`Binding<Bool>` on the Section); List owns only an ephemeral scroll offset in `NodeState`, per [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md). List renders chrome (selection gutter, section spacing, scrollbar) but never invents data, selection, or expansion.

Row content is an app-supplied row builder, not a column model: file lists, message timelines, and navigation sidebars are all the same widget with different row views. Accessories are ordinary row composition. A trailing count or label is the one shared affordance: `.badge(_:)` on a row, see [Row badges](#row-badges) and [Badge](../primitives/badge.md).

Rows wrap (owner decision, 2026-10-18): a row is content, so its text word-wraps at the List's content width and takes every row it needs, as in SwiftUI. Items therefore differ in height, and the scroll offset, the indicator, and paging count rows, not items, per [ScrollView's contract](scroll-view.md#rows-and-variable-height-content). An item cut by the top or bottom edge draws its visible rows, and the selection highlight covers every row of the selected item. `.lineLimit(1)` on a row, or on the whole List through the environment, restores single-line rows that tail-truncate with `…`. Section headers, badges, and the selection gutter are chrome and stay one row.

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

// Builder form for Section grouping; rows keep the same identity rules. `selection` and
// `mailboxesExpanded` are Bindings from the app's model.
List(selection: selection) {
    Section("Mailboxes", isExpanded: mailboxesExpanded) { ForEach(boxes) { box in row(box) } }
    Section("Tags") { ForEach(tags) { tag in row(tag) } }
}
```

The selection parameter is outer-optional, following SwiftUI's `Binding<SelectionValue?>?` shape: passing a binding opts into selection (gutter, selection keys, activation); omitting it yields a display list (timeline, log) that reserves no gutter and scrolls like [ScrollView](scroll-view.md). Selection presence is a structural choice made at init, never a runtime mode.

These shapes are the [translation key](../translation-key.md)'s forms. The selection is an app-owned binding that arrows move directly, so List keeps no separate cursor (keys D1 and D3); a selection change is a binding write (key C6); activation is the optional `onActivate:` closure, which receives the element (key C8); rows come from a row closure or child views in the builder (key A7), keyed by `ForEach` ids (key A2). List joins the focus ring through `.focusable(_:)` with an explicit `FocusID`, as one focus stop (keys B10 and E1). The Mouse table names every hit region (key F1), the disclosure glyphs are Marks tokens (key K3), and colours are roles (key J1).

## Prior art

- omp2 has no List. Its counterparts are Select's rows ([`select.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L191-L197)) and the settings screen's row list ([`settings.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1771-L1796)). Copy Select's row hover, which it reads from the graph at paint rather than storing ([L929-L934](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L929-L934), key F4), drawn as a fill behind the row's own colours ([L1026-L1031](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L1026-L1031)), and the settings list's rows built by a loop over app data (key A7). Reject Select's internal cursor and scroll state: the selection is the app's binding and the offset is NodeState (keys D3 and D4). Reject its wheel moving the cursor ([L1174-L1177](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L1174-L1177)): List's wheel scrolls without moving the selection (key F7). Reject its type-to-filter (keys C7 and M2) and the settings screen's hand-written key-hint footer, which is KeyLegend's job (key E8).
- Ratatui `List`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/list.rs`, `list/state.rs`, `list/rendering.rs` -- copy the offset/selected state split and the render-owns-offset reveal model. Reject whole-item offset granularity: Tessera counts rows, so a partly visible item draws its visible rows (owner decision, 2026-10-18). Reject index arithmetic with `usize::MAX` sentinels (Tessera selection is ID-keyed), reject the `WhenSelected` highlight-spacing default (Ratatui's own docs admit the reflow is worse UX -- Tessera always reserves the gutter), and reject its absent section model, which forces every app to hand-roll headers that arrow keys then land on.
- Textual `OptionList`/`ListView`/`Tree` -- copy the data-not-widgets rendering model (`OptionList` virtualizes rows; `ListView`'s widget-per-row measured ~10 s to load 1000 rows) and the focused/blurred cursor token-pair convention. Reject the three-widget fragmentation: one List with an optional selection binding covers all three.
- Bubbles `list` -- good keyboard feel; reject the kitchen-sink bundling (filter, paginator, spinner, help baked into one model) and the widget-owned cursor. Filtering and status lines are app composition in Tessera.
- SwiftUI `List` -- copy the outer-optional selection binding shape, the `Section(isExpanded:)` vocabulary, row identity rules (`Identifiable`, stable IDs, constant view count per row), and wrapping rows with `.lineLimit(1)` as the opt-out (owner decision, 2026-10-18). Reject `EditMode` (touch-only workaround) and `swipeActions` (no touch surface).
- Tessera [Table](table.md) -- reuse controlled selection, the selection token set, the clamp rules, and the shared ScrollIndicator contract; List must not inherit Table's column model.

## Anatomy

A sectioned mail sidebar with a selection binding present. Section headers come from [Section](section.md); the badge is row content, not List chrome.

```wireframe 26x12
▾ Mailboxes              █
   Inbox              12 █
▌  Drafts              3 █
   Sent                  █
   Junk                  █
                         █
▸ Projects               █
                         █
▾ Tags                   │
   urgent                │
   later                 │
   review                │
```

```text
Callouts (26x12, 0-based):
1. r0       Section header -- Section chrome; disclosure `disclosure.expanded` in the
            gutter column, title `secondary`; not selectable, not focusable;
            chrome, one row (Section's wrap exception)
2. r1-r4    Data row -- one row per item in this data set; text from the app row builder
            at c3 (Section's two-column row indent; sectionless rows start at c1);
            content, wraps, so a longer label takes more rows (see Wrapped)
3. r2 c0    Selection bar -- `selection.bar` in `accent` (focused) / `secondary`
            (unfocused); every row of the selected item also gets `selection.fill`; the
            bar cell takes the fill when derived; where `selection.fill` is reverse video
            (slots, indexed256, NO_COLOR) the bar draws on the terminal background and the
            fill starts at the next cell ([selection](../tokens.md#selection); owner
            decision, 2026-10-19)
4. r1 c22   Badge -- trailing count from plain text or `.badge(_:)`; neutral tone by
            default (see Row badges); right-aligned by the app's row builder; chrome,
            one row
5. r5, r7   Section spacer -- List chrome, one blank row between adjacent sections
6. r6       Collapsed header -- `disclosure.collapsed`; the section's rows are hidden;
            chrome, one row
7. c25      Scrollbar -- output-only ScrollIndicator; 12 of 18 content rows visible
            (every item here is one row; six more Tags rows below); thumb =
            max(1, floor(12x12/18)) = 8
8. r0-r11   Viewport -- wheel target; every flattened row scrolls, headers included
9. r3       Hover (not drawn in this fixture) -- on by default; the row under the pointer
            takes `hover` (12%, [fill roles](../tokens.md#fill-roles)); its row label (the
            row's first text line) is underlined where no fill is drawn (slots, NO_COLOR,
            16-colour); a selected row keeps `selection.fill` under the pointer
```

Region names for the mouse table: data row, section header, viewport.

## Row badges

Owner decision, omp2 review, 2026-10: a row takes `.badge(_:)` for a count or short label, as in SwiftUI. The badge is a [Badge](../primitives/badge.md) and trails the row content at the trailing edge; it is row content, not List chrome. The default tone is neutral, so a count stays quiet; an app passes another tone for a row that needs attention. Tab items take the same modifier ([TabView](tab-view.md)).

Two unselected rows with neutral count badges, as apps use them.

```wireframe 40x2
Inbox                               ▐12▌
Drafts                               ▐3▌
```

```text
Callouts (40x2, 0-based):
1. r0 c36-c39  Count badge, neutral -- trailing row content from `.badge(_:)`; the Inbox
               count, default tone
2. r1 c37-c39  Count badge, neutral -- the Drafts count
```

## States

Mobile (40x16): a message list -- the second canonical use case. Two-line rows from the row builder (sender plus time, then a `secondary` preview line); the selection bar paints on every line of the selected row. Mid-scroll: items 4-11 of 20 visible, which is rows 8-23 of 40, so thumb = max(1, floor(16x16/40)) = 6 starting at floor(8x(16-6)/(40-16)) = 3. The preview line is `secondary` content, so it wraps; at this width every preview fits one row.

```wireframe 40x16
 Maya Chen                       09:41 │
  Fixed the split view divider drag    │
▌Build Bot                       09:37 │
▌ tessera CI: 734 tests passed on main █
 Rob                             09:12 █
  Can List sections collapse in v1?    █
 Priya Patel                     08:58 █
  Monodraw snippet library feedback    █
 Deploy Bot                      08:30 █
  demo app preview deployed to staging │
 Maya Chen                       07:55 │
  Scroll indicator thumb rounding      │
 Linh Tran                       07:41 │
  Table column solver notes            │
 Rob                             07:02 │
  Weekend plan: list + section pass    │
```

Wrapped (34x8): rows wrap at the content width, so items differ in height (owner decision, 2026-10-18). Ten items make 20 content rows at 32 cells (the gutter takes c0, the indicator c33), the viewport shows 8, and the offset is 2 rows: the first item shows only its last row, the second (selected) item paints its bar on both rows, and the last visible item shows only its first row, with no truncation mark. Thumb = max(1, floor(8x8/20)) = 3 starting at floor(2x(8-3)/(20-8)) = 0.

```wireframe 34x8
 the list                        █
▌Selection highlight covers every█
▌row of a wrapped item           █
 Single-line rows stay one row   │
 Scrolling counts rows, so a     │
 partly visible item draws its   │
 visible rows                    │
 Paging moves one viewport of    │
```

```text
Callouts (34x8, 0-based):
1. r0 c1-c8      Data row, partial at the top -- last row of a three-row item (content
                 row 2); its first two rows sit above the viewport; content, wraps
2. r1-r2 c0      Selection bar -- `selection.bar` on every row of the selected item; both
                 rows also get `selection.fill`; the bar cell takes the fill when derived;
                 where `selection.fill` is reverse video the bar draws on the terminal
                 background and the fill starts at the next cell
                 ([selection](../tokens.md#selection))
3. r1-r2 c1-c32  Data row, selected -- two-row item at the 32-cell content width;
                 content, wraps
4. r3 c1-c29     Data row -- one-row item; content, wraps (it fits)
5. r4-r6 c1-c29  Data row -- three-row item, whole
6. r7 c1-c28     Data row, partial at the bottom -- first row of a two-row item; its
                 second row is below the viewport; no truncation mark
7. r0-r7 c33     Scrollbar -- three-row thumb at r0-r2, counted in rows
```

Single-line (34x6): `.lineLimit(1)` on the List through the environment (or on each row) restores single-line rows. The same first six items are one row each, and each tail truncates with `…`; the second item is selected. Thumb = max(1, floor(6x6/10)) = 3 starting at 0.

```wireframe 34x6
 Wrap long titles instead of cut…█
▌Selection highlight covers ever…█
 Single-line rows stay one row   █
 Scrolling counts rows, so a par…│
 Paging moves one viewport of ro…│
 Resize re-wraps every item      │
```

```text
Callouts (34x6, 0-based):
1. r0, r1, r3, r4 c32  Truncation mark -- `truncation.mark` (`…`; ASCII `~`) ends the
                       row; Text marks its own cut
2. r1 c0               Selection bar -- `selection.bar` in `accent` (focused) /
                       `secondary` (unfocused); the single row also gets
                       `selection.fill`; the bar cell takes the fill when derived; where
                       `selection.fill` is reverse video the bar draws on the terminal
                       background and the fill starts at the next cell
                       ([selection](../tokens.md#selection))
3. r0-r5 c33           Scrollbar -- three-row thumb at r0-r2
```

Min (12x3, the declared floor): gutter, wrapped rows, scrollbar. The floor is the gutter and Section indent (3), the widest word of the anatomy's rows with their trailing badge, and the indicator column: `Inbox` + gap + `12` is 3 + 5 + 1 + 2 + 1 = 12, and `Drafts` with a one-cell badge is 3 + 6 + 1 + 1 + 1 = 12. The wireframe is sectionless, so rows start at c1 and wrap inside 10 content cells. Below this width words break between graphemes and the scrollbar drops below width 8; List never fails or clips without a mark.

```wireframe 12x3
▌Inbox     █
 Drafts and│
 old mail  │
```

```text
Callouts (12x3, 0-based):
1. r0 c0     Selection bar -- `selection.bar` on the selected one-row item in `accent`
             (focused) / `secondary` (unfocused); the bar cell takes the fill when
             derived; where `selection.fill` is reverse video the bar draws on the
             terminal background and the fill starts at the next cell
             ([selection](../tokens.md#selection))
2. r1-r2 c1  Data row -- `Drafts and old mail` wrapped at 10 cells over two rows;
             content, wraps
3. r0-r2 c11 Scrollbar -- one-row thumb at r0; 5 content rows in a 3-row viewport
```

Degraded ascii/no-color (26x5, the anatomy's top slice): geometry identical, glyphs swapped per the [degradation ladder](../tokens.md#degradation-ladder) -- `>` selection, `-`/`+` disclosure, `|`/`#` scrollbar. Unfocused looks the same in any capability but uses `selection.inactive` instead of `selection.fill`.

```wireframe 26x5
- Mailboxes              #
   Inbox              12 #
>  Drafts              3 #
   Sent                  |
+ Projects               |
```

Empty data renders the List's static structure (declared Section headers) and zero rows; List invents no placeholder message. Loading, empty, and error presentations are app child states, composed beside or instead of the List.

## State model

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| rows | derived | flattened visible presentation | recomputed from data, section structure, and expansion bindings on every update; collapsed sections contribute only their header; never stored |
| row heights | derived | `[Int]` (rows per flattened item) | each item is measured at the content width with a nil height, so a wrapping item reports every row it needs; re-measured whenever the width changes; never stored (key D10) |
| selection | Binding | `Element.ID?` (optional param) | List never invents a value; if the ID vanishes from data or its section collapses, selection renders nowhere and the binding is not mutated; arrows move it directly, with no separate cursor (keys D1 and D3) |
| selection presence | derived | `Bool` | structural: binding supplied at init reserves the gutter and enables selection keys; absent binding reserves no gutter and arrows scroll |
| section expansion | Binding | `Bool` per collapsible Section | forwarded to each [Section](section.md); List reads it to flatten rows and writes it only for the Left/Right and header-click rows below |
| scroll offset | NodeState | `Int` (content rows above the viewport) | counts rows, not items; a partly visible item at either edge draws its visible rows; clamps to `0...maximum scroll offset` on every update, including after a width change re-wraps the items; selection-moving keys reveal the selected item: the fewest rows that show every row of it, aligning its first row with the viewport top when it is taller than the viewport (key D4) |
| maximum scroll offset | derived | `Int` | `max(0, C - V)` for C content rows (the sum of row heights) and V viewport rows; recomputed per layout pass; never stored |
| row line limit | Environment | `Int?` (`lineLimit`) | default nil, so rows wrap; `.lineLimit(1)` on a row or on the List restores single-line rows; chrome (headers, badges) pins its own value |
| header styling | Environment | `secondary` | Section header default; see [Section](section.md) |
| selection style | Environment | `selection.*` tokens | active vs inactive chosen by focus |
| hovered row | derived | `Int?` (row index under the pointer) | derived at render from the graph-owned hover point (key F4); the graph clears it on focus loss and when motion tracking stops ([Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md)); never stored in NodeState or a binding; nil while hover enabled is false; a selected row keeps `selection.fill` under the pointer |
| hover enabled | Environment | `Bool` | on by default, and List requests motion tracking while it is live in the graph; `.rowHover(.disabled)` removes the hover fill and the request (owner decision, 2026-10-19); the spelling is a placeholder (see Open questions) |

The "selection ID vanished" rule is Slice 7's mandatory "app mutated data under the widget" case, and collapsing the selected row's section is deliberately the same case: render sanely, never write the binding to "fix" it. Re-expanding renders the selection again without auto-scrolling; the next selection-moving key applies the visibility clamp.

The scroll offset has exactly one runtime owner: if `List` handles events as a stateful leaf it uses `LeafView.handleEvent` with the same `NodeState` read by layout and rendering, and never mirrors the offset into `_ResponderView.ResponderState`.

List is one focus stop: rows are not individually focusable, and Tab moves past the whole widget. Focus presentation rides the selection tint swap; when hosted in a focus-appearance host (for example [Box](../primitives/box.md)) the host paints its [focus rule](../tokens.md#focus). A selection-less List follows [ScrollView's](scroll-view.md) delegated focus appearance.

## Key table

With a selection binding, arrows auto-commit through the binding -- no Enter or Space to confirm ([NavigationSplitView sidebar contract](navigation-split-view.md)). Traversal visits selectable rows only: section headers and collapsed content are skipped by construction, never by caller-side skip loops.

| Key | Precondition | Effect | Consumed |
| --- | --- | --- | --- |
| Down | focused, selection binding present, selection set | moves selection to next visible selectable row via binding | yes |
| Up | focused, selection binding present, selection set | moves selection to previous visible selectable row via binding | yes |
| Down | focused, selection binding present, selection not set | sets selection to first visible selectable row via binding | yes |
| PgDn | focused, selection binding present | moves selection one viewport of rows down via binding | yes |
| PgUp | focused, selection binding present | moves selection one viewport of rows up via binding | yes |
| Home | focused, selection binding present | moves selection to first selectable row via binding | yes |
| End | focused, selection binding present | moves selection to last selectable row via binding | yes |
| Enter | focused, selection is set | calls `onActivate` with the selected element | yes |
| Left | focused, selection set, its section collapsible, expanded | collapses the selection's section via its expansion binding | yes |
| Right | focused, selection set, its section collapsible, collapsed | expands the selection's section via its expansion binding | yes |
| Down | focused, selection binding absent, offset below maximum | increments NodeState scroll offset | yes |
| Up | focused, selection binding absent, offset above 0 | decrements NodeState scroll offset | yes |

Up and Down at the first and last selectable row saturate and stay consumed (Table parity): selection keys never leak to ancestors while the List is focused. A hidden selection (collapsed section) stays the traversal anchor: Down and Up move to the nearest visible selectable row after or before its flattened position. Without a selection binding, boundary arrows follow ScrollView: unchanged offset, not consumed, for ancestor routing. Every selection-moving effect also updates the `NodeState` scroll offset by reveal (see the state model). Selection keys move by item; only the offset is in rows, so PgUp and PgDn move the selection to the item containing the row one viewport (V rows) above or below the selected item's first row, clamped to the first and last selectable item.

## Mouse table

| Event | Region | Precondition | Effect | Consumed |
| --- | --- | --- | --- | --- |
| click | data row | selection binding present | sets selection to that row's ID via binding; click-to-focus runs first (key F6) | yes |
| double-click | data row | selection binding present | sets selection, then calls `onActivate` | yes |
| click | section header | header collapsible | toggles that section's expansion via its binding | yes |
| click | section header | header not collapsible | none -- noninteractive label | no |
| wheel-down | viewport | scroll offset < maximum scroll offset | increments NodeState scroll offset | yes |
| wheel-up | viewport | scroll offset > 0 | decrements NodeState scroll offset | yes |
| move | data row | hover enabled | none: the graph moves its hover point and the derived hovered row follows (key F4); no selection or scroll change | no |

Wheel scrolling moves the viewport without touching selection (the bar and fill simply are not rendered until the row returns), as key F7 sets for List. Boundary wheel events are not consumed so a scrollable ancestor can continue (ScrollView routing parity). The ScrollIndicator is output-only: List routes no click or drag to it (key F2). Right and middle clicks have no List use, because context menus are post-1.0 (key F3; see [Scope decisions](#scope-decisions)).

## Sizing

List is greedy on both axes when proposed; its ideal is content-driven. Numbers use the anatomy's data set (18 flattened rows) and the Wrapped state's data set (10 items); the rule, not the numbers, is normative.

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil | 11x18 | ideal: widest flattened row's unwrapped width (a nil width does not wrap) by every row (a nil height); all 18 rows fit, no indicator reservation |
| 26 x 12 | 26x12 | fills the proposal exactly; content rows beyond the viewport scroll |
| 34 x nil | 34x18 | wrapped fixture: items wrap at the 33-cell content width (gutter at c0) and take every row, so 18 content rows and no indicator |
| 34 x 8 | 34x8 | wrapped fixture: 20 rows overflow 8, so the indicator column is reserved and items re-wrap at 32 cells; offset, thumb, and paging count rows; edge items draw their visible rows |
| 12 x 3 | 12x3 | fills at the declared floor; rows wrap inside 10 content cells and the viewport scrolls; partial items draw their visible rows with no mark |
| 6 x 2 | 6x2 | fills; the indicator drops below width 8, so content is 5 cells: rows wrap at 5 cells with grapheme breaks and the viewport scrolls; no mark, since a List proposes a nil height to its items; never a layout failure |
| 200 x 50 | 200x50 | fills; rows keep their content height, rows below content stay blank |

## Environment

- `selection.bar` (ASCII `>`), `selection.fill`, `selection.inactive`; bar colour `accent` when focused, `secondary` when unfocused; the bar cell takes the fill when derived, and where `selection.fill` is reverse video it draws on the terminal background ([selection](../tokens.md#selection))
- `disclosure.expanded`, `disclosure.collapsed` (ASCII `-` / `+`) -- collapsible Section headers ([Marks](../tokens.md#marks))
- `secondary` -- Section header default and the preview row-content convention
- `hover` -- 12% row fill ([fill roles](../tokens.md#fill-roles)), the row-fill form of hover (key B14); slots and NO_COLOR use an underline on the row label instead; `.rowHover(.disabled)` is the placeholder opt-out spelling (owner decision, 2026-10-19)
- track `border`, thumb `accent`, and ASCII `scrollIndicator.ascii` for the output-only ScrollIndicator in its default `standard` preset, omp2's look (key K8; [scroll indicators](../tokens.md#scroll-indicators); [migration map](../tokens.md#migration-map))
- `truncation.mark`
- `lineLimit` / `truncationMode` (environment) -- app-set row budget and cut mode reach row content; Section headers and badges pin their own values
- [Focus rules](../tokens.md#focus) -- only via a delegating focus-appearance host; List adds no focus ring of its own

## Primitive dependencies

- [Section](section.md) (a widget) -- companion owning header anatomy and expansion presentation; List and Section land together in plan 032 step 14.2.
- [Badge](../primitives/badge.md) -- trailing row badge via `.badge(_:)` (see Row badges).
- [ScrollIndicator](../primitives/scroll-indicator.md) -- shared with ScrollView and Table; output-only, List supplies viewport state but routes no pointer input to it (key F2).
- [Text](../primitives/text.md#wrapping) -- row wrapping, [row budget](../primitives/text.md#row-budget), and [truncation](../primitives/text.md#truncation) (`lineLimit`, `truncationMode`); wrapping lands in plan 032 step 9.2, before List in step 14.2.
- [ScrollView](scroll-view.md#rows-and-variable-height-content) (a widget) -- the row-based offset, partial-item, paging, and reveal contract List follows.
- [Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md) mouse routing (plan 032 Phase 11) -- row hit testing (position to row ID), wheel routing, and the motion request for row hover come from the framework contract, never a private rect map (the gap Ratatui cannot close; issue #273). Row hover lands with List in step 14.2.

## Requirements

- `rows recompute from data and expansion bindings on every update without storage` (state model: rows)
- `vanished selection id renders no selection and does not mutate the binding` (state model: selection)
- `selected multi-line row paints the bar on every line` (states: mobile)
- `list fills its proposal on both axes` (sizing: 26 x 12)
- `nil x nil fits all rows without an indicator reservation` (sizing: nil x nil)
- `ascii degradation preserves geometry` (states: degraded)
- `row badge trails the row content at the trailing edge` (row badges)
- `rows wrap at the content width and take every row they need` (states: wrapped)
- `selection highlight covers every row of a wrapped item` (states: wrapped; anatomy: callout 3)
- `selection bar cell draws on the terminal background where selection fill is reverse video` (anatomy: callout 3)
- `line limit of one restores single-line tail-truncated rows` (states: single-line)
- `section headers stay one row under an inherited line limit` (anatomy: callout 1; state model: row line limit)
- `nil height proposal takes every wrapped row and reserves no indicator` (sizing: 34 x nil)
- `narrow width breaks words between graphemes, scrolls the viewport and draws no mark` (sizing: 6 x 2)

### Focus

- `arrow selection auto-commits through the binding without enter` (key table: Down)
- `down with no selection selects the first visible selectable row` (key table: Down, selection not set)
- `selection traversal skips section headers by construction` (key table: Down; anatomy: callout 1)
- `collapsing the selected rows section hides selection without mutating the binding` (state model: selection; key table: Left)
- `arrows from a hidden selection move to the nearest visible selectable row` (key table: Down)
- `left collapses and right expands the selections section via its binding` (key table: Left, Right)
- `enter activates the selected element` (key table: Enter)
- `unfocused selection renders the inactive tint` (state model: selection style)
- `selection bar is accent when focused and secondary when unfocused` (anatomy: callout 3)
- `list is one focus stop and tab moves past the whole widget` (Anatomy; State model; Key table)
- `list leaves its focus treatment to a hosting box and without a selection binding follows the scroll view's delegated focus appearance` (state model: selection style; scroll-view focus appearance)
- `up and down at the first and last selectable row saturate and stay consumed` (key table: Up, Down)
- `home and end select the first and last selectable row` (key table: Home, End)

### Pointer

- `double click selects then activates` (mouse table: double-click)
- `click on a data row selects it through the binding` (mouse table: click)
- `click on a collapsible header toggles expansion through its binding` (mouse table: section header)
- `row under the pointer takes the hover fill; a selected row keeps selection.fill under the pointer` (Anatomy callout 9; state model: hovered row)
- `rows request pointer motion only while the list is live in the graph` (state model: hover enabled; [Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md))
- `.rowHover(.disabled) removes the hover fill and the motion request` (state model: hover enabled; Environment: hover)
- `pointer motion moves the derived hovered row without changing selection or scroll offset` (mouse table: move; state model: hovered row)
- `the hovered row clears on focus loss and when motion tracking stops` (state model: hovered row)
- `slots, NO_COLOR and 16-colour show hover as an underline on the row label` (Degradation: hover)
- `click on a data row focuses the list before it selects and is consumed` (mouse table: click)
- `right and middle clicks have no list use` (mouse table)
- `click or drag on the list scroll indicator is not routed` (mouse table: scroll indicator)

### Scroll

- `selection stays visible when moved past the viewport edge` (key table: Down; state: scroll offset)
- `wheel scrolling moves viewport without changing selection` (mouse table: wheel-down)
- `boundary wheel events pass to ancestors unconsumed` (mouse table: wheel-down precondition)
- `re-expansion renders the preserved selection without auto-scrolling` (state model: selection)
- `scroll offset clamps when app shrinks data` (state model: scroll offset)
- `absent selection binding reserves no gutter and arrows scroll` (state model: selection presence; key table: Down, binding absent)
- `partly visible items draw their visible rows at the top and bottom edges without a mark` (states: wrapped)
- `scroll offset thumb and paging count rows not items` (state model: scroll offset; sizing: 34 x 8)
- `reveal scrolls the fewest rows that show the whole selected item` (state model: scroll offset; key table: Down)
- `item taller than the viewport top-aligns when revealed` (state model: scroll offset)
- `width change re-measures item heights and clamps the offset` (state model: row heights; scroll offset)
- `page down moves selection to the item one viewport of rows below` (key table: PgDn)
- `page up moves selection to the item one viewport of rows above` (key table: PgUp)
- `without a selection binding boundary arrows leave the offset unchanged and are not consumed` (key table: Down, binding absent)
- `selection scrolled out of view by the wheel draws no bar or fill until it returns` (state model: scroll offset)

## Degradation

- `NO_COLOR`: selection falls back to reverse video; headers to dim.
- 16-color: indexed equivalents; geometry unchanged.
- Hover: slots, NO_COLOR and 16-colour draw no hover fill; the row label is underlined (owner decision, 2026-10-19).
- ASCII-only: degraded wireframe above -- `>` selection, `-`/`+` disclosure, `|`/`#` scrollbar, `~` truncation mark.
- Below `min` (12x3): words break between graphemes and the viewport scrolls, with no mark on partial items (an app `lineLimit(1)` still marks with `…`, ASCII `~`), and the indicator drops below width 8; never a layout failure.

## Scope decisions

- Selection styling: `listSelectionStyle` is deferred to the [Slice 3](../../spec/phase-4/slice-03-styling-and-decoration.md) style/environment contract. v1 consumes the `selection.*` tokens directly with no parallel style protocol (ScrollView precedent); List keeps its selection tokens (owner decision, 2026-10-10).
- Multi-select `Binding<Set<ID>>` is out of v1, shared with [Table](table.md#open-questions). Revisit after both ship single-select with identical semantics (owner decision, 2026-10-10).
- Rows wrap by default (owner decision, 2026-10-18): List follows SwiftUI, with `.lineLimit(1)` as the opt-out on a row or the whole List. Offsets, thumb, and paging count rows per ScrollView's contract; selection covers every row of the item.
- Context menus are post-1.0, as key F3 records; the [1.0 surface](../../spec/phase-4/prerequisites-and-scheduling.md#the-10-surface) counts each catalog deferral as post-1.0. They need a secondary-click event in the catalog's [mouse-event vocabulary](../../design.md#mouse-table) plus Slice 5 routing; the target API shape is SwiftUI's `contextMenu(forSelectionType:menu:primaryAction:)`, whose menu closure receives the selection so empty-space and on-row menus differ.
- Bulk expand and collapse chords (Shift-Left/Right) are post-1.0 until a use case appears. A 1.0 app binds its own chord with `.onKey` on the List and writes the expansion bindings (keys C9, E3 and E5).
- Virtualization: List makes no claim in 1.0 that it builds only its visible rows (key G11).

This design was reviewed against the [Phase 4 theses](../../spec/phase-4.md): data, selection, and expansion are the app's bindings; the scroll offset is NodeState with one owner; hover is derived from the graph, never stored; and rows, heights, and the indicator are recomputed integer geometry on every pass.

## Open questions

- Row hover opt-out spelling: `.rowHover(.disabled)` is a placeholder name (owner decision, 2026-10-19), and [Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md) leaves the final name to Table and List. The owner picks it; deferred to plan 032 step 14.2, and Table records the same question for step 14.4.

## Inspiration

A List should make application data and selection obvious, not hide them behind a widget state object. Scrolling is an implementation detail; selected identity remains app state. Sections earn their keep by making headers unselectable by construction -- the single clearest lesson from Ratatui's ecosystem, where every app re-implements header-skipping arrow loops.
