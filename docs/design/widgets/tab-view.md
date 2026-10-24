---
kind: widget
status: ready
---

# TabView

`TabView` is Tessera's controlled tab bar with switchable panes. The application owns the selection through a `Binding` to a `Hashable` value. The view shows the pane for that value, draws the bar with a filled pill for the active tab and `secondary` text for the rest, and wraps the bar onto more rows rather than truncating it. When the bar runs out of width, inactive tabs with an icon collapse to that icon while the active tab keeps its label. Tab items accept `.badge(_:)`. The view keeps no state of its own: the chosen tab is the app's binding (key D1), and focus belongs to the graph, so TabView has no `NodeState`.

Owner decision, omp2 review, 2026-10: adopt as-is. `TabView` is controlled, tab items accept `.badge(_:)` as in SwiftUI, and inactive tabs collapse to icons when the bar is narrow.

The wireframes below are the accepted Tessera states, drawn from omp2's rendering with its theme roles renamed to Tessera roles. This widget follows the controlled-widget rule in [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md), takes its focus and key delivery from [Slice 4](../../spec/phase-4/slice-04-focus-and-key-routing.md), and its pointer delivery from [Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md).

## Prior art

- omp2 `Tabs`, [`tabs.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L1-L600). Copy the pill for the active tab, muted inactive titles, the rule row under the bar, wrapping of the bar onto extra rows, and icon-only collapse of inactive tabs when narrow. Sources: [`select` and `active`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L110-L118), [`chip_layout`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L158-L200), [`measure`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L235-L246), [`paint`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L272-L364), [`key`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L388-L401), [`mouse`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L403-L432). Reject the index-based selection. omp2 stores an unclamped index, clamps the pane to the last tab, and compares the raw index for the pill, so the pill and the pane can disagree. Tessera selects by identity through a binding and never clamps silently.
- SwiftUI [`TabView`](https://developer.apple.com/documentation/swiftui/tabview) and [`Tab`](https://developer.apple.com/documentation/swiftui/tab) supply the API vocabulary: `TabView(selection:)`, tab items identified by `value`, and `.badge(_:)` on a tab. Reject SwiftUI's platform-drawn tab bar; the terminal bar is drawn by the view.
- Translation, per the [translation key](../translation-key.md): each omp2 `tab` record is a `Tab` child view in the builder (key A7), titles and icons are initializer parameters (key B11), and the active index becomes the selection binding (key D1), so there is no value to harvest (key A10). Focus is an explicit `.focusable` identity drawn in the `focus` role (keys E1, E2), Left and Right are the Key table's only rows (key E3), and each chip is a hit region (key F1). Theme colours become roles (key J1). The bar flows its chips onto more rows as Picker's radio chips do (key G6). Icons resolve through Label's catalog (key K2), the cursor is the `cursor` mark (key K3), the rule row is a `light` rule (key K7), and the pill's ends are the `▐` `▌` caps (key K10). omp2 tints the chip under the pointer; TabView draws no hover (key F4; owner decision, 2026-10-10). The icon collapse is a `ViewThatFits` choice (key G10).

## API direction

Swift in SwiftUI vocabulary; a provisional shape (vocabulary, not a commitment).

```swift
enum Panel: Hashable { case overview, logs, config }

// `panel` is a Binding<Panel> from the app's model.
TabView(selection: panel) {
    Tab("Overview", icon: "home", value: Panel.overview) {
        Text("Build passed on main at 14:02.")
    }
    Tab("Logs", icon: "terminal", value: Panel.logs) {
        Text("cargo test: 312 passed")
    }
    .badge(3)
    Tab("Config", icon: "gear", value: Panel.config) {
        Text("strict = true")
    }
}
```

Callers compose focus explicitly, as Picker's callers do (key E1):

```swift
TabView(selection: panel) { … }
    .focusable(tabsFocusID)
    .focused(focused, equals: tabsFocusID)
```

`icon:` names resolve through the icon catalog that [Label](../primitives/label.md) uses. An unknown name draws no icon. A tab without an icon never shrinks. A tab badge draws trailing, outside its chip, as list rows draw badges: `▐Inbox▌ ▐3▌` (owner decision, 2026-10-10).

Tab chips are chrome (owner decision, 2026-10-18): each chip title is a `Text` with `.lineLimit(1)` applied by TabView itself, so an app's inherited `lineLimit` never reaches it, and each chip stays one row. The bar is a 2-cell cursor gutter beside `Flow(spacing: 2) { chips }` (key G6), as Picker's radio group is: wrapped lines start under the first chip, a chip wider than the line sits alone in a slot of the line's width and tail-truncates its label, and no chip wraps internally. `ViewThatFits(in: .horizontal)` chooses between the bar with full labels and the bar with every inactive icon chip collapsed, so the bar collapses before it wraps (key G10; [ViewThatFits](../primitives/view-that-fits.md), which splits omp2's chip layout the same way). omp2 collapses inactive chips one at a time from the last; no fixture here tells the two apart. The pane is app content: it inherits `lineLimit` and `truncationMode` and word-wraps at the pane width.

## Anatomy

Natural fixture: three tabs, the first active, the view focused so the cursor is drawn, and a pane showing one line of text. The bar is the tab row, the rule sits under it, and the pane is the active tab's content.

```wireframe 80x3
❯ ▐Overview▌   Logs    Config
────────────────────────────────────────────────────────────────────────────────
Build passed on main at 14:02.
```

```text
Callouts (80x3, 0-based):
1. r0 c0-1    Cursor -- `❯` in `focus` while the tab view is focused; two spaces otherwise.
              Drawn on the bar row only.
2. r0 c2-11   Active chip "Overview" -- caps `▐` and `▌` and the fill in `focus` while
              focused; bold title in `contrast` on the `focus` fill; chrome, one row.
3. r0 c15-18  Inactive chip "Logs" -- title in `secondary`; no caps, no fill; chrome, one row.
4. r0 c23-28  Inactive chip "Config" -- same as callout 3.
5. r1 c0-79   Rule -- `─` repeated to the content width, `border`.
6. r2 c0-29   Pane -- the active tab's content, placed on the row below the rule with the
              full content width; content, wraps.
7. frame      Whole view -- not a drawn element. Receives pointer events that hit no chip,
              rule, or pane, including the gaps between chips.
```

Styled grid (roles are Tessera roles, see [tokens.md](../tokens.md#roles); focus per owner decision, 2026-10-19):

```text
── chars ──
❯ ▐Overview▌   Logs    Config
────────────────────────────────────────────────────────────────────────────────
Build passed on main at 14:02.
── style ──
A.ABBBBBBBBA...CCCC....CCCCCC
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
A  fg=focus -- cursor and active-chip caps
B  fg=contrast bg=focus bold -- active-chip title
C  fg=secondary -- inactive titles
D  fg=primary -- pane content
E  fg=border -- rule row
```

## States

### Mobile: eight tabs wrap (40x5)

At 40 columns, eight tabs with no icons wrap onto three bar rows. The rule follows the last bar row and the pane follows the rule. The component is drawn at its natural height, five rows, not padded to a taller frame (owner decision, 2026-10-10).

```wireframe 40x5
❯ ▐Overview▌   Logs    Config
   Metrics    Traces    Alerts
   Deploys    Secrets
────────────────────────────────────────
Build passed on main.
```

```text
Callouts (40x5, 0-based):
1. r0-r2   Bar -- chips wrap onto extra rows (the component's own layout of chrome, each chip
           one row); chips without an icon never shrink, so the bar wraps instead of collapsing.
2. r0 c0   Cursor -- `❯` in `focus` on the first bar row only.
3. r3      Rule -- sits under the last bar row, not under the first.
4. r4      Pane -- starts on the row below the rule; content, wraps.
```

```text
── chars ──
❯ ▐Overview▌   Logs    Config
   Metrics    Traces    Alerts
   Deploys    Secrets
────────────────────────────────────────
Build passed on main.
── style ──
A.ABBBBBBBBA...CCCC....CCCCCC
...CCCCCCC....CCCCCC....CCCCCC
...CCCCCCC....CCCCCCC
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
DDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
A  fg=focus -- cursor and active-chip caps
B  fg=contrast bg=focus bold -- active-chip title
C  fg=secondary -- inactive titles
D  fg=primary -- pane content
E  fg=border -- rule row
```

### Switched: Left on the first tab wraps to Config

The bound selection moved to the last tab through the binding. The pill follows the bound value, and the pane shows the Config text. The rule and the pane are unchanged.

```wireframe 40x3
❯  Overview    Logs   ▐Config▌
────────────────────────────────────────
strict = true
```

```text
Callouts (40x3, 0-based):
1. r0 c0-1    Cursor -- `❯` in `focus`; the tab view is focused.
2. r0 c22-29  Active chip "Config" -- caps and fill in `focus`, bold title in `contrast`;
              the pill moved with the bound value.
3. r0 c3-18   Inactive chips "Overview", "Logs" -- `secondary` titles; they keep their labels
              because the bar fits.
```

```text
── chars ──
❯  Overview    Logs   ▐Config▌
────────────────────────────────────────
strict = true
── style ──
A..CCCCCCCC....CCCC...ABBBBBBA
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
DDDDDDDDDDDDD
── legend ──
.  default
A  fg=focus -- cursor and active-chip caps
B  fg=contrast bg=focus bold -- active-chip title
C  fg=secondary -- inactive titles
D  fg=primary -- pane content
E  fg=border -- rule row
```

### Minimum: icon collapse (24x5)

At 24 columns the active tab keeps its label. Inactive tabs with an icon collapse to the icon alone. Config's icon wraps onto the second bar row because the collapsed bar would overflow row one (derived, not captured). The pane is content and wraps within 24 columns.

```wireframe 24x5
 ▐ Overview▌   
   
────────────────────────
Build passed on main at
14:02.
```

```text
Callouts (24x5, 0-based):
1. r0 c0-1    Cursor -- the `cursor` mark, U+F054 under Nerd Font, in `focus` (key K3).
2. r0 c2-13   Active chip "Overview" -- home icon U+F015 at c3 (gap c4); caps and fill in
              `focus`; bold title in `contrast` on the `focus` fill; full label kept.
3. r0 c17-18  Collapsed chip "Logs" -- terminal icon U+F120 at c17 (gap c18), alone, in
              `secondary`.
4. r1 c3-4    Collapsed chip "Config" -- gear icon U+F013 at c3 (gap c4), in `secondary`,
              wrapped to the second bar row.
5. r2 c0-23   Rule -- `─` to the content width, `border`.
6. r3-r4      Pane -- wraps to the 24-column width.
```

The collapse grids use the Nerd Font charset. Under `.unicode` only `gear` has a glyph (`⚙`); `home` and `terminal` draw no icon, so those tabs keep their labels, since a tab without an icon never shrinks ([icon catalog](../tokens.md#icon-catalog); owner decision, 2026-10-19). A Nerd Font icon takes two cells, the glyph and a real space that is also the icon-title gap ([Nerd Font cells](../tokens.md#nerd-font-cells)).

```text
── chars ──
 ▐ Overview▌   
   
────────────────────────
Build passed on main at
14:02.
── style ──
A.ABBBBBBBBBBA...CC
...CC
EEEEEEEEEEEEEEEEEEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDD
DDDDDD
── legend ──
.  default
A  fg=focus -- cursor and active-chip caps
B  fg=contrast bg=focus bold -- active-chip title
C  fg=secondary -- inactive icons and titles
D  fg=primary -- pane content
E  fg=border -- rule row
```

### Minimum, ASCII (24x5)

ASCII has no caps or fills. The cursor is `>`, the active tab is a flat bold label in `focus`, and icons paint their ASCII names, `home`, `term` and `gear`, instead of glyphs. The rule is `-`.

```wireframe 24x5
> home Overview
   term    gear
------------------------
Build passed on main at
14:02.
```

```text
── chars ──
> home Overview
   term    gear
------------------------
Build passed on main at
14:02.
── style ──
A.BBBBBBBBBBBBB
...CCCC....CCCC
EEEEEEEEEEEEEEEEEEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDD
DDDDDD
── legend ──
.  default
A  fg=focus -- cursor
B  fg=focus bold -- active label
C  fg=secondary -- inactive titles and icon names
D  fg=primary -- pane content
E  fg=border -- rule row
```

### Under the minimum: truncated active label (12x6)

Derived from the settled truncation order, not captured (owner decision, 2026-10-10 for the order; the integer result follows from it). At 12 columns the 12-cell active chip does not fit beside the 2-cell cursor, so Flow gives it the whole 10-cell line and its label tail-truncates (chrome, one row): `Overv…`. The collapsed icon chips wrap onto the second bar row, 2 cells apart; the rule spans the proposal; the pane is content and wraps at 12 columns.

```wireframe 12x6
 ▐ Overv…▌
        
────────────
Build passed
on main at
14:02.
```

```text
Callouts (12x6, 0-based):
1. r0 c0-1    Cursor -- the `cursor` mark, U+F054 under Nerd Font, in `focus` (key K3).
2. r0 c2-11   Active chip -- home icon U+F015 at c3 (gap c4) and the label cut to `Overv…`;
              chrome, one row; Flow's slot is the whole 10-cell line.
3. r1 c3-4 and r1 c9-10  Collapsed chips -- terminal U+F120 and gear U+F013 icons alone, in
              `secondary`, on the second bar row.
4. r2 c0-11   Rule -- `─` repeated to the 12-column proposal, `border`.
5. r3-r5      Pane -- the active tab's content; content, wraps at 12 columns.
```

### Unfocused

No unfocused capture exists. The cursor is two spaces, and the active pill stays in `accent` with its caps and fill; its title stays bold `contrast` on the `accent` fill. This follows omp2's paint rules and is derived, not captured.

```wireframe 80x3
  ▐Overview▌   Logs    Config
────────────────────────────────────────────────────────────────────────────────
Build passed on main at 14:02.
```

```text
Callouts (80x3, 0-based):
1. r0 c0-1    Cursor -- two spaces; the cursor is drawn only while the tab view is focused.
2. r0 c2-11   Active chip "Overview" -- caps and fill in `accent`; bold title in `contrast`
              on the `accent` fill.
3. r0 c15-18  Inactive chip "Logs" -- title in `secondary`; no caps, no fill.
4. r0 c23-28  Inactive chip "Config" -- same as callout 3.
5. r1 c0-79   Rule -- `─` repeated to the content width, `border`.
6. r2 c0-29   Pane -- the active tab's content.
```

```text
── chars ──
  ▐Overview▌   Logs    Config
────────────────────────────────────────────────────────────────────────────────
Build passed on main at 14:02.
── style ──
..ABBBBBBBBA...CCCC....CCCCCC
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
A  fg=accent -- active-chip caps
B  fg=contrast bg=accent bold -- active-chip title
C  fg=secondary -- inactive titles
D  fg=primary -- pane content
E  fg=border -- rule row
```

### No matching selection

A binding that matches no tab draws no pill and an empty pane, and the binding is left unchanged (owner decision, 2026-10-10). The cursor still shows while the tab view is focused.

```wireframe 40x3
❯  Overview    Logs    Config
────────────────────────────────────────

```

```text
Callouts (40x3, 0-based):
1. r0 c0-1    Cursor -- `❯` in `focus`; the tab view is focused.
2. r0 c3-28   Inactive titles "Overview", "Logs", "Config" -- `secondary`; no pill is drawn.
3. r1 c0-39   Rule -- `─` repeated to the content width, `border`.
4. r2         Pane -- empty.
```

```text
── chars ──
❯  Overview    Logs    Config
────────────────────────────────────────

── style ──
A..CCCCCCCC....CCCC....CCCCCC
EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
── legend ──
.  default
A  fg=focus -- cursor
C  fg=secondary -- inactive titles
E  fg=border -- rule row
```

## State model

Schema: [README](../../design.md#state-model-table).

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| selection | Binding | `Value` (`Hashable`) | The view writes only through the binding on Left, Right, and chip click (key D1). It never invents or clamps a value (states: no matching selection). |
| bar layout | derived | chip widths, collapsed set, row count | Recomputed at the proposed width on every layout by `ViewThatFits` and `Flow` (keys D10, G6, G10). Never stored. |
| is focused | Environment | `Bool` | Injected below the explicit `.focusable` modifier from the FocusManager's live identity (key E1). The cursor and the active-pill focus fill follow it (key E2); it is never mirrored into NodeState. |
| pill and pane | derived | active tab | Recomputed from the bound selection on every render. |

## Key table

Schema: [README](../../design.md#key-table).

| Key | Precondition | Effect | Consumed |
| --- | --- | --- | --- |
| Left | focused | Selection moves to the previous tab through the binding; from the first tab, wraps to the last. | yes |
| Right | focused | Selection moves to the next tab through the binding; from the last tab, wraps to the first. | yes |

Every other key bubbles to the ancestors (key E3), and an unfocused tab view handles no keys.

## Mouse table

Schema: [README](../../design.md#mouse-table). Regions must be named in the anatomy callouts: `tab chip` (callouts 2-4), `rule` (callout 5), `pane` (callout 6), and `frame` (callout 7).

| Event | Region | Precondition | Effect | Consumed |
| --- | --- | --- | --- | --- |
| click | tab chip | chip index < count | Selection becomes that chip's value through the binding. Clicking the active chip writes the same value. | yes |
| click | rule | always | No effect. | no |
| click | pane | always | No effect. | no |
| click | frame | always | No effect; a click in a gap between chips lands here. | no |
| wheel-up | frame | always | No effect. | no |
| wheel-down | frame | always | No effect. | no |
| drag | frame | always | No effect. | no |
| move | frame | always | No effect. The bar paints no hover state, so the tab view requests no move input; move input is requested only while a hover consumer exists in its subtree (owner decision, 2026-10-10). | no |

## Sizing

Schema: [README](../../design.md#sizing-table). Results derived from the formula are marked as such. The bar's ideal width is the 2-cell cursor gutter plus one [Flow](../primitives/flow.md) line of chips, 2 cells apart; a chip is its title, its icon and gap where the charset draws one, and 2 cells of caps or padding. Chips are chrome and stay one row; the pane is content and wraps at the proposed width.

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil | 30x3 | Natural width is the larger of the bar (30: the gutter, chips of 10, 6 and 8 cells, and 2 cells between chips) and the widest pane (30); height is bar rows + 1 + pane rows (derived, not captured). |
| 24x5 | 24x5 | Tight fit at the minimum: `min(bar, 24)`; inactive icon chips collapse and chips without an icon wrap instead of shrinking (derived, not captured). |
| 40x3 | 40x3 | Captured default: the bar fits at full labels, and the rule and one pane line fill the height. |
| 40xnil | 40x5 | Captured wrap: chips wrap onto extra rows before the pane, and the rule follows the last bar row. |
| 16xnil | 16x5 | Under the minimum (derived): the active chip still fits (14 cells), the icon chips wrap to a second bar row, the rule spans 16, and the pane wraps to two rows: 2 + 1 + 2. |
| 12xnil | 12x6 | Under the minimum (derived): the active label tail-truncates to `Overv…` first (settled order), the icon chips wrap to a second bar row, the rule spans 12, and the pane wraps to three rows: 2 + 1 + 3. See the 12x6 state. |
| W<24 x nil | W x (bar rows + 1 + pane rows) | Under the minimum the result width is the proposal (the rule spans it) and the height is the bar rows plus the rule plus the pane rows at W. The order the bar gives way in is settled (owner decision, 2026-10-10): the active label truncates first, then inactive chips show icons only, then the pill caps drop. |
| 80x3 | 80x3 | Over-maximum: there is no maximum width; the rule spans the proposal and the pane takes the full content width. |

## Environment

Tokens consumed (see [tokens.md](../tokens.md#roles)).

- `accent`: the unfocused active tab's caps and fill.
- `focus`: the cursor, and the active tab's caps and fill while the tab view is focused.
- `primary`: pane content and padding cells.
- `secondary`: inactive titles. `border`: the rule row ([text roles](../tokens.md#text-roles)).
- `contrast`: title text on the active pill, `on(R)` inside `solid(R)` ([composite styles](../tokens.md#composite-styles)).
- `cursor` mark: `❯`, U+F054 under Nerd Font, `>` under ASCII, drawn in `focus` ([marks](../tokens.md#marks); key K3).
- Pill ends: the squared [caps](../tokens.md#caps), `▐` and `▌` in the fill colour (key K10); for ASCII see [Open questions](#open-questions).

## Primitive dependencies

- [Label](../primitives/label.md) (`ready`): chip icons and the icon catalog. Its icon table decides which names exist; the collapse is a `ViewThatFits` choice, not a `Label` style.
- [Badge](../primitives/badge.md) (`ready`): `.badge(_:)` on tab items. A tab badge draws trailing, outside its chip, as list rows draw badges (owner decision, 2026-10-10).
- [Flow](../primitives/flow.md) (`ready`): the bar's chip wrap (key G6), as for Picker's radio group.
- [ViewThatFits](../primitives/view-that-fits.md) (`ready`): chooses the bar with full labels or the bar with inactive icon chips collapsed (key G10).

## Requirements

Schema: [README](../../design.md#requirements-list).

- `tab view shows only the pane for the bound selection` (state model: selection; anatomy).
- `tab view never changes the bound selection on its own` (state model: selection).
- `active tab draws a filled pill and inactive tabs draw secondary titles` (anatomy callouts 2-4).
- `rule row draws in border, not secondary` (anatomy callout 5; states: mobile).
- `selection matching no tab draws no pill and an empty pane and leaves the binding unchanged` (states: no matching selection).
- `chips without an icon never shrink` (states: mobile).
- `bar wraps onto extra rows before the pane` (states: mobile).
- `rule row sits under the last bar row` (states: mobile).
- `narrow bar keeps the active tab labeled and collapses inactive icon tabs` (states: minimum).
- `bar keeps full labels while they fit one line and collapses inactive icon chips before it wraps` (sizing: 40x3; states: minimum; API direction: ViewThatFits).
- `a chip wider than the line sits alone and truncates its label to the line width` (states: under the minimum, 12x6).
- `under 24 columns truncates the active label, then collapses inactive chips to icons, then drops the pill caps` (sizing: under 24; states: under the minimum).
- `under 24 columns the result width is the proposal and the height is bar rows plus rule plus pane rows` (sizing: 16xnil, 12xnil).
- `tab chips are one row and never wrap internally; the pane wraps at its width` (anatomy callouts 2-6; states: under the minimum).
- `selected tab moves the pill without changing the pane layout` (states: switched).
- `tab view height is bar rows plus rule row plus active pane height` (sizing: nil x nil).
- `natural width is the larger of the bar and the widest pane` (sizing: nil x nil).

### Focus

- `left on the first tab wraps the selection to the last tab` (key table).
- `right on the last tab wraps the selection to the first tab` (key table).
- `left and right write the selection only through the binding` (state model: selection).
- `focused tab view draws the focus cursor on the bar row only` (anatomy callout 1).
- `nerd font draws the cursor mark as U+F054` (states: minimum; Environment: cursor mark).
- `unfocused tab view draws a blank cursor and the accent pill` (states: unfocused).
- `active pill is solid(focus) while the tab view is focused and solid(accent) when it is not` (anatomy callout 2; states: unfocused; [composite styles](../tokens.md#composite-styles)).
- `tab view bubbles every key except left and right and handles no keys while unfocused` (key table)
- `ascii tab view draws the cursor as > and the active tab as a flat bold label in focus while focused and accent otherwise` (states; Degradation: ASCII)
- `focused tab view with no matching tab shows its cursor with no pill and an empty pane` (state model: selection; states)

### Pointer

- `clicking a tab chip writes its value through the binding` (mouse table: click).
- `clicking the active tab chip leaves the selection unchanged` (mouse table: click).
- `a click outside a tab chip has no effect` (mouse table: click on rule, pane, frame).
- `move input is requested only while a hover consumer exists in the subtree; with none, move events are not delivered` (mouse table: move).
- `move events draw no hover state` (mouse table: move).
- `wheel and drag on the tab frame have no effect and are not consumed` (mouse table)

## Degradation

- Colour degradation follows the [degradation ladder](../tokens.md#degradation-ladder). This widget adds no rule of its own. The focused fill uses `focus`, so no brightened variant is derived.
- ASCII-only: the cursor is `>` followed by a space; pill caps are empty, so the active tab is a flat bold label, in `focus` while focused and in `accent` otherwise; the rule is `-`; icons paint their ASCII names (`home`, `term`, `gear`) instead of glyphs. Collapse and wrapping behave as in Unicode.
- Below 24 columns the truncation order in the sizing table applies (owner decision, 2026-10-10), and the result follows from it (states: under the minimum, 12x6).

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): the selection is the app's binding, the view holds no NodeState, focus stays with the graph, and the bar's wrap and collapse are deterministic integer-cell layout.

## Open questions

- **ASCII active tab (key K10).** Under ASCII the active tab is a flat bold label with no caps or fill, as omp2's ASCII chips are. The squared caps fall back to `.rectangle` fill cells under ASCII ([caps](../tokens.md#caps)), which Picker's radio group draws. The owner decides which TabView follows; deferred to plan 032 step 16.3, which builds TabView.

## Inspiration

Triage destination for inbox entries about this component.
