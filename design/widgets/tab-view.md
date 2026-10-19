---
kind: widget
status: wireframed
---

# TabView

`TabView` is Tessera's controlled tab bar with switchable panes. The application owns the
selection through a `Binding` to a `Hashable` value. The view shows the pane for that
value, draws the bar with a filled pill for the active tab and muted text for the rest,
and wraps the bar onto more rows rather than truncating it. When the bar runs out of
width, inactive tabs with an icon collapse to that icon while the active tab keeps its
label. Tab items accept `.badge(_:)`. The view keeps no selection of its own: losing its
`NodeState` loses pointer and focus bookkeeping, never the chosen tab.

Owner decision, omp2 review, 2026-10: adopt as-is. `TabView` is controlled, tab items
accept `.badge(_:)` as in SwiftUI, and inactive tabs collapse to icons when the bar is
narrow.

The wireframes below are the accepted Tessera states, drawn from omp2's rendering with its
theme roles renamed to Tessera roles. This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase),
takes its focus and key delivery from
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system), and its
pointer delivery from [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Prior art

- omp2 `Tabs`,
  [`tabs.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L1-L600).
  Copy the pill for the active tab, muted inactive titles, the rule row under the bar,
  wrapping of the bar onto extra rows, and icon-only collapse of inactive tabs when
  narrow. Sources:
  [`select` and `active`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L110-L118),
  [`chip_layout`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L158-L200),
  [`measure`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L235-L246),
  [`paint`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L272-L364),
  [`key`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L388-L401),
  [`mouse`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L403-L432).
  Reject the index-based selection. omp2 stores an unclamped index, clamps the pane to the
  last tab, and compares the raw index for the pill, so the pill and the pane can
  disagree. Tessera selects by identity through a binding and never clamps silently.
- SwiftUI [`TabView`](https://developer.apple.com/documentation/swiftui/tabview) and
  [`Tab`](https://developer.apple.com/documentation/swiftui/tab) supply the API
  vocabulary: `TabView(selection:)`, tab items identified by `value`, and `.badge(_:)` on
  a tab. Reject SwiftUI's platform-drawn tab bar; the terminal bar is drawn by the view.

## API direction

Swift in SwiftUI vocabulary. Signatures are a sketch until the widget is specified.

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

`icon:` names resolve through the icon catalog that [Label](../primitives/label.md) uses.
An unknown name draws no icon. A tab without an icon never shrinks. A tab badge draws
trailing, outside its chip, as list rows draw badges: `▐Inbox▌ ▐3▌` (owner decision,
2026-10-10).

## Anatomy

Natural fixture: three tabs, the first active, the view focused so the cursor is drawn,
and a pane showing one line of text. The bar is the tab row, the rule sits under it, and
the pane is the active tab's content.

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
              focused; bold title in `contrast` on the `focus` fill.
3. r0 c15-18  Inactive chip "Logs" -- title in `muted`; no caps, no fill.
4. r0 c23-28  Inactive chip "Config" -- same as callout 3.
5. r1 c0-79   Rule -- `─` repeated to the content width, `muted`.
6. r2 c0-29   Pane -- the active tab's content, placed on the row below the rule with the
              full content width.
7. frame      Whole view -- not a drawn element. Receives pointer events that hit no chip,
              rule, or pane, including the gaps between chips.
```

Styled grid (roles are Tessera roles; `muted` and `contrast` are pending plan 032 step
5.3; focus roles per owner decision, 2026-10-10):

```text
── chars ──
❯ ▐Overview▌   Logs    Config
────────────────────────────────────────────────────────────────────────────────
Build passed on main at 14:02.
── style ──
A.ABBBBBBBBA...CCCC....CCCCCC
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDD

── legend ──
.  default
A  fg=focus (`semantic.focus`): cursor and active-chip caps
B  fg=contrast bg=focus, bold: active-chip title (token pending plan 032 step 5.3)
C  fg=muted (token pending plan 032 step 5.3): inactive titles and rule
D  fg=primary: pane content
```

## States

### Mobile: eight tabs wrap (40x5)

At 40 columns, eight tabs with no icons wrap onto three bar rows. The rule follows the
last bar row and the pane follows the rule. The component is drawn at its natural height,
five rows, not padded to a taller frame (owner decision, 2026-10-10).

```wireframe 40x5
❯ ▐Overview▌   Logs    Config
   Metrics    Traces    Alerts
   Deploys    Secrets
────────────────────────────────────────
Build passed on main.
```

```text
Callouts (40x5, 0-based):
1. r0-r2   Bar -- chips wrap onto extra rows; chips without an icon never shrink, so the bar
           wraps instead of collapsing.
2. r0 c0   Cursor -- `❯` in `focus` on the first bar row only.
3. r3      Rule -- sits under the last bar row, not under the first.
4. r4      Pane -- starts on the row below the rule.
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
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
DDDDDDDDDDDDDDDDDDDDD

── legend ──
.  default
A  fg=focus (`semantic.focus`): cursor and active-chip caps
B  fg=contrast bg=focus, bold: active-chip title (token pending plan 032 step 5.3)
C  fg=muted (token pending plan 032 step 5.3): inactive titles and rule
D  fg=primary: pane content
```

### Switched: Left on the first tab wraps to Config

The bound selection moved to the last tab through the binding. The pill follows the bound
value, and the pane shows the Config text. The rule and the pane are unchanged.

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
3. r0 c3-18   Inactive chips "Overview", "Logs" -- muted titles; they keep their labels
              because the bar fits.
```

```text
── chars ──
❯  Overview    Logs   ▐Config▌
────────────────────────────────────────
strict = true
── style ──
A..CCCCCCCC....CCCC...ABBBBBBA
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
DDDDDDDDDDDDD

── legend ──
.  default
A  fg=focus (`semantic.focus`): cursor and active-chip caps
B  fg=contrast bg=focus, bold: active-chip title (token pending plan 032 step 5.3)
C  fg=muted (token pending plan 032 step 5.3): inactive titles and rule
D  fg=primary: pane content
```

### Minimum: icon collapse (24x5)

At 24 columns the active tab keeps its label. Inactive tabs with an icon collapse to the
icon alone. Config's icon wraps onto the second bar row because the collapsed bar would
overflow row one (derived, not captured). The pane wraps within 24 columns.

```wireframe 24x5
❯ ▐🏠 Overview▌   💻
   ⚙
────────────────────────
Build passed on main at
14:02.
```

```text
Callouts (24x5, 0-based):
1. r0 c0-1    Cursor -- `❯` in `focus`.
2. r0 c2-14   Active chip "Overview" with its `home` icon -- caps and fill in `focus`, bold
              title in `contrast`; full label kept.
3. r0 c18-19  Collapsed chip "Logs" -- `terminal` icon alone, in `muted`.
4. r1 c3      Collapsed chip "Config" -- `gear` icon, in `muted`, wrapped to the second bar
              row.
5. r2 c0-23   Rule -- `─` repeated to the content width, `muted`.
6. r3-r4      Pane -- wraps to the 24-column width.
```

```text
── chars ──
❯ ▐🏠 Overview▌   💻
   ⚙
────────────────────────
Build passed on main at
14:02.
── style ──
A.ABBBBBBBBBBBA...CC
...C
CCCCCCCCCCCCCCCCCCCCCCCC
DDDDDDDDDDDDDDDDDDDDDDD
DDDDDD

── legend ──
.  default
A  fg=focus (`semantic.focus`): cursor and active-chip caps
B  fg=contrast bg=focus, bold: active-chip title (token pending plan 032 step 5.3)
C  fg=muted (token pending plan 032 step 5.3): inactive titles and rule
D  fg=primary: pane content
```

### Minimum, ASCII (24x5)

ASCII has no caps or fills. The cursor is `>`, the active tab is a flat bold label in
`focus`, and icons paint their ASCII names, `home`, `term` and `gear`, instead of glyphs.
The rule is `-`.

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
CCCCCCCCCCCCCCCCCCCCCCCC
DDDDDDDDDDDDDDDDDDDDDDD
DDDDDD

── legend ──
.  default
A  fg=focus (`semantic.focus`): cursor
B  fg=focus, bold: active label
C  fg=muted (token pending plan 032 step 5.3): icon names and rule
D  fg=primary: pane content
```

### Unfocused

No unfocused capture exists. The cursor is two spaces, and the active pill stays in
`accent` with its caps and fill; its title stays bold `contrast` on the `accent` fill.
This follows omp2's paint rules and is derived, not captured.

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
3. r0 c15-18  Inactive chip "Logs" -- title in `muted`; no caps, no fill.
4. r0 c23-28  Inactive chip "Config" -- same as callout 3.
5. r1 c0-79   Rule -- `─` repeated to the content width, `muted`.
6. r2 c0-29   Pane -- the active tab's content.
```

```text
── chars ──
  ▐Overview▌   Logs    Config
────────────────────────────────────────────────────────────────────────────────
Build passed on main at 14:02.
── style ──
..ABBBBBBBBA...CCCC....CCCCCC
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
DDDDDDDDDDDDDDDDDDDDDDDDDDDDDD

── legend ──
.  default
A  fg=accent (`semantic.accent`): active-chip caps
B  fg=contrast bg=accent, bold: active-chip title (token pending plan 032 step 5.3)
C  fg=muted (token pending plan 032 step 5.3): inactive titles and rule
D  fg=primary: pane content
```

### No matching selection

A binding that matches no tab draws no pill and an empty pane, and the binding is left
unchanged (owner decision, 2026-10-10). The cursor still shows while the tab view is
focused.

```wireframe 40x3
❯  Overview    Logs    Config
────────────────────────────────────────

```

```text
Callouts (40x3, 0-based):
1. r0 c0-1    Cursor -- `❯` in `focus`; the tab view is focused.
2. r0 c3-28   Inactive titles "Overview", "Logs", "Config" -- `muted`; no pill is drawn.
3. r1 c0-39   Rule -- `─` repeated to the content width, `muted`.
4. r2         Pane -- empty.
```

```text
── chars ──
❯  Overview    Logs    Config
────────────────────────────────────────

── style ──
A..CCCCCCCC....CCCC....CCCCCC
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC


── legend ──
.  default
A  fg=focus (`semantic.focus`): cursor
C  fg=muted (token pending plan 032 step 5.3): inactive titles and rule
```

## State model

Schema: [README](../README.md#state-model-table).

| State         | Owner           | Type                                  | Reset or clamp rule                                                                                                                          |
| ------------- | --------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| selection     | app             | `Binding<Value: Hashable>`            | The view writes only through the binding on Left, Right, and chip click. It never invents or clamps a value (states: no matching selection). |
| bar layout    | derived         | chip widths, collapsed set, row count | Recomputed at the proposed width on every layout. Never stored.                                                                              |
| focus         | responder graph | `Bool`                                | Owned by the responder graph. The cursor and the active-pill focus fill follow it.                                                           |
| pill and pane | derived         | active tab                            | Recomputed from the bound selection on every render.                                                                                         |

## Key table

Schema: [README](../README.md#key-table).

| Key   | Precondition | Effect                                                                                          | Consumed |
| ----- | ------------ | ----------------------------------------------------------------------------------------------- | -------- |
| Left  | focused      | Selection moves to the previous tab through the binding; from the first tab, wraps to the last. | yes      |
| Right | focused      | Selection moves to the next tab through the binding; from the last tab, wraps to the first.     | yes      |
| other | focused      | No effect; the key continues to the ancestors.                                                  | no       |
| other | unfocused    | Not handled by the tab view.                                                                    | no       |

## Mouse table

Schema: [README](../README.md#mouse-table). Regions must be named in the anatomy callouts:
`tab chip` (callouts 2-4), `rule` (callout 5), `pane` (callout 6), and `frame` (callout
7).

| Event      | Region   | Precondition       | Effect                                                                                                                                                                                    | Consumed |
| ---------- | -------- | ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click      | tab chip | chip index < count | Selection becomes that chip's value through the binding. Clicking the active chip writes the same value.                                                                                  | yes      |
| click      | rule     | always             | No effect.                                                                                                                                                                                | no       |
| click      | pane     | always             | No effect.                                                                                                                                                                                | no       |
| click      | frame    | always             | No effect; a click in a gap between chips lands here.                                                                                                                                     | no       |
| wheel-up   | frame    | always             | No effect.                                                                                                                                                                                | no       |
| wheel-down | frame    | always             | No effect.                                                                                                                                                                                | no       |
| drag       | frame    | always             | No effect.                                                                                                                                                                                | no       |
| move       | frame    | always             | No effect. The bar paints no hover state, so the tab view requests no move input; move input is requested only while a hover consumer exists in its subtree (owner decision, 2026-10-10). | no       |

## Sizing

Schema: [README](../README.md#sizing-table). Results derived from the formula are marked
as such; the bar width is `2 + Σ(title width + 4)` per tab, with icons ignored.

| Proposal   | Result | Rule                                                                                                                                                    |
| ---------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil  | 32x3   | Natural width is the larger of the bar and the widest pane; height is bar rows + 1 + pane rows (derived, not captured).                                 |
| 24x5       | 24x5   | Tight fit at the minimum: `min(bar, 24)`; inactive icon chips collapse and chips without an icon wrap instead of shrinking (derived, not captured).     |
| 40x3       | 40x3   | Captured default: the bar fits at full labels, and the rule and one pane line fill the height.                                                          |
| 40xnil     | 40x5   | Captured wrap: chips wrap onto extra rows before the pane, and the rule follows the last bar row.                                                       |
| W<24 x nil | open   | Under the minimum the active label truncates first, then inactive chips show icons only, then the pill caps drop. The integer size is an open question. |
| 80x3       | 80x3   | Over-maximum: there is no maximum width; the rule spans the proposal and the pane takes the full content width.                                         |

## Environment

Tokens consumed. Roles marked pending are not yet in [tokens.md](../tokens.md) (plan 032
step 5.3).

- `semantic.accent`: the unfocused active tab's caps and fill.
- `semantic.focus`: the cursor, and the active tab's caps and fill while the tab view is
  focused.
- `semantic.primary`: pane content and padding cells.
- `muted`: inactive titles and the rule row. Not in `tokens.md`; token pending plan 032
  step 5.3.
- `contrast`: title text on the active pill. Not in `tokens.md`; token pending plan 032
  step 5.3.

## Primitive dependencies

- [Label](../primitives/label.md): chip icons and the icon catalog. Its icon table decides
  which names exist; the collapse behaviour here is the Tessera chip rule, not a `Label`
  style.
- [Badge](../primitives/badge.md): `.badge(_:)` on tab items. A tab badge draws trailing,
  outside its chip, as list rows draw badges (owner decision, 2026-10-10).

## Requirements

Schema: [README](../README.md#requirements-list).

- `tab view shows only the pane for the bound selection` (state model: selection;
  anatomy).
- `left on the first tab wraps the selection to the last tab` (key table).
- `right on the last tab wraps the selection to the first tab` (key table).
- `left and right write the selection only through the binding` (state model: selection).
- `tab view never changes the bound selection on its own` (state model: selection).
- `clicking a tab chip writes its value through the binding` (mouse table: click).
- `clicking the active tab chip leaves the selection unchanged` (mouse table: click).
- `a click outside a tab chip has no effect` (mouse table: click on rule, pane, frame).
- `move input is requested only while a hover consumer exists in the subtree; with none, move events are not delivered`
  (mouse table: move).
- `move events draw no hover state` (mouse table: move).
- `focused tab view draws the focus cursor on the bar row only` (anatomy callout 1).
- `unfocused tab view draws a blank cursor and the accent pill` (states: unfocused).
- `active tab draws a filled pill and inactive tabs draw muted titles` (anatomy callouts
  2-4).
- `selection matching no tab draws no pill and an empty pane and leaves the binding unchanged`
  (states: no matching selection).
- `chips without an icon never shrink` (states: mobile).
- `bar wraps onto extra rows before the pane` (states: mobile).
- `rule row sits under the last bar row` (states: mobile).
- `narrow bar keeps the active tab labeled and collapses inactive icon tabs` (states:
  minimum).
- `under 24 columns truncates the active label, then collapses inactive chips to icons, then drops the pill caps`
  (sizing: under 24).
- `selected tab moves the pill without changing the pane layout` (states: switched).
- `tab view height is bar rows plus rule row plus active pane height` (sizing: nil x nil).
- `natural width is the larger of the bar and the widest pane` (sizing: nil x nil).

## Degradation

- Colour degradation follows the [degradation ladder](../tokens.md#degradation-ladder).
  This widget adds no rule of its own. The focused fill uses `semantic.focus`, so no
  brightened variant is derived.
- ASCII-only: the cursor is `>` followed by a space; pill caps are empty, so the active
  tab is a flat bold label, in `focus` while focused and in `accent` otherwise; the rule
  is `-`; icons paint their ASCII names (`home`, `term`, `gear`) instead of glyphs.
  Collapse and wrapping behave as in Unicode.
- Below 24 columns the truncation order in the sizing table applies (owner decision,
  2026-10-10). No wireframe is drawn for it.

## Open questions

Decisions deliberately not made yet, each with what unblocks it.

- **Under-minimum result.** The truncation order under 24 columns is settled (owner
  decision, 2026-10-10). The integer size for a proposal under 24 columns is not derived
  yet, so that sizing row stays open. Unblocks: a derived or captured size at a proposal
  under 24 columns.
- **Collapse dependency.** Collapse is specified here as the Tessera chip rule. Until the
  [Label](../primitives/label.md) icon table is settled, the set of collapsible icons is a
  design reference, not a settled API.
- **Token roles.** `muted` and `contrast` have no rows in `tokens.md`; both are token
  pending plan 032 step 5.3. The brightened accent is gone (owner decision, 2026-10-10),
  so it needs no token. Unblocks: plan 032 step 5.3.

## Inspiration

Triage destination for inbox entries about this component.
