---
kind: widget
status: specified
---

# Picker

`Picker` is Tessera's controlled selection control over an app-supplied finite option set.
The application owns both that set and the selected value through `Binding<Selection>`;
Picker only derives which supplied option is selected and renders it. It retains no
business data and never invents a selection. This is a widget-layer design following the
controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase),
with explicit focus supplied by
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system) and
pointer delivery supplied by [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

The 1.0 presentations are the default inline cycling row, a radio group, a segmented
control, and a menu. Each presentation is chosen through `pickerStyle` and shares the same
binding, focus, and enabled rules. Picker holds one value; selecting several is the
separate [MultiPicker](multi-picker.md) type (owner decision, 2026-10-18).

Text in Picker follows the [wrap and truncation rules](../README.md#wrap-and-truncation)
(owner decision, 2026-10-18). The title, menu option labels, descriptions, and the
collapsed value in a host row are content: they wrap and scroll in rows, and apps opt out
with `.lineLimit(1)`. The standalone inline row's value slot, radio chips, segments, and
markers are chrome, one row, and pin their own single-row values. Radio chips and segments
keep their drop and truncate rules.

## Prior art

- Ratatui tabs: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/tabs.rs` -- copy its
  label measurement and constrained rendering of a selected item. Reject its
  stateful-index API and direct event model: Tessera derives the selected index from the
  app-owned binding and routes only focused responder input.
- Ratatui list state: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/list/state.rs`
  -- copy the discipline of clamping a visual index when the item collection changes.
  Reject retaining a selected item or offset in Picker state; an absent bound value
  remains absent until the user intentionally cycles it.
- Apple SwiftUI [Picker](https://developer.apple.com/documentation/swiftui/picker) -- copy
  the controlled selection binding, finite choices, label-builder vocabulary, and the
  style values `.menu`, `.radioGroup`, and `.segmented`. Reject wheel and popover
  presentations in 1.0; the menu style is an in-place list.
- Textual [Select](https://textual.textualize.io/widgets/select/) -- copy its compact
  presentation of the current choice. Reject its transient expanded list and
  widget-retained choice state. The menu style keeps its option list in place (owner
  decision, omp2 review, 2026-10).
- omp2 radio chip row,
  [`radio.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/radio.rs#L167-L197)
  -- copy the chip vocabulary, the pill-capped active chip, the Left and Right wraparound,
  and the chip click. Adjust: a chip row that does not fit wraps onto more rows instead of
  clipping, so every option stays visible (owner decision, omp2 review, 2026-10).
- omp2 segmented control,
  [`segmented.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/segmented.rs#L183-L220)
  -- copy the icon-and-label segments, the one-cell padding on both sides of each segment,
  the active and focused treatment, and the Left and Right wraparound. Adjust: segments
  are chrome, one row, so labels tail-truncate, and a row too narrow for labels falls back
  to icons only (owner decision, omp2 review, 2026-10).
- omp2 select menu,
  [`select.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L514-L715)
  -- copy the in-place option list, the cursor glyph separate from the chosen glyph, the
  custom "Other (type your own)" row with its editing keys, and the Up, Down, Enter, and
  Space behaviour (owner decision, omp2 review, 2026-10). Its digit quick-select is in
  Picker 1.0 (owner decision, 2026-10-11); its multi-select is the separate
  [MultiPicker](multi-picker.md) (owner decision, 2026-10-18); its description layout is
  the own-row form when descriptions do not fit an aligned column (owner decision,
  2026-10-18); its fuzzy filter is not in 1.0 (see Out of scope).

## API direction

The public API takes SwiftUI's shape: a title string or a `label` view, a required
selection binding, an app-supplied finite option collection, and a value-label builder
(owner decision, 2026-10-18):

```swift
public struct Picker<Label: View, Selection: Hashable, Value: View>: View {
    public init(
        selection: Binding<Selection>,
        options: [Selection],
        @ViewBuilder content: @escaping (Selection) -> Value,
        @ViewBuilder label: () -> Label
    )
}

extension Picker where Label == Text {
    public init(
        _ title: String,
        selection: Binding<Selection>,
        options: [Selection],
        @ViewBuilder content: @escaping (Selection) -> Value
    )
}
```

The title, or the `label` view, names the Picker (owner decision, 2026-10-18). It is the
menu's title row, the row label when a host such as a [Form](form.md) places the Picker,
and the accessible name. The inline cycling row and the segmented control draw it before
themselves, as [LabeledContent](labeled-content.md) draws its label, and the radio group
does the same. `.labelsHidden()` hides the drawn title in every presentation and keeps it
as the accessible name (see [Title](#title)). The title is content and wraps.

The `selection` binding is the sole source of a selected value. The title, `options`, and
`content` are immutable widget configuration supplied by the application; changing them on
reconciliation is authoritative. Callers compose focus explicitly:

```swift
Picker("Size", selection: selection, options: options) { option in Text(option) }
    .focusable(pickerFocusID)
    .focused(focused, equals: pickerFocusID)
```

A `label` view takes the place of the title string:

```swift
Picker(selection: selectedRegion, options: regions) { region in
    Text(region)
} label: {
    Label("Region", systemImage: "globe")
}
```

The presentation is chosen with the 1.0 style values. The default is the inline cycling
row.

```swift
// `selectedView` is a Binding from the app's model.
Picker("View", selection: selectedView, options: views) { view in
    Label(view.title, systemImage: view.symbol)
}
.pickerStyle(.segmented)
.labelStyle(.iconOnly)
```

- `.pickerStyle(.radioGroup)` -- a horizontal chip row that wraps onto more rows. Chips
  are chrome, one row each.
- `.pickerStyle(.segmented)` -- a horizontal segment control with tail-truncated labels
  and an icon-only fallback. Segments are chrome, one row. Segment icons are
  [Label](../primitives/label.md) catalog names; every catalog row has an ASCII form, and
  an unknown name draws its raw text.
- `.pickerStyle(.menu)` -- an in-place option list with a cursor and, when the initializer
  supplies `customOption`, a custom row. Option rows are content: they wrap, and the list
  scrolls in rows (owner decision, 2026-10-18).

The inline cycling row is a single-row control: its value slot is chrome, one row, and
tail-truncates; an inherited `lineLimit` never reaches it. In a host row such as a Form
row, the inline value follows the host-row content rule (Q27): it is content, wraps under
the value column, and the host decides its row count (owner decision, 2026-10-18). A
standalone inline row stays chrome.

The custom "Other" row is an initializer parameter, not a modifier (owner decision,
2026-10-18):

```swift
public init(
    selection: Binding<Selection>,
    options: [Selection],
    customOption: @escaping (String) -> Selection?,
    customOptionLabel: String = "Other (type your own)",
    @ViewBuilder content: @escaping (Selection) -> Value,
    @ViewBuilder label: () -> Label
)

// Where Label == Text:
public init(
    _ title: String,
    selection: Binding<Selection>,
    options: [Selection],
    customOption: @escaping (String) -> Selection?,
    customOptionLabel: String = "Other (type your own)",
    @ViewBuilder content: @escaping (Selection) -> Value
)
```

`customOption` turns the typed draft into a `Selection`, or returns `nil` to reject it:
the draft stays and editing continues. No closure, no row. `Selection` is no longer
constrained to `String`. The row appears only in the `.menu` style; the other styles
ignore the closure. A bound value that matches no option is shown on the custom row
through `content`. A typed value that equals an option marks that option and adds no row.

```swift
// `environment` is a Binding<String> from the app's model.
Picker(
    "Environment",
    selection: environment,
    options: ["Production", "Staging"],
    customOption: { draft in draft.isEmpty ? nil : draft }
) { name in Text(name) }
.pickerStyle(.menu)
```

Multi-select is the separate [MultiPicker](multi-picker.md) type, with its own
`.multiPickerStyle(_:)` (owner decision, 2026-10-18). Picker has one initializer family
and holds exactly one value.

Option descriptions attach with `.optionDescription(_:)`, which takes a closure returning
`String?`. A `nil` result draws no description for that option. The menu lays descriptions
out in an aligned column when every one fits whole, and otherwise on their own rows under
the labels (see [Menu with descriptions](#menu-with-descriptions)).

```swift
Picker("Deploy region", selection: selectedRegion, options: regions) { region in
    Text(region)
}
.optionDescription { region in regionNotes[region] }
```

Picker renders from `EnvironmentValues.isFocused` and handles keys only when
`ResponderContext.isFocused` is true.

> Deferred: custom `PickerStyle` conformance, custom chrome, and style configuration land
> in a later slice. They must preserve the implemented selection, keyboard, pointer,
> enabled, and focus behavior.

## Presentations

| Presentation       | Swift value                             | Shape                                                            | Height                                             |
| ------------------ | --------------------------------------- | ---------------------------------------------------------------- | -------------------------------------------------- |
| Inline cycling row | default                                 | one row, chevrons, value slot                                    | 1, plus the title's rows when it stacks            |
| Radio group        | `.pickerStyle(.radioGroup)`             | horizontal chips, wrapped onto more rows                         | wrapped rows, plus the title's rows when it stacks |
| Segmented control  | `.pickerStyle(.segmented)`              | one row of segments, icon-only fallback                          | 1, plus the title's rows when it stacks            |
| Menu               | `.pickerStyle(.menu)`                   | in-place option list with cursor; custom row when supplied       | title row plus option rows                         |
| Menu in a host row | `.pickerStyle(.menu)` inside a host row | the value and `▾` when closed; the open list draws below the row | the value's rows when closed (1 while it fits)     |

Multi-select presentations are [MultiPicker's](multi-picker.md#presentations).

## Anatomy

The default inline cycling row is one row, and it is a single-row control: the value slot
is chrome (`.lineLimit(1)` applied by the component), so it tail-truncates and never
wraps, whatever height or `lineLimit` the app offers (owner decision, 2026-10-18). This
holds for a standalone row; in a host row such as a Form row the inline value is content,
wraps under the value column, and the host decides its row count (Q27). `Medium` is the
currently selected option's label. Both chevrons stay visible at an endpoint so the
control keeps a stable, recognizable shape; unavailable directions are inert rather than
cycling.

```wireframe 10x1
‹ Medium ›
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Picker hit target -- complete allocated one-row Picker frame; its value slot
            is the only activating mouse region.
2. r0 c0    previous chevron -- U+2039; it inherits the Picker row's resolved Style and
            signals the previous direction but is not independently clickable in 1.0.
3. r0 c2-c7 value slot -- selected option label; primary click focuses before attempting
            the next selection; chrome, one row.
4. r0 c9    next chevron -- U+203A; it inherits the Picker row's resolved Style and
            signals the next direction but is not independently clickable in 1.0.
```

The other three presentations are specified under States, with their own wireframes. The
inline row, radio group, and segmented control wireframes show the control alone, as under
`.labelsHidden()`; [Title](#title) shows the title drawn before them.

## States

### Mobile

`mobile` is 40 columns wide at natural height. Picker keeps its one-row, label-hugging
geometry and is not padded to a 40x16 frame (owner decision, 2026-10-10).

```wireframe 40x1
‹ Medium ›
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c9 Picker hit target -- the inline row stays label-hugging at the mobile viewport.
2. r0 c0    previous chevron -- visible navigation affordance.
3. r0 c2-c7 value slot -- selected option label, not stretched to viewport width; chrome,
            one row.
4. r0 c9    next chevron -- visible navigation affordance.
```

### Minimum

The declared normal-rendering floor is `5x1`: the two chevrons, two separating spaces, and
one value-label cell. The value slot is chrome, one row, so at this floor a longer
selected label tail-truncates with `truncation.mark` rather than wrapping. The floor is
unchanged by the 2026-10-18 wrap rules: a single-row control keeps its own drop and
truncate rules.

```wireframe 5x1
‹ M ›
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4 Picker hit target -- minimum inline frame that retains both directions and one
            label cell.
2. r0 c0    previous chevron -- previous-direction affordance.
3. r0 c2    value slot -- one-cell, grapheme-safe tail-truncated selected label; chrome, one
            row.
4. r0 c4    next chevron -- next-direction affordance.
```

### Single option

A supplied one-option set keeps both chevrons to preserve stable geometry. Its selected
index is both endpoints, so every cycle attempt is inert and bubbles.

```wireframe 8x1
‹ Only ›
```

```text
Callouts (8x1, 0-based):
1. r0 c0-c7 Picker hit target -- stable one-row frame for a one-option set.
2. r0 c0    previous chevron -- visible but inert first-endpoint affordance.
3. r0 c2-c5 value slot -- the sole supplied option's label; chrome, one row.
4. r0 c7    next chevron -- visible but inert last-endpoint affordance.
```

### Absent bound value

If the bound value is absent from the current option set, Picker displays an em dash. It
does not repair or write the binding. The first enabled cycle with a nonempty option set
selects that set's first option and writes the binding.

```wireframe 5x1
‹ — ›
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4 Picker hit target -- stable frame while no supplied option matches the binding.
2. r0 c0    previous chevron -- visible direction affordance.
3. r0 c2    value slot -- absent-value placeholder, not a selection; chrome, one row.
4. r0 c4    next chevron -- visible direction affordance.
```

### Focused

Focus is never inferred from position. An app-installed `FocusID` match gives the inline
row `focus`; its cells and geometry do not change.

```wireframe 10x1
‹ Medium ›
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Picker hit target -- full row uses the focused resolved Style.
2. r0 c0    previous chevron -- focused previous-direction affordance.
3. r0 c2-c7 value slot -- focused selected label and keyboard target; chrome, one row.
4. r0 c9    next chevron -- focused next-direction affordance.
```

### Disabled

A disabled Picker renders all visible cells in `disabled`, is absent from the focusable
list, never changes its binding, and leaves keys and clicks unconsumed so an ancestor may
handle them.

```wireframe 10x1
‹ Medium ›
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Picker hit target -- disabled complete row; it is not an interactive target.
2. r0 c0    previous chevron -- disabled directional chrome.
3. r0 c2-c7 value slot -- disabled selected label; chrome, one row.
4. r0 c9    next chevron -- disabled directional chrome.
```

### ASCII degraded

At the ASCII-only rung, the inline presentation replaces the Unicode chevrons with their
one-cell ASCII fallbacks. Focus remains an attribute treatment rather than new geometry.

```wireframe 10x1
< Medium >
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Picker hit target -- same one-row geometry at the ASCII-only rung.
2. r0 c0    previous chevron -- ASCII `<` fallback for U+2039.
3. r0 c2-c7 value slot -- selected label; `—` would fall back to `-` when absent; chrome, one row.
4. r0 c9    next chevron -- ASCII `>` fallback for U+203A.
```

### Title

The inline cycling row and the segmented control draw the title before themselves, as
[LabeledContent](labeled-content.md) draws its label (owner decision, 2026-10-18): the
title in `secondary`, one gap cell, then the control. `ViewThatFits` keeps them side by
side when the control's natural width fits after the title; otherwise the title stacks
above the control, which then takes the full width. The title is content and wraps; the
control keeps its own one-row rules. The radio group, the other style that is not a list,
draws its title the same way. The title is not a hit target, so a click on it bubbles.
Inside a host row the host draws the title as its row label, and the Picker draws none.

`.labelsHidden()` on the Picker or an ancestor hides the drawn title in every
presentation, the menu's title row included. The title stays the accessible name:

```swift
Picker("View", selection: selectedView, options: views) { view in
    Label(view.title, systemImage: view.symbol)
}
.pickerStyle(.segmented)
.labelsHidden()
```

#### Title beside the inline row

```wireframe 15x1
Size ‹ Medium ›
```

```text
Callouts (15x1, 0-based):
1. r0 c0-c3  title -- "Size" in `secondary`; content, wraps; not a hit target.
2. r0 c4     gap -- one default cell.
3. r0 c5-c14 inline cycling row -- the Anatomy row, unchanged: chevrons and value slot;
             chrome, one row.
```

Styled grid for the title beside the inline row:

```text
── chars ──
Size ‹ Medium ›
── style ──
AAAA.BBBBBBBBBB
── legend ──
.  default
A  fg=secondary
B  fg=primary
```

#### Title stacked above the segmented control

At 24 columns the segmented fixture's natural width (28 cells) does not fit after the
title "View" and its gap, so the title stacks above the segments. The segments take the
full row and tail-truncate as in
[Tail-truncated labels at 24 columns](#tail-truncated-labels-at-24-columns).

```wireframe 24x2
View
 ▦ Grid  ≡ List  ⚙ Set…
```

```text
Callouts (24x2, 0-based):
1. r0 c0-c3  title -- "View" in `secondary`, stacked above the control; content, wraps.
2. r1 c0-c23 segmented control -- the full row; "Settings" tail-truncates to "Set…";
             chrome, one row.
```

### Radio group

The radio group is a horizontal row of chips, one per option. The selected chip is a pill
with accent background, contrast bold label, and pill caps on both sides. Unselected chips
are `secondary`. A chip's width is its label plus two pill-cap cells and one gap cell.
Each chip is chrome, one row (owner decision, 2026-10-18): the group is the component's
own flow layout of chrome items, so a chip that does not fit on the current row wraps onto
the next row, indented under the first chip, and every option stays visible and reachable.
A chip wider than the row tail-truncates with `truncation.mark`; the chip pins
`.lineLimit(1)`, so an inherited `lineLimit` never reaches it. Left and Right move through
the options in order and wrap across rows. The `❯` cursor prefix appears only while the
group is focused. Owner decision, omp2 review, 2026-10. `.radioGroup` is the wrapping chip
row; the vertical list is `.menu`, so there is no third layout (owner decision,
2026-10-10). The group's floor is the gutter plus the widest chip, `9x4` for this fixture
(see Sizing).

#### Wrapped to two rows

```wireframe 20x2
❯  sol   terra
   kimi  ▐fable▌
```

```text
Callouts (20x2, 0-based):
1. r0-r1 c0-c19 Radio group hit target -- each chip is one Chip hit; the group is the
            allocated frame.
2. r0 c0-c1  focus cursor -- `❯` plus a space in `focus` while focused; blank when unfocused.
3. r0 c3-c5  chip "sol" -- inactive chip; `secondary` label with padding; chrome, one row.
4. r0 c9-c13 chip "terra" -- inactive chip; starts the first row's second column stop;
            chrome, one row.
5. r1 c3-c6  chip "kimi" -- inactive chip on the wrapped row, indented under the first chip;
            chrome, one row.
6. r1 c9-c15 chip "fable" -- active pill: accent background, contrast bold label, and
            pill caps ▐ and ▌ outside the label; chrome, one row.
```

Styled grid for the wrapped radio group (owner-accepted review grid, roles renamed per
[tokens.md](../tokens.md#roles)):

```text
── chars ──
❯  sol   terra
   kimi  ▐fable▌
── style ──
EEBCCCBBBCCCCC
..BCCCCBBADDDDDA
── legend ──
.  default
A  fg=accent -- pill caps
B  fg=primary
C  fg=secondary
D  fg=contrast bg=accent bold underline
E  fg=focus bold
```

#### Wrapped to one chip per row

At 14 columns no two chips share a row. Each chip takes its own row, which reads as a
vertical list. It is still the chip row; the vertical list is the menu presentation. Every
option is still visible.

```wireframe 14x4
❯  sol
   terra
   kimi
  ▐fable▌
```

```text
Callouts (14x4, 0-based):
1. r0-r3 c0-c13 Radio group hit target -- four rows; the group grows to the wrapped height.
2. r0 c0-c1  focus cursor -- `❯` plus a space while focused.
3. r0 c3-c5  chip "sol" -- inactive chip on the first row; chrome, one row.
4. r1 c3-c7  chip "terra" -- inactive chip on its own wrapped row; chrome, one row.
5. r2 c3-c6  chip "kimi" -- inactive chip on its own wrapped row; chrome, one row.
6. r3 c2-c8  chip "fable" -- active pill; the left cap hangs one cell left of the label
            column, so the label aligns with the other chips; chrome, one row.
```

Styled grid for the one-chip-per-row radio group:

```text
── chars ──
❯  sol
   terra
   kimi
  ▐fable▌
── style ──
EEBCCC
..BCCCCC
..BCCCC
..ADDDDDA
── legend ──
.  default
A  fg=accent -- pill caps
B  fg=primary
C  fg=secondary
D  fg=contrast bg=accent bold underline
E  fg=focus bold
```

The active chip's underline appears only while the group is focused; there is no hover
treatment in 1.0 (owner decision, 2026-10-10). The grids above show the focused state.

#### Radio group floor

At the `9x4` floor each chip takes its own row, and the widest chips, "terra" and "fable",
fill the row after the two-cell gutter: five label cells plus two pill caps. Every chip
stays whole (owner decision, 2026-10-18; see Sizing).

```wireframe 9x4
❯  sol
   terra
   kimi
  ▐fable▌
```

```text
Callouts (9x4, 0-based):
1. r0-r3 c0-c8 Radio group hit target -- four rows at the floor width.
2. r0 c0-c1  focus cursor -- `❯` plus a space while focused.
3. r1 c2-c8  chip "terra" -- inactive; a widest chip with its two padding cells, whole;
             chrome, one row.
4. r3 c2-c8  chip "fable" -- active pill with caps ▐ and ▌, whole; chrome, one row.
```

### Segmented control

The segmented control is one row of segments. Each segment shows an icon, a label, or
both, with one cell of padding on each side. Segments are chrome, one row (owner decision,
2026-10-18): each pins `.lineLimit(1)`, so an inherited `lineLimit` never reaches it and a
segment label never wraps; every segment callout below is chrome, one row. The active
segment is `solid(accent)`: a contrast bold label on an accent fill, with no underline in
colour tiers; under `NO_COLOR` it is reverse video, bold, and underlined while the picker
is focused (owner decision, 2026-10-19;
[composite styles](../tokens.md#composite-styles)). Inactive segments are `secondary` on a
`surface` band, and draw `primary` while the picker is focused (owner decision,
2026-10-19; [fill roles](../tokens.md#fill-roles)). Icons are monochrome, never colour
emoji. When the row is too narrow for the full labels, the longest label gives up space
first and tail-truncates with `truncation.mark`, keeping two characters before the mark.
Below that floor, every segment shows its icon only. A segment without an icon and without
room for its label keeps `truncation.mark` rather than disappearing, so no option is
dropped. Owner decision, omp2 review, 2026-10. Segment icons are
[Label](../primitives/label.md) catalog names: every catalog row has an ASCII form, and an
unknown name draws its raw text.

#### Icons only at 40 columns

The app uses `.labelStyle(.iconOnly)`. Path, Tree, and Diff are icons only, with Tree
selected. This grid draws the Nerd Font charset: each icon is two cells, the glyph and a
real space, so an icon-only segment is `pad + icon(2) + pad`, four cells
([Nerd Font cells](../tokens.md#nerd-font-cells)). Under the Unicode charset Path and Tree
have no icon and keep `truncation.mark`; Diff draws `▤`.

```wireframe 40x1
       
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c11 Segmented group hit target -- one row; each segment is one Chip hit spanning its
            cells.
2. r0 c0-c3  Path segment -- icon-only (U+F15B), inactive; chrome, one row.
3. r0 c4-c7  Tree segment -- icon-only (U+F07B), active: `solid(accent)`; chrome, one row.
4. r0 c8-c11 Diff segment -- icon-only (U+EAE9), inactive; chrome, one row.
```

Styled grid for icons only at 40 columns (review grid, roles renamed):

```text
── chars ──
       
── style ──
AAAABBBBAAAA
── legend ──
.  default
A  fg=secondary bg=surface
B  fg=contrast bg=accent bold
```

#### Tail-truncated labels at 24 columns

"Settings" is the longest label, so it gives up space first and becomes "Set…". "Grid" and
"List" keep their full labels because the row still has room for them. The grid draws the
Unicode charset, so `list` is the one-cell `≡` (owner decision, 2026-10-19).

```wireframe 24x1
 ▦ Grid  ≡ List  ⚙ Set…
```

```text
Callouts (24x1, 0-based):
1. r0 c0-c23  Segmented group hit target -- one row; three segments.
2. r0 c0-c7   Grid segment -- active: `▦ Grid` with one cell of padding on each side.
3. r0 c8-c15  List segment -- inactive; full label fits.
4. r0 c16-c23 Settings segment -- inactive; label tail-truncated to `Set…` with its ⚙
            icon at c17.
```

Styled grid for tail-truncated labels at 24 columns:

```text
── chars ──
 ▦ Grid  ≡ List  ⚙ Set…
── style ──
BBBBBBBBAAAAAAAAAAAAAAAA
── legend ──
.  default
A  fg=secondary bg=surface
B  fg=contrast bg=accent bold
```

#### Icons only at 20 columns

Labels are too narrow for any useful text, so all three segments show their icons only.

```wireframe 20x1
 ▦  ≡  ⚙
```

```text
Callouts (20x1, 0-based):
1. r0 c0-c8  Segmented group hit target -- one row; the labels are dropped below the floor.
2. r0 c0-c2  Grid segment -- icon-only (▦), active.
3. r0 c3-c5  List segment -- icon-only (≡), inactive.
4. r0 c6-c8  Settings segment -- icon-only (⚙), inactive.
```

Styled grid for icons only at 20 columns:

```text
── chars ──
 ▦  ≡  ⚙
── style ──
BBBAAAAA
── legend ──
.  default
A  fg=secondary bg=surface
B  fg=contrast bg=accent bold
```

### Menu

The menu is an in-place list: the title row draws the Picker's title (owner decision,
2026-10-18), and each option takes one or more rows below it. No overlay opens. The cursor
row carries a `❯` and a bold label in the `focus` role. The cursor and the chosen option
are separate: `◉` in `accent` (one selection-mark colour with Toggle and Form; owner
decision, 2026-10-10) marks the chosen option, and `○` in `secondary` marks every other
option. The cursor starts on the chosen option, or on the first option when the bound
value is absent; it clamps when the option set changes, and the `❯` appears only while the
Picker is focused (owner decision, 2026-10-10). Enter or Space on an option chooses it.
Under `.labelsHidden()` the menu draws no title row.

The title row and option labels are content: they word-wrap at the menu's width, a wrapped
option's continuation rows indent under its label, and the cursor and selection cover
every row of the option. The option list scrolls in rows when the height is fixed (see
Menu scrolling in rows). `.lineLimit(1)` on an option or on the Picker, through the
environment, opts out: the label then tail-truncates on its row (owner decision,
2026-10-18). The markers, cursor, and caret are chrome, one row.

The custom row exists only when the initializer receives
`customOption: (String) -> Selection?`; no closure, no row (owner decision, 2026-10-18).
Its label is `customOptionLabel`, defaulting to "Other (type your own)". The row starts
text editing on Enter or Space, and the typed text follows a colon in `info` with a beam
caret. Enter hands the draft to the closure: a non-nil value is committed and stays chosen
after the caret goes away; `nil` rejects the draft and editing continues. Owner decision,
omp2 review, 2026-10. In 1.0 the menu also takes digit quick-select and option
descriptions (owner decision, 2026-10-11; see Menu with descriptions). Multi-select is the
separate [MultiPicker](multi-picker.md) type.

The captures below are omp2's menu at 40 columns, with legend roles renamed to Tessera
names, drawn with a `customOption` closure. None of their labels needs a second row at
this width; Wrapped option label shows one that does.

#### Cursor on an unchosen option

```wireframe 40x4
Environment
❯ ○ Production
  ○ Staging
  ○ Other (type your own)
```

```text
Callouts (40x4, 0-based):
1. r0 c0-c10  Picker title -- the title row; not a selection target; content, wraps.
2. r1 c0      cursor -- `❯` in `focus` on the cursor row; blank when unfocused.
3. r1 c2      unchosen marker -- `○` in `secondary`; chosen rows show `◉` in `accent`; chrome,
            one row.
4. r1 c4-c13  cursor label -- "Production" in the `focus` role; content, wraps.
5. r2 c4-c10  option label -- "Staging" in primary; content, wraps.
6. r3 c4-c24  custom row -- "Other (type your own)"; Enter or Space starts editing; present
            only because the Picker was given `customOption`; content, wraps.
```

Styled grid for the cursor on an unchosen option:

```text
── chars ──
Environment
❯ ○ Production
  ○ Staging
  ○ Other (type your own)
── style ──
AAAAAAAAAAA
BBCDEEEEEEEEEE
BBCDDDDDDDD
BBCDDDDDDDDDDDDDDDDDDDDDD
── legend ──
.  default
A  fg=primary bold
B  fg=focus
C  fg=secondary
D  fg=primary
E  fg=focus bold
```

#### Custom row while typing

The custom row is chosen and editing. Its typed draft follows the colon in `info`, and a
beam caret follows the draft. The chosen marker is `◉` in `accent`. A click on another
option while editing ends editing, discards the draft, and commits that option; a click on
the custom row keeps editing (owner decision, 2026-10-10).

```wireframe 40x4
Environment
  ○ Production
  ○ Staging
❯ ◉ Other (type your own): staging-eu▏
```

```text
Callouts (40x4, 0-based):
1. r0 c0-c10  Picker title -- the title row; content, wraps.
2. r3 c0      cursor -- `❯` in `focus`; the custom row is the cursor row.
3. r3 c2      chosen marker -- `◉` in `accent`: the custom row is the chosen value; chrome, one
            row.
4. r3 c4-c24 custom label -- "Other (type your own)" in `focus`; content, wraps.
5. r3 c25-c26 separator -- ": " in `secondary`; chrome, one row.
6. r3 c27-c36 draft text -- "staging-eu" in `info`; the shared text-editing core edits it;
            chrome, one row (see the exception below).
7. r3 c37     beam caret -- `▏` in accent; shown only while editing; chrome, one row.
```

> Wrap exception (rule 1): the draft line stays on one row and scrolls horizontally around
> the caret, with no wrap and no tail mark. Wrapping would move text under the caret as
> the user types, as in [TextField](text-field.md). The custom label and the committed
> value are content and wrap (owner decision, 2026-10-18).

Styled grid for the custom row while typing:

```text
── chars ──
Environment
  ○ Production
  ○ Staging
❯ ◉ Other (type your own): staging-eu▏
── style ──
AAAAAAAAAAA
BBCDDDDDDDDDDD
BBCDDDDDDDD
HHEDHHHHHHHHHHHHHHHHHHHHHCCGGGGGGGGGGB
── legend ──
.  default
A  fg=primary bold
B  fg=accent -- caret
C  fg=secondary
D  fg=primary
E  fg=accent
G  fg=info
H  fg=focus
```

#### Custom row after commit

`customOption` accepted the draft and Enter committed it. The row stays chosen and shows
the committed value through `content`; the caret goes away. A `nil` result from the
closure would have rejected the draft and kept editing. An empty draft on Enter ends
editing and leaves the bound value unchanged. Escape after a commit clears the draft, and
the committed value stays (owner decision, 2026-10-10).

```wireframe 40x4
Environment
  ○ Production
  ○ Staging
❯ ◉ Other (type your own): staging-eu
```

```text
Callouts (40x4, 0-based):
1. r0 c0-c10  Picker title -- the title row; content, wraps.
2. r3 c2      chosen marker -- `◉` in `accent`; the custom value is committed; chrome, one row.
3. r3 c4-c24 custom label -- `customOptionLabel`, "Other (type your own)" in `focus`;
            content, wraps.
4. r3 c27-c36 committed value -- "staging-eu" drawn through `content` in `info`; no caret, no
            editing; content, wraps.
```

Styled grid for the custom row after commit:

```text
── chars ──
Environment
  ○ Production
  ○ Staging
❯ ◉ Other (type your own): staging-eu
── style ──
AAAAAAAAAAA
BBCDDDDDDDDDDD
BBCDDDDDDDD
HHEDHHHHHHHHHHHHHHHHHHHHHCCGGGGGGGGGG
── legend ──
.  default
A  fg=primary bold
B  fg=accent
C  fg=secondary
D  fg=primary
E  fg=accent
G  fg=info
H  fg=focus
```

#### No selection

With no bound option, no row shows `◉`, and the cursor starts on the first option (Vim in
this capture; owner decision, 2026-10-10). The title row stays primary bold.

```wireframe 40x5
Editor
❯ ○ Vim
  ○ Emacs
  ○ Nano
  ○ Helix
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c5 Picker title -- the title row; content, wraps.
2. r1-r4    option rows -- every option is unchosen; `○` in `secondary`; labels are content, wraps.
3. r1 c0    cursor -- `❯` in `focus` on "Vim"; the cursor does not select it.
```

Styled grid for no selection:

```text
── chars ──
Editor
❯ ○ Vim
  ○ Emacs
  ○ Nano
  ○ Helix
── style ──
AAAAAA
HHCDHHH
BBCDDDDDD
BBCDDDDD
BBCDDDDDD
── legend ──
.  default
A  fg=primary bold
B  fg=accent
C  fg=secondary
D  fg=primary
H  fg=focus
```

#### Wrapped option label

An option label wider than the row wraps at word boundaries. The marker and cursor belong
to the option's first row; continuation rows indent under the label, past the four prefix
cells. The cursor and selection cover every row of the option, so both label rows take the
cursor treatment (owner decision, 2026-10-18).

```wireframe 24x4
Theme
❯ ◉ Solarized light with
    high contrast
  ○ Nord
```

```text
Callouts (24x4, 0-based):
1. r0 c0-c4   Picker title -- the title row; content, wraps.
2. r1 c0      cursor -- `❯` in `focus` on the option's first row.
3. r1 c2      chosen marker -- `◉` in `accent`, on the first row only; chrome, one row.
4. r1 c4-c23  label, first row -- "Solarized light with" in `focus` bold; content, wraps.
5. r2 c4-c16  label, continuation row -- "high contrast", indented under the label and part of
              the same cursor option; content, wraps.
6. r3 c2      unchosen marker -- `○` in `secondary`.
7. r3 c4-c7   option label -- "Nord" in primary; content, wraps.
```

With `.lineLimit(1)` on the option or the Picker, the first label would instead
tail-truncate on one row: "Solarized light wit…". <!-- codespell:ignore wit -->

#### Menu floor

The menu's floor is `14x6` for the `Environment` fixture: the four prefix cells plus the
widest label word, "Production" (ten cells); the title "Environment" (eleven cells) is
narrower. Every word stays whole, and "Other (type your own)" wraps to three rows in the
ten cells after the prefix (owner decision, 2026-10-18; see Sizing).

```wireframe 14x6
Environment
❯ ○ Production
  ○ Staging
  ○ Other
    (type your
    own)
```

```text
Callouts (14x6, 0-based):
1. r0 c0-c10    Picker title -- the title row; content, wraps.
2. r1 c0        cursor -- `❯` in `focus` on the cursor row.
3. r1 c4-c13    label "Production" -- the widest word, whole in the ten cells after the
                prefix; content, wraps.
4. r3-r5 c4-c13 custom row label -- "Other (type your own)" on three rows, continuation
                rows indented under the label; content, wraps.
```

#### Menu with descriptions

Each option may carry a description, drawn in `secondary` and content (owner decision,
2026-10-11). The layout is chosen per menu with `ViewThatFits`, never per option (owner
decision, 2026-10-18):

- **Aligned column.** When every description fits whole in the cells after the column, the
  descriptions align in a `secondary` column that starts two cells after the widest label,
  past the four prefix cells. Each option stays one row.
- **Own rows.** Otherwise every description goes on its own row under its label, indented
  to the label column (omp2's layout). On its own row a description wraps and never
  tail-truncates, and a description is never dropped.

The cursor and selection cover an option's description row. The same rule applies to the
open list of a menu in a host row, measured from its four-cell indent.

##### Aligned column

```wireframe 40x5
Deploy region
❯ ◉ eu-west   Ireland, lowest latency
  ○ us-east   Virginia, most capacity
  ○ ap-south  Mumbai, for APAC users
  ○ sa-east   Sao Paulo, lowest cost
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c12   Picker title -- the title row; content, wraps.
2. r1 c0       cursor -- `❯` in `focus`, drawn while focused.
3. r1 c2       chosen mark -- `◉` in `accent`; the other rows show `○` in `secondary`.
4. r1 c4-10    label "eu-west" -- `focus` bold on the cursor row; content, wraps.
5. r1-r4 c14   description column -- starts at cell 14: four prefix cells, the widest label
               "ap-south" (eight cells), and two cells.
6. r1 c14-36   description "Ireland, lowest latency" -- `secondary`; fits whole in the 26 cells
               that remain; content, wraps.
7. r3 c14-35   description "Mumbai, for APAC users" -- `secondary`; fits whole; content, wraps.
```

##### Own rows

The ap-south description is 57 cells and does not fit whole in the 26 cells after the
column, so the whole menu switches layout: every description sits under its label. The
ap-south description wraps in the 36 cells after the indent.

```wireframe 40x10
Deploy region
❯ ◉ eu-west
    Ireland, lowest latency
  ○ us-east
    Virginia, most capacity
  ○ ap-south
    Mumbai, for APAC users, best for
    India and Southeast Asia
  ○ sa-east
    Sao Paulo, lowest cost
```

```text
Callouts (40x10, 0-based):
1. r0 c0-c12   Picker title -- the title row; content, wraps.
2. r1 c0       cursor -- `❯` in `focus` on the first option's label row.
3. r1 c2       chosen mark -- `◉` in `accent`; the other label rows show `○` in `secondary`.
4. r1 c4-10    label "eu-west" -- `focus` bold; content, wraps.
5. r2 c4-26    description "Ireland, lowest latency" -- `secondary`, indented to the label column;
               content, wraps.
6. r6-r7 c4-35 description "Mumbai, for APAC users, best for India and Southeast Asia" --
               `secondary`, wrapped to two rows in the 36 cells after the indent; never
               tail-truncated; content, wraps.
```

#### Menu scrolling in rows

When the menu's height is fixed, the title row stays pinned and the option rows scroll in
a viewport beneath it, following the
[ScrollView contract](scroll-view.md#rows-and-variable-height-content) (owner decision,
2026-10-18). The offset, the thumb, and paging count rows, not options. Here the own-rows
fixture sits in a `40x6` menu: the viewport is `V = 5` rows and the options take
`C = 2 + 2 + 3 + 2 = 9` rows. The offset is 3 rows, so us-east shows only its description
row and sa-east only its label row. The indicator takes the last column, so content wraps
at 39. The thumb is `max(1, floor(5 * 5 / 9)) = 2` rows starting at
`floor(3 * (5 - 2) / (9 - 5)) = 2`. The cursor is on ap-south, which is wholly in view.

```wireframe 40x6
Deploy region
    Virginia, most capacity           │
❯ ○ ap-south                          │
    Mumbai, for APAC users, best for  █
    India and Southeast Asia          █
  ○ sa-east                           │
```

```text
Callouts (40x6, 0-based):
1. r0 c0-c12   Picker title -- the title row, outside the scrolling region; content, wraps.
2. r1 c4-c26   partial item, top -- the description row of us-east; its label row is above
               the viewport. The partial item draws its visible row with no mark.
3. r2 c0       cursor -- `❯` in `focus` on ap-south, a whole item in view.
4. r3-r4 c4-c35 description of ap-south -- two wrapped rows; content, wraps.
5. r5 c2-c10   partial item, bottom -- the label row of sa-east; its description row is below
               the viewport.
6. r1-r5 c39   scroll indicator -- track `│` and a two-row thumb `█` on r3-r4.
```

## State model

Each presentation owns its own state. Picker retains no business data in any presentation;
the only widget-retained values are the UI states named below.

### Inline cycling row

| State                              | Owner       | Type                                                   | Reset or clamp rule                                                                                                                                                                                                                                                                                              |
| ---------------------------------- | ----------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection                          | Binding     | `Binding<Selection>`                                   | App-owned source of truth. Picker writes only a supplied option after an enabled interior cycle or a first cycle from an absent value; an external replacement is authoritative.                                                                                                                                 |
| is enabled                         | Environment | `Bool`                                                 | Read on every reconciliation. `false` removes Picker from the focusable list and prevents activation without changing `selection`.                                                                                                                                                                               |
| semantic Styles                    | Environment | `primary`, `focus`, and `disabled` full `Style` values | Read on every render; the resolved row Style is primary when enabled and unfocused, focus when focused, and disabled when disabled.                                                                                                                                                                              |
| option count                       | derived     | `Int`                                                  | Recomputed from the current app-supplied option set on every reconciliation; clamps to `0...Int.max` and never changes the set.                                                                                                                                                                                  |
| selected option index              | derived     | `Int?`                                                 | Recompute by searching the current option set on every reconciliation. It is `nil` when the set is empty or `selection` is absent; Picker shows the placeholder and does not write the binding. Otherwise it is in `0...(option count - 1)`.                                                                     |
| is focused                         | Environment | `Bool`                                                 | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Picker reads it during rendering and checks `ResponderContext.isFocused` for events.                                                                                                                                    |
| value slot geometry and truncation | derived     | `TerminalSize` and rendered grapheme range             | Recomputed from the final one-row allocation on every layout; clamp to the value slot, tail-truncate at grapheme boundaries with `truncation.mark`, and never increase height.                                                                                                                                   |
| title layout                       | derived     | beside or stacked                                      | Recomputed on every layout by `ViewThatFits`: the title sits before the row, in `secondary` with one gap cell, when the row's natural width fits after it; otherwise it stacks above the row. Never stored. The radio group and segmented control lay out their title the same way (owner decision, 2026-10-18). |
| labels hidden                      | Environment | `Bool`                                                 | Set by `.labelsHidden()` on the Picker or an ancestor; read on every layout. `true` draws no title in any presentation; the title stays the accessible name.                                                                                                                                                     |

The title, option set, and label builder are immutable widget configuration, not retained
business state. The inline cycling row has no expanded presentation, so it needs no open
or reveal `NodeState`.

### Radio group

| State                 | Owner       | Type                 | Reset or clamp rule                                                                                                                                                                                                                                             |
| --------------------- | ----------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection             | Binding     | `Binding<Selection>` | App-owned. Picker writes only a supplied option after a Left, Right, or chip click. From an absent value, Left or Right selects the first option.                                                                                                               |
| selected option index | derived     | `Int?`               | Recomputed from `selection` on every reconciliation; `nil` when the value is absent, and the group shows no pill.                                                                                                                                               |
| cursor index          | widget UI   | `Int`                | Keyboard position of the `❯` prefix while focused. Starts on the chosen option, or on 0 when the value is absent, without choosing it (owner decision, 2026-10-10). Clamped on every reconciliation; not written to `selection`.                                |
| wrapped layout        | derived     | rows of chip indices | Recomputed from the final allocated width on every layout. A chip starts a new row when it would exceed the width; wrapped rows indent three cells under the first chip. Chips are chrome, one row each; a chip wider than the row tail-truncates. Never clips. |
| is focused            | Environment | `Bool`               | Controls the `❯` cursor prefix and the active underline, which are drawn only while focused; there is no hover treatment in 1.0. Events are checked through `ResponderContext.isFocused`.                                                                       |

### Menu

| State              | Owner       | Type                 | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                                      |
| ------------------ | ----------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection          | Binding     | `Binding<Selection>` | App-owned. Picker writes only on Enter, Space, a digit, or a click that commits an option, or on Enter that ends custom editing with a value `customOption` accepts.                                                                                                                                                                                                                                     |
| chosen option      | derived     | `Int?`               | Recomputed from `selection`; the matching row shows `◉` in `accent`. `nil` when the value is absent; no row is marked. With `customOption`, a value that matches no option is a custom value: the custom row is marked and shows it through `content`. A custom value equal to an option marks that option and adds no row.                                                                              |
| cursor index       | widget UI   | `Int`                | Keyboard position within the list, not business data and not written to `selection`. Clamped to `0...(option count - 1)` on every reconciliation. Starts on the chosen option, or on the first option when the value is absent (owner decision, 2026-10-10).                                                                                                                                             |
| editing            | widget UI   | `Bool`               | `true` after Enter or Space chooses the custom row. Ends on Enter with an accepted value or on Escape; a draft `customOption` rejects (`nil`) leaves it `true`. Reset to `false` when the custom row is removed. The custom row exists only when the initializer received `customOption`; without it `editing` is always `false` (owner decision, 2026-10-18).                                           |
| draft text         | widget UI   | `String`             | Accepts typed text only while editing. Enter passes a nonempty draft to `customOption`; an accepted value is written to `selection`, a `nil` result keeps the draft and editing, and an empty draft ends editing and leaves `selection` unchanged. Escape clears the draft; a committed value stays (owner decision, 2026-10-10). The row shows the committed value through `content` when it is chosen. |
| scroll offset      | widget UI   | `Int`                | Rows above the viewport (owner decision, 2026-10-18). Clamped to `0...max(0, content rows - visible rows)` on every reconciliation and after a width change re-wraps the options; then reveal re-applies to the cursor option, changing the offset by the fewest rows that show every row of it (an option taller than the viewport aligns its first row with the top).                                  |
| option heights     | derived     | `[Int]`              | Each option is measured at the content width with a nil height and re-measured on every width change; content extent is their sum. The title row is outside the scrolling region.                                                                                                                                                                                                                        |
| description layout | derived     | aligned or own rows  | Recomputed per menu on every layout by `ViewThatFits`: aligned when every description fits whole in the cells after the column, otherwise own rows for every description (owner decision, 2026-10-18). Never stored.                                                                                                                                                                                     |
| is focused         | Environment | `Bool`               | Gates every key in the key table; the cursor prefix is drawn while focused.                                                                                                                                                                                                                                                                                                                              |

### Segmented control

| State                 | Owner       | Type                             | Reset or clamp rule                                                                                                                                                                                                                                                                                                      |
| --------------------- | ----------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| selection             | Binding     | `Binding<Selection>`             | App-owned. Picker writes only after Left, Right, or a segment click.                                                                                                                                                                                                                                                     |
| selected option index | derived     | `Int?`                           | Recomputed from `selection`; `nil` when the value is absent, and no segment is active.                                                                                                                                                                                                                                   |
| label presentation    | derived     | per-segment icon, label, or both | Recomputed from the final width on every layout: first the longest label tail-truncates to two characters plus `truncation.mark`; below that floor every segment is icon-only. Never changes `selection`.                                                                                                                |
| segment widths        | derived     | cells per segment                | Recomputed on every layout as icon width, one padding cell on each side, and label width (when shown). A Nerd Font icon is two cells, the glyph and its gap; a Unicode icon is one cell plus one gap cell ([Nerd Font cells](../tokens.md#nerd-font-cells)). A segment with no icon and no room keeps `truncation.mark`. |
| is focused            | Environment | `Bool`                           | While focused, unselected labels brighten from `secondary` to `primary`; under `NO_COLOR` the same brightening shows as dim to default, and the selected segment, reverse and bold, also underlines (owner decision, 2026-10-19). Events are checked through `ResponderContext.isFocused`.                               |

### Menu in a host row

| State        | Owner       | Type     | Reset or clamp rule                                                                                                                                                                                                                                            |
| ------------ | ----------- | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| open         | widget UI   | `Bool`   | Set by Enter, Space, or a click on the closed row. Cleared without committing by Escape, focus loss, or a click outside; cleared by Enter that commits and by a click on the row while open.                                                                   |
| cursor index | widget UI   | `Int`    | Starts on the chosen option when opened, or on the first option when none is chosen. Clamped on every reconciliation.                                                                                                                                          |
| summary      | derived     | `String` | The chosen label, or `—` when absent. Content (owner decision, 2026-10-18): it wraps at word boundaries under the value column, and `▾` follows its last word. The host decides the row count; a host that fixes one row gets a marked cut, `…` with `▾` kept. |
| is focused   | Environment | `Bool`   | Focus loss closes an open list. A disabled row is absent from focus and cannot open.                                                                                                                                                                           |

The multi-select host row state is in [MultiPicker](multi-picker.md#state-model).

## Key table

### Inline cycling row

| Key   | Precondition                                                                            | Effect                                                        | Consumed |
| ----- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------- | -------- |
| Right | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding     | yes      |
| Down  | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding     | yes      |
| Left  | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding     | yes      |
| Up    | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding     | yes      |
| Right | focused and is enabled and selected option index is below option count minus one        | advances `selection` to the next supplied option via binding  | yes      |
| Down  | focused and is enabled and selected option index is below option count minus one        | advances `selection` to the next supplied option via binding  | yes      |
| Left  | focused and is enabled and selected option index is above zero                          | moves `selection` to the previous supplied option via binding | yes      |
| Up    | focused and is enabled and selected option index is above zero                          | moves `selection` to the previous supplied option via binding | yes      |
| Right | focused and is enabled and selected option index equals option count minus one          | leaves `selection` unchanged at the last option               | no       |
| Down  | focused and is enabled and selected option index equals option count minus one          | leaves `selection` unchanged at the last option               | no       |
| Left  | focused and is enabled and selected option index equals zero                            | leaves `selection` unchanged at the first option              | no       |
| Up    | focused and is enabled and selected option index equals zero                            | leaves `selection` unchanged at the first option              | no       |

No key handler exists when `option count` is zero, when Picker is disabled, or for keys
not listed above. Those events bubble unchanged. Endpoint bubbling deliberately mirrors
the boundary behavior of [ScrollView](scroll-view.md). The inline row does not cycle past
its endpoints; the radio group and segmented control wrap around (see below).

### Radio group

| Key         | Precondition                                                                            | Effect                                                                                             | Consumed |
| ----------- | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | -------- |
| Right       | focused and is enabled and option count is positive                                     | advances `selection` to the next supplied option; the last option wraps to the first, across rows  | yes      |
| Left        | focused and is enabled and option count is positive                                     | moves `selection` to the previous supplied option; the first option wraps to the last, across rows | yes      |
| Right       | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding                                          | yes      |
| Left        | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding                                          | yes      |
| Right, Left | focused and is enabled and option count is zero                                         | no handler                                                                                         | no       |
| Up, Down    | any                                                                                     | no handler; bubbles                                                                                | no       |

Left and Right wrap modularly, as in omp2 radio (owner decision, 2026-10-10: wraparound is
kept). A single-option group consumes Left and Right and leaves `selection` unchanged. An
unfocused or disabled group returns Skip.

### Menu

| Key                                            | Precondition                                                                                             | Effect                                                                                                                                                                                                                                          | Consumed |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Up                                             | focused and is enabled and option count is positive and not editing and cursor is below the first option | moves cursor to the previous option; `selection` unchanged                                                                                                                                                                                      | yes      |
| Up                                             | focused and is enabled and option count is positive and not editing and cursor is on the first option    | cursor unchanged; clamps without wrapping                                                                                                                                                                                                       | no       |
| Down                                           | focused and is enabled and option count is positive and not editing and cursor is above the last option  | moves cursor to the next option; `selection` unchanged                                                                                                                                                                                          | yes      |
| Down                                           | focused and is enabled and option count is positive and not editing and cursor is on the last option     | cursor unchanged; clamps without wrapping                                                                                                                                                                                                       | no       |
| PgUp                                           | focused and is enabled and option count is positive and not editing                                      | moves cursor up by the options that span one viewport of rows (`V` rows), clamped to the first option; reveal follows                                                                                                                           | yes      |
| PgDn                                           | focused and is enabled and option count is positive and not editing                                      | moves cursor down by the options that span one viewport of rows (`V` rows), clamped to the last option; reveal follows                                                                                                                          | yes      |
| Home                                           | focused and is enabled and option count is positive and not editing                                      | moves cursor to the first option; consumed even when the cursor is already there                                                                                                                                                                | yes      |
| End                                            | focused and is enabled and option count is positive and not editing                                      | moves cursor to the last option; consumed even when the cursor is already there                                                                                                                                                                 | yes      |
| Enter                                          | focused and is enabled and not editing and cursor is on an option other than the custom row              | commits the cursor option via binding                                                                                                                                                                                                           | yes      |
| Enter                                          | focused and is enabled and not editing and cursor is on the custom row                                   | chooses the custom row and starts editing; `selection` written on commit                                                                                                                                                                        | yes      |
| Space                                          | focused and is enabled and not editing and cursor is on an option other than the custom row              | commits the cursor option via binding, as Enter does                                                                                                                                                                                            | yes      |
| Space                                          | focused and is enabled and not editing and cursor is on the custom row                                   | chooses the custom row and starts editing                                                                                                                                                                                                       | yes      |
| Enter                                          | editing                                                                                                  | ends editing when `customOption` accepts the nonempty draft: the value is committed via binding. A `nil` result rejects the draft: editing continues and `selection` is unchanged. An empty draft ends editing and leaves `selection` unchanged | yes      |
| Escape                                         | editing                                                                                                  | ends editing and clears the draft text; `selection` unchanged by this key                                                                                                                                                                       | yes      |
| Escape                                         | focused and enabled and not editing and custom row is chosen                                             | clears the draft text if any; the committed `selection` stays                                                                                                                                                                                   | yes      |
| Backspace, Ctrl-U, Ctrl-W, printable character | editing                                                                                                  | edited by the shared text-editing core                                                                                                                                                                                                          | yes      |
| any other key                                  | editing                                                                                                  | no effect; swallowed so the draft is not disturbed                                                                                                                                                                                              | yes      |
| any key                                        | not focused, disabled, or option count is zero                                                           | no handler; bubbles                                                                                                                                                                                                                             | no       |
| Left, Right, other keys                        | focused and enabled and not editing                                                                      | no handler; bubbles                                                                                                                                                                                                                             | no       |
| Escape                                         | focused and enabled and not editing and custom row is not chosen                                         | no handler; bubbles                                                                                                                                                                                                                             | no       |
| 1 to 9                                         | focused and is enabled and not editing and option count is at least N                                    | commits the Nth option via binding, as Enter does; the custom row, if Nth, starts editing                                                                                                                                                       | yes      |
| 1 to 9                                         | focused and is enabled and not editing and option count is below N                                       | no handler; bubbles                                                                                                                                                                                                                             | no       |

Digits 1 to 9 pick the Nth option in display order (owner decision, 2026-10-11). Options
past the ninth have no digit and are reached with the arrow or page keys. Digit labels are
not drawn on rows, and [KeyLegend](key-legend.md) shows `1–9 choose` (owner decision,
2026-10-18). The custom row, when `customOption` is supplied, is the last option and
counts toward the digits.

Multi-select keys live in [MultiPicker](multi-picker.md#key-table): there Space toggles,
Enter never toggles, and a standalone menu or radio group lets Enter bubble (owner
decision, 2026-10-18). Single-select Picker is unchanged: Enter chooses.

### Segmented control

| Key         | Precondition                                                                            | Effect                                                                                | Consumed |
| ----------- | --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | -------- |
| Right       | focused and is enabled and option count is positive                                     | advances `selection` to the next supplied option; the last option wraps to the first  | yes      |
| Left        | focused and is enabled and option count is positive                                     | moves `selection` to the previous supplied option; the first option wraps to the last | yes      |
| Right       | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding (open question)             | yes      |
| Left        | focused and is enabled and option count is positive and selected option index is absent | sets `selection` to the first supplied option via binding (open question)             | yes      |
| Right, Left | focused and is enabled and option count is zero                                         | no handler                                                                            | no       |
| Up, Down    | any                                                                                     | no handler; bubbles (open question)                                                   | no       |

## Mouse table

`click` means a primary click. Pointer delivery uses Slice 5 hit testing. Where a click
selects, it installs this Picker's explicit focus before attempting selection, in every
presentation, as the inline value-slot click does (owner decision, 2026-10-10).

### Inline cycling row

`click` on the value slot follows the same non-wrapping rules as the keys below.

| Event | Region           | Precondition                                                                | Effect                                                                                                    | Consumed |
| ----- | ---------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | -------- |
| click | value slot       | is enabled and option count is positive and selected option index is absent | installs this Picker's focus, then sets `selection` to the first supplied option via binding              | yes      |
| click | value slot       | is enabled and selected option index is below option count minus one        | installs this Picker's focus, then advances `selection` to the next supplied option via binding           | yes      |
| click | value slot       | is enabled and selected option index equals option count minus one          | installs this Picker's focus, leaves `selection` unchanged because the next option is unavailable         | no       |
| click | value slot       | not is enabled                                                              | leaves focus and `selection` unchanged                                                                    | no       |
| click | previous chevron | always                                                                      | does not install focus or change `selection`; the visual affordance is not independently clickable in 1.0 | no       |
| click | next chevron     | always                                                                      | does not install focus or change `selection`; the visual affordance is not independently clickable in 1.0 | no       |

An enabled value-slot click deliberately follows the same non-wrapping next-direction rule
as Right and Down. Pointer events outside the value slot have no Picker handler and
bubble.

### Radio group

| Event              | Region                 | Precondition                                                               | Effect                                                                        | Consumed |
| ------------------ | ---------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | -------- |
| click              | chip `i`               | is enabled and `i` is below option count and `i` is not the selected index | installs this Picker's focus, then sets `selection` to option `i` via binding | yes      |
| click              | chip `i`               | is enabled and `i` is the selected index                                   | installs this Picker's focus; leaves `selection` unchanged                    | yes      |
| click              | chip `i`               | `i` is at or above option count                                            | no handler                                                                    | no       |
| click              | gutter, gaps, row ends | always                                                                     | no handler; bubbles                                                           | no       |
| click              | any                    | not is enabled                                                             | leaves focus and `selection` unchanged                                        | no       |
| wheel, other mouse | any                    | always                                                                     | no handler; bubbles                                                           | no       |

### Menu

| Event                | Region                       | Precondition                                                                     | Effect                                                                                                     | Consumed |
| -------------------- | ---------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------- |
| click                | option row                   | is enabled, option count is positive, row is not the custom row, and not editing | installs this Picker's focus, moves cursor to that row, then commits it via binding                        | yes      |
| click                | option row                   | is enabled, option count is positive, row is not the custom row, and editing     | ends editing and discards the draft; installs focus, moves cursor to that row, then commits it via binding | yes      |
| click                | custom row                   | is enabled, option count is positive, and not editing                            | installs focus, moves cursor to the custom row, then chooses it and starts editing (same as Enter)         | yes      |
| click                | custom row                   | is enabled, option count is positive, and editing                                | installs focus and moves cursor to the custom row; editing and the draft continue                          | yes      |
| click                | title row, below last option | always                                                                           | no handler; bubbles                                                                                        | no       |
| wheel up, wheel down | any                          | is enabled and option count is positive                                          | moves cursor one option up or down; consumed even when already at the first or last option                 | yes      |
| wheel up, wheel down | any                          | option count is zero                                                             | no handler; bubbles                                                                                        | no       |
| click                | any                          | not is enabled                                                                   | leaves focus, cursor, and `selection` unchanged                                                            | no       |
| other mouse          | any                          | always                                                                           | no handler; bubbles                                                                                        | no       |

### Segmented control

| Event       | Region                                           | Precondition                                                               | Effect                                                                        | Consumed |
| ----------- | ------------------------------------------------ | -------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | -------- |
| click       | segment `i`                                      | is enabled and `i` is below option count and `i` is not the selected index | installs this Picker's focus, then sets `selection` to option `i` via binding | yes      |
| click       | segment `i`                                      | is enabled and `i` is the selected index                                   | installs this Picker's focus; leaves `selection` unchanged                    | yes      |
| click       | outside segments or `i` at or above option count | always                                                                     | no handler; bubbles                                                           | no       |
| click       | any                                              | not is enabled                                                             | leaves focus and `selection` unchanged                                        | no       |
| other mouse | any                                              | always                                                                     | no handler; bubbles                                                           | no       |

## Menu collapsed in a host row

A Picker `.menu` can sit inside a host row, such as a Form row. The host supplies the
label column and draws the Picker's title there as the row label (owner decision,
2026-10-18). The Picker takes the value column after it, up to the row's right edge.
Collapsed, the row shows the chosen option's label and an open marker `▾` in `secondary`
([Marks](../tokens.md#marks), `dropdown`).

The collapsed value is content (owner decision, 2026-10-18). It wraps at word boundaries
under the value column, and `▾` follows its last word after one space, moving to the next
row like a word when the last row has no room. The host decides how many rows the value
gets: Form stacks its label above the value before the value wraps (see
[Form](form.md#narrow-17-columns)), and a host that fixes one row gets a marked cut, the
value tail-truncated with `…` and `▾` kept after it. An inherited `lineLimit` reaches the
value as it reaches any content.

Enter or Space opens the option list in place, below the row. The open list draws no title
row: the host row above it is its heading. Its option rows are the menu's rows, indented
four cells; they wrap in the width after the indent and scroll in rows like the standalone
menu. Esc or focus loss closes the list without committing. Enter commits a choice and
closes the list. While the row is closed, its keys bubble to the host.

The option rows keep the menu's marks, cursor, and digit rules (see the Menu states).
Descriptions draw in the open list with the same layout rule, measured from the four-cell
indent. Form links to this section instead of restating its dropdown keys. A multi-select
host is a [MultiPicker](multi-picker.md#menu-in-a-host-row); it keeps the list open while
Space toggles and closes it on Enter (owner decision, 2026-10-18).

### Closed row

```wireframe 40x1
Region      eu ▾
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c11  host label -- "Region", the Picker's title, drawn by the host as its row
              label; not drawn by Picker.
2. r0 c12-c13 value -- "eu", the chosen option's label, in `info`, as Form's select value;
              content, wraps.
3. r0 c15     open marker -- `▾` in `secondary`; drawn while closed and while open.
```

### Closed row, wrapped value

A host that keeps its label column at 24 columns leaves a 12-cell value column. The value
"Europe West (Ireland)" does not fit one row, so it wraps there, and `▾` follows the last
word. Form would first stack its label above the value (see [Form](form.md)).

```wireframe 24x2
Region      Europe West
            (Ireland) ▾
```

```text
Callouts (24x2, 0-based):
1. r0 c0-c5   host label -- "Region", the Picker's title, drawn by the host.
2. r0 c12-c22 value, first row -- "Europe West" in `info`; content, wraps.
3. r1 c12-c20 value, continuation -- "(Ireland)", under the value column; content, wraps.
4. r1 c22     open marker -- `▾` in `secondary`, one space after the last word.
```

### Open list, single-select

```wireframe 40x4
Region      eu ▾
    ❯ ◉ eu
      ○ us
      ○ ap
```

```text
Callouts (40x4, 0-based):
1. r0 c0-c11  host label -- "Region", supplied by the host.
2. r0 c12-c13 value -- "eu"; `info`; content, wraps.
3. r0 c15     open marker -- `▾` in `secondary`.
4. r1-r3 c4-c39 option rows -- indented four cells below the host row, with the menu's marks;
              content, wraps.
5. r1 c4      cursor -- `❯` in `focus` on the cursor row, drawn while focused.
6. r1-r3 c6   markers -- `◉` in `accent` on the chosen option, `○` in `secondary` otherwise.
7. r1 c8-9    label "eu" -- the cursor label, `focus` bold.
```

The multi-select open list, with its Space toggles and Enter-closes keys, is
[MultiPicker's](multi-picker.md#open-list).

### Mouse

| Event                | Region                        | Precondition                    | Effect                                                                                | Consumed |
| -------------------- | ----------------------------- | ------------------------------- | ------------------------------------------------------------------------------------- | -------- |
| click                | host row                      | is enabled and closed           | installs this Picker's focus, then opens the list as Enter does                       | yes      |
| click                | host row                      | is enabled and open             | installs focus and closes the list without committing                                 | yes      |
| click                | option row                    | is enabled and open             | installs focus, moves cursor to that row, commits it via binding, and closes the list | yes      |
| click                | outside the host row and list | open                            | closes the list without committing, as focus loss does; the click bubbles             | no       |
| click                | host row                      | not is enabled                  | leaves focus and the list unchanged                                                   | no       |
| wheel up, wheel down | list                          | is enabled and open             | moves cursor one option up or down, clamped; consumed                                 | yes      |
| wheel up, wheel down | host row                      | closed, or option count is zero | no handler; bubbles                                                                   | no       |
| other mouse          | any                           | always                          | no handler; bubbles                                                                   | no       |

### Keys

#### Closed

| Key                                       | Precondition                      | Effect                                                                                                                 | Consumed |
| ----------------------------------------- | --------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | -------- |
| Enter, Space                              | focused and is enabled and closed | opens the list below the row; the cursor starts on the first chosen option, or on the first option when none is chosen | yes      |
| Up, Down, Left, Right, digits, other keys | focused and is enabled and closed | no handler; bubbles                                                                                                    | no       |
| any key                                   | not focused or disabled           | no handler; bubbles                                                                                                    | no       |

#### Open list

| Key                     | Precondition                                  | Effect                                                                                                                                     | Consumed |
| ----------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| Up, Down                | open and is enabled                           | moves cursor to the previous or next option; clamps without wrapping; `selection` unchanged                                                | yes      |
| PgUp, PgDn, Home, End   | open and is enabled                           | move cursor as the Menu keys do                                                                                                            | yes      |
| Enter                   | open, not editing, cursor on an option        | commits the cursor option via binding and closes the list; focus stays on the host row                                                     | yes      |
| Space                   | open, not editing, cursor on an option        | commits the cursor option, as Enter does                                                                                                   | yes      |
| Enter, Space            | open, not editing, cursor on the custom row   | starts editing, as in the Menu; the list stays open                                                                                        | yes      |
| Enter                   | open, editing                                 | as the Menu's editing Enter: an accepted draft is committed via binding and closes the list; a rejected or empty draft keeps the list open | yes      |
| 1 to 9                  | open, not editing, option count is at least N | commits the Nth option and closes the list                                                                                                 | yes      |
| 1 to 9                  | open, option count is below N                 | no handler; bubbles                                                                                                                        | no       |
| Escape                  | open, editing                                 | ends editing and clears the draft; the list stays open                                                                                     | yes      |
| Escape                  | open, not editing                             | closes the list without committing                                                                                                         | yes      |
| Left, Right, other keys | open, not editing                             | no handler; consumed so the row's value does not change behind the list                                                                    | yes      |
| Tab, Shift-Tab          | open                                          | no handler; bubbles, and the resulting focus loss closes the list without committing                                                       | no       |

## Sizing

Results use the `Medium` fixture label for the inline row, with the title hidden unless a
row names one. Picker's height follows its presentation: the inline row and segmented
control are one row high, the radio group is as many rows as its wrapped chips need, and
the menu is its title row plus the rows its options need (labels and descriptions wrap, so
an option may take several rows). A title stacked above a control adds its own rows.
Picker measures its natural width and does not opportunistically grow into surplus space.

### Inline cycling row

| Proposal                | Result | Rule                                                                                                                  |
| ----------------------- | ------ | --------------------------------------------------------------------------------------------------------------------- |
| nil x nil               | 10x1   | Natural inline result: six `Medium` label cells, two spaces, and two one-cell chevrons.                               |
| nil x nil, title "Size" | 15x1   | The title (four cells), one gap cell, and the 10x1 row side by side.                                                  |
| 12 x nil, title "Size"  | 10x2   | The row does not fit beside the title, so the title stacks above it; the row keeps its natural width.                 |
| 10x1                    | 10x1   | Tight fit retains the full natural presentation.                                                                      |
| 4x1                     | 4x1    | Below the `5x1` floor, omit the value slot and retain the two directional affordances without drawing partial glyphs. |
| 80x24                   | 10x1   | Extra width and height do not enlarge a label-hugging inline Picker.                                                  |

### Radio group

| Proposal  | Result  | Rule                                                                                                                                                                                                                                       |
| --------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| nil x nil | one row | Every chip on one row at its natural width; a nil width does not wrap. The group measures width as the cursor slot plus each chip's label width, two pill-cap cells, and one gap cell between chips. Chip width is label + 2 caps + 1 gap. |
| 20x2      | 2 rows  | The four-option set wraps to two rows; wrapped rows indent three cells under the first chip (wrap-20).                                                                                                                                     |
| 14x4      | 4 rows  | Each chip takes its own row when no two fit (wrap-14).                                                                                                                                                                                     |
| 9x4       | 4 rows  | The floor: the cursor gutter (two cells) plus the widest chip, "terra" or "fable" (five label cells and two pill caps). Re-derived under the wrap default (owner decision, 2026-10-18).                                                    |
| 8x4       | 4 rows  | Below the floor the widest chips tail-truncate with `truncation.mark`; chips are chrome, one row each.                                                                                                                                     |

### Menu

Menu fixtures: `Environment` (Production, Staging, and the custom row "Other (type your
own)"), `Deploy region` (four options with descriptions), and `Channels` in
[MultiPicker](multi-picker.md#sizing). A nil width never wraps; a finite width wraps
content at word boundaries; a nil height reports every row (owner decision, 2026-10-18).

| Proposal              | Result | Rule                                                                                                                                                                                                                                             |
| --------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| nil x nil             | 25x4   | `Environment`: four prefix cells plus "Other (type your own)" (21 cells); the title row plus every option row; the custom row is one of the rows and adds none.                                                                                  |
| 40x4                  | 40x4   | Title row plus three options, each on one row.                                                                                                                                                                                                   |
| 20x5                  | 20x5   | The custom row's label wraps in the 16 cells after the prefix ("Other (type your" and "own)"), so the menu is one row taller than the option count; continuation rows indent under the label.                                                    |
| 20x4, `.lineLimit(1)` | 20x4   | The app opts out of wrapping: each option keeps one row and "Other (type your own)" tail-truncates to "Other (type you…".                                                                                                                        |
| 14x6                  | 14x6   | The floor: four prefix cells plus the widest label word, "Production" (ten cells); the title "Environment" (eleven cells) is narrower. "Other (type your own)" takes three rows. Re-derived under the wrap default (owner decision, 2026-10-18). |
| 13x7                  | 13x7   | Below the floor "Production" breaks between grapheme clusters ("Productio" and "n") and the menu grows by one row; nothing clips.                                                                                                                |
| 40x3                  | 40x3   | A fixed height shows the title row and two viewport rows; the option rows scroll in rows, an indicator column is reserved, and a partly visible option draws its visible rows (menu scrolling in rows).                                          |
| 40x5, aligned         | 40x5   | Descriptions fixture, short descriptions: every description fits whole in the 26 cells after the column at cell 14, so the aligned layout is chosen and each option is one row.                                                                  |
| 40x10, own rows       | 40x10  | Descriptions fixture, long ap-south description: it does not fit whole, so every description moves to its own row under its label; ap-south's wraps to two rows in the 36 cells after the indent.                                                |
| 20x15, own rows       | 20x15  | In the 16 cells after the indent the descriptions take 2, 2, 4, and 2 rows; the title and four label rows make 15. Descriptions wrap and never tail-truncate.                                                                                    |

### Segmented control

| Proposal  | Result | Rule                                                                                                                                                                                                                                                                    |
| --------- | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 1 row  | Natural width: each segment is one padding cell, its icon, one cell between icon and label, its label, and one padding cell. A Nerd Font icon counts two cells, the glyph and its gap, so it needs no extra gap cell ([Nerd Font cells](../tokens.md#nerd-font-cells)). |
| 24x1      | 1 row  | The longest label tail-truncates first, down to two characters plus `truncation.mark` (narrow-24).                                                                                                                                                                      |
| 20x1      | 1 row  | Below the label floor every segment is icon-only (narrow-20).                                                                                                                                                                                                           |

### Collapsed host row

| Proposal                     | Result                   | Rule                                                                                                                                                                                                                                                        |
| ---------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil, closed            | 1 row                    | The host row: the title as the host's label, the collapsed value, and `▾`. The host supplies the label column; the Picker takes the value column and the width after it. A nil width does not wrap.                                                         |
| open                         | value rows + option rows | The host row plus the rows the options need, drawn below the host row and indented four cells; option rows wrap in the width after the indent and scroll like the menu.                                                                                     |
| 24 x nil, closed, long value | 2 rows                   | The value is content (owner decision, 2026-10-18): "Europe West (Ireland)" wraps in the 12-cell value column to "Europe West" and "(Ireland) ▾"; `▾` follows the last word and moves to the next row like a word when it has no room. The row never widens. |
| 24x1, closed, long value     | 1 row                    | A host that fixes one row gets a marked cut: the value tail-truncates so that `▾` still fits after it, "Europe We… ▾".                                                                                                                                      |

## Environment

Picker consumes `isEnabled` and applies one resolved Style to its implemented inline row:
`primary` when enabled and unfocused, `focus` when focused, and `disabled` when disabled.
`truncation.mark` defines grapheme-safe value-slot overflow; its chevron and placeholder
substitutions are specified in [Degradation](#degradation).

`lineLimit` and `truncationMode` flow through the environment to the title, menu option
labels, descriptions, and the collapsed host-row value (content). The standalone inline
row's value slot, chips, segments, and markers are chrome and pin their own single-row
values, so an inherited `lineLimit` never reaches them (owner decision, 2026-10-18).
`labelsHidden` (environment, set by `.labelsHidden()`) hides the drawn title in every
presentation.

The radio group, segmented control, and menu use the same enabled and focused rules. Their
sub-element roles are:

- `primary` -- labels and unchosen option text.
- `secondary` -- the title drawn before the inline row, radio group, and segmented
  control, as LabeledContent draws its label.
- `focus` -- the focused group's cursor glyph and label, and the active chip underline.
- `accent` -- the active segment and active chip background; the chosen marker `◉` in the
  menu, the same selection-mark colour as Toggle and Form.
- `secondary` -- inactive chips and segments, the unchosen marker `○`, and each option
  description (owner decision, 2026-10-11). Unselected segment labels draw `primary`
  instead while the picker is focused (owner decision, 2026-10-19).
- `disabled` -- every visible cell of a disabled Picker.
- `contrast` -- the label on an active chip or segment.
- `info` -- the typed custom text in the menu.
- `surface` -- the inactive segment band.

Roles: `secondary` (was `muted`), `info`, `contrast` (`on(R)` inside `solid(R)`), and
`surface` are defined in [tokens.md](../tokens.md#roles); `primary`, `accent`, `focus`,
and `disabled` are too.

> Deferred: endpoint-specific affordance styling, custom `PickerStyle`, and custom-style
> environment inputs land in a later slice. Focus follows [tokens.md](../tokens.md#focus).

## Primitive dependencies

- [`Text`](../primitives/text.md) -- ready; renders selected labels and the absent-value
  placeholder, measures display cells, and provides grapheme-safe tail truncation.
- [`Label`](../primitives/label.md) -- supplies the icon-and-title pair for segments and
  menu rows, and the `.iconOnly` label style.
- [`Button`](button.md) -- the active chip uses the filled emphasis and the capped ends of
  the button's [shapes](button.md#shape).
- [`List`](list.md) -- supplies the row chrome for the menu's option list.
- [`LabeledContent`](labeled-content.md) -- the title-before-control layout, with its
  stacking rule, that the inline row, radio group, and segmented control copy.
- [`Style modifiers`](../primitives/style-modifiers.md) -- ready; resolve and apply the
  inherited complete semantic Styles without giving Picker its own mutable visual state.
- [Focus manager and responder context](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
  -- supplies app-installed `FocusID` routing and focusable-list participation.
- [Mouse hit testing](../../docs/Spec.md#slice-5-mouse-and-hit-testing) -- supplies chip,
  segment, and value-slot hit testing and click-to-focus ordering.
- [`ScrollView`](scroll-view.md) -- supplies the row-based scrolling contract the menu's
  option list follows (cross-axis proposal, partial items, paging, reveal).
- `ViewThatFits` -- chooses the description layout per menu (candidate primitive; see
  [inbox](../inbox.md)).

## Requirements

Schema: [README](../README.md#requirements-list). Multi-select requirements live in
[MultiPicker](multi-picker.md#requirements).

Inline cycling row:

- `picker renders its selected option between stable inline chevrons` (anatomy wireframe:
  inline cycling row).
- `picker retains both chevrons for a single supplied option` (state wireframe: single
  option).
- `picker displays a secondary placeholder without repairing an absent binding` (state
  wireframe: absent bound value; state model: selected option index).
- `picker first enabled cycle from an absent value selects the first supplied option` (key
  table: Right with selected option index absent).
- `picker advances on focused right and down keys` (key table: Right and Down below option
  count minus one).
- `picker moves backward on focused left and up keys` (key table: Left and Up above zero).
- `picker bubbles an unavailable endpoint cycle without changing selection` (key table:
  Right and Down at last option; Left and Up at first option).
- `picker focuses before a value-slot click advances selection` (mouse table: value slot
  below option count minus one).
- `picker leaves a last-option value-slot click unconsumed` (mouse table: value slot at
  last option).
- `disabled picker is unfocusable and leaves input unconsumed` (state wireframe: disabled;
  mouse table: value slot not is enabled).
- `picker tail-truncates a constrained selected label at a grapheme boundary and keeps one row`
  (state model: value slot geometry and truncation; sizing table: 5x1 floor).
- `picker standalone inline row pins one row against an inherited lineLimit` (anatomy:
  value slot, chrome, one row; a host row treats the inline value as content, Q27).
- `picker substitutes ASCII chevrons and placeholder when capability requires it` (state
  wireframe: ASCII degraded; degradation: ASCII-only).
- `picker radio group draws the active chip's caps as rectangle cells under ASCII-only`
  (degradation: radio group; chip width unchanged).
- `picker menu draws (*) and ( ) markers and > cursor under ASCII-only` (degradation:
  menu).

Title:

- `picker title and label initializers name the picker and set its accessible name` (API
  direction).
- `picker draws its title before the inline row in the secondary role` (state: title
  beside the inline row; sizing: inline nil x nil with title).
- `picker stacks its title above a control that does not fit beside it` (state: title
  stacked above the segmented control; sizing: inline 12 x nil with title).
- `picker labelsHidden hides the drawn title and keeps it as the accessible name` (state:
  title; state model: labels hidden).
- `picker menu draws its title as the title row and none under labelsHidden` (state: menu;
  state model: labels hidden).

Radio group:

- `picker radio group wraps chips onto more rows instead of clipping` (states: wrap-20 and
  wrap-14).
- `picker radio group keeps every option visible at 14 columns` (state: one chip per row).
- `picker radio group indents wrapped rows three cells under the first chip` (state:
  wrap-20).
- `picker radio group chips stay one row each and tail-truncate when wider than the row`
  (state: radio group; sizing: radio 8x4).
- `picker radio group floor is the gutter plus the widest chip` (state: radio group floor;
  sizing: radio 9x4).
- `picker radio group Right and Left advance in order and wrap across rows` (key table:
  radio Right and Left).
- `picker radio group leaves Up and Down unconsumed` (key table: radio Up and Down).
- `picker radio group click on a chip sets selection and consumes the click` (mouse table:
  radio chip `i`).
- `picker radio group shows the cursor prefix only while focused` (state model: is
  focused).
- `picker radio group renders the selected chip as a pill with accent background` (state:
  wrap-20; styled grid).

Menu:

- `picker menu lists options in place with a cursor separate from the chosen marker`
  (state: cursor on an unchosen option).
- `picker menu clamps Up and Down at the list edges without wrapping` (key table: menu Up
  and Down).
- `picker menu Enter commits the cursor option through the binding` (key table: menu
  Enter).
- `picker menu shows no chosen marker when the binding is absent` (state: no selection).
- `picker menu wheel moves the cursor and is consumed at list edges` (mouse table: menu
  wheel).
- `picker menu click on an option row moves the cursor then commits it` (mouse table: menu
  option row).
- `picker menu wraps a long option label and indents continuation rows under the label`
  (state: wrapped option label; sizing: 20x5).
- `picker menu selection and cursor cover every row of a wrapped option` (state: wrapped
  option label).
- `picker menu lineLimit one tail-truncates an option label on its row` (sizing: 20x4
  lineLimit one).
- `picker menu floor is the prefix plus the widest label word` (state: menu floor; sizing:
  14x6).
- `picker menu grapheme-breaks a word wider than the row below the floor` (sizing: 13x7).
- `picker menu scrolls in rows and shows partial items at both edges` (state: menu
  scrolling in rows; state model: scroll offset).
- `picker menu reveals the whole cursor item by the fewest rows` (state model: scroll
  offset).
- `picker menu PgUp and PgDn move the cursor by viewport rows` (key table: menu PgUp and
  PgDn).

Custom option:

- `picker draws no Other row without a customOption closure` (API direction; state model:
  editing).
- `picker customOption label defaults to Other type your own` (API direction).
- `picker menu Enter on the custom row starts editing` (key table: menu Enter on custom
  row; state: custom row while typing).
- `picker menu editing keys edit the draft and Enter commits it through customOption` (key
  table: editing rows).
- `picker menu keeps editing when customOption rejects the draft` (key table: menu Enter,
  editing).
- `picker menu Escape ends editing and clears the draft while a committed value stays`
  (key table: menu Escape; state: custom row after commit).
- `picker menu keeps the custom row chosen with its committed value after Enter` (state:
  custom row after commit).
- `picker menu draft line stays one row and scrolls around the caret` (state: custom row
  while typing; wrap exception).
- `picker custom value equal to an option marks that option and adds no duplicate` (state
  model: chosen option).

Segmented control:

- `picker segmented renders icon-only segments under labelStyle iconOnly` (state: icons
  only at 40 columns).
- `picker segmented tail-truncates the longest label first at two characters and the mark`
  (state: tail-truncated labels at 24 columns).
- `picker segmented falls back to icon-only below the label floor` (state: icons only at
  20 columns).
- `picker segmented segments are one row and pin lineLimit one` (state: segmented control;
  chrome, one row).
- `picker segmented keeps one padding cell on each side of every segment` (styled grids at
  24 and 20 columns).
- `picker segmented keeps a segment with no icon and no room as the truncation mark`
  (state model: segment widths).
- `picker segmented draws an unknown icon name as its raw text` (degradation: segmented
  control).
- `picker segmented active segment draws solid(accent) with no underline in colour tiers and underlines only under NO_COLOR while focused`
  (anatomy: segmented control; [composite styles](../tokens.md#composite-styles); owner
  decision, 2026-10-19).
- `picker segmented unselected segment labels brighten from secondary to primary while the picker is focused`
  (state model: segment widths; owner decision, 2026-10-19).
- `picker segmented icon-only segment is four cells with Nerd Font icons, pad + icon(2) + pad`
  (sizing; [Nerd Font cells](../tokens.md#nerd-font-cells)).
- `picker segmented file and folder icons draw no icon under the Unicode charset and the segment keeps its truncation mark`
  (icon catalog; [icon catalog](../tokens.md#icon-catalog)).
- `picker segmented Right and Left wrap and are consumed` (key table: segmented Right and
  Left).
- `picker segmented click on a segment sets selection and consumes the click` (mouse
  table: segment `i`).

Menu digits and descriptions:

- `picker menu digit key commits the Nth option` (key table: menu digits).
- `picker menu digit beyond the option count bubbles` (key table: menu digits).
- `picker menu draws no digit labels on rows` (state: cursor on an unchosen option).
- `picker menu digit is typed text while editing the custom row` (key table: editing
  rows).
- `picker menu aligns descriptions in a secondary column when every description fits whole`
  (state: menu with descriptions, aligned column; sizing: 40x5).
- `picker menu puts every description on its own row when any would not fit whole` (state:
  menu with descriptions, own rows; sizing: 40x10).
- `picker menu wraps a description on its own row and never tail-truncates it` (state:
  menu with descriptions, own rows; sizing: 20x15).
- `picker menu chooses the description layout per menu` (state model: description layout).
- `picker menu descriptions use the secondary role` (environment: sub-element roles).

Menu collapsed in a host row:

- `picker host row shows the collapsed value with an open marker` (state: host row
  closed).
- `picker host row Enter and Space open the list below the row` (key table: host row
  closed).
- `picker host row Up, Down, Left, and Right bubble while closed` (key table: host row
  closed).
- `picker host row Enter and Space commit the cursor option and close` (key table: host
  open list).
- `picker host row Escape closes the list without committing` (key table: host open list).
- `picker host row focus loss closes the list without committing` (state model: open
  flag).
- `picker host row digit key commits the Nth option and closes` (key table: host open
  list).
- `picker host row draws the title as the host's row label and no title row in the open list`
  (state: closed row; menu collapsed in a host row).
- `picker host row closed value wraps under the value column with the open marker after its last word`
  (state: closed row, wrapped value; sizing: collapsed host row 24 x nil).
- `picker host row closed value under a fixed one-row host ends in the mark and keeps the open marker`
  (sizing: collapsed host row 24x1).

## Degradation

Picker follows the [degradation ladder](../tokens.md#degradation-ladder). In `NO_COLOR`,
[roles](../tokens.md#roles) reduce to their attributes and focused Picker remains bold; in
16-color, `accent` resolves to ANSI 14 on dark schemes and ANSI 6 on light, with no bold
in colour tiers ([hue roles](../tokens.md#hue-roles)). At the ASCII-only rung, U+2039 `‹`
becomes `<`, U+203A `›` becomes `>`, and the absent-value em dash `—` becomes `-`; every
replacement is one display cell and preserves the inline geometry. `truncation.mark`
becomes `~` at that same rung.

Per presentation:

- Radio group: at the ASCII-only rung the cursor prefix becomes `>` plus a space. The
  selected chip's pill caps become `.rectangle` caps, one full accent-filled cell on each
  side of the chip, as Button's `.rectangle` draws them. Chip width is unchanged under
  ASCII, so the wrap rule measures the same width at every rung (owner decision,
  2026-10-10).
- Segmented control: segment icons are [Label](../primitives/label.md) catalog names, so
  they resolve through the active charset; every catalog row has an ASCII form, and an
  unknown name draws its raw text. Unicode: Path and Tree have no icon and keep
  `truncation.mark`; Diff draws `▤` ([icon catalog](../tokens.md#icon-catalog)). The label
  floor and icon-only fallback are unchanged at every rung.
- Menu: at the ASCII-only rung the chosen marker `◉` becomes `(*)` and the unchosen marker
  `○` becomes `( )`, the ASCII forms of Toggle's `.circle`. These markers are three cells
  instead of one, so the option label is measured within the remaining width. The cursor
  `❯` becomes `>`, and the beam caret `▏` becomes `|` (owner decision, 2026-10-10).
- Multi-select: the check marks, their ASCII forms, and the multi radio group's
  degradation live in [MultiPicker](multi-picker.md#degradation).
- Option descriptions: a description is plain text at every rung, on its own row or in the
  aligned column. The ASCII-only rung changes no description glyph, and `NO_COLOR` removes
  only its `secondary` colour (owner decision, 2026-10-11).
- Collapsed host row: the open marker `▾` becomes `v` (owner decision, 2026-10-11), and a
  fixed one-row cut ends in `~`.

Below the declared `5x1` floor, Picker reduces feature use rather than drawing partial
glyphs: at `4x1` it omits the value slot and retains the two directional affordances; with
fewer than two cells it emits no partial Picker chrome and has no input handler. This is
layout degradation only: it never manufactures a selection or writes the binding. The
title, menu option labels, descriptions, and the collapsed host-row value are content:
below their floor they wrap and break between grapheme clusters, and a fixed height cuts
only the last visible row with `truncation.mark` (`~` at the ASCII-only rung).

## Open questions

- **Deferred:** an overlay or popover presentation of the menu. The menu and its collapsed
  host row draw their option list in place, so an overlay would need a transient open bit,
  placement, dismissal, and option-hit semantics without changing the `Binding<Selection>`
  ownership rule.
- **Deferred:** per-option disabled state. 1.0 treats every supplied option as selectable;
  disabled-option visibility, traversal, and placeholder policy are deferred to
  [Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
- **Resolved:** `contrast` is `on(R)`, the label colour inside `solid(R)`
  ([composite styles](../tokens.md#composite-styles)), not a free-standing role. The
  active segment and chip are `solid(accent)` (owner decision, 2026-10-19).
- **Resolved:** an absent bound value displays `—` and does not write the binding. The
  first enabled cycle with a nonempty option set writes the first option.

## Out of scope

- Fuzzy filtering of menu options is outside Picker 1.0 (owner decision, 2026-10-11). It
  is recorded as a feature idea in [design/inbox.md](../inbox.md).

## Inspiration

A Picker should make the current app-owned choice legible in one terminal row and make the
next choice predictable, not hide selection policy in private widget state.
