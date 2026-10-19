---
kind: widget
status: specified
---

# Form

`Form` is Tessera's column of labelled fields. Each row has a label, a cursor glyph on the
focused row, and a value in a shared value column. Field kinds are bool, enum, text,
select, multi, and number. The label column is as wide as the widest label plus two cells,
so every value starts in the same column. Enum and number values edit in place. Select and
multi fields are Picker's menu collapsed in their row. Open, its option rows sit below the
row (see [Picker](picker.md#menu-collapsed-in-a-host-row)). The view keeps its cursor,
scroll offset, open dropdown and text editing state; the app owns the field values through
bindings, as in every Tessera controlled widget. The focused row's cursor and bold label
follow [Focus border](../primitives/border.md#focus-border), rule 3.

Owner decision, omp2 review, 2026-10: adopt as-is. The aligned label column and inline
dropdowns are accepted. The number field is the reference for [Stepper](stepper.md). The
validation message is painted inline after the value, never on its own row; see
[Validation](#validation-inline-message) (owner decision, 2026-10-10).

The wireframes below are the accepted Tessera states, drawn from omp2's rendering with its
theme roles renamed to Tessera roles. This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase),
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
  [`mouse`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L696-L749),
  [`validation_error`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L750-L766),
  [`paint_field_value`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L856-L935),
  with the number field at
  [L910-L922](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L910-L922).
  Reject three things. omp2 keeps field data inside the Form; Tessera binds each field to
  app state. omp2 draws the number arrows only on the focused row; Tessera follows
  [Stepper](stepper.md) and shows them on every number row, focused or not (owner
  decision, 2026-10-10). omp2 never paints the validation message it computes; its
  [Wizard](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/wizard.rs#L258-L266)
  paints one on the row below its field. Form takes the inline placement instead (see
  [Validation](#validation-inline-message)).
- SwiftUI [`Form`](https://developer.apple.com/documentation/swiftui/form) supplies the
  vocabulary: a column of controls with labels, and `LabeledContent` for label-value rows.
  Reject its platform-drawn cells; the terminal rows are drawn by the view.

## API direction

Swift in SwiftUI vocabulary. Signatures are a sketch until the widget is specified. The
bindings are app-supplied values named without a dollar-sign prefix; Tessera has no
property-wrapper state. The bool row is a `Toggle` that draws the `.text` style inside a
Form, so it paints the captured text `true` or `false` (see
[Toggle](toggle.md#text-style)). Multi-select has no SwiftUI `Form` or `Picker` control.
Tessera adds it as a `Binding<Set<Value>>` initializer on Picker, mirroring Table's
`Binding<Set<ID>>` (a Tessera addition, owner decision, 2026-10-10). The multi row is that
Picker collapsed in its row (see [Picker](picker.md#menu-collapsed-in-a-host-row)); it is
not a separate control.

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
    Picker("Scopes", selection: scopes) { /* Binding<Set<Scope>>: repo, issues, actions */ }
    Stepper("Replicas", value: replicas, in: 1...8)
}
```

`.required(_:)` and `.pattern(_:message:)` are sketch names for the validation rules. The
app supplies the wording; when the message is omitted, the Form builds it from the field
label (see Validation). The Replicas row is a native number field, so the Form lays it out
in the shared column; a `LabeledContent` does not join that column (see Primitive
dependencies).

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
              focused (`>` in ASCII). Two spaces on the other rows and whenever the Form is not focused.
2. r0 c2-7    Label "Strict" -- `primary`; `focus` bold on the cursor row only.
3. r0-r5 c2-11  Label column -- each label is padded to the widest label plus two cells, so
              every value starts at column 12 for this fixture.
4. r0 c12-15  Bool value "true" -- `success` when true, `muted` when false. The Toggle
              `.text` style draws it.
5. r1 c12-13  Enum value "eu" -- `info`. Arrows appear only on the focused row (see Focused).
6. r2 c12-14  Text value "omp" -- `primary`. A masked field paints the `secret` icon instead.
7. r3 c12-15  Select value "dark" -- `info`, then `▾` in `muted`. Opens a dropdown below the row.
8. r4 c12-15  Multi value "repo" -- `info`: the first two checked labels joined by a comma and a space, then ` +N` for the rest, then `▾` in `muted` (Picker summary). With no values checked, it reads `none` in `info`.
9. r5 c12-16  Number value "3" -- `primary` at c14, between a decrement arrow `◂` at c12 and an increment arrow `▸` at c16, both `muted`. The arrows show on every number row, focused or not, as Stepper does (owner decision, 2026-10-10).
10. scrollbar -- the rightmost column, drawn only when the content overflows the window.
    Not in this fixture; see Open questions.
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
B  fg=focus, bold
C  fg=primary
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
```

## States

### Unfocused

Unfocused, the Form draws no cursor and no bold label. Labels are `primary`, and every
value keeps its presentation: the bool in `success`, text, enum, select and multi values
in `info`, and the number in `primary` with muted arrows.

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
4. r1 c12-13, r3 c12-15, r4 c12-15 Values "eu", "dark", "repo" -- `info`; `▾` in `muted`.
5. r5 c12-16   Number "3" -- `primary`, between `muted` arrows.
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
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
```

### Focused: the enum field

Region is focused and its value is `eu`. The value sits between muted arrows, `◂` and `▸`,
so the row shows that it cycles: Left and Right step to the previous and next choice, and
Enter or Space cycle forward (see the Key table). The arrows show on the focused enum row
only (inferred; the number-row rule covers numbers, owner decision, 2026-10-10). The label
is `focus` bold, and the cursor takes the gutter.

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
3. r1 c12     Decrement arrow `◂` -- `muted`.
4. r1 c14-15  Value "eu" -- `info`.
5. r1 c17     Increment arrow `▸` -- `muted`.
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
B  fg=focus, bold
C  fg=primary
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
```

### Focused: the number field

The fixture's keys moved the cursor to Region and cycled it from `eu` to `ap`, then moved
it to Replicas and stepped the number from 3 to 4. Replicas is now focused. Its label
turns bold focus, and the number shows `◂ 4 ▸`, as it does unfocused: a muted decrement
arrow, one separator space, the value in `primary`, one separator space, and a muted
increment arrow. The arrows are the [Stepper](stepper.md) presentation and show on every
number row, focused or not (owner decision, 2026-10-10). The other rows show their
unfocused presentation.

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
3. r5 c12     Decrement arrow `◂` -- `muted`.
4. r5 c14     Value "4" -- `primary`.
5. r5 c16     Increment arrow `▸` -- `muted`.
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
C  fg=success (token pending plan 032 step 5.3)
D  fg=info (token pending plan 032 step 5.3)
E  fg=muted (token pending plan 032 step 5.3)
F  fg=focus, bold
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
2. r5 c12     Decrement arrow `<` -- `muted`.
3. r5 c16     Increment arrow `>` -- `muted`.
4. r3 c17, r4 c17  Dropdown glyph -- `v` in `muted`.
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
C  fg=success (token pending plan 032 step 5.3)
D  fg=info (token pending plan 032 step 5.3)
E  fg=muted (token pending plan 032 step 5.3)
F  fg=focus, bold
```

### Select dropdown open

Enter on the Theme row opens Picker's menu below the row (see
[Picker](picker.md#menu-collapsed-in-a-host-row)); Picker owns the keys and mouse rules
while it is open. The sub-cursor starts on the current choice (`dark`), drawn as a `focus`
`❯` on a radio mark. The picked choice shows `◉` in `accent`; the others show `○` in
`muted`. The sub-rows are indented four cells, and the rows below the dropdown move down
by one row per choice.

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
3. r3 c12-15  Select value "dark" -- `info`, then `▾` in `muted`, while the dropdown is open.
4. r4-r6 c4-5 Sub-cursor `❯` -- `focus` on the highlighted choice only.
5. r4 c6      Picked radio `◉` -- `accent`.
6. r5-r6 c6   Unpicked radio `○` -- `muted`.
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
C  fg=success (token pending plan 032 step 5.3)
D  fg=info (token pending plan 032 step 5.3)
E  fg=focus, bold
F  fg=muted (token pending plan 032 step 5.3)
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
3. r3 c12-15  Select value "dark" -- `info`; `v` in `muted` at c17 while open.
4. r4-r6 c4   Sub-cursor `>` -- `focus` on the highlighted choice only.
5. r4 c6-8    Picked choice `(*)` -- `accent`.
6. r5-r6 c6-8 Unpicked choices `( )` -- `muted`.
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
B  fg=focus, bold
C  fg=primary
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
G  fg=accent
```

### Multi dropdown open

Enter on the Scopes row opens Picker's multi-select menu below the row (see
[Picker](picker.md#menu-collapsed-in-a-host-row)). Checked choices show `☑` in `accent`;
unchecked show `☐` in `muted`. The sub-cursor is on Issues, which is checked, so its label
is `focus` bold. Space toggles the highlighted choice and the list stays open; Enter
closes it. Clicking a choice toggles it and keeps the list open. The row summary is
Picker's: the first two checked names joined by a comma and a space, then a space and `+N`
for the names past the first two. Here all three are checked, so the summary reads
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
3. r4 c12-26  Multi summary "repo, issues +1" -- `info`; `▾` in `muted` at c28.
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
B  fg=focus, bold
C  fg=primary
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
G  fg=accent
```

### Multi dropdown open, ASCII

ASCII marks the checkboxes `[x]` and `[ ]` and the cursor `>`, and the dropdown glyph is
`v` (see [Degradation](#degradation)). The summary keeps Picker's format; with two checked
names it has no `+N`, because `+N` counts only the names past the first two (inferred from
Picker).

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
3. r4 c12-23  Multi summary "repo, issues" -- `info`; `v` in `muted` at c25.
4. r5 c6-8    Checked box `[x]` -- `accent`; r7 c6-8 `[ ]` -- `muted`.
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
B  fg=focus, bold
C  fg=primary
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
G  fg=accent
```

### Validation: inline message

The Name field is blank and required; the cursor is on it. The Slug field holds
`Bad Slug`, which fails its pattern. A failing field paints its label in `error` and draws
the error icon `✘` in the gutter. The app supplies the wording:
`.required("Enter a name")` and `.pattern(_, message: "Use a-z, 0-9, and -")`. The first
failing message, required before pattern, paints after the value, two cells past it, or at
the value column when the value is blank. A message never adds a row. The focused failing
row keeps the cursor in the gutter, so it draws no icon; its label is bold `error`
instead.

When the app omits a message, the Form builds one from the label: `<Label> is required` or
`<Label> is invalid` (inferred default; see Open questions). The default is English text.
An app that localises its forms passes its own message for each rule (see Open questions).

**Placement: inline (owner decision, 2026-10-10).** The validation message is painted
inline after the value, never on a row of its own. A below-row placement, which the Wizard
uses, would move rows while the user types into a field, so it is not drawn. At 24 columns
the message keeps six cells and truncates; the value keeps its full width.

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
8. r1 c18-36  Message "Use a-z, 0-9, and -" -- `error`.
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
H  fg=error (token pending plan 032 step 5.3)
I  fg=error, bold (token pending plan 032 step 5.3)
```

### Validation: inline message, 24 columns

The same two fields at 24 columns, side by side. The message keeps only the cells after
the value and the gap, so it truncates with `…`. The value is never truncated.

```wireframe 24x2
❯ Name  Enter a name
✘ Slug  Bad Slug  Use a…
```

```text
Callouts (24x2, 0-based):
1. r0 c0-1    Cursor -- `focus` on the focused row.
2. r0 c8-19   Message "Enter a name" -- `error`, at the value column because the value is blank.
3. r1 c0      Error icon `✘` -- `error`.
4. r1 c8-15   Value "Bad Slug" -- `primary`, whole.
5. r1 c18-23  Message "Use a…" -- `error`; truncated at the right edge with `…`.
```

```text
── chars ──
❯ Name  Enter a name
✘ Slug  Bad Slug  Use a…
── style ──
A.IIII..HHHHHHHHHHHH
H.HHHH..CCCCCCCC..HHHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error (token pending plan 032 step 5.3)
I  fg=error, bold (token pending plan 032 step 5.3)
```

### Validation: inline message, ASCII

ASCII marks the failing field with `!` and a space in the two-cell gutter (owner decision,
2026-10-11). The focused failing row keeps the cursor `>` in the gutter and draws no icon.
Placement and truncation match the Unicode form.

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
H  fg=error (token pending plan 032 step 5.3)
I  fg=error, bold (token pending plan 032 step 5.3)
```

### Validation: below-row message (rejected)

The Wizard paints its message on the row below its field
([`wizard.rs` L258-L266](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/wizard.rs#L258-L266)).
The same two fields with the message below each one are drawn here and rejected. The
message adds a row: when Name starts failing, the Slug row moves down a row, and every row
under a failing field shifts while the user types. Inline avoids both.

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
6. r2 c8-14   Value "Bad Slug" -- `primary`.
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
H  fg=error (token pending plan 032 step 5.3)
I  fg=error, bold (token pending plan 032 step 5.3)
```

```wireframe 24x4
❯ Name
        Enter a name
✘ Slug  Bad Slug
        Use a-z, 0-9, a…
```

```text
Callouts (24x4, 0-based):
1. r0 c0-1    Cursor -- `focus`.
2. r0 c2-5    Label "Name" -- `error`, bold.
3. r1 c8-19   Message "Enter a name" -- `error`.
4. r2 c0      Error icon `✘` -- `error`.
5. r3 c8-23   Message "Use a-z, 0-9, a…" -- `error`; truncated at the right edge with `…`.
```

```text
── chars ──
❯ Name
        Enter a name
✘ Slug  Bad Slug
        Use a-z, 0-9, a…
── style ──
A.IIII
........HHHHHHHHHHHH
H.HHHH..CCCCCCCC
........HHHHHHHHHHHHHHHH
── legend ──
.  default
A  fg=focus
C  fg=primary
H  fg=error (token pending plan 032 step 5.3)
I  fg=error, bold (token pending plan 032 step 5.3)
```

### Mobile: the anatomy at 40 columns

The anatomy above is the 40-column state. The 80-column capture of the same fixture is
identical, row for row and style for style. The Form does not widen: rows keep their
natural width, and the label column does not grow beyond the widest label.

### Minimum: 12 columns (inferred)

Derived, not captured. The anatomy fixture's widest side-by-side row (the Theme row, 18
cells) fits at 24 columns without clipping, so the 24x6 window below shows every row side
by side. Below 24 columns the Form stacks (see [Narrow](#narrow-under-24-columns)). The
floor is the widest label plus four cells, 12 here (inferred; see Open questions). The
stacked rows fit at 12, and the multi dropdown summary tail-truncates there, which is not
captured.

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
in view. The scrollbar column is reserved on every row (c39). Its track and thumb draw
only because the content overflows (anatomy callout 10). The thumb sits at the bottom
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
3. r0-r1 c39  Track `│` -- `muted`.
4. r2-r3 c39  Thumb `█` -- `accent`.
5. r0-r3 c39  Reserved scrollbar column -- blank on every row unless the content overflows.
```

```text
── chars ──
  Name      omp                        │
❯ Theme     dark ▾                     │
  Scopes    repo ▾                     █
  Replicas  ◂ 3 ▸                      █
── style ──
..CCCC......CCC........................F
A.BBBBB.....EEEE.F.....................F
..CCCCCC....EEEE.F.....................G
..CCCCCCCC..F.C.F......................G
── legend ──
.  default
A  fg=focus
B  fg=focus, bold
C  fg=primary
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
G  fg=accent
```

### Narrow: under 24 columns

Below 24 columns the Form stacks each label above its value when a side-by-side row does
not fit (owner decision, 2026-10-11). `ViewThatFits` keeps the side-by-side layout when
every row fits. At 18 columns the reserved scrollbar column leaves 17 cells, and the Theme
row needs 18, so the whole form stacks: each label has its own row, and its value sits on
the row below, indented four cells. The stacked form is 12 rows; the 18x12 window shows
all of it, and no value truncates. The 18x6 window draws six rows and scrolls (see
Overflow).

```wireframe 18x12
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
Callouts (18x12, 0-based):
1. r0 c0      Cursor -- `❯` in `focus` on the focused Strict label.
2. r0 c2-7    Label "Strict" -- `focus` bold.
3. r1 c4-7    Value "true" -- `success`, indented four cells.
4. r2, r4, r6, r8, r10 c2+ Labels -- `primary`.
5. r3, r5, r7, r9 c4+ Values -- `info`, with `▾` in `muted` at c9 on r7 and r9.
6. r11 c4, c6, c8 Arrows `◂`, `3`, `▸` -- `muted`, `primary`, `muted`.
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
B  fg=focus, bold
C  fg=primary
D  fg=success (token pending plan 032 step 5.3)
E  fg=info (token pending plan 032 step 5.3)
F  fg=muted (token pending plan 032 step 5.3)
```

## State model

Schema: [README](../README.md#state-model-table).

| State            | Owner     | Type                                                                              | Reset or clamp rule                                                                                                                                                                                                                                                                                       |
| ---------------- | --------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| field values     | app       | `Binding` per field, typed per kind                                               | Written only through the binding. The Form keeps no copy, so discarding its NodeState loses no data.                                                                                                                                                                                                      |
| cursor           | NodeState | field index, `Int`                                                                | Clamped to the field count on every key. Chase keeps the cursor row visible.                                                                                                                                                                                                                              |
| scroll offset    | NodeState | row offset, `Int`                                                                 | Clamped to content rows minus window rows on every render.                                                                                                                                                                                                                                                |
| open dropdown    | NodeState | field index, `Int?`                                                               | Set when Picker's menu opens in a select or multi row (Enter, Space, or a click on the closed row). Cleared when it closes: Esc, Enter, a click outside, or focus loss. Focus loss closes without committing, as Esc does. The Form stores only the host row; Picker holds the list cursor and selection. |
| editing          | NodeState | `Bool`                                                                            | Set by Enter, Space, or a click on a text row. Cleared by Enter or Esc.                                                                                                                                                                                                                                   |
| pointer hover    | NodeState | row index, `Int?`                                                                 | Set by pointer movement over a row; the row paints the `hover` role. Never changes a value. The Form requests move input for this hover (owner decision, 2026-10-10).                                                                                                                                     |
| validation rules | app       | `required` `Bool` and `pattern` `Regex?`, each with an optional message `String?` | Set by the app's `.required(_:)` and `.pattern(_:message:)` modifiers and read on every render. The Form never stores them.                                                                                                                                                                               |
| validation       | derived   | first failing message, `String?`                                                  | Computed on every render; required is checked before pattern. The app's message, or the inferred default built from the label when omitted (Validation).                                                                                                                                                  |
| layout           | derived   | label width, stacked flag, content rows, window                                   | Recomputed at the proposed size on every layout; `ViewThatFits` sets the stacked flag when a side-by-side row does not fit. Never stored.                                                                                                                                                                 |

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

| Event      | Region        | Precondition                   | Effect                                                                                                                                                        | Consumed                                                  |
| ---------- | ------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| click      | row           | row index < field count        | Sets the cursor to that row, closes a dropdown open on a different row without committing (Picker's click-outside rule), and activates the row as Enter does. | yes                                                       |
| click      | open dropdown | a dropdown is open on any row  | Handled by Picker's menu (see [Picker](picker.md#menu-collapsed-in-a-host-row)); Form takes no action.                                                        | conditional (Picker's mouse rules)                        |
| click      | scrollbar     | content overflows the window   | Centers the scrollbar thumb on the pointer row, so the scroll offset follows the pointer.                                                                     | yes                                                       |
| drag       | scrollbar     | content overflows the window   | Moves the thumb to the pointer row while the button is held, as click does.                                                                                   | yes                                                       |
| wheel-up   | window        | no open list under the pointer | Scrolls the viewport up one row without moving the cursor.                                                                                                    | conditional (yes if the viewport moved; no at the top)    |
| wheel-down | window        | no open list under the pointer | Scrolls the viewport down one row without moving the cursor.                                                                                                  | conditional (yes if the viewport moved; no at the bottom) |
| move       | row           | row index < field count        | Sets the hover row, which paints the `hover` role and changes no value. Requested only because the rows paint hover (owner decision, 2026-10-10).             | no                                                        |

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

Width: natural width is the widest label plus 24 cells (`measure`). At 24 columns and
above, each label sits beside its value in the label column. Below 24 columns,
`ViewThatFits` stacks each label above its value when a side-by-side row does not fit (see
[Narrow](#narrow-under-24-columns)). The floor is the widest label plus four cells, 12
here (inferred; see Open questions). Height: content rows, one per field, two per field
while stacked, plus the rows of an open dropdown. No description row in 1.0 (owner
decision, 2026-10-11). The `MaxRows` cap is the only open question. The label column is
the widest label plus two cells, and values start after it.

| Proposal  | Result | Rule                                                                                                                                                                                         |
| --------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 32x6   | Ideal width is the widest label (`Replicas`, 8 cells) plus 24; height is the six content rows of the anatomy fixture.                                                                        |
| 24x6      | 24x6   | Tight fit at 24 columns: labels stay beside their values, and the anatomy fixture fits without clipping (see Minimum).                                                                       |
| 18x6      | 18x6   | Stacked, short: the reserved scrollbar column leaves 17 cells, so the Theme row no longer fits side by side. The stacked form is 12 rows; the ScrollView draws 6 and scrolls (see Overflow). |
| 18x12     | 18x12  | Stacked: each field is two rows; every value fits, so none truncates (see Narrow).                                                                                                           |
| 10x6      | 12x6   | Under-minimum: the width clamps to the 12-cell floor, inferred from the widest label plus four; the stacked rows fit at 12 (see Minimum).                                                    |
| 80x6      | 80x6   | Over-maximum: the Form fills the proposed width, keeps rows at natural width, and left-aligns content, so the 80-column capture matches the 40-column one row for row.                       |
| 40x6      | 40x6   | Anatomy fixture at the mobile width: six fields, no dropdown open.                                                                                                                           |
| 40x9      | 40x9   | Select-open and multi-open: each open dropdown adds three content rows below its field.                                                                                                      |
| 40x2      | 40x2   | Validation, inline: two fields; the message sits after the value and adds no row.                                                                                                            |
| 24x2      | 24x2   | Validation, inline, at 24 columns: the message keeps the cells after the value and the gap, and truncates with `…`.                                                                          |

## Environment

Tokens consumed. Roles marked pending are not yet in [tokens.md](../tokens.md) (plan 032
step 5.3).

- `primary`: labels, text and number values, unhighlighted choices, and the rest of the
  row.
- `focus` (`semantic.focus`): the cursor glyph, the focused label, and the highlighted
  choice in Picker's open list. The bold attribute follows the Focus border rule 3 (ASCII
  bold per rule 6).
- `muted`: unchecked and unpicked marks, the `▾` dropdown glyph, number arrows, `false`,
  and the scrollbar track. Not in `tokens.md`; token pending plan 032 step 5.3.
- `success`: `true`. Not in `tokens.md`; token pending plan 032 step 5.3.
- `accent`: checked and picked marks, `☑` and `◉`, and the scrollbar thumb.
  `semantic.accent` in `tokens.md` (owner decision, 2026-10-10).
- `info`: enum, select, and multi values. An empty multi value paints `none`, and an
  absent select value paints an em dash (Picker summary). Not in `tokens.md`; token
  pending plan 032 step 5.3.
- `error`: a failing field's label, its error icon, and its message. Not in `tokens.md`;
  token pending plan 032 step 5.3.
- `hover`: the background of the row under the pointer. Not in `tokens.md`; token pending
  plan 032 step 5.3.

## Primitive dependencies

- [Stepper](stepper.md) (specified): the number row's `◂ 4 ▸` presentation and steps. The
  Form shows the arrows on every number row, as Stepper does (owner decision, 2026-10-10).
- [Picker](picker.md) (specified): enum rows use its inline cycling. Select and multi rows
  are Picker's `.menu` collapsed in the row; its open list, keys, mouse rules and summary
  are Picker's ([menu collapsed in a host row](picker.md#menu-collapsed-in-a-host-row)).
  Multi-select is in Picker 1.0 (owner decision, 2026-10-11).
- [Toggle](toggle.md) (specified): the bool row. Inside a Form row, Toggle's `.text` style
  is the default and paints `true` or `false`; the standalone default is `.checkbox`. An
  explicit `.toggleStyle(_:)` on the Toggle or an ancestor wins. The row's focus rule (`❯`
  cursor and a bold focus-coloured label) applies, not the standalone underline (owner
  decision, 2026-10-10).
- [LabeledContent](labeled-content.md) (wireframed): the label-value row. A LabeledContent
  inside a Form keeps its own label column and does not join the Form's shared column.
  Space is often limited; alignment may become an option later (owner decision,
  2026-10-10).
- [TextField](text-field.md) (wireframed): text rows. Their editing keys are listed above;
  the relation to TextField's own editing model is open.
- [Label](../primitives/label.md) (wireframed): row labels, the `error` icon for a failing
  field, and the `secret` icon for masked fields.
- [ScrollIndicator](../primitives/scroll-indicator.md) (specified): the overflow scrollbar
  column.

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
- `form requests move input for its row hover and changes no value on move` (state model:
  pointer hover; mouse table: move)
- `bool row paints success when true and muted when false as text` (anatomy callout 4)
- `enum, select, and multi values paint info; select and multi show a muted dropdown glyph`
  (anatomy callouts 5, 7, 8)
- `focused enum row paints its value between muted arrows, as the number row does`
  (Focused: the enum field)
- `empty multi value paints none in info` (anatomy callout 8; Picker summary)
- `multi value joins the first two checked labels with a comma and adds +N for the rest`
  (anatomy callout 8; Picker summary)
- `absent select value paints an em dash in info` (Picker summary)
- `number value paints primary and shows its arrows on every number row, focused or not`
  (anatomy callout 9)
- `number arrows paint muted and stay in place around the value` (Focused: the number
  field)
- `select row opens Picker's menu below its row, with the cursor on the chosen option`
  (Select dropdown open; Picker closed keys)
- `multi row opens Picker's multi menu below its row, with a checkbox per choice` (Multi
  dropdown open; Picker closed keys)
- `picked radio and checked box paint accent; unpicked radio paints muted` (Select
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
- `validation message truncates before the value does at 24 columns` (Validation: inline
  message, 24 columns)
- `validation adds no row` (Validation: inline message; below-row message rejected)
- `form computes the first failing message, required before pattern` (state model:
  validation)
- `form lays out a LabeledContent in its own label column` (Primitive dependencies)
- `explicit toggle style on a form row overrides the text default` (Primitive
  dependencies: Toggle)
- `form at 80 columns is identical to the 40-column form` (Mobile)
- `form stacks each label above its value when a row does not fit side by side, before any truncation`
  (Narrow: under 24 columns)
- `form stacks each field into two rows while the layout is stacked` (Sizing: 18x12)
- `form keeps every stacked label and value whole at the 12-column floor` (Sizing: 10x6)
- `form reserves its scrollbar column on every row and draws it only on overflow` (anatomy
  callout 10; Overflow: 40x4)
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
- Below 24 columns: `ViewThatFits` takes the side-by-side layout when every row fits, and
  otherwise stacks each label above its value, the value on the row below, indented four
  cells (owner decision, 2026-10-11; see [Narrow](#narrow-under-24-columns)). Truncation
  applies only if the stacked layout still does not fit: the validation message truncates
  and then drops, and values tail-truncate with `…`. The floor is the widest label plus
  four cells, 12 here (inferred; see Open questions).

## Open questions

- **MaxRows cap.** The ScrollView caps the drawn rows at the proposed height, so the Form
  never draws past its window (owner decision, 2026-10-11). Open: whether the ideal height
  with no proposal is capped at a `MaxRows` count. Unblocks: an owner decision on
  `MaxRows`, and a capped capture if one is wanted.
- **Narrow floor.** The floor of 12 cells (widest label plus four) and the stacked
  layout's value indent are inferred, not owner decisions. Unblocks: owner confirmation,
  then a captured 12-column wireframe.
- **Default validation wording.** `<Label> is required` and `<Label> is invalid` are
  inferred defaults for omitted messages. Unblocks: owner confirmation of the template and
  its localisation (see Validation).

## Inspiration

No inbox entries yet.
