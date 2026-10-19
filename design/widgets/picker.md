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
binding, focus, and enabled rules.

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
  the active and focused treatment, and the Left and Right wraparound. Adjust: labels
  tail-truncate, and a row too narrow for labels falls back to icons only (owner decision,
  omp2 review, 2026-10).
- omp2 select menu,
  [`select.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L514-L715)
  -- copy the in-place option list, the cursor glyph separate from the chosen glyph, the
  custom "Other (type your own)" row with its editing keys, and the Up, Down, Enter, and
  Space behaviour (owner decision, omp2 review, 2026-10). Its digit quick-select and
  multi-select are in Picker 1.0 (owner decision, 2026-10-11); its fuzzy filter is not
  (see Out of scope).

## API direction

The implemented public API has a required selection binding, app-supplied finite option
collection, and value-label builder:

```swift
public struct Picker<Selection: Hashable, Value: View>: View {
    public init(
        selection: Binding<Selection>,
        options: [Selection],
        @ViewBuilder content: @escaping (Selection) -> Value
    )
}
```

The `selection` binding is the sole source of a selected value. `options` and `content`
are immutable widget configuration supplied by the application; changing them on
reconciliation is authoritative. Callers compose focus explicitly:

```swift
Picker(selection: selection, options: options) { option in Text(option) }
    .focusable(pickerFocusID)
    .focused(focused, equals: pickerFocusID)
```

The presentation is chosen with the 1.0 style values. The default is the inline cycling
row.

```swift
// `selectedView` is a Binding from the app's model.
Picker(selection: selectedView, options: views) { view in
    Label(view.title, systemImage: view.symbol)
}
.pickerStyle(.segmented)
.labelStyle(.iconOnly)
```

- `.pickerStyle(.radioGroup)` -- a horizontal chip row that wraps onto more rows.
- `.pickerStyle(.segmented)` -- a horizontal segment control with tail-truncated labels
  and an icon-only fallback.
- `.pickerStyle(.menu)` -- an in-place option list with a cursor and a custom row.

Multi-select is a second initializer on the same `Picker`, taking
`Binding<Set<Selection>>`. It takes the same options and value-label builder, and the set
holds any subset of the options (owner decision, 2026-10-11).

```swift
// `selectedRegions` is a Binding<Set<String>> from the app's model.
Picker(selection: selectedRegions, options: regions) { region in Text(region) }
    .pickerStyle(.menu)
```

Only styles that can hold several values accept a multi-select Picker. `.menu` and
`.radioGroup` conform to `MultiSelectPickerStyle`; `.segmented` and the inline cycling row
do not, so `.pickerStyle(.segmented)` on a multi-select Picker does not compile. Space
toggles the highlighted option, a digit toggles the Nth option, and Enter closes a menu
open in a host row.

Option descriptions attach with `.optionDescription(_:)`, which takes a closure returning
`String?`. A `nil` result draws no description for that option.

```swift
Picker(selection: selectedRegion, options: regions) { region in Text(region) }
    .optionDescription { region in regionNotes[region] }
```

Picker renders from `EnvironmentValues.isFocused` and handles keys only when
`ResponderContext.isFocused` is true.

> Deferred: custom `PickerStyle` conformance, custom chrome, and style configuration land
> in a later slice. They must preserve the implemented selection, keyboard, pointer,
> enabled, and focus behavior.

## Presentations

| Presentation             | Swift value                                          | Shape                                                        | Height                     |
| ------------------------ | ---------------------------------------------------- | ------------------------------------------------------------ | -------------------------- |
| Inline cycling row       | default                                              | one row, chevrons, value slot                                | 1                          |
| Radio group              | `.pickerStyle(.radioGroup)`                          | horizontal chips, wrapped onto more rows                     | number of wrapped rows     |
| Segmented control        | `.pickerStyle(.segmented)`                           | one row of segments, icon-only fallback                      | 1                          |
| Menu                     | `.pickerStyle(.menu)`                                | in-place option list with cursor and custom row              | title row plus option rows |
| Multi-select menu        | `.pickerStyle(.menu)` on a multi-select Picker       | in-place option list with `☑` and `☐` marks, no custom row   | title row plus option rows |
| Multi-select radio group | `.pickerStyle(.radioGroup)` on a multi-select Picker | chips that toggle rather than choose, wrapped onto more rows | number of wrapped rows     |
| Menu in a host row       | `.pickerStyle(.menu)` inside a host row              | one row when closed; the open list draws below the row       | 1 when closed              |

## Anatomy

The default inline cycling row is one row. `Medium` is the currently selected option's
label. Both chevrons stay visible at an endpoint so the control keeps a stable,
recognizable shape; unavailable directions are inert rather than wrapping.

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
            the next selection.
4. r0 c9    next chevron -- U+203A; it inherits the Picker row's resolved Style and
            signals the next direction but is not independently clickable in 1.0.
```

The other three presentations are specified under States, with their own wireframes.

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
3. r0 c2-c7 value slot -- selected option label, not stretched to viewport width.
4. r0 c9    next chevron -- visible navigation affordance.
```

### Minimum

The declared normal-rendering floor is `5x1`: the two chevrons, two separating spaces, and
one value-label cell. At this floor, a longer selected label tail-truncates with
`truncation.mark`.

```wireframe 5x1
‹ M ›
```

```text
Callouts (5x1, 0-based):
1. r0 c0-c4 Picker hit target -- minimum inline frame that retains both directions and one
            label cell.
2. r0 c0    previous chevron -- previous-direction affordance.
3. r0 c2    value slot -- one-cell, grapheme-safe tail-truncated selected label.
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
3. r0 c2-c5 value slot -- the sole supplied option's label.
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
3. r0 c2    value slot -- absent-value placeholder, not a selection.
4. r0 c4    next chevron -- visible direction affordance.
```

### Focused

Focus is never inferred from position. An app-installed `FocusID` match gives the inline
row `semantic.focus`; its cells and geometry do not change.

```wireframe 10x1
‹ Medium ›
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Picker hit target -- full row uses the focused resolved Style.
2. r0 c0    previous chevron -- focused previous-direction affordance.
3. r0 c2-c7 value slot -- focused selected label and keyboard target.
4. r0 c9    next chevron -- focused next-direction affordance.
```

### Disabled

A disabled Picker renders all visible cells in `semantic.disabled`, is absent from the
focusable list, never changes its binding, and leaves keys and clicks unconsumed so an
ancestor may handle them.

```wireframe 10x1
‹ Medium ›
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Picker hit target -- disabled complete row; it is not an interactive target.
2. r0 c0    previous chevron -- disabled directional chrome.
3. r0 c2-c7 value slot -- disabled selected label.
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
3. r0 c2-c7 value slot -- selected label; `—` would fall back to `-` when absent.
4. r0 c9    next chevron -- ASCII `>` fallback for U+203A.
```

### Radio group

The radio group is a horizontal row of chips, one per option. The selected chip is a pill
with accent background, contrast bold label, and pill caps on both sides. Unselected chips
are muted. A chip's width is its label plus two pill-cap cells and one gap cell. A chip
that does not fit on the current row wraps onto the next row, indented under the first
chip, so every option stays visible and reachable. A chip wider than the row
tail-truncates with `truncation.mark`. Left and Right move through the options in order
and wrap across rows. The `❯` cursor prefix appears only while the group is focused. Owner
decision, omp2 review, 2026-10. `.radioGroup` is the wrapping chip row; the vertical list
is `.menu`, so there is no third layout (owner decision, 2026-10-10).

#### Wrapped to two rows

```wireframe 20x2
❯  sol   terra
   kimi  ▐fable▌
```

```text
Callouts (20x2, 0-based):
1. r0-r1 c0-c19 Radio group hit target -- each chip is one Chip hit; the group is the
            allocated frame.
2. r0 c0-c1  focus cursor -- `❯` plus a space in `semantic.focus` while focused; blank when unfocused.
3. r0 c3-c5  chip "sol" -- inactive chip; muted label with padding.
4. r0 c9-c13 chip "terra" -- inactive chip; starts the first row's second column stop.
5. r1 c3-c6  chip "kimi" -- inactive chip on the wrapped row, indented under the first chip.
6. r1 c9-c15 chip "fable" -- active pill: accent background, contrast bold label, and
            pill caps ▐ and ▌ outside the label.
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
3. r0 c3-c5  chip "sol" -- inactive chip on the first row.
4. r1 c3-c7  chip "terra" -- inactive chip on its own wrapped row.
5. r2 c3-c6  chip "kimi" -- inactive chip on its own wrapped row.
6. r3 c2-c8  chip "fable" -- active pill; the left cap hangs one cell left of the label
            column, so the label aligns with the other chips.
```

Styled grid for the wrapped radio group (owner-accepted review grid, roles renamed to
Tessera names; `contrast*` and `muted*` pending, see Open questions):

```text
── chars ──
❯  sol   terra
   kimi  ▐fable▌
── style ──
EEBCCCBBBCCCCC
..BCCCCBBADDDDDA
── legend ──
.  default
A  fg=accent (pill caps)
B  fg=primary
C  fg=muted*
D  fg=contrast* bg=accent bold underline
E  focus role (`semantic.focus`)
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
A  fg=accent (pill caps)
B  fg=primary
C  fg=muted*
D  fg=contrast* bg=accent bold underline
E  focus role (`semantic.focus`)
```

The active chip's underline appears only while the group is focused; there is no hover
treatment in 1.0 (owner decision, 2026-10-10). The grids above show the focused state.

### Segmented control

The segmented control is one row of segments. Each segment shows an icon, a label, or
both, with one cell of padding on each side. The active segment has an accent background,
a contrast bold label, and an underline while focused. Inactive segments are muted on a
`surface*` band. When the row is too narrow for the full labels, the longest label gives
up space first and tail-truncates with `truncation.mark`, keeping two characters before
the mark. Below that floor, every segment shows its icon only. A segment without an icon
and without room for its label keeps `truncation.mark` rather than disappearing, so no
option is dropped. Owner decision, omp2 review, 2026-10.

#### Icons only at 40 columns

The app uses `.labelStyle(.iconOnly)`. Path, Tree, and Diff are icons only, with Tree
selected.

```wireframe 40x1
 📄  📁  ▤
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c10 Segmented group hit target -- one row; each segment is one Chip hit spanning its
            cells.
2. r0 c0-c3  Path segment -- icon-only (📄), inactive.
3. r0 c4-c7  Tree segment -- icon-only (📁), active: accent background, contrast bold label,
            underline while focused.
4. r0 c8-c10 Diff segment -- icon-only (▤), inactive.
```

Styled grid for icons only at 40 columns (review grid, roles renamed):

```text
── chars ──
 📄  📁  ▤
── style ──
AAAABBBBAAA
── legend ──
.  default
A  fg=muted* bg=surface*
B  fg=contrast* bg=accent bold underline
```

#### Tail-truncated labels at 24 columns

"Settings" is the longest label, so it gives up space first and becomes "Se…". "Grid" and
"List" keep their full labels because the row still has room for them.

```wireframe 24x1
 ▦ Grid  📜 List  ⚙ Se…
```

```text
Callouts (24x1, 0-based):
1. r0 c0-c23  Segmented group hit target -- one row; three segments.
2. r0 c0-c7   Grid segment -- active: " ▦ Grid " with one cell of padding on each side.
3. r0 c8-c16  List segment -- inactive; full label fits.
4. r0 c17-c23 Settings segment -- inactive; the label is tail-truncated to "Se…" (two
            characters plus `truncation.mark`), with its icon.
```

Styled grid for tail-truncated labels at 24 columns:

```text
── chars ──
 ▦ Grid  📜 List  ⚙ Se…
── style ──
BBBBBBBBAAAAAAAAAAAAAAAA
── legend ──
.  default
A  fg=muted* bg=surface*
B  fg=contrast* bg=accent bold underline
```

#### Icons only at 20 columns

Labels are too narrow for any useful text, so all three segments show their icons only.

```wireframe 20x1
 ▦  📜  ⚙
```

```text
Callouts (20x1, 0-based):
1. r0 c0-c9  Segmented group hit target -- one row; the labels are dropped below the floor.
2. r0 c0-c2  Grid segment -- icon-only (▦), active.
3. r0 c3-c6  List segment -- icon-only (📜), inactive.
4. r0 c7-c9  Settings segment -- icon-only (⚙), inactive.
```

Styled grid for icons only at 20 columns:

```text
── chars ──
 ▦  📜  ⚙
── style ──
BBBAAAAAAA
── legend ──
.  default
A  fg=muted* bg=surface*
B  fg=contrast* bg=accent bold underline
```

### Menu

The menu is an in-place list: the title row is the Picker's label, and each option is one
row below it. No overlay opens. The cursor row carries a `❯` and a bold label in the
`semantic.focus` role. The cursor and the chosen option are separate: `◉` in `accent` (one
selection-mark colour with Toggle and Form; owner decision, 2026-10-10) marks the chosen
option, and `○` in `muted*` marks every other option. The cursor starts on the chosen
option, or on the first option when the bound value is absent; it clamps when the option
set changes, and the `❯` appears only while the Picker is focused (owner decision,
2026-10-10). Enter or Space on an option chooses it. The custom row "Other (type your
own)" exists only when `Selection` is `String` (constrained initializer); it starts text
editing on Enter or Space, and the typed text follows a colon in `info*` with a beam
caret. Enter commits the draft, which stays chosen after the caret goes away. Owner
decision, omp2 review, 2026-10. In 1.0 the menu also takes digit quick-select, option
descriptions, and multi-select with `☑` and `☐` marks (owner decision, 2026-10-11; see
Menu with descriptions and Multi-select menu).

The captures below are omp2's menu at 40 columns, with legend roles renamed to Tessera
names.

#### Cursor on an unchosen option

```wireframe 40x4
Environment
❯ ○ Production
  ○ Staging
  ○ Other (type your own)
```

```text
Callouts (40x4, 0-based):
1. r0 c0-c10  Picker label -- the title row; not a selection target.
2. r1 c0      cursor -- `❯` in `semantic.focus` on the cursor row; blank when unfocused.
3. r1 c2      unchosen marker -- `○` in `muted*`; chosen rows show `◉` in `accent`.
4. r1 c4-c13  cursor label -- "Production" in the `semantic.focus` role.
5. r2 c4-c10  option label -- "Staging" in primary.
6. r3 c4-c24  custom row -- "Other (type your own)"; Enter or Space starts editing.
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
B  focus (`semantic.focus`)
C  fg=muted*
D  fg=primary
E  focus (`semantic.focus`) bold
```

#### Custom row while typing

The custom row is chosen and editing. Its typed draft follows the colon in `info*`, and a
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
1. r0 c0-c10  Picker label -- the title row.
2. r3 c0      cursor -- `❯` in `semantic.focus`; the custom row is the cursor row.
3. r3 c2      chosen marker -- `◉` in `accent`: the custom row is the chosen value.
4. r3 c4-c24 custom label -- "Other (type your own)" in `semantic.focus`.
5. r3 c25-c26 separator -- ": " in `muted*`.
6. r3 c27-c36 draft text -- "staging-eu" in `info*`; the shared text-editing core edits it.
7. r3 c37     beam caret -- `▏` in accent; shown only while editing.
```

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
B  fg=accent (caret)
C  fg=muted*
D  fg=primary
E  fg=accent
G  fg=info*
H  focus (`semantic.focus`)
```

#### Custom row after commit

Enter commits the draft. The row stays chosen and keeps the typed text; the caret goes
away. An empty draft on Enter ends editing and leaves the bound value unchanged. Escape
after a commit clears the draft, and the committed value stays (owner decision,
2026-10-10).

```wireframe 40x4
Environment
  ○ Production
  ○ Staging
❯ ◉ Other (type your own): staging-eu
```

```text
Callouts (40x4, 0-based):
1. r0 c0-c10  Picker label -- the title row.
2. r3 c2      chosen marker -- `◉` in `accent`; the custom value is committed.
3. r3 c4-c24 custom label -- "Other (type your own)" in `semantic.focus`.
4. r3 c27-c36 committed text -- "staging-eu" in `info*`; no caret, no editing.
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
C  fg=muted*
D  fg=primary
E  fg=accent
G  fg=info*
H  focus (`semantic.focus`)
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
1. r0 c0-c5 Picker label -- the title row.
2. r1-r4    option rows -- every option is unchosen; `○` in `muted*`.
3. r1 c0    cursor -- `❯` in `semantic.focus` on "Vim"; the cursor does not select it.
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
C  fg=muted*
D  fg=primary
H  focus (`semantic.focus`)
```

#### Multi-select menu

The multi-select menu lists options in place, with a check mark on every chosen option.
The cursor is separate from the marks: `❯` marks the cursor row, `☑` in `accent` marks a
chosen option, and `☐` in `muted*` marks the others. Space toggles the cursor option and
keeps the list open. It has no custom row.

```wireframe 40x5
Channels
  ☑ Email
❯ ☐ SMS
  ☑ Push
  ☐ Webhook
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c7  Picker label -- the title row; not a selection target.
2. r1 c2     chosen mark -- `☑` in `accent`.
3. r2 c0     cursor -- `❯` in `semantic.focus` on the cursor row, drawn while focused.
4. r2 c2     unchosen mark -- `☐` in `muted*`.
5. r1 c4-8   label "Email" -- `primary`.
6. r2 c4-6   label "SMS" -- the cursor label, `semantic.focus` bold.
```

Styled grid for the Unicode multi-select menu:

```text
── chars ──
Channels
  ☑ Email
❯ ☐ SMS
  ☑ Push
  ☐ Webhook
── style ──
AAAAAAAA
..B.DDDDD
C.E.FFF
..B.DDDD
..E.DDDDDDD
── legend ──
.  default
A  fg=primary bold
B  fg=accent
C  focus (`semantic.focus`)
D  fg=primary
E  fg=muted*
F  focus (`semantic.focus`) bold
```

#### Multi-select menu, ASCII

```wireframe 40x5
Channels
  [x] Email
> [ ] SMS
  [x] Push
  [ ] Webhook
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c7  Picker label -- the title row.
2. r1 c2-4   chosen mark -- `[x]`, Toggle's checkbox at the ASCII-only rung; the label starts at c6.
3. r2 c0     cursor -- `>` at the ASCII-only rung.
4. r2 c2-4   unchosen mark -- `[ ]`.
```

#### Menu with descriptions

Each option may carry a one-line description, drawn in `muted` after its label. The
description column starts two cells after the widest label, past the four prefix cells, so
every description aligns. A description tail-truncates with `truncation.mark` to the cells
that remain. When fewer than four cells remain after the column, no description is drawn
for any option (sizing: 12x4).

```wireframe 40x5
Deploy region
❯ ◉ eu-west   Ireland, lowest latency
  ○ us-east   Virginia, most capacity
  ○ ap-south  Mumbai, for APAC users, b…
  ○ sa-east   Sao Paulo, lowest cost
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c12  Picker label -- the title row.
2. r1 c0      cursor -- `❯` in `semantic.focus`, drawn while focused.
3. r1 c2      chosen mark -- `◉` in `accent`; the other rows show `○` in `muted*`.
4. r1 c4-10   label "eu-west" -- `semantic.focus` bold on the cursor row.
5. r1-r4 c14  description column -- starts at cell 14: four prefix cells, the widest label
              "ap-south" (eight cells), and two cells.
6. r1 c14-36  description "Ireland, lowest latency" -- `muted*`; fits the 26 cells that remain.
7. r3 c14-39  description "Mumbai, for APAC users, b…" -- tail-truncated with `truncation.mark`
              to the 26 cells that remain.
```

## State model

Each presentation owns its own state. Picker retains no business data in any presentation;
the only widget-retained values are the UI states named below.

### Inline cycling row

| State                              | Owner       | Type                                                                              | Reset or clamp rule                                                                                                                                                                                                                          |
| ---------------------------------- | ----------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection                          | Binding     | `Binding<Selection>`                                                              | App-owned source of truth. Picker writes only a supplied option after an enabled interior cycle or a first cycle from an absent value; an external replacement is authoritative.                                                             |
| is enabled                         | Environment | `Bool`                                                                            | Read on every reconciliation. `false` removes Picker from the focusable list and prevents activation without changing `selection`.                                                                                                           |
| semantic Styles                    | Environment | `semantic.primary`, `semantic.focus`, and `semantic.disabled` full `Style` values | Read on every render; the resolved row Style is primary when enabled and unfocused, focus when focused, and disabled when disabled.                                                                                                          |
| option count                       | derived     | `Int`                                                                             | Recomputed from the current app-supplied option set on every reconciliation; clamps to `0...Int.max` and never changes the set.                                                                                                              |
| selected option index              | derived     | `Int?`                                                                            | Recompute by searching the current option set on every reconciliation. It is `nil` when the set is empty or `selection` is absent; Picker shows the placeholder and does not write the binding. Otherwise it is in `0...(option count - 1)`. |
| is focused                         | Environment | `Bool`                                                                            | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Picker reads it during rendering and checks `ResponderContext.isFocused` for events.                                                                |
| value slot geometry and truncation | derived     | `TerminalSize` and rendered grapheme range                                        | Recomputed from the final one-row allocation on every layout; clamp to the value slot, tail-truncate at grapheme boundaries with `truncation.mark`, and never increase height.                                                               |

The option set and label builder are immutable widget configuration, not retained business
state. The inline cycling row has no expanded presentation, so it needs no open or reveal
`NodeState`.

### Radio group

| State                 | Owner       | Type                 | Reset or clamp rule                                                                                                                                                                                                              |
| --------------------- | ----------- | -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection             | Binding     | `Binding<Selection>` | App-owned. Picker writes only a supplied option after a Left, Right, or chip click. From an absent value, Left or Right selects the first option.                                                                                |
| selected option index | derived     | `Int?`               | Recomputed from `selection` on every reconciliation; `nil` when the value is absent, and the group shows no pill.                                                                                                                |
| cursor index          | widget UI   | `Int`                | Keyboard position of the `❯` prefix while focused. Starts on the chosen option, or on 0 when the value is absent, without choosing it (owner decision, 2026-10-10). Clamped on every reconciliation; not written to `selection`. |
| wrapped layout        | derived     | rows of chip indices | Recomputed from the final allocated width on every layout. A chip starts a new row when it would exceed the width; wrapped rows indent three cells under the first chip. Never clips.                                            |
| is focused            | Environment | `Bool`               | Controls the `❯` cursor prefix and the active underline, which are drawn only while focused; there is no hover treatment in 1.0. Events are checked through `ResponderContext.isFocused`.                                        |

### Menu

| State         | Owner       | Type                 | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                   |
| ------------- | ----------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection     | Binding     | `Binding<Selection>` | App-owned. Picker writes only on Enter, Space, a digit, or a click that commits an option, or on Enter that ends custom editing.                                                                                                                                                                                                                      |
| chosen option | derived     | `Int?`               | Recomputed from `selection`; the matching row shows `◉` in `accent`. `nil` when the value is absent; no row is marked.                                                                                                                                                                                                                                |
| cursor index  | widget UI   | `Int`                | Keyboard position within the list, not business data and not written to `selection`. Clamped to `0...(option count - 1)` on every reconciliation. Starts on the chosen option, or on the first option when the value is absent (owner decision, 2026-10-10).                                                                                          |
| editing       | widget UI   | `Bool`               | `true` after Enter or Space chooses the custom row. Ends on Enter (commit) or Escape (cancel). Reset to `false` when the custom row is removed from the option set.                                                                                                                                                                                   |
| draft text    | widget UI   | `String`             | Accepts typed text only while editing. Enter commits a nonempty draft to `selection`; an empty draft ends editing and leaves `selection` unchanged. Escape clears the draft; a committed value stays (owner decision, 2026-10-10). Not shown after editing ends unless the custom row is the chosen value, in which case the committed text is shown. |
| is focused    | Environment | `Bool`               | Gates every key in the key table; the cursor prefix is drawn while focused.                                                                                                                                                                                                                                                                           |

### Segmented control

| State                 | Owner       | Type                             | Reset or clamp rule                                                                                                                                                                                       |
| --------------------- | ----------- | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection             | Binding     | `Binding<Selection>`             | App-owned. Picker writes only after Left, Right, or a segment click.                                                                                                                                      |
| selected option index | derived     | `Int?`                           | Recomputed from `selection`; `nil` when the value is absent, and no segment is active.                                                                                                                    |
| label presentation    | derived     | per-segment icon, label, or both | Recomputed from the final width on every layout: first the longest label tail-truncates to two characters plus `truncation.mark`; below that floor every segment is icon-only. Never changes `selection`. |
| segment widths        | derived     | cells per segment                | Recomputed on every layout as icon width, one padding cell on each side, and label width (when shown). A segment with no icon and no room keeps `truncation.mark`.                                        |
| is focused            | Environment | `Bool`                           | Controls the underline of the active segment; events are checked through `ResponderContext.isFocused`.                                                                                                    |

### Multi-select

| State         | Owner       | Type                      | Reset or clamp rule                                                                                                                                                     |
| ------------- | ----------- | ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| selection     | Binding     | `Binding<Set<Selection>>` | App-owned. Picker writes only after a toggle: Space, a digit, or a click on an option or chip. Elements with no supplied option stay in the set, unchanged and undrawn. |
| checked count | derived     | `Int`                     | Recomputed from `selection` and the option set on every reconciliation; feeds the host summary.                                                                         |
| cursor index  | widget UI   | `Int`                     | Keyboard position within the list or chip row. Clamped to `0...(option count - 1)` on every reconciliation; never written to `selection`.                               |
| is focused    | Environment | `Bool`                    | Gates every key; the `❯` cursor and the focus treatment draw only while focused.                                                                                        |

### Menu in a host row

| State        | Owner       | Type     | Reset or clamp rule                                                                                                                                                                                                                       |
| ------------ | ----------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| open         | widget UI   | `Bool`   | Set by Enter, Space, or a click on the closed row. Cleared without committing by Escape, focus loss, or a click outside; cleared by Enter in either mode and by a click on the row while open. Multi-select toggles already written stay. |
| cursor index | widget UI   | `Int`    | Starts on the first chosen option when opened, or on the first option when none is chosen. Clamped on every reconciliation.                                                                                                               |
| summary      | derived     | `String` | Single-select: the chosen label, or `—` when absent. Multi-select: the first two chosen labels joined by a comma and a space, then a space and `+N` for the rest; `none` when empty. Names tail-truncate with `…` before the count.       |
| is focused   | Environment | `Bool`   | Focus loss closes an open list. A disabled row is absent from focus and cannot open.                                                                                                                                                      |

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
the boundary behavior of [ScrollView](scroll-view.md). The inline row does not wrap; the
radio group and segmented control do (see below).

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

#### Multi-select radio group

| Key                       | Precondition                                        | Effect                                                                                                   | Consumed |
| ------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | -------- |
| Right                     | focused and is enabled and option count is positive | moves the cursor to the next option; the last wraps to the first, across rows; `selection` unchanged     | yes      |
| Left                      | focused and is enabled and option count is positive | moves the cursor to the previous option; the first wraps to the last, across rows; `selection` unchanged | yes      |
| Space, Enter              | focused and is enabled and option count is positive | toggles the cursor option's membership via binding                                                       | yes      |
| Right, Left, Space, Enter | focused and is enabled and option count is zero     | no handler                                                                                               | no       |
| Up, Down                  | any                                                 | no handler; bubbles                                                                                      | no       |

Left and Right move the cursor only, so a multi-select radio group changes `selection` on
an explicit Space or Enter, never by moving.

### Menu

| Key                                            | Precondition                                                                                             | Effect                                                                                                                                    | Consumed |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| Up                                             | focused and is enabled and option count is positive and not editing and cursor is below the first option | moves cursor to the previous option; `selection` unchanged                                                                                | yes      |
| Up                                             | focused and is enabled and option count is positive and not editing and cursor is on the first option    | cursor unchanged; clamps without wrapping                                                                                                 | no       |
| Down                                           | focused and is enabled and option count is positive and not editing and cursor is above the last option  | moves cursor to the next option; `selection` unchanged                                                                                    | yes      |
| Down                                           | focused and is enabled and option count is positive and not editing and cursor is on the last option     | cursor unchanged; clamps without wrapping                                                                                                 | no       |
| PageUp                                         | focused and is enabled and option count is positive and not editing                                      | moves cursor up by one page, clamped to the first option                                                                                  | yes      |
| PageDown                                       | focused and is enabled and option count is positive and not editing                                      | moves cursor down by one page, clamped to the last option                                                                                 | yes      |
| Home                                           | focused and is enabled and option count is positive and not editing                                      | moves cursor to the first option; consumed even when the cursor is already there                                                          | yes      |
| End                                            | focused and is enabled and option count is positive and not editing                                      | moves cursor to the last option; consumed even when the cursor is already there                                                           | yes      |
| Enter                                          | focused and is enabled and not editing and cursor is on an option other than the custom row              | commits the cursor option via binding                                                                                                     | yes      |
| Enter                                          | focused and is enabled and not editing and cursor is on the custom row                                   | chooses the custom row and starts editing; `selection` written on commit                                                                  | yes      |
| Space                                          | focused and is enabled and not editing and cursor is on an option other than the custom row              | commits the cursor option via binding, as Enter does                                                                                      | yes      |
| Space                                          | focused and is enabled and not editing and cursor is on the custom row                                   | chooses the custom row and starts editing                                                                                                 | yes      |
| Enter                                          | editing                                                                                                  | ends editing; a nonempty draft is committed as the custom value via binding; an empty draft ends editing and leaves `selection` unchanged | yes      |
| Escape                                         | editing                                                                                                  | ends editing and clears the draft text; `selection` unchanged by this key                                                                 | yes      |
| Escape                                         | focused and enabled and not editing and custom row is chosen                                             | clears the draft text if any; the committed `selection` stays                                                                             | yes      |
| Backspace, Ctrl-U, Ctrl-W, printable character | editing                                                                                                  | edited by the shared text-editing core                                                                                                    | yes      |
| any other key                                  | editing                                                                                                  | no effect; swallowed so the draft is not disturbed                                                                                        | yes      |
| any key                                        | not focused, disabled, or option count is zero                                                           | no handler; bubbles                                                                                                                       | no       |
| Left, Right, other keys                        | focused and enabled and not editing                                                                      | no handler; bubbles                                                                                                                       | no       |
| Escape                                         | focused and enabled and not editing and custom row is not chosen                                         | no handler; bubbles                                                                                                                       | no       |
| 1 to 9                                         | focused and is enabled and not editing and option count is at least N                                    | commits the Nth option via binding, as Enter does; the custom row, if Nth, starts editing                                                 | yes      |
| 1 to 9                                         | focused and is enabled and not editing and option count is below N                                       | no handler; bubbles                                                                                                                       | no       |

Digits 1 to 9 pick the Nth option in display order (owner decision, 2026-10-11). Options
past the ninth have no digit and are reached with the arrow or page keys. Digit labels are
not drawn, so the option rows match the state wireframes.

#### Multi-select menu

| Key                                   | Precondition                                          | Effect                                                                                 | Consumed |
| ------------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------- | -------- |
| Up, Down, PageUp, PageDown, Home, End | focused and is enabled and option count is positive   | move the cursor as in the Menu table; `selection` unchanged                            | yes      |
| Space                                 | focused and is enabled and option count is positive   | toggles the cursor option's membership in `selection` via binding; the list stays open | yes      |
| 1 to 9                                | focused and is enabled and option count is at least N | toggles the Nth option via binding and moves the cursor to it; the list stays open     | yes      |
| 1 to 9                                | focused and is enabled and option count is below N    | no handler; bubbles                                                                    | no       |
| Enter, Escape                         | focused and is enabled                                | no handler; bubbles, because a standalone list has nothing to close                    | no       |
| any key                               | not focused, disabled, or option count is zero        | no handler; bubbles                                                                    | no       |

The standalone multi-select menu draws every option with `☑` or `☐` and has no custom row.
Its title row, cursor, and label rules are those of the single-select menu.

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

A multi-select radio group keeps the chip regions above. A click on chip `i` installs
focus and toggles chip `i` via binding; the other chips are unchanged. Chips at or above
the option count have no handler, as above.

### Menu

| Event                | Region                       | Precondition                                                                     | Effect                                                                                                     | Consumed |
| -------------------- | ---------------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------- |
| click                | option row                   | is enabled, option count is positive, row is not the custom row, and not editing | installs this Picker's focus, moves cursor to that row, then commits it via binding                        | yes      |
| click                | option row                   | is enabled, option count is positive, row is not the custom row, and editing     | ends editing and discards the draft; installs focus, moves cursor to that row, then commits it via binding | yes      |
| click                | custom row                   | is enabled, option count is positive, and not editing                            | installs focus, moves cursor to the custom row, then chooses it and starts editing (same as Enter)         | yes      |
| click                | custom row                   | is enabled, option count is positive, and editing                                | installs focus and moves cursor to the custom row; editing and the draft continue                          | yes      |
| click                | title row, below last option | always                                                                           | no handler; bubbles                                                                                        | no       |
| wheel up, wheel down | any                          | is enabled and option count is positive                                          | moves cursor one row up or down; consumed even when already at the first or last option                    | yes      |
| wheel up, wheel down | any                          | option count is zero                                                             | no handler; bubbles                                                                                        | no       |
| click                | option row, multi-select     | is enabled and option count is positive                                          | installs this Picker's focus, moves cursor to that row, then toggles it via binding; the list stays open   | yes      |
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
label column. The Picker takes the value column after it, up to the row's right edge.
Collapsed, the row shows the value summary and an open marker `▾` in `muted`. Enter or
Space opens the option list in place, below the row. Its option rows are the menu's rows,
indented four cells. Esc or focus loss closes the list without committing. Enter commits a
single-select choice and closes the list. A multi-select host keeps the list open while
Space toggles, and Enter closes it. While the row is closed, its keys bubble to the host.

The option rows keep the menu's marks, cursor, and digit rules (see the Menu and
Multi-select menu states). Descriptions draw in the open list with the same column rule,
measured from the four-cell indent. Form links to this section instead of restating its
dropdown keys.

### Closed row, single-select

```wireframe 40x1
Region      eu ▾
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c11  host label -- "Region", supplied by the host, not drawn by Picker.
2. r0 c12-c13 value -- "eu", the chosen option's label, in `info`, as Form's select value.
3. r0 c15     open marker -- `▾` in `muted`; drawn while closed and while open.
```

### Open list, multi-select

```wireframe 40x5
Regions     eu, us +1 ▾
      ☑ eu
    ❯ ☑ us
      ☑ ap
      ☐ sa
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c11  host label -- "Regions", supplied by the host.
2. r0 c12-c20 summary -- "eu, us +1": the first two chosen names, then a count of the rest; `info`.
3. r0 c22     open marker -- `▾` in `muted`.
4. r1-r4 c4-c39 option rows -- indented four cells below the host row, with the menu's marks.
5. r2 c4      cursor -- `❯` in `semantic.focus` on the cursor row, drawn while focused.
6. r1-r4 c6   check marks -- `☑` in `accent` for chosen options, `☐` in `muted*` otherwise.
7. r2 c8-9    label "us" -- the cursor label, `semantic.focus` bold.
```

### Mouse

| Event                | Region                        | Precondition                    | Effect                                                                                | Consumed |
| -------------------- | ----------------------------- | ------------------------------- | ------------------------------------------------------------------------------------- | -------- |
| click                | host row                      | is enabled and closed           | installs this Picker's focus, then opens the list as Enter does                       | yes      |
| click                | host row                      | is enabled and open             | installs focus and closes the list without committing                                 | yes      |
| click                | option row, single-select     | is enabled and open             | installs focus, moves cursor to that row, commits it via binding, and closes the list | yes      |
| click                | option row, multi-select      | is enabled and open             | installs focus, moves cursor to that row, toggles it via binding; the list stays open | yes      |
| click                | outside the host row and list | open                            | closes the list without committing, as focus loss does; the click bubbles             | no       |
| click                | host row                      | not is enabled                  | leaves focus and the list unchanged                                                   | no       |
| wheel up, wheel down | list                          | is enabled and open             | moves cursor one row up or down, clamped; consumed                                    | yes      |
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

| Key                         | Precondition                                    | Effect                                                                                      | Consumed |
| --------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------- | -------- |
| Up, Down                    | open and is enabled                             | moves cursor to the previous or next option; clamps without wrapping; `selection` unchanged | yes      |
| PageUp, PageDown, Home, End | open and is enabled                             | move cursor as the Menu keys do                                                             | yes      |
| Enter                       | open, single-select, cursor on an option        | commits the cursor option via binding and closes the list; focus stays on the host row      | yes      |
| Space                       | open, single-select                             | commits the cursor option, as Enter does                                                    | yes      |
| Space                       | open, multi-select                              | toggles the cursor option's membership via binding; the list stays open                     | yes      |
| Enter                       | open, multi-select                              | closes the list; nothing is written, because each toggle is already written                 | yes      |
| 1 to 9                      | open, option count is at least N, single-select | commits the Nth option and closes the list                                                  | yes      |
| 1 to 9                      | open, option count is at least N, multi-select  | toggles the Nth option, moves the cursor to it, and keeps the list open                     | yes      |
| 1 to 9                      | open, option count is below N                   | no handler; bubbles                                                                         | no       |
| Escape                      | open                                            | closes the list without committing; toggles already written in multi-select stay            | yes      |
| Left, Right, other keys     | open                                            | no handler; consumed so the row's value does not change behind the list                     | yes      |
| Tab, Shift-Tab              | open                                            | no handler; bubbles, and the resulting focus loss closes the list without committing        | no       |

## Sizing

Results use the `Medium` fixture label for the inline row. Picker's height follows its
presentation: the inline row and segmented control are one row high, the radio group is as
many rows as its wrapped chips need, and the menu is its title row plus one row per
option. Picker measures its natural width and does not opportunistically grow into surplus
space.

### Inline cycling row

| Proposal  | Result | Rule                                                                                                                  |
| --------- | ------ | --------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 10x1   | Natural inline result: six `Medium` label cells, two spaces, and two one-cell chevrons.                               |
| 10x1      | 10x1   | Tight fit retains the full natural presentation.                                                                      |
| 4x1       | 4x1    | Below the `5x1` floor, omit the value slot and retain the two directional affordances without drawing partial glyphs. |
| 80x24     | 10x1   | Extra width and height do not enlarge a label-hugging inline Picker.                                                  |

### Radio group

| Proposal  | Result  | Rule                                                                                                                                                                                                                                                             |
| --------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | one row | Every chip on one row at its natural width; the group measures width as the cursor slot plus each chip's label width, two pill-cap cells, and one gap cell between chips. Chip width is label + 2 caps + 1 gap; a chip wider than the row truncates at the tail. |
| 20x2      | 2 rows  | The four-option set wraps to two rows; wrapped rows indent three cells under the first chip (wrap-20).                                                                                                                                                           |
| 14x4      | 4 rows  | Each chip takes its own row when no two fit (wrap-14).                                                                                                                                                                                                           |

### Menu

| Proposal                         | Result           | Rule                                                                                                                                                                               |
| -------------------------------- | ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 40x4                             | 4 rows           | Title row plus three options; the custom row is one of the options and adds no row.                                                                                                |
| 40x5                             | 5 rows           | Title row plus four options; check marks in a multi-select menu add no height.                                                                                                     |
| narrower than the longest option | unchanged height | Option labels tail-truncate with `truncation.mark` at grapheme boundaries; the menu never widens.                                                                                  |
| 20x4                             | 4 rows           | With descriptions: the description column starts at cell 14 (four prefix cells, the widest label, two cells) and tail-truncates to the six cells that remain.                      |
| 12x4                             | 4 rows           | With descriptions: fewer than four cells remain after the description column, so no description is drawn for any option; labels tail-truncate to the eight cells after the prefix. |

### Segmented control

| Proposal  | Result | Rule                                                                                                                         |
| --------- | ------ | ---------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 1 row  | Natural width: each segment is one padding cell, its icon, one cell between icon and label, its label, and one padding cell. |
| 24x1      | 1 row  | The longest label tail-truncates first, down to two characters plus `truncation.mark` (narrow-24).                           |
| 20x1      | 1 row  | Below the label floor every segment is icon-only (narrow-20).                                                                |

### Collapsed host row

| Proposal                | Result           | Rule                                                                                                                                         |
| ----------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil, closed       | 1 row            | The host row: label, collapsed value, and `▾`. The host supplies the label column; the Picker takes the value column and the width after it. |
| open                    | 1 + option rows  | The host row plus one row per option, drawn below the host row and indented four cells. Check marks add no height.                           |
| narrower than the value | unchanged height | Names tail-truncate with `…` first and the `+N` count is kept; the row never widens.                                                         |

## Environment

Picker consumes `isEnabled` and applies one resolved semantic Style to its implemented
inline row: `semantic.primary` when enabled and unfocused, `semantic.focus` when focused,
and `semantic.disabled` when disabled. `truncation.mark` defines grapheme-safe value-slot
overflow; its chevron and placeholder substitutions are specified in
[Degradation](#degradation).

The radio group, segmented control, and menu use the same enabled and focused rules. Their
sub-element roles are:

- `primary` -- labels and unchosen option text.
- `focus` -- the focused group's cursor glyph and label, and the active chip underline,
  via `semantic.focus`.
- `accent` -- the active segment and active chip background; the chosen marker `◉` in the
  menu and the check mark `☑` in a multi-select menu, the same selection-mark colour as
  Toggle and Form.
- `muted` -- inactive chips and segments, the unchosen marker `○` or `☐`, and each option
  description (owner decision, 2026-10-11).
- `disabled` -- every visible cell of a disabled Picker.
- `contrast` -- the label on an active chip or segment.
- `info` -- the typed custom text in the menu.
- `surface` -- the inactive segment band.

Token pending plan 032 step 5.3: `muted`, `info`, `contrast`, and `surface` have no entry
in [tokens](../tokens.md) yet. `semantic.primary`, `semantic.accent`, `semantic.focus`,
and `semantic.disabled` exist.

> Deferred: endpoint-specific affordance styling, custom `PickerStyle`, `focus.border`,
> and custom-style environment inputs land in a later slice.

## Primitive dependencies

- [`Text`](../primitives/text.md) -- ready; renders selected labels and the absent-value
  placeholder, measures display cells, and provides grapheme-safe tail truncation.
- [`Label`](../primitives/label.md) -- supplies the icon-and-title pair for segments and
  menu rows, and the `.iconOnly` label style.
- [`Button`](button.md) -- the active chip uses the filled emphasis and the capped ends of
  the button's [shapes](button.md#shape).
- [`List`](list.md) -- supplies the row chrome for the menu's option list.
- [`Style modifiers`](../primitives/style-modifiers.md) -- ready; resolve and apply the
  inherited complete semantic Styles without giving Picker its own mutable visual state.
- [Focus manager and responder context](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
  -- supplies app-installed `FocusID` routing and focusable-list participation.
- [Mouse hit testing](../../docs/Spec.md#slice-5-mouse-and-hit-testing) -- supplies chip,
  segment, and value-slot hit testing and click-to-focus ordering.

## Requirements

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
- `picker tail-truncates a constrained selected label at a grapheme boundary` (state
  model: value slot geometry and truncation; sizing table: 5x1 floor).
- `picker substitutes ASCII chevrons and placeholder when capability requires it` (state
  wireframe: ASCII degraded; degradation: ASCII-only).
- `picker radio group draws the active chip's caps as rectangle cells under ASCII-only`
  (degradation: radio group; chip width unchanged).
- `picker menu draws (*) and ( ) markers and > cursor under ASCII-only` (degradation:
  menu).

Radio group:

- `picker radio group wraps chips onto more rows instead of clipping` (states: wrap-20 and
  wrap-14).
- `picker radio group keeps every option visible at 14 columns` (state: one chip per row).
- `picker radio group indents wrapped rows three cells under the first chip` (state:
  wrap-20).
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
- `picker menu Enter on the custom row starts editing` (key table: menu Enter on custom
  row; state: custom row while typing).
- `picker menu editing keys edit the draft and Enter commits it` (key table: editing
  rows).
- `picker menu Escape ends editing and clears the draft while a committed value stays`
  (key table: menu Escape; state: custom row after commit).
- `picker menu keeps the custom row chosen with its committed text after Enter` (state:
  custom row after commit).
- `picker menu shows no chosen marker when the binding is absent` (state: no selection).
- `picker menu wheel moves the cursor and is consumed at list edges` (mouse table: menu
  wheel).
- `picker menu click on an option row moves the cursor then commits it` (mouse table: menu
  option row).

Segmented control:

- `picker segmented renders icon-only segments under labelStyle iconOnly` (state: icons
  only at 40 columns).
- `picker segmented tail-truncates the longest label first at two characters and the mark`
  (state: tail-truncated labels at 24 columns).
- `picker segmented falls back to icon-only below the label floor` (state: icons only at
  20 columns).
- `picker segmented keeps one padding cell on each side of every segment` (styled grids at
  24 and 20 columns).
- `picker segmented keeps a segment with no icon and no room as the truncation mark`
  (state model: segment widths).
- `picker segmented Right and Left wrap and are consumed` (key table: segmented Right and
  Left).
- `picker segmented click on a segment sets selection and consumes the click` (mouse
  table: segment `i`).

Multi-select:

- `picker multi-select menu draws a check mark on every chosen option` (state:
  multi-select menu open).
- `picker multi-select menu Space toggles the cursor option and keeps the list open` (key
  table: multi-select menu Space).
- `picker multi-select menu Enter bubbles in place` (key table: multi-select menu Enter).
- `picker multi-select radio group Space and Enter toggle the cursor chip` (key table:
  multi-select radio Space and Enter).
- `picker multi-select radio group Left and Right move the cursor and wrap across rows`
  (key table: multi-select radio Left and Right).
- `picker multi-select click toggles the option and keeps the list open` (mouse table:
  multi-select option row).
- `picker multi-select keeps set elements without a supplied option in the binding` (state
  model: multi-select selection).
- `picker multi-select draws bracketed marks under ASCII-only` (degradation: multi-select
  menu).

Menu digits and descriptions:

- `picker menu digit key commits the Nth option` (key table: menu digits).
- `picker multi-select digit key toggles the Nth option and keeps the list open` (key
  table: multi-select menu digits).
- `picker menu digit beyond the option count bubbles` (key table: menu digits).
- `picker menu digit is typed text while editing the custom row` (key table: editing
  rows).
- `picker menu descriptions start two cells after the widest label` (state: menu with
  descriptions; sizing: 20x4).
- `picker menu descriptions tail-truncate within the remaining width` (state: menu with
  descriptions).
- `picker menu omits descriptions when fewer than four cells remain` (sizing: 12x4).
- `picker menu descriptions use the muted role` (environment: sub-element roles).

Menu collapsed in a host row:

- `picker host row shows the collapsed value with an open marker` (state: host row
  closed).
- `picker host row Enter and Space open the list below the row` (key table: host row
  closed).
- `picker host row Up, Down, Left, and Right bubble while closed` (key table: host row
  closed).
- `picker host row single Enter and Space commit the cursor option and close` (key table:
  host list single).
- `picker host row Escape closes a single-select list without committing` (key table: host
  list single).
- `picker host row focus loss closes the list without committing` (state model: open
  flag).
- `picker host row multi-select Space toggles and keeps the list open` (key table: host
  list multi).
- `picker host row multi-select summary shows the first two chosen names and a count`
  (state model: summary).
- `picker host row multi-select summary truncates names before the count` (state model:
  summary).
- `picker host row multi-select empty set summary reads none` (state model: summary).
- `picker host row digit key commits or toggles the Nth option` (key table: host list).

## Degradation

Picker follows the [degradation ladder](../tokens.md#degradation-ladder). In `NO_COLOR`,
semantic Styles reduce to their attributes and focused Picker remains bold; in 16-color,
`semantic.accent` resolves to its indexed-color plus attribute fallback. At the ASCII-only
rung, U+2039 `‹` becomes `<`, U+203A `›` becomes `>`, and the absent-value em dash `—`
becomes `-`; every replacement is one display cell and preserves the inline geometry.
`truncation.mark` becomes `~` at that same rung.

Per presentation:

- Radio group: at the ASCII-only rung the cursor prefix becomes `>` plus a space. The
  selected chip's pill caps become `.rectangle` caps, one full accent-filled cell on each
  side of the chip, as Button's `.rectangle` draws them. Chip width is unchanged under
  ASCII, so the wrap rule measures the same width at every rung (owner decision,
  2026-10-10).
- Segmented control: segment icons resolve through the active charset. A segment whose
  icon has no ASCII form needs an app-supplied fallback (open question). The label floor
  and icon-only fallback are unchanged at every rung.
- Menu: at the ASCII-only rung the chosen marker `◉` becomes `(*)` and the unchosen marker
  `○` becomes `( )`, the ASCII forms of Toggle's `.circle`. These markers are three cells
  instead of one, so the option label is measured within the remaining width. The cursor
  `❯` becomes `>`, and the beam caret `▏` becomes `|` (owner decision, 2026-10-10).
- Multi-select menu: the check marks `☑` and `☐` become `[x]` and `[ ]`, the ASCII forms
  of Toggle's checkbox. Both are three cells, so the option label is measured within the
  remaining width (owner decision, 2026-10-11). Multi-select radio chips keep their pill
  caps and show no check mark, so they need no further substitution.
- Multi-select menu under `NO_COLOR`: the chosen and unchosen marks differ by glyph (`☑`
  against `☐`), not by colour, so the selection reads without colour (owner decision,
  2026-10-11).
- Option descriptions: a description is plain text after its label at every rung. The
  ASCII-only rung changes no description glyph, and `NO_COLOR` removes only its `muted*`
  colour (owner decision, 2026-10-11).
- Collapsed host row: the open marker `▾` becomes `v`. The value summary keeps its `+N`
  suffix under the same truncation rule at every rung (owner decision, 2026-10-11).

Below the declared `5x1` floor, Picker reduces feature use rather than drawing partial
glyphs: at `4x1` it omits the value slot and retains the two directional affordances; with
fewer than two cells it emits no partial Picker chrome and has no input handler. This is
layout degradation only: it never manufactures a selection or writes the binding.

## Open questions

- **Deferred:** an overlay or popover presentation of the menu. The menu and its collapsed
  host row draw their option list in place, so an overlay would need a transient open bit,
  placement, dismissal, and option-hit semantics without changing the `Binding<Selection>`
  ownership rule.
- **Deferred:** per-option disabled state. 1.0 treats every supplied option as selectable;
  disabled-option visibility, traversal, and placeholder policy are deferred to
  [Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
- **Open:** the `contrast` role used on active chips and segments is not in the Tessera
  role list. Name it or map it to an existing role; token pending plan 032 step 5.3.
- **Open:** segmented icon ASCII fallback. A segment whose icon has no ASCII form needs an
  app-supplied fallback; the ASCII rung does not define one for the segmented control.
- **Open:** multi-select details inferred while applying the owner's 2026-10-11 answers,
  not owner decisions: the `Binding<Set<Selection>>` initializer has no title parameter;
  Enter in a standalone multi-select menu passes to the parent (only a hosted menu has an
  open state to close); options past the ninth get no digit and digit labels aren't drawn;
  multi-select menus have no custom "Other" row; and the protocol is named
  `MultiSelectPickerStyle`. Overload resolution when `Selection` is itself a `Set` is
  unchecked against the compiler. Unblocks: owner confirmation, and a compile check once
  Picker is built.
- **Open:** option description layout (inferred): muted, after the label in a column at
  four plus the widest label plus two, tail-truncated, and dropped when fewer than four
  cells remain. Unblocks: owner confirmation.
- **Resolved:** an absent bound value displays `—` and does not write the binding. The
  first enabled cycle with a nonempty option set writes the first option.

## Out of scope

- Fuzzy filtering of menu options is outside Picker 1.0 (owner decision, 2026-10-11). It
  is recorded as a feature idea in [design/inbox.md](../inbox.md).

## Inspiration

A Picker should make the current app-owned choice legible in one terminal row and make the
next choice predictable, not hide selection policy in private widget state.
