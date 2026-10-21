---
kind: widget
status: ready
---

# Form

`Form` is Tessera's column of labelled fields. Each row has a label, a cursor glyph on the
focused row, and a value in a shared value column. Field kinds are bool, enum, text,
select, multi, and number. The label column is as wide as the widest label plus two cells,
so every value starts in the same column. Enum and number values edit in place. Select
fields are Picker's menu and multi fields are MultiPicker's menu, each collapsed in its
row. Open, its option rows sit below the row (see
[Picker](picker.md#menu-collapsed-in-a-host-row)). The view keeps its cursor, scroll
offset, open dropdown and text editing state; the app owns the field values through
bindings, as in every Tessera controlled widget. The focused row's cursor and bold label
follow [Focus border](../primitives/border.md#focus-border), rule 3.

Labels and values are content: they wrap and are never cut without a mark (see
[Wrap and truncation](../README.md#wrap-and-truncation)). Row labels are plain `Text`, not
[Label](../primitives/label.md), so Label's one-row title rule does not reach them. The
cursor, the dropdown glyph and the number arrows are chrome and stay on one row. A value
that does not fit beside its label triggers the stacked layout before it wraps; stacked, a
value wraps at the width after its four-cell indent, and a label never truncates (owner
decision, 2026-10-18). A collapsed select or multi value is content too: it wraps under
the value column with `▾` ([Marks](../tokens.md#marks), `dropdown`) one space after its
last word (owner decision, 2026-10-18).

Owner decision, omp2 review, 2026-10: adopt as-is. The aligned label column and inline
dropdowns are accepted. The number field is the reference for [Stepper](stepper.md). The
validation message is painted inline after the value and wraps under the value when it
does not fit; see [Validation](#validation-inline-message) (owner decisions, 2026-10-10
and 2026-10-18).

The wireframes below are the accepted Tessera states, drawn from omp2's rendering with its
theme roles renamed to Tessera roles. This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-and-controlled-widgets),
takes its focus and key delivery from
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system), and its
pointer delivery from [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Prior art

- omp2 `Form`,
  [`form.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L1-L998).
  Copy the label column sized to the widest label, the cursor glyph and bold focus label
  on the focused row, inline enum and number values, the dropdown rows indented under
  their field, and the number field's `◂ 4 ▸` presentation. Sources:
  [`measure`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L364-L373),
  [`height`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L374-L381),
  [`paint`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L382-L575),
  [`key`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L590-L694),
  [`mouse`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L696-L731),
  [`validation_error`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L750-L766),
  [`paint_field_value`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L856-L935),
  with the number field at
  [L910-L922](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L910-L922).
  Reject four things. omp2 keeps field data inside the Form and harvests it by id
  ([`value`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L767-L776));
  Tessera binds each field to app state (keys A10 and D1). omp2 draws the number arrows
  only on the focused row; Tessera follows [Stepper](stepper.md) and shows them on every
  number row, focused or not (owner decision, 2026-10-10). omp2 never paints the
  validation message it computes; its
  [Wizard](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/wizard.rs#L258-L266)
  paints one on the row below its field. Form takes the inline placement instead (see
  [Validation](#validation-inline-message)). omp2's `measure` reports the widest label
  plus 24 cells; Tessera reports its widest side-by-side row instead, as Text reports its
  widest line and List its widest row (see [Sizing](#sizing)). The
  [translation key](../translation-key.md) settles three more points. Copy omp2's row
  hover, which it reads from the graph at paint rather than storing
  ([L415-L425](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L415-L425)),
  as key F4 sets. Reject its scrollbar jump on click and drag
  ([L270-L288](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L270-L288),
  [L709-L714](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L709-L714)):
  indicators are output-only (key F2). Reject its direction-aware focus entry, which puts
  the cursor on the first or last row
  ([`enter`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L581-L588)):
  the cursor keeps its row (key D9).
- SwiftUI [`Form`](https://developer.apple.com/documentation/swiftui/form) supplies the
  vocabulary: a column of controls with labels, and `LabeledContent` for label-value rows.
  Reject its platform-drawn cells; the terminal rows are drawn by the view.

Form's other key rows: a control's title is its row label (key B11); a select or multi row
opens Picker's menu in flow below the row, never in a layer (key H3); the `❯` cursor and
the `▾` dropdown glyph are Marks tokens (key K3); the focused row draws in the `focus`
role (key E2); the scrollbar is the `standard` indicator preset (key K8); colours are
roles (key J1); paste reaches the focused Form like a key (key E7); and the Key and Mouse
tables list every event it consumes, by hit region (keys E3 and F1).

## API direction

Swift in SwiftUI vocabulary, in the [translation key](../translation-key.md)'s forms. The
fields are child controls in a `@ViewBuilder` (keys A4 and A7), and each control's own
app-owned binding holds its value (key D1). The bindings are app-supplied values named
without a dollar-sign prefix; Tessera has no property-wrapper state. The bool row is a
`Toggle` that draws the `.text` style inside a Form, so it paints the captured text `true`
or `false` (see [Toggle](toggle.md#text-style)). Multi-select has no SwiftUI `Form` or
`Picker` control. Tessera adds `MultiPicker`, a sibling of Picker that takes a
`Binding<Set<Value>>`, mirroring Table's `Binding<Set<ID>>` (a Tessera addition, owner
decision, 2026-10-10; a separate type, owner decision, 2026-10-18). Its default style is
`.multiPickerStyle(.menu)` (owner decision, 2026-10-18). The multi row is that MultiPicker
in its `.menu` style, collapsed in its row (see
[MultiPicker](multi-picker.md#menu-in-a-host-row)); it is not a separate control.

```swift
public struct Form<Content: View>: View {
    public init(@ViewBuilder content: () -> Content)
}
```

```swift
// strict, region, name, slug, theme, replicas, and scopes are bindings from the app's model.
Form {
    Toggle("Strict", isOn: strict)
    Picker("Region", selection: region) { /* eu, ap */ }
    TextField("Name", text: name)
        .required("Enter a name")
    TextField("Slug", text: slug)
        .pattern("[a-z0-9-]+", message: "Use a-z, 0-9, and -")
    Picker("Theme", selection: theme) { /* dark, light, nord */ }
    MultiPicker("Scopes", selection: scopes) { /* Binding<Set<Scope>>: repo, issues, actions */ }
    Stepper("Replicas", value: replicas, in: 1...8)
}
```

`.required(_:)` and `.pattern(_:message:)` are sketch names for the validation rules (key
M1). The app supplies the wording; when the message is omitted, the Form builds it from
the field label (see Validation). The Replicas row is a native number field, so the Form
lays it out in the shared column; a `LabeledContent` does not join that column (see
Primitive dependencies).

The Form is one focus stop: it joins the focus ring through `.focusable(_:)` with an
explicit `FocusID` (keys B10 and E1), and its cursor, which is NodeState, moves between
the rows (key D3).

Each control's title is its row label. The Form draws `Strict`, `Region`, `Scopes` and the
other titles in its label column, and each control draws only its value in the value
column; the title stays the control's accessible name. Picker and MultiPicker take a title
as SwiftUI's Picker does (owner decision, 2026-10-18), so the enum row's inline Picker
draws no title before its cycling value, and the open list of a select or multi row draws
no heading row: the row above it shows the title.

## Anatomy

Natural fixture: six fields, the first focused so the cursor is drawn on its row, with one
bool, one enum, one text, one select, one multi and one number. The fixture is 40 columns
wide, the mobile width. The 80-column capture is identical row for row and style for
style.

```wireframe 40x6
❯ Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
```

```text
Callouts (40x6, 0-based):
1. r0 c0-1    Cursor -- the `❯` glyph in `focus` on the focused row while the Form is
              focused (`>` in ASCII); chrome, one row. Two spaces on the other rows and whenever the Form is not focused.
2. r0 c2-7    Label "Strict" -- `primary`; `focus` bold on the cursor row only; content, wraps, never truncates.
3. r0-r5 c2-11  Label column -- each label is padded to the widest label plus two cells, so
              every value starts at column 12 for this fixture.
4. r0 c12-15  Bool value "true" -- `success` when true, `secondary` when false; content, wraps. The Toggle
              `.text` style draws it.
5. r1 c12-13  Enum value "eu" -- `info`; content, wraps. Arrows appear only on the focused row (see Focused); arrows are chrome, one row.
6. r2 c12-14  Text value "omp" -- `primary`; content, wraps. A masked field paints the `secret` icon instead, in `secondary` (owner decision, 2026-10-19; [icon catalog](../tokens.md#icon-catalog)): Nerd Font U+F023, no icon under `.unicode`, `[**]` in ASCII.
7. r3 c12-15  Select value "dark" -- `info`; content, wraps under the value column, with `▾` (`dropdown`, [Marks](../tokens.md#marks)) in `secondary` one space after its last word (owner decision, 2026-10-18); the glyph is chrome, one cell. Opens a dropdown below the row.
8. r4 c12-15  Multi value "repo" -- `info`: MultiPicker's summary, the first two checked labels joined by a comma and a space, then ` +N` for the rest. Content, wraps under the value column: the names wrap rather than truncate, the `+N` form is kept, and `▾` in `secondary` follows the last word (owner decision, 2026-10-18). With no values checked, it reads `none` in `info`.
9. r5 c12-16  Number value "3" -- `primary` at c14, between a decrement arrow `◂` at c12 and an increment arrow `▸` at c16, both `secondary`; chrome, one row. The number is atomic: it never wraps (see Stepper). The arrows show on every number row, focused or not, as Stepper does (owner decision, 2026-10-10).
10. scrollbar -- the rightmost column, reserved and drawn only when the rows overflow the
    window's height (see [ScrollView](scroll-view.md#cross-axis-proposal)). Not in this fixture; see Overflow: 40x4. Output-only: it takes no clicks or drags (key F2).
11. row -- each field row, r0-r5 c0-39. A click sets the cursor to the row and activates it as Enter does.
12. window -- the viewport, r0-r5 c0-39. The wheel scrolls it without moving the cursor.
```

```text
── chars ──
❯ Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
── style ──
AABBBBBB....DDDD
..CCCCCC....EE
..CCCC......CCC
..CCCCC.....EEEE.F
..CCCCCC....EEEE.F
..CCCCCCCC..F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
```

## States

### Unfocused

Unfocused, the Form draws no cursor and no bold label. Labels are `primary`, and every
value keeps its presentation: the bool in `success`, text, enum, select and multi values
in `info`, and the number in `primary` with secondary arrows.

```wireframe 40x6
  Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
```

```text
Callouts (40x6, 0-based):
1. r0-r5 c0-1  No cursor -- two spaces in the gutter; no `focus` glyph.
2. r0-r5 c2-11 Labels -- `primary`, not bold.
3. r0 c12-15   Value "true" -- `success`.
4. r1 c12-13, r3 c12-15, r4 c12-15 Values "eu", "dark", "repo" -- `info`; `▾` in `secondary`.
5. r5 c12-16   Number "3" -- `primary`, between `secondary` arrows.
```

```text
── chars ──
  Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
── style ──
..CCCCCC....DDDD
..CCCCCC....EE
..CCCC......CCC
..CCCCC.....EEEE.F
..CCCCCC....EEEE.F
..CCCCCCCC..F.C.F
── legend ──
.  default
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
```

### Focused: the enum field

Region is focused and its value is `eu`. The value sits between secondary arrows, `◂` and
`▸`, so the row shows that it cycles: Left and Right step to the previous and next choice,
and Enter or Space cycle forward (see the Key table). The arrows show on the focused enum
row only (inferred; the number-row rule covers numbers, owner decision, 2026-10-10). The
label is `focus` bold, and the cursor takes the gutter.

```wireframe 40x6
  Strict    true
❯ Region    ◂ eu ▸
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
```

```text
Callouts (40x6, 0-based):
1. r1 c0      Cursor -- `❯` in `focus` on the focused row.
2. r1 c2-7    Label "Region" -- `focus` bold.
3. r1 c12     Decrement arrow `◂` -- `secondary`.
4. r1 c14-15  Value "eu" -- `info`.
5. r1 c17     Increment arrow `▸` -- `secondary`.
```

```text
── chars ──
  Strict    true
❯ Region    ◂ eu ▸
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
── style ──
..CCCCCC....DDDD
A.BBBBBB....F.EE.F
..CCCC......CCC
..CCCCC.....EEEE.F
..CCCCCC....EEEE.F
..CCCCCCCC..F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
```

### Focused: the number field

The fixture's keys moved the cursor to Region and cycled it from `eu` to `ap`, then moved
it to Replicas and stepped the number from 3 to 4. Replicas is now focused. Its label
turns bold focus, and the number shows `◂ 4 ▸`, as it does unfocused: a secondary
decrement arrow, one separator space, the value in `primary`, one separator space, and a
secondary increment arrow. The arrows are the [Stepper](stepper.md) presentation and show
on every number row, focused or not (owner decision, 2026-10-10). The other rows show
their unfocused presentation.

```wireframe 40x6
  Strict    true
  Region    ap
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
❯ Replicas  ◂ 4 ▸
```

```text
Callouts (40x6, 0-based):
1. r5 c0-1    Cursor -- `focus`, the focused row.
2. r5 c2-9    Label "Replicas" -- `focus` bold.
3. r5 c12     Decrement arrow `◂` -- `secondary`.
4. r5 c14     Value "4" -- `primary`.
5. r5 c16     Increment arrow `▸` -- `secondary`.
```

```text
── chars ──
  Strict    true
  Region    ap
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
❯ Replicas  ◂ 4 ▸
── style ──
AABBBBBBBBBBCCCC
AABBBBBBBBBBDD
AABBBBBBBBBBBBB
AABBBBBBBBBBDDDDEE
AABBBBBBBBBBDDDDEE
AAFFFFFFFFBBEEBEE
── legend ──
.  default
A  fg=focus
B  fg=primary
C  fg=success
D  fg=info
E  fg=secondary
F  fg=focus bold
```

### Focused, ASCII

ASCII has no cursor glyph or arrows. The cursor is `>`, the number arrows are `<` and `>`,
and the dropdown glyph is `v`. The layout and the label column are unchanged.

```wireframe 40x6
  Strict    true
  Region    ap
  Name      omp
  Theme     dark v
  Scopes    repo v
> Replicas  < 4 >
```

```text
Callouts (40x6, 0-based):
1. r5 c0      Cursor -- `>` in `focus`.
2. r5 c12     Decrement arrow `<` -- `secondary`.
3. r5 c16     Increment arrow `>` -- `secondary`.
4. r3 c17, r4 c17  Dropdown glyph -- `v` in `secondary`.
```

```text
── chars ──
  Strict    true
  Region    ap
  Name      omp
  Theme     dark v
  Scopes    repo v
> Replicas  < 4 >
── style ──
AABBBBBBBBBBCCCC
AABBBBBBBBBBDD
AABBBBBBBBBBBBB
AABBBBBBBBBBDDDDEE
AABBBBBBBBBBDDDDEE
AAFFFFFFFFBBEEBEE
── legend ──
.  default
A  fg=focus
B  fg=primary
C  fg=success
D  fg=info
E  fg=secondary
F  fg=focus bold
```

### Select dropdown open

Enter on the Theme row opens Picker's menu below the row (see
[Picker](picker.md#menu-collapsed-in-a-host-row)); Picker owns the keys and mouse rules
while it is open. The sub-cursor starts on the current choice (`dark`), drawn as a `focus`
`❯` on a radio mark. The picked choice shows `◉` in `accent`; the others show `○` in
`secondary`. The sub-rows are indented four cells, and the rows below the dropdown move
down by one row per choice.

```wireframe 40x9
  Strict    true
  Region    eu
  Name      omp
❯ Theme     dark ▾
    ❯ ◉ dark
      ○ light
      ○ nord
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
```

```text
Callouts (40x9, 0-based):
1. r3 c0-1    Cursor -- the Theme row is focused.
2. r3 c2-7    Label "Theme" -- `focus` bold.
3. r3 c12-15  Select value "dark" -- `info`, then `▾` in `secondary`, while the dropdown is open.
4. r4-r6 c4-5 Sub-cursor `❯` -- `focus` on the highlighted choice only.
5. r4 c6      Picked radio `◉` -- `accent`.
6. r5-r6 c6   Unpicked radio `○` -- `secondary`.
7. r4 c8-11   Highlighted choice "dark" -- `focus` bold. The other choices are `primary`.
8. r7-r8      Rows below the dropdown -- unchanged; the Form grows by three sub-rows.
```

```text
── chars ──
  Strict    true
  Region    eu
  Name      omp
❯ Theme     dark ▾
    ❯ ◉ dark
      ○ light
      ○ nord
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
── style ──
..BBBBBB....CCCC
..BBBBBB....DD
..BBBB......BBB
AAEEEEE.....DDDD.F
....AAG.EEEE
......F.BBBBB
......F.BBBB
..BBBBBB....DDDD.F
..BBBBBBBB..F.B.F
── legend ──
.  default
A  fg=focus
B  fg=primary
C  fg=success
D  fg=info
E  fg=focus bold
F  fg=secondary
G  fg=accent
```

### Select dropdown open, ASCII

ASCII marks the choices `(*)` and `( )`, the sub-cursor `>`, and the dropdown glyph `v`
(see [Degradation](#degradation)). The layout is unchanged.

```wireframe 40x9
  Strict    true
  Region    eu
  Name      omp
> Theme     dark v
    > (*) dark
      ( ) light
      ( ) nord
  Scopes    repo v
  Replicas  < 3 >
```

```text
Callouts (40x9, 0-based):
1. r3 c0      Cursor -- `>` in `focus`, on the Theme row.
2. r3 c2-6    Label "Theme" -- `focus` bold.
3. r3 c12-15  Select value "dark" -- `info`; `v` in `secondary` at c17 while open.
4. r4-r6 c4   Sub-cursor `>` -- `focus` on the highlighted choice only.
5. r4 c6-8    Picked choice `(*)` -- `accent`.
6. r5-r6 c6-8 Unpicked choices `( )` -- `secondary`.
7. r4 c10-13  Highlighted choice "dark" -- `focus` bold.
```

```text
── chars ──
  Strict    true
  Region    eu
  Name      omp
> Theme     dark v
    > (*) dark
      ( ) light
      ( ) nord
  Scopes    repo v
  Replicas  < 3 >
── style ──
..CCCCCC....DDDD
..CCCCCC....EE
..CCCC......CCC
A.BBBBB.....EEEE.F
....A.GGG.BBBB
......FFF.CCCCC
......FFF.CCCC
..CCCCCC....EEEE.F
..CCCCCCCC..F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
G  fg=accent
```

### Multi dropdown open

Enter on the Scopes row opens MultiPicker's menu below the row (see
[MultiPicker](multi-picker.md#menu-in-a-host-row)). Checked choices show `☑` in `accent`;
unchecked show `☐` in `secondary`. The sub-cursor is on Issues, which is checked, so its
label is `focus` bold. Space toggles the highlighted choice and the list stays open; Enter
closes it. Clicking a choice toggles it and keeps the list open. The row summary is
MultiPicker's: the first two checked names joined by a comma and a space, then a space and
`+N` for the names past the first two. Here all three are checked, so the summary reads
`repo, issues +1`. With nothing checked it reads `none` in `info`.

```wireframe 40x9
  Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
❯ Scopes    repo, issues +1 ▾
      ☑ repo
    ❯ ☑ issues
      ☑ actions
  Replicas  ◂ 3 ▸
```

```text
Callouts (40x9, 0-based):
1. r4 c0      Cursor -- the Scopes row is focused.
2. r4 c2-7    Label "Scopes" -- `focus` bold.
3. r4 c12-26  Multi summary "repo, issues +1" -- `info`; `▾` in `secondary` at c28.
4. r5-r7 c6   Checked boxes `☑` -- `accent`.
5. r5 c8-11, r7 c8-14 Unhighlighted choices "repo", "actions" -- `primary`.
6. r6 c4      Sub-cursor `❯` -- `focus` on the highlighted choice only.
7. r6 c8-13   Highlighted choice "issues" -- `focus` bold.
```

```text
── chars ──
  Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
❯ Scopes    repo, issues +1 ▾
      ☑ repo
    ❯ ☑ issues
      ☑ actions
  Replicas  ◂ 3 ▸
── style ──
..CCCCCC....DDDD
..CCCCCC....EE
..CCCC......CCC
..CCCCC.....EEEE.F
A.BBBBBB....EEEEEEEEEEEEEEE.F
......G.CCCC
....A.G.BBBBBB
......G.CCCCCCC
..CCCCCCCC..F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
G  fg=accent
```

### Multi dropdown open, ASCII

ASCII marks the checkboxes `[x]` and `[ ]` and the cursor `>`, and the dropdown glyph is
`v` (see [Degradation](#degradation)). The summary keeps MultiPicker's format; with two
checked names it has no `+N`, because `+N` counts only the names past the first two (see
[MultiPicker](multi-picker.md#menu-in-a-host-row)).

```wireframe 40x9
  Strict    true
  Region    eu
  Name      omp
  Theme     dark v
> Scopes    repo, issues v
      [x] repo
    > [x] issues
      [ ] actions
  Replicas  < 3 >
```

```text
Callouts (40x9, 0-based):
1. r4 c0      Cursor -- `>` in `focus` on the Scopes row, the focused row.
2. r4 c2-7    Label "Scopes" -- `focus` bold.
3. r4 c12-23  Multi summary "repo, issues" -- `info`; `v` in `secondary` at c25.
4. r5 c6-8    Checked box `[x]` -- `accent`; r7 c6-8 `[ ]` -- `secondary`.
5. r6 c4      Sub-cursor `>` -- `focus` on the highlighted choice only.
6. r6 c10-15  Highlighted choice "issues" -- `focus` bold.
7. r5, r7 c10+ Unhighlighted choices -- `primary`.
```

```text
── chars ──
  Strict    true
  Region    eu
  Name      omp
  Theme     dark v
> Scopes    repo, issues v
      [x] repo
    > [x] issues
      [ ] actions
  Replicas  < 3 >
── style ──
..CCCCCC....DDDD
..CCCCCC....EE
..CCCC......CCC
..CCCCC.....EEEE.F
A.BBBBBB....EEEEEEEEEEEE.F
......GGG.CCCC
....A.GGG.BBBBBB
......FFF.CCCCCCC
..CCCCCCCC..F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
G  fg=accent
```

### Validation: inline message

The Name field is blank and required; the cursor is on it. The Slug field holds
`Bad Slug`, which fails its pattern. A failing field paints its label in `error` and draws
the error icon `✘` in the gutter. The app supplies the wording:
`.required("Enter a name")` and `.pattern(_, message: "Use a-z, 0-9, and -")`. The first
failing message, required before pattern, paints after the value, two cells past it, or at
the value column when the value is blank. The message is content and wraps (owner
decision, 2026-10-18): it starts on the field's row, and when it does not fit, its
continuation rows sit under the value, indented to the value column. The field grows
taller while the message is shown; nothing is cut off. The focused failing row keeps the
cursor in the gutter, so it draws no icon; its label is bold `error` instead.

When the app omits a message, the Form builds one from the label: `<Label> is required` or
`<Label> is invalid` (owner decision, 2026-10-18). An app-supplied message always wins.
The default is English text and 1.0 has no localisation, because Tessera's other built-in
UI strings are English too (owner decision, 2026-10-18); an app that needs another
language passes its own message for each rule.

**Placement: inline (owner decision, 2026-10-10).** The validation message is painted
inline after the value, never on a row of its own: it starts on the field's row. A
below-row placement, which the Wizard uses, would add a row under every failing field even
when the message fits, so it is not drawn. Inline adds rows only when the message does not
fit after the value, and then as continuation rows under the value (owner decision,
2026-10-18). At 24 columns the first row holds `Use` after the value and the rest wraps
under the value (see the 24-column state).

```wireframe 40x2
❯ Name  Enter a name
✘ Slug  Bad Slug  Use a-z, 0-9, and -
```

```text
Callouts (40x2, 0-based):
1. r0 c0-1    Cursor -- `focus` on the focused row. The cursor takes the gutter, so no icon.
2. r0 c2-5    Label "Name" -- `error`, bold: focused and failing.
3. r0 c8-19   Message "Enter a name" -- `error`, at the value column because the value is blank.
4. r1 c0      Error icon `✘` -- `error`, in the gutter of an unfocused failing row.
5. r1 c2-5    Label "Slug" -- `error`.
6. r1 c8-15   Value "Bad Slug" -- `primary`. The message never truncates the value.
7. r1 c16-17  Gap -- two default cells between the value and the message.
8. r1 c18-36  Message "Use a-z, 0-9, and -" -- `error`; content, wraps (it fits on the row here).
```

```text
── chars ──
❯ Name  Enter a name
✘ Slug  Bad Slug  Use a-z, 0-9, and -
── style ──
A.IIII..HHHHHHHHHHHH
H.HHHH..CCCCCCCC..HHHHHHHHHHHHHHHHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error
I  fg=error bold
```

### Validation: inline message, 24 columns

The same two fields at 24 columns, side by side. The message starts after the value and
the gap; only `Use` fits there, so the rest wraps under the value, indented to the value
column (owner decision, 2026-10-18). The Slug field is two rows while the message shows.
The value is never truncated.

```wireframe 24x3
❯ Name  Enter a name
✘ Slug  Bad Slug  Use
        a-z, 0-9, and -
```

```text
Callouts (24x3, 0-based):
1. r0 c0-1    Cursor -- `focus` on the focused row.
2. r0 c8-19   Message "Enter a name" -- `error`, at the value column because the value is blank; it fits on the row.
3. r1 c0      Error icon `✘` -- `error`.
4. r1 c8-15   Value "Bad Slug" -- `primary`, whole.
5. r1 c18-20  Message first row "Use" -- `error`; the only word that fits after the value and the gap.
6. r2 c8-22   Message continuation "a-z, 0-9, and -" -- `error`; under the value, indented to the value column. Nothing is cut off.
```

```text
── chars ──
❯ Name  Enter a name
✘ Slug  Bad Slug  Use
        a-z, 0-9, and -
── style ──
A.IIII..HHHHHHHHHHHH
H.HHHH..CCCCCCCC..HHH
........HHHHHHHHHHHHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error
I  fg=error bold
```

### Validation: inline message, ASCII

ASCII marks the failing field with `!` and a space in the two-cell gutter (owner decision,
2026-10-11). The focused failing row keeps the cursor `>` in the gutter and draws no icon.
Placement and wrapping match the Unicode form.

```wireframe 40x2
> Name  Enter a name
! Slug  Bad Slug  Use a-z, 0-9, and -
```

```text
Callouts (40x2, 0-based):
1. r0 c0      Cursor -- `>` in `focus`; the cursor takes the gutter, so no icon.
2. r0 c2-5    Label "Name" -- `error`, bold: focused and failing.
3. r0 c8-19   Message "Enter a name" -- `error`, at the value column because the value is blank.
4. r1 c0      Error icon `!` -- `error`, in the gutter of an unfocused failing row; a space follows it.
5. r1 c2-5    Label "Slug" -- `error`.
6. r1 c8-15   Value "Bad Slug" -- `primary`.
7. r1 c18-36  Message "Use a-z, 0-9, and -" -- `error`.
```

```text
── chars ──
> Name  Enter a name
! Slug  Bad Slug  Use a-z, 0-9, and -
── style ──
A.IIII..HHHHHHHHHHHH
H.HHHH..CCCCCCCC..HHHHHHHHHHHHHHHHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error
I  fg=error bold
```

### Validation: below-row message (rejected)

The Wizard paints its message on the row below its field
([`wizard.rs` L258-L266](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/wizard.rs#L258-L266)).
The same two fields with the message below each one are drawn here and rejected. The
message always adds a row, even when it would fit after the value: when Name starts
failing, the Slug row moves down a row, and every row under a failing field shifts while
the user types. Inline adds rows only when the message does not fit after the value.

```wireframe 40x4
❯ Name
        Enter a name
✘ Slug  Bad Slug
        Use a-z, 0-9, and -
```

```text
Callouts (40x4, 0-based):
1. r0 c0-1    Cursor -- `focus`.
2. r0 c2-5    Label "Name" -- `error`, bold.
3. r1 c8-19   Message "Enter a name" -- `error`, on its own row below the field.
4. r2 c0      Error icon `✘` -- `error`.
5. r2 c2-5    Label "Slug" -- `error`.
6. r2 c8-15   Value "Bad Slug" -- `primary`.
7. r3 c8-26   Message "Use a-z, 0-9, and -" -- `error`.
```

```text
── chars ──
❯ Name
        Enter a name
✘ Slug  Bad Slug
        Use a-z, 0-9, and -
── style ──
A.IIII
........HHHHHHHHHHHH
H.HHHH..CCCCCCCC
........HHHHHHHHHHHHHHHHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error
I  fg=error bold
```

```wireframe 24x5
❯ Name
        Enter a name
✘ Slug  Bad Slug
        Use a-z, 0-9,
        and -
```

```text
Callouts (24x5, 0-based):
1. r0 c0-1    Cursor -- `focus`.
2. r0 c2-5    Label "Name" -- `error`, bold.
3. r1 c8-19   Message "Enter a name" -- `error`.
4. r2 c0      Error icon `✘` -- `error`.
5. r3-r4 c8-20 Message "Use a-z, 0-9," and "and -" -- `error`; wraps within the 16 cells under the value column.
```

```text
── chars ──
❯ Name
        Enter a name
✘ Slug  Bad Slug
        Use a-z, 0-9,
        and -
── style ──
A.IIII
........HHHHHHHHHHHH
H.HHHH..CCCCCCCC
........HHHHHHHHHHHHH
........HHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error
I  fg=error bold
```

### Mobile: the anatomy at 40 columns

The anatomy above is the 40-column state. The 80-column capture of the same fixture is
identical, row for row and style for style. The Form does not widen: rows keep their
natural width, and the label column does not grow beyond the widest label.

### Minimum: 10 columns, 11 with a scrollbar (owner decision, 2026-10-18)

The floor is the cursor gutter (2) plus the widest label (`Replicas`, 8 cells in the
fixture): 10 cells when the form fits its height (owner decision, 2026-10-18). When the
form overflows its height, the ScrollView reserves a scrollbar column, so the floor is one
more: 11. Labels never truncate, so the widest label row sets it. The stacked form is the
narrow one, and its values need only six cells after the four-cell indent (`dark ▾`,
`repo ▾`), so every row fits. A longer select or multi value wraps under the value column
with `▾` after its last word rather than raising the floor: with `light` chosen, the Theme
value draws `light` on one row and `▾` on the next (owner decision, 2026-10-18). The
stacked form is 12 rows, so the minimum is 10x12 when the window shows all of them and 11
columns wide when it is shorter. A parent that assigns less than the floor gets grapheme
breaks in labels and wrapped values, never a silent clip.

```wireframe 10x12
❯ Strict
    true
  Region
    eu
  Name
    omp
  Theme
    dark ▾
  Scopes
    repo ▾
  Replicas
    ◂ 3 ▸
```

```text
Callouts (10x12, 0-based):
1. r0-r10 c2-9 Labels -- content, wraps, never truncates; `Replicas` fills c2-9, the widest row of the form.
2. r1, r3, r5, r7, r9, r11 c4-9 Values -- content, wraps at six cells; `dark ▾` and `repo ▾` fill c4-9. A longer select or multi value wraps under the value column with `▾` after its last word.
3. r0 c0       Cursor -- `❯` in `focus`; chrome, one row.
```

```text
── chars ──
❯ Strict
    true
  Region
    eu
  Name
    omp
  Theme
    dark ▾
  Scopes
    repo ▾
  Replicas
    ◂ 3 ▸
── style ──
A.BBBBBB
....DDDD
..CCCCCC
....EE
..CCCC
....CCC
..CCCCC
....EEEE.F
..CCCCCC
....EEEE.F
..CCCCCCCC
....F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
```

### Minimum, overflowing: 11x6

The same stacked form in a six-row window. Measured at 11 columns the stacked form is 12
rows, more than the window, so the ScrollView reserves the scrollbar column (c10) and
measures again at 10. The label row is still 10 cells, so `Replicas` stays whole. The
offset is 6 and the cursor is on Replicas; the thumb is three rows, starting three rows
down.

```wireframe 11x6
  Theme   │
    dark ▾│
  Scopes  │
    repo ▾█
❯ Replicas█
    ◂ 3 ▸ █
```

```text
Callouts (11x6, 0-based):
1. r4 c0      Cursor -- `❯` in `focus` on the Replicas label; chrome, one row.
2. r4 c2-9    Label "Replicas" -- `focus` bold; content, whole at the 10-cell label row.
3. r0-r2 c10  Track `│` -- `border` (structural; [scroll indicators](../tokens.md#scroll-indicators)).
4. r3-r5 c10  Thumb `█` -- `accent`.
5. r0-r5 c10  Reserved scrollbar column -- the extra cell of the floor.
```

```text
── chars ──
  Theme   │
    dark ▾│
  Scopes  │
    repo ▾█
❯ Replicas█
    ◂ 3 ▸ █
── style ──
..CCCCC...H
....EEEE.FH
..CCCCCC..H
....EEEE.FG
A.BBBBBBBBG
....F.C.F.G
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
E  fg=info
F  fg=secondary
G  fg=accent
H  fg=border
```

### Side by side at 24 columns

Derived, not captured. The anatomy fixture's widest side-by-side rows (Theme and Scopes,
18 cells) fit at 24 columns without clipping, and its six rows fit the window, so no
scrollbar column is reserved and the 24x6 window below shows every row side by side. When
a value does not fit beside its label, the Form stacks before any value wraps (see
[Narrow](#narrow-17-columns); owner decision, 2026-10-18).

```wireframe 24x6
❯ Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
```

```text
Callouts (24x6, 0-based):
1. r0-r5 c0-23  Form -- the anatomy fixture at 24 columns, side by side; no row is clipped.
2. r0-r5 c2-11  Label column -- width 10, the widest label plus two cells, unchanged at 24.
```

### Overflow: 40x4

The Form is a ScrollView of rows. This window is four rows tall and the Form has six, so
the offset is two: the first two rows scroll off the top, and the cursor on Theme is kept
in view. The ScrollView measures the rows at the full 40 columns, finds that they overflow
the window, and only then reserves the rightmost column (c39) for the scrollbar and
measures again at 39 (see [ScrollView](scroll-view.md#cross-axis-proposal)). A form that
fits its height reserves no column (anatomy callout 10). The thumb sits at the bottom
because the offset is at its maximum.

```wireframe 40x4
  Name      omp                        │
❯ Theme     dark ▾                     │
  Scopes    repo ▾                     █
  Replicas  ◂ 3 ▸                      █
```

```text
Callouts (40x4, 0-based):
1. r1 c0      Cursor -- `❯` in `focus` on the Theme row, the focused row, kept in view.
2. r1 c2-6    Label "Theme" -- `focus` bold.
3. r0-r1 c39  Track `│` -- `border`.
4. r2-r3 c39  Thumb `█` -- `accent`.
```

```text
── chars ──
  Name      omp                        │
❯ Theme     dark ▾                     │
  Scopes    repo ▾                     █
  Replicas  ◂ 3 ▸                      █
── style ──
..CCCC......CCC........................H
A.BBBBB.....EEEE.F.....................H
..CCCCCC....EEEE.F.....................G
..CCCCCCCC..F.C.F......................G
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
E  fg=info
F  fg=secondary
G  fg=accent
H  fg=border
```

### Narrow: 17 columns

The Form stacks each label above its value when a side-by-side row does not fit (owner
decision, 2026-10-11); `ViewThatFits` keeps the side-by-side layout while every row fits.
The ScrollView measures the rows at its full width and reserves its scrollbar column only
when they overflow its height (see [ScrollView](scroll-view.md#cross-axis-proposal)). At
18 columns the side-by-side form is six rows, so an 18x6 or 18x12 window reserves no
column, and its widest rows, Theme and Scopes, are 18 cells, so they fit: the form stays
side by side.

```wireframe 18x6
❯ Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
```

```text
Callouts (18x6, 0-based):
1. r3-r4 c2-17 Theme and Scopes rows -- the widest rows, 18 cells; they fill the width, so the form stays side by side.
2. r3-r4 c17  Dropdown glyph `▾` -- `secondary`, in the last column: the six rows fit the window, so no scrollbar column is reserved.
```

```text
── chars ──
❯ Strict    true
  Region    eu
  Name      omp
  Theme     dark ▾
  Scopes    repo ▾
  Replicas  ◂ 3 ▸
── style ──
AABBBBBB....DDDD
..CCCCCC....EE
..CCCC......CCC
..CCCCC.....EEEE.F
..CCCCCC....EEEE.F
..CCCCCCCC..F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
```

At 17 columns the Theme and Scopes rows no longer fit, so the whole form stacks: each
label has its own row, and its value sits on the row below, indented four cells. Values
are content and wrap at the width after the indent (13 cells at 17 columns); labels never
truncate (owner decision, 2026-10-18). The stacked form is 12 rows; the 17x12 window shows
all of it, so no column is reserved and no value wraps. The 17x6 window draws six rows and
scrolls (see Overflow, stacked).

```wireframe 17x12
❯ Strict
    true
  Region
    eu
  Name
    omp
  Theme
    dark ▾
  Scopes
    repo ▾
  Replicas
    ◂ 3 ▸
```

```text
Callouts (17x12, 0-based):
1. r0 c0      Cursor -- `❯` in `focus` on the focused Strict label; chrome, one row.
2. r0 c2-7    Label "Strict" -- `focus` bold; content, wraps, never truncates.
3. r1 c4-7    Value "true" -- `success`, indented four cells; content, wraps.
4. r2, r4, r6, r8, r10 c2+ Labels -- `primary`; content, wraps, never truncates.
5. r3, r5, r7, r9 c4+ Values -- `info`; content, wraps at 13 cells under the value column, with `▾` in `secondary` one space after the last word, at c9 on r7 and r9.
6. r11 c4, c6, c8 Arrows `◂`, `3`, `▸` -- `secondary`, `primary`, `secondary`; arrows chrome, one row, number atomic.
7. r0-r11 c16 No scrollbar column -- the 12 rows fit the window, so none is reserved.
```

```text
── chars ──
❯ Strict
    true
  Region
    eu
  Name
    omp
  Theme
    dark ▾
  Scopes
    repo ▾
  Replicas
    ◂ 3 ▸
── style ──
A.BBBBBB
....DDDD
..CCCCCC
....EE
..CCCC
....CCC
..CCCCC
....EEEE.F
..CCCCCC
....EEEE.F
..CCCCCCCC
....F.C.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
D  fg=success
E  fg=info
F  fg=secondary
```

### Narrow: long values wrap

A value longer than the stacked value width wraps onto more rows under its label, at the
same four-cell indent (owner decision, 2026-10-18). The fixture is a two-field form, Name
and Scopes, at 18 columns. Neither value fits beside its label, so the form stacks; its
six rows fit the window, so no scrollbar column is reserved and each value row holds 14
cells. The Name value `omp staging cluster eu` breaks after `omp staging`. Scopes has all
three choices checked, so its summary is `repo, issues +1`: the names wrap rather than
truncate, the first-two and `+N` form is kept, and `▾` follows the last word, so the
second row reads `+1 ▾` (owner decision, 2026-10-18). A select value wraps the same way.
The editing line of a text field being edited follows [TextField](text-field.md), not this
wrap.

```wireframe 18x6
❯ Name
    omp staging
    cluster eu
  Scopes
    repo, issues
    +1 ▾
```

```text
Callouts (18x6, 0-based):
1. r0 c0      Cursor -- `❯` in `focus`; chrome, one row.
2. r0 c2-5    Label "Name" -- `focus` bold; content, wraps, never truncates.
3. r1 c4-14   Value row 1 "omp staging" -- `primary`; content, wraps at 14 cells.
4. r2 c4-13   Value row 2 "cluster eu" -- `primary`: the wrapped remainder at the same indent.
5. r3 c2-7    Label "Scopes" -- `primary`.
6. r4 c4-15   Summary row 1 "repo, issues" -- `info`; content, wraps: ` +1` would need 15 cells.
7. r5 c4-5    Summary row 2 "+1" -- `info`: the `+N` count after the first two names.
8. r5 c7      Dropdown glyph `▾` -- `secondary`, one space after the last word; chrome, one cell.
```

```text
── chars ──
❯ Name
    omp staging
    cluster eu
  Scopes
    repo, issues
    +1 ▾
── style ──
A.BBBB
....CCCCCCCCCCC
....CCCCCCCCCC
..CCCCCC
....EEEEEEEEEEEE
....EE.F
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
E  fg=info
F  fg=secondary
```

### Overflow, stacked: 17x6

The stacked form is 12 rows and the window is six, so it scrolls. The ScrollView measures
the stacked rows at 17 columns, finds that they overflow, reserves the scrollbar column
(c16) and measures again at 16, so values wrap at 12 cells; none needs to here. The offset
counts rows above the viewport (3), so the window starts on Region's value row: the field
is partly in view, and the viewport edge draws its visible row with no mark. The cursor is
on Theme. With content 12 rows and window 6 rows in a six-cell track, the thumb is three
rows and starts one row down.

```wireframe 17x6
    eu          │
  Name          █
    omp         █
❯ Theme         █
    dark ▾      │
  Scopes        │
```

```text
Callouts (17x6, 0-based):
1. r0 c4-5    Value "eu" -- `info`: Region's value row, the second row of a field whose label row is above the viewport. Drawn without a mark.
2. r3 c0      Cursor -- `❯` in `focus` on the Theme label.
3. r3 c2-6    Label "Theme" -- `focus` bold.
4. r0, r4-r5 c16 Track `│` -- `border`.
5. r1-r3 c16  Thumb `█` -- `accent`.
6. r0-r5 c16  Reserved scrollbar column -- reserved because the 12 stacked rows overflow the six-row window.
```

```text
── chars ──
    eu          │
  Name          █
    omp         █
❯ Theme         █
    dark ▾      │
  Scopes        │
── style ──
....EE..........H
..CCCC..........G
....CCC.........G
A.BBBBB.........G
....EEEE.F......H
..CCCCCC........H
── legend ──
.  default
A  fg=focus
B  fg=focus bold
C  fg=primary
E  fg=info
F  fg=secondary
G  fg=accent
H  fg=border
```

## State model

Schema: [README](../README.md#state-model-table).

| State            | Owner       | Type                                                                              | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------- | ----------- | --------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| field values     | Binding     | `Binding` per field, typed per kind                                               | App-owned: each row's control takes its own binding (key D1). Written only through the binding. The Form keeps no copy and harvests no values (key A10), so discarding its NodeState loses no data.                                                                                                                                                                                                                                       |
| cursor           | NodeState   | field index, `Int`                                                                | Starts on the first row when the Form node is created and keeps its row across focus changes; direction-aware entry is rejected (key D9). Clamped to the field count on every key. Chase keeps the cursor row visible.                                                                                                                                                                                                                    |
| scroll offset    | NodeState   | rows above the viewport, `Int`                                                    | Clamped to content rows minus window rows on every render. Field heights vary: a stacked field is two or more rows, a wrapped value or validation message adds rows, an open dropdown adds its rows. A field partly in view draws its visible rows at the edge, with no mark. Chase changes the offset by the fewest rows that show the whole field; a field taller than the window top-aligns. One owner: the Form's NodeState (key D4). |
| open dropdown    | NodeState   | field index, `Int?`                                                               | Set when Picker's menu opens in a select or multi row (Enter, Space, or a click on the closed row). Cleared when it closes: Esc, Enter, a click outside, or focus loss. Focus loss closes without committing, as Esc does. The Form stores only the host row; Picker holds the list cursor and selection. (key D7)                                                                                                                        |
| editing          | NodeState   | `Bool`                                                                            | Set by Enter, Space, or a click on a text row. Cleared by Enter or Esc, and by focus loss (key D7).                                                                                                                                                                                                                                                                                                                                       |
| hovered row      | derived     | row index, `Int?`                                                                 | Derived at render from the graph-owned hover point (key F4); never stored in NodeState or a binding. The graph clears it on focus loss and when motion tracking stops ([Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing)). The row paints the `hover` role and no value changes. The Form requests move input for this hover (owner decision, 2026-10-10).                                                                      |
| validation rules | Environment | `required` `Bool` and `pattern` `Regex?`, each with an optional message `String?` | Configuration, not state: set by the app's `.required(_:)` and `.pattern(_:message:)` modifiers on a field (key M1), as `.characterLimit(_:)` configures [TextField](text-field.md), and read on every render. The Form never stores them.                                                                                                                                                                                                |
| validation       | derived     | first failing message, `String?`                                                  | Computed on every render; required is checked before pattern. The app's message, or the default built from the label when omitted (Validation; owner decision, 2026-10-18). The message wraps under the value, so a failing field is taller while it shows (owner decision, 2026-10-18).                                                                                                                                                  |
| layout           | derived     | label width, stacked flag, value width, content rows, window                      | Recomputed at the proposed size on every layout; `ViewThatFits` sets the stacked flag when a value or label does not fit side by side. Each field, with any validation message rows, is measured at its width with a nil height, and re-measured on width change. Never stored.                                                                                                                                                           |

## Key table

Schema: [README](../README.md#key-table). While a dropdown is open, its keys belong to
Picker's menu (see [Picker](picker.md#menu-collapsed-in-a-host-row)).

| Key                 | Precondition                                          | Effect                                                                                                                              | Consumed                               |
| ------------------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| ↑                   | focused, no dropdown open, cursor below the first row | Mutates cursor: moves up one row; chase keeps it visible.                                                                           | yes                                    |
| ↑                   | focused, no dropdown open, cursor on the first row    | No effect.                                                                                                                          | no                                     |
| ↓                   | focused, no dropdown open, cursor above the last row  | Mutates cursor: moves down one row; chase keeps it visible.                                                                         | yes                                    |
| ↓                   | focused, no dropdown open, cursor on the last row     | No effect.                                                                                                                          | no                                     |
| PgUp                | focused, no dropdown open                             | Mutates cursor: moves up one window, clamped to the first row.                                                                      | yes                                    |
| PgDn                | focused, no dropdown open                             | Mutates cursor: moves down one window, clamped to the last row.                                                                     | yes                                    |
| ←                   | focused, no dropdown open, enum row                   | Mutates the enum value: cycles to the previous choice.                                                                              | yes                                    |
| →                   | focused, no dropdown open, enum row                   | Mutates the enum value: cycles to the next choice.                                                                                  | yes                                    |
| ←                   | focused, no dropdown open, number row                 | Mutates the number value: steps down by the field's step, clamped to its minimum.                                                   | yes                                    |
| →                   | focused, no dropdown open, number row                 | Mutates the number value: steps up by the field's step, clamped to its maximum.                                                     | yes                                    |
| ←                   | focused, no dropdown open, other kind                 | No effect.                                                                                                                          | no                                     |
| →                   | focused, no dropdown open, other kind                 | No effect.                                                                                                                          | no                                     |
| Enter               | focused, no dropdown open, bool row                   | Mutates the bool value: toggles it.                                                                                                 | yes                                    |
| Space               | focused, no dropdown open, bool row                   | Mutates the bool value: toggles it.                                                                                                 | yes                                    |
| Enter               | focused, no dropdown open, enum row                   | Mutates the enum value: cycles forward.                                                                                             | yes                                    |
| Space               | focused, no dropdown open, enum row                   | Mutates the enum value: cycles forward.                                                                                             | yes                                    |
| Enter               | focused, no dropdown open, select or multi row        | Opens Picker's menu below the row; its cursor starts on the chosen option (Picker's closed keys).                                   | yes                                    |
| Space               | focused, no dropdown open, select or multi row        | Opens Picker's menu below the row, as Enter does.                                                                                   | yes                                    |
| Enter               | focused, no dropdown open, text row                   | Mutates editing: starts editing.                                                                                                    | yes                                    |
| Space               | focused, no dropdown open, text row                   | Mutates editing: starts editing.                                                                                                    | yes                                    |
| Enter               | focused, no dropdown open, number row                 | No effect.                                                                                                                          | no                                     |
| Space               | focused, no dropdown open, number row                 | No effect.                                                                                                                          | no                                     |
| any key             | dropdown open                                         | Handled by Picker's open list; Form has no keys of its own while it is open (see [Picker](picker.md#menu-collapsed-in-a-host-row)). | conditional (Picker's open-list rules) |
| Enter               | editing text                                          | Mutates editing: stops editing.                                                                                                     | yes                                    |
| Esc                 | editing text                                          | Mutates editing: stops editing.                                                                                                     | yes                                    |
| Backspace           | editing text                                          | Mutates the text value: deletes one character.                                                                                      | yes                                    |
| Ctrl-u              | editing text                                          | Mutates the text value: clears it.                                                                                                  | yes                                    |
| Ctrl-w              | editing text                                          | Mutates the text value: deletes a word.                                                                                             | yes                                    |
| Space               | editing text                                          | Mutates the text value: appends a space.                                                                                            | yes                                    |
| printable character | editing text                                          | Mutates the text value: inserts the character.                                                                                      | yes                                    |
| paste               | editing text                                          | Mutates the text value: appends the text, with newlines and tabs replaced by spaces.                                                | yes                                    |
| paste               | not editing                                           | Ignored.                                                                                                                            | no                                     |
| any other key       | editing text                                          | No effect.                                                                                                                          | yes                                    |
| any other key       | not editing, no dropdown open                         | Not handled by the Form.                                                                                                            | no                                     |

## Mouse table

Schema: [README](../README.md#mouse-table). Regions must be named in Anatomy callouts.
Regions: `row` (anatomy callout 11), `scrollbar` (anatomy callout 10), and `window`
(anatomy callout 12). An open dropdown's option rows are Picker's regions, not Form's (see
[Picker](picker.md#menu-collapsed-in-a-host-row)).

| Event      | Region        | Precondition                   | Effect                                                                                                                                                                                              | Consumed                                                  |
| ---------- | ------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| click      | row           | row index < field count        | Sets the cursor to that row, closes a dropdown open on a different row without committing (Picker's click-outside rule), and activates the row as Enter does. Click-to-focus runs first (key F6).   | yes                                                       |
| click      | open dropdown | a dropdown is open on any row  | Handled by Picker's menu (see [Picker](picker.md#menu-collapsed-in-a-host-row)); Form takes no action.                                                                                              | conditional (Picker's mouse rules)                        |
| click      | scrollbar     | always                         | None: the indicator is output-only (key F2; [ScrollIndicator](../../docs/Spec.md#scrollindicator)); the click returns `.ignored`.                                                                   | no                                                        |
| drag       | scrollbar     | always                         | None: the indicator is output-only, so a drag on it returns `.ignored` (key F2).                                                                                                                    | no                                                        |
| wheel-up   | window        | no open list under the pointer | Scrolls the viewport up one row without moving the cursor.                                                                                                                                          | conditional (yes if the viewport moved; no at the top)    |
| wheel-down | window        | no open list under the pointer | Scrolls the viewport down one row without moving the cursor.                                                                                                                                        | conditional (yes if the viewport moved; no at the bottom) |
| move       | row           | row index < field count        | None: the graph moves its hover point, and the derived hovered row follows and paints `hover` (key F4); no value changes. Requested only because the rows paint hover (owner decision, 2026-10-10). | no                                                        |

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

Width: the ideal width for a nil width proposal is the widest side-by-side row, measured
unwrapped, as Text reports its widest line and List its widest row: 18 cells for the
anatomy fixture (Theme and Scopes). A validation message does not count toward it: the
message wraps under the value instead of stacking the form (owner decisions, 2026-10-10
and 2026-10-18), so the side-by-side arrangement that `ViewThatFits` tests (key G10)
measures labels and values only. Each label sits beside its value while every row fits, so
`ViewThatFits` keeps the side-by-side layout exactly down to that width: 18 columns here.
When a value does not fit beside its label, `ViewThatFits` stacks each label above its
value before any value wraps (owner decision, 2026-10-18; see
[Narrow](#narrow-17-columns)). The ScrollView measures the rows at the full width and
reserves its scrollbar column only when they overflow the height (see
[ScrollView](scroll-view.md#cross-axis-proposal)). Stacked, values indent four cells and
wrap at the width after the indent; labels never truncate. The floor is the cursor gutter
(2) plus the widest label (`Replicas`, 8): 10 when the form fits its height, and 11 when
it overflows, for the reserved scrollbar column (owner decision, 2026-10-18; see Minimum).
Height: every content row, one per field, two or more per field while stacked (more when a
value or a validation message wraps), plus the rows of an open dropdown. A nil height
proposal reports every row, with no ideal-height cap, as ScrollView, List, Table and
Outline do; an app caps the Form with a max-height frame (owner decision, 2026-10-18). No
description row in 1.0 (owner decision, 2026-10-11). The label column is the widest label
plus two cells, and values start after it.

| Proposal             | Result | Rule                                                                                                                                                                                                                                                                                       |
| -------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| nil x nil            | 18x6   | Ideal width is the widest side-by-side row (Theme and Scopes, 18 cells), measured unwrapped; height is every row, the six content rows of the anatomy fixture, with no cap.                                                                                                                |
| nil x 4              | 19x4   | Nil width, short: the six side-by-side rows overflow four, so the scrollbar column adds one cell to the 18-cell ideal (see ScrollView cross-axis proposal; Overflow: 40x4).                                                                                                                |
| 24x6                 | 24x6   | Side by side at 24 columns: labels stay beside their values, and the anatomy fixture fits without clipping (see Side by side at 24 columns).                                                                                                                                               |
| 18x6                 | 18x6   | Tight fit: the narrowest side-by-side width. The six rows fit the height, so no scrollbar column is reserved, and the Theme and Scopes rows (18 cells) fill the width (see Narrow: 17 columns).                                                                                            |
| 17x6                 | 17x6   | Stacked, short: the Theme and Scopes rows do not fit at 17 columns, so the form stacks. The 12 stacked rows overflow six, so the ScrollView reserves its scrollbar column and draws 6 rows; values wrap at 12 cells (see Overflow, stacked).                                               |
| 17x12                | 17x12  | Stacked: each field is two rows; the 12 rows fit the height, so no column is reserved, and every value fits in 13 cells, so none wraps (see Narrow: 17 columns).                                                                                                                           |
| 17 x nil             | 17x12  | Stacked, nil height: every row is reported, 12 here, with no cap; nothing overflows, so no column is reserved.                                                                                                                                                                             |
| 18 x nil, long value | 18x6   | Narrow wrap fixture: `omp staging cluster eu` and `repo, issues +1 ▾` each wrap to two value rows at 14 cells, so the two-field form is six rows (see Narrow: long values wrap).                                                                                                           |
| 8x12                 | 10x12  | Under-minimum: the Form reports the 10-cell floor, the cursor gutter plus the widest label, because the 12 stacked rows fit the height (owner decision, 2026-10-18). If a parent still assigns less, labels break between graphemes and values wrap; nothing clips silently (see Minimum). |
| 8x6                  | 11x6   | Under-minimum, short: the 12 stacked rows overflow six, so the scrollbar column is reserved and the floor is 11 (see Minimum, overflowing).                                                                                                                                                |
| 80x6                 | 80x6   | Over-maximum: the Form fills the proposed width, keeps rows at natural width, and left-aligns content, so the 80-column capture matches the 40-column one row for row.                                                                                                                     |
| 40x6                 | 40x6   | Anatomy fixture at the mobile width: six fields, no dropdown open.                                                                                                                                                                                                                         |
| 40x9                 | 40x9   | Select-open and multi-open: each open dropdown adds three content rows below its field.                                                                                                                                                                                                    |
| 40x2                 | 40x2   | Validation, inline: two fields; the message fits after the value and adds no row.                                                                                                                                                                                                          |
| 24x3                 | 24x3   | Validation, inline, at 24 columns: `Use` fits after the value and the gap, the rest wraps under the value, so the Slug field is two rows.                                                                                                                                                  |

## Environment

Tokens consumed: [roles](../tokens.md#roles); focus, fill and hue rules are in
[focus](../tokens.md#focus), [fill roles](../tokens.md#fill-roles) and
[hue roles](../tokens.md#hue-roles).

- `primary`: labels, text and number values, unhighlighted choices, and the rest of the
  row.
- `focus`: the cursor glyph, the focused label, and the highlighted choice in Picker's
  open list. The terminal's default foreground in bold ([focus](../tokens.md#focus)). The
  bold attribute follows the Focus border rule 3 (ASCII bold per rule 6).
- `secondary`: unchecked and unpicked marks, the `▾` dropdown glyph, number arrows,
  `false`, and the masked-field `secret` icon ([text roles](../tokens.md#text-roles)).
- `border`: the scrollbar track `│` ([scroll indicators](../tokens.md#scroll-indicators)).
- `success`: `true` ([hue roles](../tokens.md#hue-roles)).
- `accent`: checked and picked marks, `☑` and `◉`, and the scrollbar thumb
  ([hue roles](../tokens.md#hue-roles)).
- `info`: enum, select, and multi values. An empty multi value paints `none`, and an
  absent select value paints an em dash (Picker summary).
- `error`: a failing field's label, its error icon, and its message.
- `hover`: the background of the row under the pointer, the row-fill form of hover (key
  B14): `fill12` where derived, and an underline on the row label where no fill can stand
  apart ([fill roles](../tokens.md#fill-roles)) (owner decision, 2026-10-19).
- `lineLimit`, `truncationMode` (environment): flow to labels and values, which are
  content. The cursor, glyphs and arrows pin their own one-row values.

## Primitive dependencies

- [ViewThatFits](../primitives/view-that-fits.md) (`ready`): the side-by-side or stacked
  choice, as `ViewThatFits(in: .horizontal)` over the side-by-side and stacked
  arrangements (key G10; [Spec](../../docs/Spec.md#flow-layout-and-viewthatfits)). Plan
  032 step 14.1 builds it, before Form lands.
- [Stepper](stepper.md): the number row's `◂ 4 ▸` presentation and steps. The Form shows
  the arrows on every number row, as Stepper does (owner decision, 2026-10-10).
- [Picker](picker.md): enum rows use its inline cycling. Select rows are Picker's `.menu`
  collapsed in the row; multi rows are a MultiPicker in its default `.menu` style,
  collapsed the same way (owner decision, 2026-10-18). Each takes a title, which the Form
  draws as the row label (owner decision, 2026-10-18). The open list, keys, mouse rules
  and summary are Picker's
  ([menu collapsed in a host row](picker.md#menu-collapsed-in-a-host-row)) and, for the
  multi row, [MultiPicker's](multi-picker.md#menu-in-a-host-row). The collapsed value is
  content whose rows the Form decides: it wraps under the value column with `▾` after its
  last word (owner decision, 2026-10-18). Multi-select is in 1.0 (owner decision,
  2026-10-11).
- [Toggle](toggle.md): the bool row. Inside a Form row, Toggle's `.text` style is the
  default and paints `true` or `false`; the standalone default is `.checkbox`. An explicit
  `.toggleStyle(_:)` on the Toggle or an ancestor wins. The row's focus rule (`❯` cursor
  and a bold focus-coloured label) applies, not the standalone underline (owner decision,
  2026-10-10).
- [LabeledContent](labeled-content.md): the label-value row. A LabeledContent inside a
  Form keeps its own label column and does not join the Form's shared column. Space is
  often limited; alignment may become an option later (owner decision, 2026-10-10).
- [TextField](text-field.md): text rows. Their editing keys are listed above; how they
  relate to TextField's own key table is an [open question](#open-questions).
- [Label](../primitives/label.md): the `error` icon for a failing field and the `secret`
  icon for masked fields. Row labels are plain `Text`, not Label, so they wrap and never
  truncate; Label's one-row title rule does not apply to them.
- [ScrollIndicator](../primitives/scroll-indicator.md): the overflow scrollbar column,
  output-only (key F2).

## Requirements

Backticked sentence-style test names, each traced to a table row or wireframe state.
Schema: [README](../README.md#requirements-list).

- `form paints each label in a column sized to the widest label plus two cells` (anatomy
  callout 3)
- `form paints the cursor glyph and the bold focus label on the focused row only` (anatomy
  callouts 1-2; focus border rule 3)
- `form draws the cursor only while focused` (anatomy callout 1)
- `form draws no cursor and no bold label while unfocused` (Unfocused)
- `form writes a field value only through its binding` (state model: field values)
- `form derives its hovered row from graph-owned hover, requests move input for it, and changes no value on move`
  (state model: hovered row; mouse table: move)
- `bool row paints success when true and secondary when false as text` (anatomy callout 4)
- `enum, select, and multi values paint info; select and multi show a secondary dropdown glyph`
  (anatomy callouts 5, 7, 8)
- `select and multi values wrap under the value column with the dropdown glyph after the last word`
  (anatomy callouts 7-8; Narrow: long values wrap, callouts 6-8)
- `focused enum row paints its value between secondary arrows, as the number row does`
  (Focused: the enum field)
- `empty multi value paints none in info` (anatomy callout 8; MultiPicker summary)
- `multi value joins the first two checked labels with a comma and adds +N for the rest`
  (anatomy callout 8; MultiPicker summary)
- `multi summary wraps its names rather than truncating and keeps the +N count` (Narrow:
  long values wrap; Sizing: 18 x nil, long value)
- `absent select value paints an em dash in info` (Picker summary)
- `number value paints primary and shows its arrows on every number row, focused or not`
  (anatomy callout 9)
- `number arrows paint secondary and stay in place around the value` (Focused: the number
  field)
- `select row opens Picker's menu below its row, with the cursor on the chosen option`
  (Select dropdown open; Picker closed keys)
- `multi row opens MultiPicker's menu below its row, with a checkbox per choice` (Multi
  dropdown open; Picker closed keys)
- `picked radio and checked box paint accent; unpicked radio paints secondary` (Select
  dropdown open, callouts 5-6; Multi dropdown open, callout 4)
- `dropdown choices indent four cells under their field` (Select dropdown open; Picker
  menu collapsed in a host row)
- `ASCII cursor is > and number arrows are < and >` (Focused, ASCII)
- `ASCII checkbox and radio marks are [x] [ ] and (*) ( )` (Select dropdown open, ASCII;
  Multi dropdown open, ASCII)
- `ASCII error icon is ! and a space inside the two-cell gutter` (Validation: inline
  message, ASCII)
- `failing field paints its label in error with the error icon in the gutter` (Validation:
  inline message, callouts 4-5)
- `focused failing field keeps the cursor and paints its label bold error` (Validation:
  inline message, callouts 1-2)
- `validation message paints after the value with a two-cell gap` (Validation: inline
  message, callout 7)
- `required message paints at the value column when the value is blank` (Validation:
  inline message, callout 3)
- `validation message uses the app's wording and builds one from the label when omitted`
  (Validation: inline message, default wording in its prose)
- `validation message wraps under the value, indented to the value column, when it does not fit after the value`
  (Validation: inline message, 24 columns)
- `validation message grows the field's height only while shown and cuts nothing off`
  (Validation: inline message, 24 columns; Sizing: 24x3)
- `validation adds no row when the message fits after the value` (Validation: inline
  message; below-row message rejected)
- `form computes the first failing message, required before pattern` (state model:
  validation)
- `form lays out a LabeledContent in its own label column` (Primitive dependencies)
- `explicit toggle style on a form row overrides the text default` (Primitive
  dependencies: Toggle)
- `form at 80 columns is identical to the 40-column form` (Mobile)
- `form row label is the control's title, which stays its accessible name` (API direction;
  anatomy callout 2)
- `form keeps the side-by-side layout while every row fits` (Narrow: 17 columns, 18x6;
  Sizing: 18x6)
- `form stacks each label above its value when a value does not fit beside its label, before any wrap or truncation`
  (Narrow: 17 columns)
- `form stacks each field into two rows while the layout is stacked` (Sizing: 17x12)
- `form wraps a stacked value at the width after its four-cell indent` (Narrow: long
  values wrap; Sizing: 18 x nil, long value)
- `form draws row labels as plain text that wraps and never truncates` (anatomy callout 2;
  Minimum; Primitive dependencies: Label)
- `form keeps every stacked label and value whole at the 10-column floor when it fits its height`
  (Minimum; Sizing: 8x12)
- `form floor is the cursor gutter plus the widest label, and one more for the scrollbar column when it overflows`
  (Minimum, overflowing; Sizing: 8x6)
- `form reports every row for a nil height proposal, with no ideal-height cap` (Sizing:
  nil x nil; 17 x nil)
- `form ideal width is its widest side-by-side row, plus the scrollbar column only when the rows overflow`
  (Sizing: nil x nil; nil x 4)
- `form draws the visible rows of a partly visible field at the viewport edge, with no mark`
  (Overflow, stacked)
- `form chase changes the offset by the fewest rows that show the whole field` (state
  model: scroll offset)
- `form reserves its scrollbar column only when its rows overflow its height` (anatomy
  callout 10; Overflow: 40x4; Overflow, stacked; Sizing: 18x6, 17x6)
- `form scrolls content taller than its proposed height inside the window` (Overflow:
  40x4)
- `up on the first row and down on the last row are not consumed` (key table)
- `enter or space on a select or multi row opens Picker's menu` (key table)
- `keys while a dropdown is open are handled by Picker's menu` (key table)
- `focus loss closes an open dropdown without committing` (key table; state model: open
  dropdown)
- `clicking a row sets the cursor and closes a dropdown open on another row` (mouse table:
  row)
- `clicks in an open dropdown are handled by Picker's menu` (mouse table)
- `form height is the content rows plus the rows of an open dropdown` (Sizing: 40x6, 40x9)
- `wheel scrolls the viewport without moving the cursor` (mouse table: wheel-up,
  wheel-down)
- `form leaves clicks and drags on its scrollbar unconsumed` (mouse table: scrollbar)
- `form cursor starts on the first row and keeps its row across focus changes` (state
  model: cursor)
- `form ends text editing on focus loss` (state model: editing)

## Degradation

- Colour degradation follows the [degradation ladder](../tokens.md#degradation-ladder).
  This widget adds no rule of its own.
- ASCII-only: the cursor is `>` in `focus`; the arrows are `<` and `>`; dropdown glyphs
  are `v`. Focus is bold, since ASCII has no heavier line (focus border rule 6). Checkbox
  and radio marks are `[x]`/`[ ]` and `(*)`/`( )` (owner decision, 2026-10-11), as in
  [Select dropdown open, ASCII](#select-dropdown-open-ascii) and
  [Multi dropdown open, ASCII](#multi-dropdown-open-ascii). The label column and value
  column are unchanged.
- ASCII validation: the error icon is `!` and a space, so the two-cell gutter holds (owner
  decision, 2026-10-11). `[!!]` stays Label's standalone text. The failing state is
  captured in [Validation: inline message, ASCII](#validation-inline-message-ascii).
- Narrow widths: `ViewThatFits` takes the side-by-side layout when every row fits, and
  otherwise stacks each label above its value, the value on the row below, indented four
  cells (owner decision, 2026-10-11; see [Narrow](#narrow-17-columns)). Stacked values,
  select and multi values included, wrap at the width after the indent and labels never
  truncate (owner decision, 2026-10-18). Below the floor (10 cells, or 11 when the form
  overflows its height and reserves a scrollbar column), labels and values break between
  graphemes; nothing clips silently. The validation message wraps under the value,
  indented to the value column (owner decision, 2026-10-18). ASCII keeps the `~` mark
  where a mark is drawn.

This design was reviewed against the
[Phase 4 theses](../../docs/Spec.md#phase-4--view-layer-the-tessera-module): every field
value is the app's binding and the Form keeps no copy; the cursor, scroll offset, open
dropdown, and editing flag are NodeState with one owner; hover is derived from the graph;
and the side-by-side or stacked choice is deterministic integer layout through
`ViewThatFits`.

## Open questions

- Text rows and TextField's keys. A text row is a `TextField`, but while editing, the
  Form's key table edits it with no caret, as omp2's Form does: printable characters and
  Space append, Backspace deletes one character, Ctrl-u clears, and Ctrl-w deletes a word.
  Standalone, [TextField's key table](text-field.md#key-table) edits at a grapheme caret
  with Left, Right, Home, and End. Does a Form text row hand its editing keys to
  TextField's key table, as a select row hands its keys to Picker's menu, or keep the
  Form's rows? Deferred to plan 032 step 13.4, which builds the shared text editing core;
  the key table above holds until the owner decides.
- Masked rows (key M8). The anatomy paints the `secret` icon in place of a masked text
  value (owner decision, 2026-10-19), but no 1.0 API declares a row masked, and TextField
  defers secure entry past 1.0 ([TextField](text-field.md#deferred-post-10)). The owner
  decides whether 1.0 needs a masking modifier for display only; deferred to plan 032 step
  16.3, where Form lands.

## Inspiration

No inbox entries yet.
