---
kind: widget
status: ready
---

# MultiPicker

`MultiPicker` is Tessera's controlled multi-selection control over an app-supplied finite option set. It is a separate type from [Picker](picker.md) (owner decision, 2026-10-18): Picker holds one value and MultiPicker holds a set of them, so the two never share an initializer or a style protocol. The application owns the options and the selected values through a binding; MultiPicker only derives which supplied options are checked and renders them. It retains no business data and never invents a selection. This is a widget-layer design following the controlled-widget rule in [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md), with explicit focus supplied by [Slice 4](../../spec/phase-4/slice-04-focus-and-key-routing.md) and pointer delivery supplied by [Slice 5](../../spec/phase-4/slice-05-mouse-and-hit-testing.md).

The 1.0 presentations are the menu and the radio group. Each is chosen through `multiPickerStyle` and shares the same binding, focus, and enabled rules. Menu rows, option descriptions, scrolling, and the custom "Other" row follow [Picker](picker.md); this doc records only what multi-select changes.

## Prior art

- Apple SwiftUI [MultiDatePicker](https://developer.apple.com/documentation/swiftui/multidatepicker) -- copy the naming pattern for a multi-value sibling of a single-value picker, and the `Binding<Set<...>>` selection. Reject its calendar presentation.
- Apple SwiftUI `List(selection:)` -- copy the `Binding<Set<Selection>>` precedent for a plain multi-selection binding. Apple's `searchable(tokens:)` is the precedent for the ordered custom-option initializer, which binds any random-access, range-replaceable collection of the selection type.
- omp2 select menu with `multi` ([`select.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L514-L715)) is the counterpart -- copy the in-place option list, the cursor glyph separate from the check mark, and the Space toggle (`activate` L680-692; owner decision, 2026-10-11). Enter never toggles in MultiPicker (owner decision, 2026-10-18). omp2's multi-select Enter does not toggle either: it emits `Submit` (L656-659), and MultiPicker lets Enter bubble so a default button submits (key C3). The chosen set (`chosen` L142) is the app's binding, written per toggle (keys D1, C6), and the cursor, `editing`, `custom_text`, and `scroll` are NodeState, as in [Picker](picker.md#prior-art) (keys D3, D7, D8, D4). Its filter is not in 1.0 (keys C7, M2).
- [Picker](picker.md) -- the single-select sibling. Its menu, radio group, option descriptions, scrolling contract, and custom row are the base this doc builds on.

## API direction

```swift
public struct MultiPicker<Label: View, Selection: Hashable, Value: View>: View {
    // Plain: any subset of `options`.
    public init(
        selection: Binding<Set<Selection>>,
        options: [Selection],
        @ViewBuilder content: @escaping (Selection) -> Value,
        @ViewBuilder label: () -> Label
    )

    // With a custom "Other" row: typed values join the selection.
    public init<C>(
        selection: Binding<C>,
        options: [Selection],
        customOption: @escaping (String) -> Selection?,
        customOptionLabel: String = "Other (type your own)",
        @ViewBuilder content: @escaping (Selection) -> Value,
        @ViewBuilder label: () -> Label
    ) where C: RangeReplaceableCollection & RandomAccessCollection, C.Element == Selection
}

extension MultiPicker where Label == Text {
    public init(
        _ title: String,
        selection: Binding<Set<Selection>>,
        options: [Selection],
        @ViewBuilder content: @escaping (Selection) -> Value
    )

    public init<C>(
        _ title: String,
        selection: Binding<C>,
        options: [Selection],
        customOption: @escaping (String) -> Selection?,
        customOptionLabel: String = "Other (type your own)",
        @ViewBuilder content: @escaping (Selection) -> Value
    ) where C: RangeReplaceableCollection & RandomAccessCollection, C.Element == Selection
}
```

MultiPicker mirrors Picker's initializers: a title string or a `label` view, the same `options`, and the same value-label builder (owner decision, 2026-10-18). The title is the menu's title row, the row label when a host such as a [Form](form.md) places the MultiPicker, and the accessible name. The radio group draws it before itself, as [Picker's](picker.md#title) inline row, radio group, and segmented control do, and `.labelsHidden()` hides the drawn title in every presentation while it stays the accessible name. The presentation is chosen with `.multiPickerStyle(_:)`, which accepts only `.menu` and `.radioGroup`; the default is `.menu` (owner decision, 2026-10-18). The inline cycling row and the segmented control hold one value, so they are not MultiPicker styles and `.multiPickerStyle(.segmented)` does not compile.

```swift
// `selectedRegions` is a Binding<Set<String>> from the app's model.
MultiPicker("Regions", selection: selectedRegions, options: regions) { region in
    Text(region)
}
.multiPickerStyle(.menu)
```

- **Plain initializer.** The set holds any subset of `options`. Elements with no supplied option stay in the set, unchanged and undrawn.
- **Custom-option initializer** (owner decision, 2026-10-18). The "Other" row exists only when the initializer receives `customOption`; no closure, no row. The closure turns the typed draft into a `Selection`, or returns `nil` to reject it: the draft stays and editing continues. `customOptionLabel` defaults to "Other (type your own)". The binding is any `RangeReplaceableCollection & RandomAccessCollection` of `Selection`; apps usually pass an `Array`, so typed values keep the order they were added in. There is no swift-collections dependency, because `OrderedSet` is not a `RangeReplaceableCollection`. Unlike Picker's custom row, a typed value is added to the selection and does not replace it.
- The custom row appears only in the `.menu` style. Under `.radioGroup` the closure is unused and selection elements with no supplied option stay in the binding, undrawn.

Option descriptions attach with `.optionDescription(_:)`, exactly as on Picker (see [Picker: menu with descriptions](picker.md#menu-with-descriptions)).

MultiPicker renders from `EnvironmentValues.isFocused` and handles keys only when `ResponderContext.isFocused` is true. Callers compose focus explicitly with `.focusable` and `.focused(_:equals:)`, as Picker's callers do.

> Deferred: custom multi-picker styles and style configuration wait on the Slice 7 style contract, with Picker's (see [Picker](picker.md#api-direction)). They must preserve the implemented selection, keyboard, pointer, enabled, and focus behavior.

## Presentations

| Presentation | Swift value | Shape | Height |
| --- | --- | --- | --- |
| Menu | `.multiPickerStyle(.menu)` | in-place option list with `☑` and `☐` marks; custom row when supplied | title row plus option rows |
| Radio group | `.multiPickerStyle(.radioGroup)` | chips that toggle rather than choose, wrapped onto more rows | number of wrapped rows |
| Menu in a host row | `.multiPickerStyle(.menu)` inside a host row | one row when closed; the open list draws below the row | 1 when closed |

## Anatomy

The menu lists options in place under its title row, with a check mark on every chosen option. The cursor is separate from the marks: `❯` marks the cursor row, `☑` in `accent` marks a chosen option, and `☐` in `secondary` marks the others. Space toggles the cursor option and keeps the list open. Enter never toggles. Option labels and the title row are content: they wrap and scroll in rows, as in [Picker's menu](picker.md#menu); `.lineLimit(1)` opts out (owner decision, 2026-10-18).

```wireframe 40x5
Channels
  ☑ Email
❯ ☐ SMS
  ☑ Push
  ☐ Webhook
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c7  Title row -- the MultiPicker's title; not a selection target; content, wraps.
2. r1 c2     chosen mark -- `☑` in `accent`; chrome, one row.
3. r2 c0     cursor -- `❯` in `focus` on the cursor row, drawn while focused.
4. r2 c2     unchosen mark -- `☐` in `secondary`; chrome, one row.
5. r1 c4-8   option label "Email" -- `primary`; content, wraps.
6. r2 c4-6   option label "SMS" -- the cursor label, `focus` bold; content, wraps.
```

Styled grid for the Unicode menu:

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
C  fg=focus
D  fg=primary
E  fg=secondary
F  fg=focus bold
```

## States

### Mobile

`mobile` is 40 columns wide at natural height. The Anatomy wireframe is already 40 columns wide, so the menu at `mobile` is that wireframe; the menu keeps its natural height and is not padded to a 40x16 frame (owner decision, 2026-10-10).

### Minimum

The declared normal-rendering floor of the menu is `11x5` for this fixture: the title row plus four options, each on one row. The primary content is the option labels, so the floor is the four prefix cells plus the widest label word, "Webhook" (seven cells); the title "Channels" (eight cells) is narrower. Below the floor words break between grapheme clusters and chrome keeps its drop order; nothing clips silently (owner decision, 2026-10-18).

```wireframe 11x5
Channels
  ☑ Email
❯ ☐ SMS
  ☑ Push
  ☐ Webhook
```

```text
Callouts (11x5, 0-based):
1. r0 c0-c7  Title row -- content, wraps.
2. r1-r4 c2  marks -- `☑` and `☐`; chrome, one row.
3. r2 c0     cursor -- `❯` in `focus`, drawn while focused.
4. r4 c4-10  option label "Webhook" -- the widest word; content, wraps.
```

### Menu, ASCII

```wireframe 40x5
Channels
  [x] Email
> [ ] SMS
  [x] Push
  [ ] Webhook
```

```text
Callouts (40x5, 0-based):
1. r0 c0-c7  Title row -- content, wraps.
2. r1 c2-4   chosen mark -- `[x]`, Toggle's checkbox at the ASCII-only rung; chrome, one
             row; the label starts at c6.
3. r2 c0     cursor -- `>` at the ASCII-only rung.
4. r2 c2-4   unchosen mark -- `[ ]`; chrome, one row.
```

### Typed values above the Other row

With the custom-option initializer, selection elements that are not in `options` draw as checked rows after the supplied options and above the Other row, in binding order (owner decision, 2026-10-18). Here the binding holds `["Bug", "perf"]`: "perf" was typed earlier. The Other row is an adder: it always shows `☐`, and committing a draft adds a row above it.

```wireframe 40x6
Tags
  ☑ Bug
  ☐ Feature
  ☐ Docs
❯ ☑ perf
  ☐ Other (type your own)
```

```text
Callouts (40x6, 0-based):
1. r0 c0-c3   Title row -- content, wraps.
2. r1-r3      supplied option rows -- in `options` order; "Bug" is checked.
3. r4 c0      cursor -- `❯` in `focus` on the typed row.
4. r4 c2      typed row mark -- `☑` in `accent`; a typed value is always checked while its row
              exists.
5. r4 c4-7    typed row label -- "perf", drawn through `content`; content, wraps.
6. r5 c2      Other row mark -- `☐` in `secondary`.
7. r5 c4-24   Other row label -- `customOptionLabel`; Space starts editing; content, wraps.
```

Unchecking a typed row removes its value from the binding and the row from the list. A checked supplied option unchecks and stays in place.

### Typing on the Other row

Space on the Other row starts editing. The draft follows a colon in `info` with a beam caret. Enter hands the draft to `customOption`: a non-nil value is added to the binding (never as a duplicate), editing ends, and the new row appears above the Other row. The cursor stays on the Other row, which stays unchecked, so the next value can be typed at once (owner decision, 2026-10-18). A nil result keeps the draft and editing continues.

```wireframe 40x6
Tags
  ☑ Bug
  ☐ Feature
  ☐ Docs
  ☑ perf
❯ ☐ Other (type your own): flak▏
```

```text
Callouts (40x6, 0-based):
1. r5 c0      cursor -- `❯` in `focus`; the Other row is the cursor row.
2. r5 c2      Other row mark -- `☐` in `secondary`; editing does not check it.
3. r5 c4-24   Other row label -- "Other (type your own)" in `focus`; content, wraps.
4. r5 c25-26  separator -- ": " in `secondary`.
5. r5 c27-30  draft text -- "flak" in `info`; edited by the shared text-editing core.
6. r5 c31     beam caret -- `▏` in accent; shown only while editing.
```

> Wrap exception (rule 1): the draft line stays on one row and scrolls horizontally around the caret, with no wrap and no tail mark. Wrapping would move text under the caret as the user types, as in [TextField](text-field.md). The label and committed typed rows are content and wrap (owner decision, 2026-10-18).

### Radio group

The radio group is Picker's chip row (see [Picker: radio group](picker.md#radio-group)) with toggle semantics: a checked chip is `solid(accent)`, a pill with a `contrast` bold label and pill caps; an unchecked chip is `secondary`. Left and Right move the cursor only. Space toggles the cursor chip. Enter never toggles. Chips are chrome, one row each, and the row wraps onto more rows as chips require, never clipping (owner decision, 2026-10-18). The custom row does not exist in this style. The title draws before the chips, or stacks above them when they do not fit beside it, as in [Picker's title](picker.md#title); the wireframes here show the group alone, as under `.labelsHidden()`.

```wireframe 20x2
❯ ▐sol▌  terra
   kimi  ▐fable▌
```

```text
Callouts (20x2, 0-based):
1. r0-r1 c0-c19 Radio group hit target -- each chip is one Chip hit; the group is the
            allocated frame.
2. r0 c0-c1  focus cursor -- `❯` plus a space in `focus` while focused.
3. r0 c2-c6  chip "sol" -- checked pill with caps ▐ and ▌; the cursor chip; chrome, one row.
4. r0 c8-c14 chip "terra" -- unchecked chip; secondary label with padding; chrome, one row.
5. r1 c2-c7  chip "kimi" -- unchecked chip on the wrapped row, indented under the first
            chip; chrome, one row.
6. r1 c9-c15 chip "fable" -- checked pill; chrome, one row.
```

### Floor and narrow radio group

The radio group's floor is the cursor gutter (two cells) plus the widest chip, "fable" or "terra" at five label cells plus two pill caps: `9x4` for this fixture. At 9 columns no two chips share a row, so each chip takes its own row and every chip stays whole. Below the floor a chip wider than the row tail-truncates with `truncation.mark`, as chrome.

```wireframe 9x4
❯ ▐sol▌
   terra
   kimi
  ▐fable▌
```

```text
Callouts (9x4, 0-based):
1. r0-r3 c0-c8 Radio group hit target -- four rows at the floor width.
2. r0 c0-c1  focus cursor -- `❯` plus a space in `focus` while focused.
3. r0 c2-c6  chip "sol" -- checked pill with caps ▐ and ▌; the cursor chip; chrome, one row.
4. r1 c2-c8  chip "terra" -- unchecked; a widest chip with its two padding cells, whole;
             chrome, one row.
5. r3 c2-c8  chip "fable" -- checked pill, whole; chrome, one row.
```

## State model

### Menu

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| selection | Binding | `Binding<Set<Selection>>` or `Binding<C>` | App-owned (key D1); each toggle writes it (key C6). MultiPicker writes only after a toggle (Space, a digit, or a click) or after a committed custom draft. Elements with no supplied option stay in the binding, unchanged and undrawn, except typed rows under the custom-option initializer. |
| checked count | derived | `Int` | Recomputed from `selection` and the option set on every reconciliation; feeds the host summary. |
| typed rows | derived | `[Selection]` | Custom-option initializer only. The elements of `selection` that are not in `options`, in binding order; each draws as a checked row above the Other row. Removed from the binding when unchecked; never duplicated. |
| cursor index | NodeState | `Int` | Position, not data (key D3). Keyboard position within the rows (options, typed rows, then the Other row). Starts as the open host list's cursor does, on the first chosen option or else the first option, because Picker's menu and host list share one start (key D9). Clamped to `0...(row count - 1)` on every reconciliation, including after a typed row disappears; never written to `selection`. When an accepted draft adds a typed row, the index moves with the Other row, so the cursor stays on it (owner decision, 2026-10-18). |
| editing | NodeState | `Bool` | Interaction in flight (key D7). `true` after Space or a click starts the Other row. Ends on Enter with an accepted value, or on Escape. A rejected draft (`nil`) leaves it `true`. Reset to `false` when the custom row is removed. |
| draft text | NodeState | `String` | An uncommitted draft (key D8): losing it loses unfinished input, never a committed value. Accepts typed text only while editing. Cleared when `customOption` accepts it and on Escape. |
| scroll offset | NodeState | `Int` | Rows above the viewport that no binding owns (key D4), as in [Picker's menu](picker.md#menu-scrolling-in-rows); clamped to `0...max(0, content rows - visible rows)` on every reconciliation, then reveal re-applies to the cursor row. |
| is focused | Environment | `Bool` | Gates every key; the `❯` cursor and the focus treatment draw only while focused. |

### Radio group

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| selection | Binding | `Binding<Set<Selection>>` | App-owned (key D1); each toggle writes it (key C6). MultiPicker writes only after a toggle (Space or a chip click). Elements with no supplied option stay in the set, unchanged and undrawn. |
| checked count | derived | `Int` | Recomputed from `selection` and the option set on every reconciliation. |
| cursor index | NodeState | `Int` | Position, not data (key D3). Keyboard position of the `❯` prefix while focused. Starts on 0, its reset rule (key D9); clamped on every reconciliation; never written to `selection`. |
| wrapped layout | derived | rows of chip indices | Recomputed from the final allocated width on every layout by [Flow](../primitives/flow.md) (key G6), as in [Picker's radio group](picker.md#radio-group). Never clips. |
| is focused | Environment | `Bool` | Controls the `❯` cursor prefix and the checked chips' underline, drawn only while focused. Events are checked through `ResponderContext.isFocused`. |

### Host row

| State | Owner | Type | Reset or clamp rule |
| --- | --- | --- | --- |
| open | NodeState | `Bool` | Interaction in flight (key D7). Set by Enter, Space, or a click on the closed row. Cleared without committing by Escape, focus loss, or a click outside; cleared by Enter and by a click on the row while open. Toggles already written stay. |
| cursor index | NodeState | `Int` | Position, not data (key D3). Starts on the first chosen option when opened, or on the first option when none is chosen (key D9). Clamped on every reconciliation. |
| summary | derived | `String` | The first two chosen labels joined by a comma and a space, then a space and `+N` for the rest; `none` when empty. Typed values count and are named like options. Content (owner decision, 2026-10-18): the names wrap at word boundaries under the value column rather than truncate, and `▾` follows the last word. The host decides the row count; a host that fixes one row gets a marked cut: names tail-truncate with `…`, and the `+N` count and `▾` stay. |
| is focused | Environment | `Bool` | Focus loss closes an open list. A disabled row is absent from focus and cannot open. |

The title is laid out as in [Picker's state model](picker.md#inline-cycling-row): the `title layout` and `labels hidden` rows apply to the radio group, and the menu draws no title row under `.labelsHidden()`.

## Key table

### Menu

| Key | Precondition | Effect | Consumed |
| --- | --- | --- | --- |
| Up, Down, PgUp, PgDn, Home, End | focused and is enabled and row count is positive and not editing | move the cursor as in [Picker's menu](picker.md#menu-2), including its edge clamping; PgUp and PgDn move by viewport rows; `selection` unchanged | yes |
| Space | focused and is enabled and not editing and cursor is on an option row or typed row | toggles that value's membership in `selection` via binding; the list stays open | yes |
| Space | focused and is enabled and not editing and cursor is on the custom row | starts editing; `selection` unchanged | yes |
| Enter | focused and is enabled and not editing | no handler; bubbles, so a default button can fire (owner decision, 2026-10-18) | no |
| Enter | editing | passes the draft to `customOption`: a non-nil value is added to `selection` via binding (no duplicate) and editing ends; `nil` keeps the draft and editing; an empty draft ends editing and leaves `selection` unchanged | yes |
| Esc | editing | ends editing and clears the draft; `selection` unchanged | yes |
| Esc | focused and is enabled and not editing | no handler; bubbles | no |
| Backspace, Ctrl-U, Ctrl-W, printable character | editing | edited by the shared text-editing core | yes |
| any other key | editing | no effect; swallowed so the draft is not disturbed | yes |
| 1 to 9 | focused and is enabled and not editing and row count is at least N | toggles the Nth option and moves the cursor to it; the list stays open; if the Nth row is the custom row, starts editing | yes |
| 1 to 9 | focused and is enabled and not editing and row count is below N | no handler; bubbles | no |
| Left, Right, other keys | focused and is enabled and not editing | no handler; bubbles | no |
| any key | not focused, disabled, or row count is zero | no handler; bubbles | no |

Digits 1 to 9 act on the Nth row in display order. Options past the ninth have no digit and are reached with the arrow or page keys. Digit labels are not drawn on rows, and [KeyLegend](key-legend.md) shows `1–9 choose` (owner decision, 2026-10-18). A standalone menu has nothing to close, so Enter always bubbles to the default button (key C3).

As in [Picker's menu](picker.md#menu-2), moving the cursor writes nothing and calls nothing (key C5), and paste reaches the draft only while editing (key E7).

### Radio group

| Key | Precondition | Effect | Consumed |
| --- | --- | --- | --- |
| Right | focused and is enabled and option count is positive | moves the cursor to the next option; the last wraps to the first, across rows; `selection` unchanged | yes |
| Left | focused and is enabled and option count is positive | moves the cursor to the previous option; the first wraps to the last, across rows; `selection` unchanged | yes |
| Space | focused and is enabled and option count is positive | toggles the cursor option's membership via binding | yes |
| Enter | focused and is enabled | no handler; bubbles, so a default button can fire (owner decision, 2026-10-18) | no |
| Right, Left, Space | focused and is enabled and option count is zero | no handler | no |
| Up, Down | any | no handler; bubbles | no |

Left and Right move the cursor only, so a radio group changes `selection` on an explicit Space, never by moving. An unfocused or disabled group returns Skip.

## Mouse table

`click` means a primary click. Pointer delivery uses Slice 5 hit testing. Every click that acts installs this MultiPicker's explicit focus first (owner decision, 2026-10-10). No presentation has a `move` row: MultiPicker draws no hover and requests no pointer motion, as in Picker (key F4).

### Menu

| Event | Region | Precondition | Effect | Consumed |
| --- | --- | --- | --- | --- |
| click | option row | is enabled, row count is positive, row is not the custom row, and not editing | installs focus, moves cursor to that row, then toggles it via binding; the list stays open | yes |
| click | option row | is enabled, row count is positive, row is not the custom row, and editing | ends editing and discards the draft; installs focus, moves cursor to that row, then toggles it via binding | yes |
| click | custom row | is enabled, row count is positive, and not editing | installs focus, moves cursor to the custom row, then starts editing | yes |
| click | custom row | is enabled, row count is positive, and editing | installs focus and moves cursor to the custom row; editing and the draft continue | yes |
| click | title row, below last option | always | no handler; bubbles | no |
| wheel-up, wheel-down | any | is enabled and row count is positive | moves cursor one option up or down; consumed even when already at the first or last option | yes |
| wheel-up, wheel-down | any | row count is zero | no handler; bubbles | no |
| click | any | not is enabled | leaves focus, cursor, and `selection` unchanged | no |
| other mouse | any | always | no handler; bubbles | no |

The wheel moves the cursor, as in Picker's menu (key F7).

### Radio group

| Event | Region | Precondition | Effect | Consumed |
| --- | --- | --- | --- | --- |
| click | chip `i` | is enabled and `i` is below option count | installs focus, then toggles option `i` via binding; the other chips are unchanged | yes |
| click | chip `i` | `i` is at or above option count | no handler | no |
| click | gutter, gaps, row ends | always | no handler; bubbles | no |
| click | any | not is enabled | leaves focus and `selection` unchanged | no |
| wheel-*, other mouse | any | always | no handler; bubbles | no |

## Menu in a host row

A MultiPicker `.menu` can sit inside a host row, such as a Form row. The host supplies the label column and draws the MultiPicker's title there as the row label (owner decision, 2026-10-18). The MultiPicker takes the value column after it, up to the row's right edge. Collapsed, the row shows the summary and an open marker `▾` in `secondary` ([Marks](../tokens.md#marks), `dropdown`).

The summary is content (owner decision, 2026-10-18). It keeps its form, the first two chosen names and then `+N` for the rest, but the names wrap at word boundaries under the value column rather than truncate, and `▾` follows the last word, moving to the next row like a word when the last row has no room. The host decides how many rows the summary gets: Form stacks its label above the value before the value wraps, and a host that fixes one row gets a marked cut, the names tail-truncated with `…` while the `+N` count and `▾` stay.

Enter or Space opens the option list in place, below the row, in flow rather than as a layer (key H3); it draws no title row, as the host row above is its heading. Its option rows are the menu's rows, indented four cells; they wrap in the width after the indent and scroll in rows like the standalone menu. Esc or focus loss closes the list without committing. Space toggles and keeps the list open; Enter closes it (owner decision, 2026-10-18). While the row is closed, its keys bubble to the host. The single-select counterpart is [Picker's host row](picker.md#menu-collapsed-in-a-host-row). Form links here for its multi dropdown rows.

### Closed row

```wireframe 40x1
Regions     eu, us +1 ▾
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c11  host label -- "Regions", the MultiPicker's title, drawn by the host as its
              row label; not drawn by MultiPicker.
2. r0 c12-c20 summary -- "eu, us +1": the first two chosen names, then a count of the rest;
              `info`; content, wraps.
3. r0 c22     open marker -- `▾` in `secondary`; drawn while closed and while open.
```

### Closed row, wrapped summary

A host that keeps its label column at 24 columns leaves a 12-cell value column. With the longer names `eu-west`, `us-east`, `ap-south`, and `sa-east` chosen, the summary "eu-west, us-east +2" does not fit one row, so the names wrap and `▾` follows the last word.

```wireframe 24x2
Regions     eu-west,
            us-east +2 ▾
```

```text
Callouts (24x2, 0-based):
1. r0 c0-c6   host label -- "Regions", the MultiPicker's title, drawn by the host.
2. r0 c12-c19 summary, first row -- "eu-west," in `info`; content, wraps.
3. r1 c12-c21 summary, continuation -- "us-east +2", under the value column; the count
              follows the second name; content, wraps.
4. r1 c23     open marker -- `▾` in `secondary`, one space after the last word.
```

### Open list

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
2. r0 c12-c20 summary -- "eu, us +1"; `info`; content, wraps.
3. r0 c22     open marker -- `▾` in `secondary`.
4. r1-r4 c4-c39 option rows -- indented four cells below the host row, with the menu's marks;
              content, wraps.
5. r2 c4      cursor -- `❯` in `focus` on the cursor row, drawn while focused.
6. r1-r4 c6   check marks -- `☑` in `accent` for chosen options, `☐` in `secondary` otherwise.
7. r2 c8-9    label "us" -- the cursor label, `focus` bold.
```

### Host mouse

| Event | Region | Precondition | Effect | Consumed |
| --- | --- | --- | --- | --- |
| click | host row | is enabled and closed | installs this MultiPicker's focus, then opens the list as Enter does | yes |
| click | host row | is enabled and open | installs focus and closes the list; toggles already written stay | yes |
| click | option row | is enabled and open | installs focus, moves cursor to that row, toggles it via binding; the list stays open | yes |
| click | outside the host row and list | open | closes the list, as focus loss does; the click bubbles | no |
| click | host row | not is enabled | leaves focus and the list unchanged | no |
| wheel-up, wheel-down | list | is enabled and open | moves cursor one option up or down, clamped; consumed | yes |
| wheel-up, wheel-down | host row | closed, or row count is zero | no handler; bubbles | no |
| other mouse | any | always | no handler; bubbles | no |

### Host keys

#### Closed

| Key | Precondition | Effect | Consumed |
| --- | --- | --- | --- |
| Enter, Space | focused and is enabled and closed | opens the list below the row; the cursor starts on the first chosen option, or on the first option when none is chosen | yes |
| Up, Down, Left, Right, digits, other keys | focused and is enabled and closed | no handler; bubbles | no |
| any key | not focused or disabled | no handler; bubbles | no |

#### Open list

| Key | Precondition | Effect | Consumed |
| --- | --- | --- | --- |
| Up, Down | open and is enabled | moves cursor to the previous or next option; clamps without wrapping; `selection` unchanged | yes |
| PgUp, PgDn, Home, End | open and is enabled | move cursor as the standalone menu keys do | yes |
| Space | open and not editing and cursor on an option row | toggles the cursor option's membership via binding; the list stays open | yes |
| Space | open and not editing and cursor on the custom row | starts editing | yes |
| Enter | open and not editing | closes the list; nothing is written, because each toggle is already written (owner decision, 2026-10-18) | yes |
| Enter, Esc, editing keys | open and editing | as the standalone menu's editing rows; the list stays open | yes |
| 1 to 9 | open, not editing, row count is at least N | toggles the Nth option, moves the cursor to it, and keeps the list open | yes |
| 1 to 9 | open, row count is below N | no handler; bubbles | no |
| Esc | open and not editing | closes the list; toggles already written stay | yes |
| Left, Right, other keys | open and not editing | no handler; consumed so the row's summary does not change behind the list | yes |
| Tab, Shift-Tab | open | no handler; bubbles, and the resulting focus loss closes the list | no |

## Sizing

MultiPicker's height follows its presentation: the radio group is as many rows as its wrapped chips need, and the menu is its title row plus the rows its options need. It measures its natural width and does not opportunistically grow into surplus space.

### Menu

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil | 11x5 | `Channels` fixture: four prefix cells plus "Webhook" is the width; the title row plus every option row is the height; a nil width does not wrap. |
| 40x5 | 40x5 | Natural size; check marks add no height. |
| 40x6 | 40x6 | Typed-values fixture: title row, three options, one typed row, and the Other row; the typed row adds one row. |
| 20x7 | 20x7 | Typed-values fixture: the Other row's label wraps in the 16 cells after the prefix ("Other (type your" and "own)"), so the menu is one row taller; continuation rows indent under the label. |
| 11x5 | 11x5 | The floor: four prefix cells plus the widest word, "Webhook" (re-derived under the wrap default, owner decision, 2026-10-18). |
| 10x6 | 10x6 | Below the floor "Webhook" breaks between grapheme clusters ("Webhoo" and "k"), so the menu grows by one row; nothing clips. |
| 40x3 | 40x3 | A fixed height shows the title row and two viewport rows; the option rows scroll in rows and an indicator column is reserved ([ScrollView](scroll-view.md#rows-and-variable-height-content)). |

### Radio group

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil | one row | Every chip on one row at its natural width: the cursor slot plus each chip's label width, two pill-cap cells, and one gap cell between chips; a nil width does not wrap. |
| 20x2 | 2 rows | The four-option set wraps to two rows; wrapped rows indent three cells under the first chip. |
| 14x4 | 4 rows | Each chip takes its own row when no two fit. |
| 9x4 | 4 rows | The floor: the cursor gutter plus the widest chip (five label cells and two caps). |
| 8x4 | 4 rows | Below the floor the widest chips tail-truncate with `truncation.mark`; chips are chrome, one row. |

### Collapsed host row

| Proposal | Result | Rule |
| --- | --- | --- |
| nil x nil, closed | 1 row | The host row: the title as the host's label, the collapsed summary, and `▾`. The host supplies the label column; the MultiPicker takes the value column and the width after it. A nil width does not wrap. |
| open | summary rows + option rows | The host row plus the rows the options need, drawn below the host row and indented four cells. Check marks add no height. |
| 24 x nil, closed, long names | 2 rows | The summary is content (owner decision, 2026-10-18): "eu-west, us-east +2" wraps in the 12-cell value column to "eu-west," and "us-east +2 ▾". Names wrap rather than truncate, and `▾` follows the last word, moving to the next row like a word when it has no room. The row never widens. |
| 24x1, closed, long names | 1 row | A host that fixes one row gets a marked cut: the names tail-truncate with `…`, and the `+N` count and `▾` stay, "eu-wes… +2 ▾". |

## Environment

MultiPicker consumes `isEnabled` and applies one resolved semantic Style: `primary` when enabled and unfocused, `focus` when focused, and `disabled` when disabled. `truncation.mark` defines grapheme-safe overflow of chips and marks the cut of a summary under a fixed one-row host; its ASCII substitution is in [Degradation](#degradation). `lineLimit` and `truncationMode` flow through the environment to the title, option labels, descriptions, and the collapsed summary (content); the marks and chips pin their own single-row values (owner decision, 2026-10-18). `labelsHidden` (environment, set by `.labelsHidden()`) hides the drawn title. Sub-element roles:

- `primary` -- labels and unchecked option text.
- `secondary` -- the title drawn before the radio group, as in Picker.
- `focus` -- the focused cursor glyph and label, and the checked chip underline.
- `accent` -- the check mark `☑` (the same selection-mark colour as Toggle and Form) and the checked chip's `solid(accent)` fill.
- `secondary` -- unchecked chips, the unchecked mark `☐`, the Other row's separator, and each option description.
- `disabled` -- every visible cell of a disabled MultiPicker.
- `contrast` -- the label on a checked chip.
- `info` -- the typed draft and the host summary.

## Primitive dependencies

- [`Text`](../primitives/text.md) -- ready; renders labels, wraps content, and provides grapheme-safe tail truncation for chrome.
- [`Picker`](picker.md) -- the menu, radio group, descriptions, and scrolling rules this doc reuses.
- [`ScrollView`](scroll-view.md) -- supplies the row-based scrolling contract.
- [`Button`](button.md) -- the checked chip uses the filled emphasis and the capped ends of the button's [shapes](button.md#shape).
- [`List`](list.md) -- supplies the row chrome for the menu's option list.
- [`Style modifiers`](../primitives/style-modifiers.md) -- ready; resolve and apply the inherited complete semantic Styles.
- [Focus manager and responder context](../../spec/phase-4/slice-04-focus-and-key-routing.md) -- supplies app-installed `FocusID` routing and focusable-list participation.
- [Mouse hit testing](../../spec/phase-4/slice-05-mouse-and-hit-testing.md) -- supplies chip and row hit testing and click-to-focus ordering.
- [`ViewThatFits`](../primitives/view-that-fits.md) -- chooses the radio group's title layout and the menu's description layout, as in Picker (key G10).
- [Flow](../primitives/flow.md) -- wraps the radio group's chips onto more rows (key G6).

## Requirements

Title and style:

- `multipicker title and label initializers name the multipicker and set its accessible name` (API direction).
- `multipicker menu draws its title as the title row and none under labelsHidden` (state: anatomy; API direction).
- `multipicker radio group draws its title before the chips or stacks it above them` (state: radio group; Picker state: title).
- `multipicker default style is menu` (API direction).

Menu:

- `multipicker menu draws a check mark on every chosen option` (state: anatomy).
- `multipicker menu draws no digit labels on rows` (state: anatomy).
- `multipicker menu draws bracketed marks under ASCII-only` (state: menu, ASCII; degradation).
- `multipicker menu wraps a long option label and indents continuation rows under the label` (sizing: 20x7).
- `multipicker menu floor is the prefix plus the widest label word` (state: minimum; sizing: 11x5).
- `multipicker menu lineLimit one tail-truncates an option label` (environment).
- `multipicker plain initializer keeps set elements without a supplied option in the binding` (state model: menu selection).

Custom option:

- `multipicker draws no Other row without a customOption closure` (API direction).
- `multipicker typed values draw as checked rows above Other in binding order` (state: typed values above the Other row).
- `multipicker radio group draws no Other row` (API direction).

Radio group:

- `multipicker radio group wraps chips onto more rows and indents under the first chip` (state: radio group).
- `multipicker radio group floor is the gutter plus the widest chip` (state: floor and narrow radio group; sizing: 9x4).

Menu in a host row:

- `multipicker host row shows the summary with an open marker` (state: closed row).
- `multipicker host row summary shows the first two chosen names and a count` (state model: summary).
- `multipicker host row summary wraps its names under the value column and keeps the count` (state: closed row, wrapped summary; sizing: collapsed host row 24 x nil).
- `multipicker host row summary under a fixed one-row host truncates names before the count` (state model: summary; sizing: collapsed host row 24x1).
- `multipicker host row empty set summary reads none` (state model: summary).

### Focus

Menu:

- `multipicker menu Space toggles the cursor option and keeps the list open` (key table: menu Space).
- `multipicker menu Enter bubbles in place` (key table: menu Enter, not editing).
- `multipicker menu Enter never toggles the cursor option` (key table: menu Enter).
- `multipicker menu digit key toggles the Nth option and keeps the list open` (key table: menu digits).
- `multipicker menu digit beyond the row count bubbles` (key table: menu digits).
- `multipicker menu paste reaches the draft only while editing` (key table: menu, paste)

Custom option:

- `multipicker custom draft Enter adds the accepted value to the binding` (key table: menu Enter, editing).
- `multipicker custom draft rejected by customOption keeps editing` (key table: menu Enter, editing).
- `multipicker never inserts a duplicate typed value` (key table: menu Enter, editing).
- `multipicker unchecking a typed value removes it from the binding and its row` (state: typed values above the Other row; state model: typed rows).
- `multipicker draft line stays one row and scrolls around the caret` (state: typing on the Other row; wrap exception).
- `multipicker cursor stays on the unchecked Other row after an accepted draft` (state: typing on the Other row; state model: cursor index).

Radio group:

- `multipicker radio group Space toggles the cursor chip` (key table: radio Space).
- `multipicker radio group Enter bubbles` (key table: radio Enter).
- `multipicker radio group Left and Right move the cursor and wrap across rows` (key table: radio Left and Right).
- `multipicker radio group leaves Up and Down unconsumed` (key table: radio Up and Down).

Menu in a host row:

- `multipicker host row draws the title as the host's row label and no title row in the open list` (state: closed row; menu in a host row).
- `multipicker host row Enter and Space open the list below the row` (host keys: closed).
- `multipicker host row Space toggles and keeps the list open` (host keys: open list).
- `multipicker host row Enter closes the list without writing` (host keys: open list).
- `multipicker host row Escape closes the list and toggles already written stay` (host keys: open list).
- `multipicker host row focus loss closes the list` (state model: open).
- `multipicker host row digit key toggles the Nth option and keeps the list open` (host keys: open list).

- `multipicker menu up, down, home and end move the cursor with edge clamping and leave the selection unchanged` (key table: menu)
- `multipicker empty draft Enter ends editing and escape clears the draft` (key table: menu Enter, editing; menu Esc)
- `multipicker menu escape outside editing bubbles` (key table: menu Esc)
- `multipicker draft editing keys edit the draft and swallow all other keys` (key table: editing rows)
- `multipicker menu digit on the Other row moves the cursor and starts editing` (key table: menu digits)
- `multipicker left, right and unlisted keys bubble and an unfocused, disabled or empty group leaves keys unconsumed` (key table: menu; radio)
- `multipicker radio group with no options installs no handler` (key table: radio)
- `multipicker closed host row bubbles keys other than enter and space` (host keys: closed)
- `multipicker open host row clamps up and down, consumes left, right and unlisted keys, and bubbles tab and shift-tab` (host keys: open list)
- `disabled multipicker host row is absent from focus and cannot open` (state model: open; host keys)
- `multipicker draws its cursor and underlines checked chips only while focused` (state model: is focused)

### Pointer

Menu:

- `multipicker menu click toggles the option and keeps the list open` (mouse table: menu option row).
- `multipicker menu wheel moves the cursor and is consumed at list edges` (mouse table: menu wheel).
- `multipicker draws no hover and requests no pointer motion` (mouse table: no move row)

Custom option:

- `multipicker Other row starts editing on Space and a click` (key table: menu Space on the custom row; mouse table: custom row).

Radio group:

- `multipicker radio group click toggles the chip` (mouse table: radio chip `i`).

- `a multipicker click that acts installs the multipicker's focus first` (mouse table; host mouse)
- `multipicker menu click while editing ends editing and discards the draft before it toggles` (mouse table: menu option row)
- `multipicker menu click on the title row or below the last option bubbles` (mouse table: menu)
- `multipicker menu wheel with zero options bubbles` (mouse table: menu wheel)
- `multipicker radio group clicks outside chips, wheel and other mouse input bubble` (mouse table: radio)
- `disabled multipicker click leaves everything unchanged and unconsumed` (mouse table: disabled)
- `multipicker host row click opens a closed list and closes an open one` (host mouse)
- `multipicker host row click on an option row moves the cursor and toggles with the list staying open` (host mouse)
- `multipicker host row click outside closes the list without committing and bubbles` (host mouse)
- `multipicker host row wheel in an open list clamps at the edges and is consumed` (host mouse)

### Scroll

Menu:

- `multipicker menu scrolls in rows under a fixed height` (sizing: 40x3; state model: scroll offset).

- `multipicker menu page up and page down move the cursor by viewport rows` (key table: menu PgUp and PgDn)
- `multipicker menu scroll offset clamps to zero through the last content row` (state model: scroll offset)
- `multipicker menu reveal re-applies to the cursor row by the fewest rows` (state model: scroll offset)
- `multipicker option taller than the viewport aligns its first row with the top` (state model: scroll offset)
- `multipicker title row stays outside the scrolling region` (state model: scroll offset; Menu)

## Degradation

MultiPicker follows the [degradation ladder](../tokens.md#degradation-ladder). In `NO_COLOR`, semantic Styles reduce to their attributes; the checked and unchecked marks differ by glyph (`☑` against `☐`), not by colour, so the selection reads without colour (owner decision, 2026-10-11). In 16-color, `accent` follows its slots column in [roles](../tokens.md#roles). `truncation.mark` becomes `~` at the ASCII-only rung.

Per presentation:

- Menu: at the ASCII-only rung the check marks `☑` and `☐` become `[x]` and `[ ]`, the ASCII forms of Toggle's checkbox. Both are three cells, so the option label is measured within the remaining width (owner decision, 2026-10-11). The cursor `❯` becomes `>`, and the beam caret `▏` becomes `|`.
- Radio group: chips keep their pill caps and show no check mark. At the ASCII-only rung the cursor prefix becomes `>` plus a space, and the pill caps become `.rectangle` caps, as in [Picker's radio group](picker.md#radio-group). Chip width is unchanged, so the wrap rule measures the same width at every rung.
- Option descriptions: plain text after the label at every rung; `NO_COLOR` removes only the colour of `secondary`, which stays dim.
- Collapsed host row: the open marker `▾` becomes `v`. Under a fixed one-row host the cut keeps the `+N` suffix at every rung (owner decision, 2026-10-11), and its mark becomes `~`.

Below the floor a menu grapheme-breaks words, grows in height, and keeps its chrome; a fixed height cuts with `…` on the last visible row only when the app sets a `lineLimit`, otherwise it scrolls. This is layout degradation only: it never manufactures a selection or writes the binding.

## Open questions

- **Deferred:** per-option disabled state, as in Picker, to [Slice 7](../../spec/phase-4/slice-07-catalog-integration.md).

Reviewed against the [Phase 4 theses](../../spec/phase-4.md): a MultiPicker is a value whose title, options, and row closure are configuration; the chosen set is the app's binding, written once per toggle or committed draft; its retained state is the cursor, editing, draft, scroll, and open NodeState of its own node, each with a reset rule, while its layouts are derived; and its pointer needs reach the session as `TerminalRequirements`, never as mode changes.

## Inspiration

A MultiPicker should make the set of chosen values legible at a glance and make every toggle an explicit act, so a default button can always claim Enter.
