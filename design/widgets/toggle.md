---
kind: widget
status: specified
---

# Toggle

`Toggle` is Tessera's controlled Boolean control. The application owns its on/off value
through `Binding<Bool>`; Toggle retains only ephemeral press presentation in `NodeState`.
It presents the current value without owning or inventing application state. This is a
widget-layer design following the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
Explicit focus and keyboard delivery come from
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system), and
pointer delivery comes from the
[mouse and hit-testing slice](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

The standalone default presentation is omp2's checkbox, adopted by owner decision (omp2
review, 2026-10): `☑` when the binding is true and `☐` when it is false, followed by one
space and the required caller-supplied label. The charset selects the marker: the Nerd
Font charset swaps in U+F14A and U+F096, and the ASCII charset uses `[x]` and `[ ]`.
Inside a Form row the default is the `.text` style, which draws the bound value as the
words `true` or `false` (owner decision, 2026-10-10; see [Text style](#text-style)). The
label supplies the accessible name. The controlled, focus, keyboard, pointer, and enabled
contract is shared by every presentation.

The label is content (owner decision, 2026-10-18): where the control may take rows, a Form
row or a standalone Toggle in a VStack, it word-wraps at the proposed width, and wrapped
rows indent under the label's first column. See [Label wrapping](#label-wrapping). The
marker is chrome and stays on the first row, and so does a standalone `.text` value word,
which takes the marker's place. Inside a host row such as a Form row, the `.text` value
word is the row's value, and that is content: the host decides its row count, and a host
that fixes one row gets a marked cut (owner decision, 2026-10-18; see
[Text style](#text-style)).

## Prior art

- Ratatui has no direct Toggle widget in
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/`; copy that absence as useful
  contrast for a small, terminal-native on/off affordance with no widget-owned application
  state. Reject adding a retained model merely to make a checkbox convenient: the bound
  Boolean remains the source of truth.
- Apple SwiftUI [Toggle](https://developer.apple.com/documentation/swiftui/toggle)
  supplies the controlled Boolean vocabulary, label-based accessible naming, and
  environment-selected style direction. Copy those concepts; reject SwiftUI's broad family
  of platform-specific presentations as a second 1.0 interaction contract.
- Textual [Switch](https://textual.textualize.io/widgets/switch/) and
  [Checkbox](https://textual.textualize.io/widgets/checkbox/) provide contrasting terminal
  and text-mode on/off presentations. Copy their immediate state legibility; reject their
  widget-owned value model and the implication that a switch presentation changes
  activation semantics.
- omp2 `Checkbox`
  ([`checkbox.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/checkbox.rs#L12-L158))
  -- adopt its glyph set, one-cell marker plus separator geometry, and label underline
  focus mark (glyph resolution L99-119; paint L91-124). Reject its internal `checked` flag
  seeded by `Prop::Checked` (L27-29): the bound Boolean stays the source of truth.

## API direction

The implemented public API requires an application-owned Boolean binding:

```swift
public struct Toggle<Label: View>: View {
    public init(
        isOn: Binding<Bool>,
        @ViewBuilder label: () -> Label
    )
}

extension Toggle where Label == Text {
    public init(_ title: String, isOn: Binding<Bool>)
}
```

The `isOn` binding is mandatory: Toggle has no unbound or internally owned value. The
label builder is required and supplies the accessible name. Focus remains explicit at the
call site:

```swift
Toggle("Receive mail", isOn: isOn)
    .focusable(toggleFocusID)
    .focused(focused, equals: toggleFocusID)
```

Toggle renders from `EnvironmentValues.isFocused` and handles keyboard activation only
when `ResponderContext.isFocused` is true.

Built-in styles are a closed set chosen with `.toggleStyle(_:)`: `.checkbox`, `.circle`,
and `.text` (owner decision, 2026-10-10, for `.text`). They land with Toggle in plan 032
step 13.2, the same way Button's built-in styles do. The default depends on context:
standalone, Toggle uses `.checkbox`; inside a Form row, it uses `.text` (owner decision,
2026-10-10). An explicit `.toggleStyle(_:)` on the Toggle or on any ancestor, including
the Form, wins over the default, so `Form { ... }.toggleStyle(.checkbox)` gives
checkboxes. Resolution takes the nearest explicit style; the context default applies only
when none exists. There is no public `.automatic` style. Custom style configuration (a
`ToggleStyle` protocol for app-defined presentations) lands later and must preserve this
controlled and focus contract.

Inside a Form row the Form's row focus rule replaces the underline: the row shows the `❯`
cursor (`>` in ASCII) and the label turns bold in the `focus` role; the ASCII charset has
no colour, so its focused label is bold alone, the same mark as every other Form row and
Stepper (owner decision, 2026-10-10). A standalone Toggle keeps the underlined label. The
Form publishes its row context through the environment; the row focus rule and the `.text`
default both read it, and Toggle holds no Form-specific state.

## Anatomy

The natural, enabled, unfocused fixture shows an on Toggle with a `Text("Receive mail")`
label in the default Unicode charset. Owner decision, omp2 review, 2026-10: the glyphs,
label geometry, and underline focus mark are omp2's checkbox, adopted as-is. The marker
and its separator take two cells, so the natural width is 14 cells.

```wireframe 14x1
☑ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13  Toggle hit target -- complete allocated Toggle rectangle; primary press and
              release must both resolve to this same node. It is the sole mouse Region.
2. r0 c0      Checkbox marker -- `☑` for a true binding and `☐` for a false binding; `accent`
              when true, `secondary` when false.
3. r0 c2-c13  Label slot -- required caller-supplied Label in `primary`; content, wraps.
              Continuation rows indent to c2.
```

```text
── chars ──
☑ Receive mail
── style ──
ABBBBBBBBBBBBB
── legend ──
.  default
A  fg=accent
B  fg=primary
```

The false binding uses `☐` in `secondary`, with the same label geometry:

```wireframe 14x1
☐ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13  Toggle hit target -- complete allocation.
2. r0 c0      Checkbox marker -- `☐` for a false binding; `secondary`.
3. r0 c2-c13  Label slot -- required caller label in `primary`; content, wraps.
```

```text
── chars ──
☐ Receive mail
── style ──
CBBBBBBBBBBBBB
── legend ──
.  default
B  fg=primary
C  fg=secondary
```

In the Nerd Font charset, the same states use U+F14A for true and U+F096 for false, in the
same two-cell marker (glyph, then a real U+0020;
[Nerd Font cells](../tokens.md#nerd-font-cells)):

```wireframe 14x1
 Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c1  Marker and separator -- U+F14A for a true binding (`accent`) or U+F096 for false (`secondary`) in c0; a real U+0020 in c1 is the icon's second cell.
2. r0 c2-c13  Label slot -- unchanged from the Unicode state.
```

## States

### Mobile

`mobile` is 40 columns wide at natural height. A parent-forced full-width Toggle keeps its
one-row checkbox geometry while its `Toggle hit target` spans all 40 columns; the fixture
has no padded rows, so Toggle does not manufacture vertical fill (owner decision,
2026-10-10).

```wireframe 40x1
☑ Receive notifications
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c39 Toggle hit target -- the parent-forced allocation spans all 40 columns; the
   trailing cells are visually empty.
2. r0 c0      Checkbox marker -- `☑` in `accent` for a true binding; it remains at the leading edge.
3. r0 c2-c22 Label slot -- caller label within the full-width allocation; content, wraps (it fits one row at 40 columns).
```

### Label wrapping

The label is content (owner decision, 2026-10-18), not chrome: Toggle does not fix it to
one row, because a standalone Toggle in a VStack and a Toggle in a Form row may both take
rows. At a finite width the label word-wraps in the slot to the right of the marker; a
word wider than the slot breaks between grapheme clusters. Continuation rows indent to the
label's first column, so the marker column stays clear. The `Toggle hit target` is the
whole allocation, every row included. A nil width does not wrap, which gives the natural
14x1. A finite height is a row budget: the label fills it and the last visible row ends in
`…` (see [Text](../primitives/text.md#row-budget)). The label inherits `lineLimit` and
`truncationMode` from the environment, so an app can opt back into a single row with
`.lineLimit(1)`. Inside a Form row in the `.text` style the Form draws the row label and
applies its own wrap rule.

```wireframe 15x2
☑ Receive
  notifications
```

```text
Callouts (15x2, 0-based):
1. r0 c0-c1  Marker and separator -- `☑` in `accent`; first row only; chrome, one row.
2. r0 c2-c8  Label first row -- `Receive`; content, wraps.
3. r1 c2-c14 Label continuation -- `notifications`, indented under the label's first column; at a 16-column proposal the slot is 14 cells, so `Receive notifications` wraps after `Receive`.
4. r0-r1     Toggle hit target -- the whole 15x2 allocation, the widest displayed row.
```

### Minimum

The component-specific `min` floor is derived from the label (owner decision, 2026-10-18):
the marker and its separator, plus the label's widest word, at the rows the label needs at
that width. For `Text("Receive mail")` the widest word is `Receive` (7 cells), so the
floor is 9x2 under the Unicode charset and 11x2 under ASCII, where `[ ]` and its separator
take four cells. The 2026-10-10 charset floors, 2x1 Unicode and 4x1 ASCII, are the same
derivation for an empty label (widest word 0): the control is one complete marker, with no
partial marker and no lost value state. Below the label floor, the label breaks between
graphemes and never clips; below the marker floor, Toggle is suppressed.

```wireframe 9x2
☐ Receive
  mail
```

```text
Callouts (9x2, 0-based):
1. r0 c0-c1 Marker and separator -- false binding marker `☐` in `secondary`.
2. r0 c2-c8 Label -- `Receive`, the widest word, whole; content, wraps.
3. r1 c2-c5 Label continuation -- `mail`.
4. r0-r1    Toggle hit target -- complete Unicode minimum allocation for this label.
```

```wireframe 11x2
[ ] Receive
    mail
```

```text
Callouts (11x2, 0-based):
1. r0 c0-c3  Marker and separator -- `[ ]` and its separator, `secondary`.
2. r0 c4-c10 Label -- `Receive`, whole; content, wraps.
3. r1 c4-c7  Label continuation -- `mail`.
4. r0-r1     Toggle hit target -- complete ASCII minimum allocation for this label.
```

The empty-label floors:

```wireframe 2x1
☐
```

```text
Callouts (2x1, 0-based):
1. r0 c0-c1 Toggle hit target -- complete Unicode minimum allocation.
2. r0 c0 Checkbox marker -- false binding marker; the separator cell and the empty label have no visible cells.
```

```wireframe 4x1
[ ]
```

```text
Callouts (4x1, 0-based):
1. r0 c0-c3 Toggle hit target -- complete ASCII minimum allocation.
2. r0 c0-c2 Checkbox marker -- false binding marker; the separator cell and the empty label have no visible cells.
```

### Focused and pressed

Owner decision, omp2 review, 2026-10: the focus mark is an underline on the label; the
marker keeps its checked or unchecked colour. An explicit `FocusID` match selects focus
presentation. A phased press applies pressed presentation only from down through the
matching release; its resolved full pressed Style covers the same cells. Both states
preserve the checkbox's glyph geometry.

```wireframe 14x1
☑ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13  Toggle hit target -- complete allocation; focus and pressed presentation
              never change its geometry.
2. r0 c0      Checkbox marker -- `☑` in `accent`; unchanged by focus.
3. r0 c2-c13  Label slot -- `primary` with an underline while focused.
```

```text
── chars ──
☑ Receive mail
── style ──
ABBBBBBBBBBBBB
── legend ──
.  default
A  fg=accent
B  fg=primary underline
```

### Disabled

A disabled Toggle has no focus or activation presentation; all visible cells use
`disabled`.

```wireframe 14x1
☑ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13 Toggle hit target -- disabled; absent from focus and never activates.
```

```text
── chars ──
☑ Receive mail
── style ──
DDDDDDDDDDDDDD
── legend ──
D  fg=disabled
```

### ASCII

Owner decision, omp2 review, 2026-10: the ASCII charset falls back to `[x]` and `[ ]`,
each followed by one space, a four-cell marker. The literal marker needs no alternate
glyph. Standalone focus stays an underline on the label in every charset; inside a Form
row the row focus rule applies instead.

```wireframe 16x1
[x] Receive mail
```

```text
Callouts (16x1, 0-based):
1. r0 c0-c15 Toggle hit target -- unchanged ASCII allocation.
2. r0 c0-c2  Checkbox marker -- literal `[x]` in `accent`; no glyph substitution occurs.
3. r0 c4-c15 Label slot -- ordinary textual label in `primary`; content, wraps; a cut under a
              row budget uses the ASCII fallback `~`.
```

```text
── chars ──
[x] Receive mail
── style ──
AAABBBBBBBBBBBBB
── legend ──
.  default
A  fg=accent
B  fg=primary
```

### Circle style

The alternative built-in `.circle` style shows a filled `◉` marker for a true binding and
a hollow `○` marker for a false one, followed by one space and the label. It keeps every
interaction rule of the checkbox; only the marker differs. The Unicode circle marker takes
the same two cells as the Unicode checkbox, so both share one natural width. The ASCII
charset widens both the circle marker and the checkbox marker to four cells.

```wireframe 14x1
◉ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13 Toggle hit target -- complete allocation; interaction matches the checkbox
   style.
2. r0 c0 Circle marker -- filled `◉` for a true binding, in `accent`.
3. r0 c2-c13 Label slot -- required caller label in `primary` when idle; content, wraps.
```

The false state uses the hollow marker at the same geometry:

```wireframe 14x1
○ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0 Circle marker -- hollow `○` for a false binding.
2. r0 c2-c13 Label slot -- required caller label; content, wraps.
```

Under the ASCII charset the circle markers become the conventional terminal radio glyphs
`(*)` for true and `( )` for false; the three-cell ASCII marker plus its separator widens
the control by two cells to the ASCII checkbox geometry.

```wireframe 16x1
(*) Receive mail
```

- **Idle, enabled, unfocused:** the checked marker uses `accent`, the unchecked marker
  uses `secondary`, and the label uses `primary`.
- **Focused:** explicit `.focusable(id).focused(binding, equals: id)` composition injects
  `EnvironmentValues.isFocused` for presentation; Toggle accepts keyboard delivery only
  through `ResponderContext.isFocused`.
- **Pressed:** `isPressed` exists from an enabled primary down or phased keyboard down
  until matching release, cancellation, focus loss, disablement, or node removal. It is
  visual feedback only and never records application work.
- **Disabled:** Toggle is absent from the focusable list, never activates, and leaves
  keyboard and pointer input unconsumed so an ancestor may handle it. It does not receive
  focus for inspection in 1.0.
- **Overflow:** the label is content and wraps (see [Label wrapping](#label-wrapping)). It
  tail-truncates with `truncation.mark` only on the last visible row of a fixed row budget
  or an app-set `lineLimit`.
- **Pointer and touch:** a primary contact toggles only when press and release hit the
  same `Toggle hit target` node. Click-to-focus occurs before pointer activation.

### Text style

Owner decision, 2026-10-10. The `.text` style draws the bound value as a word in place of
the checkbox marker: `true` in `success` when the binding is true, `false` in `secondary`
when it is false. It has no marker or glyph, so the same words draw under the Unicode,
Nerd Font, and ASCII charsets. Inside a Form row the Form draws the row label, so the
style omits its label and draws only the word; the label remains the accessible name and
the Form's row rules apply (see [Form](form.md#anatomy)). Standalone, the word is followed
by one space and the label, with the checkbox's focus and press geometry.

Inside a Form row, a click anywhere on the row, including its label column and blank
space, acts as Enter on that row and inverts the bound value once (owner decision,
2026-10-10; see the [Form mouse table](form.md#mouse-table)). The Toggle's same-node
pointer rule above governs standalone use only.

Inside a host row the value word is the row's value, and it is content, like Picker's
collapsed value (owner decision, 2026-10-18). The host decides how many rows it gets: Form
stacks its label above the value before the value wraps, a value column narrower than the
word breaks it between grapheme clusters, and a host that fixes one row gets a marked cut
with `truncation.mark` (see Sizing). Standalone, the word takes the marker's place and
stays on the first row.

```wireframe 17x1
true Receive mail
```

```text
Callouts (17x1, 0-based):
1. r0 c0-c16  Toggle hit target -- complete allocated Toggle rectangle.
2. r0 c0-c3   Value word "true" -- `success`.
3. r0 c4      Separator -- one default cell.
4. r0 c5-c16  Label slot -- required caller-supplied label in `primary`; content, wraps, continuation rows indent to c5.
```

```text
── chars ──
true Receive mail
── style ──
DDDD.BBBBBBBBBBBB
── legend ──
.  default
B  fg=primary
D  fg=success
```

The false binding draws the word in `secondary`, with the same label geometry:

```wireframe 18x1
false Receive mail
```

```text
Callouts (18x1, 0-based):
1. r0 c0-c17  Toggle hit target -- complete allocated Toggle rectangle.
2. r0 c0-c4   Value word "false" -- `secondary`.
3. r0 c5      Separator -- one default cell.
4. r0 c6-c17  Label slot -- required caller-supplied label in `primary`; content, wraps, continuation rows indent to c6.
```

```text
── chars ──
false Receive mail
── style ──
EEEEE.BBBBBBBBBBBB
── legend ──
.  default
B  fg=primary
E  fg=secondary
```

## State model

| State                   | Owner       | Type                                                                                | Reset or clamp rule                                                                                                                                                                            |
| ----------------------- | ----------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bound value             | Binding     | `Bool`                                                                              | App-owned; Toggle reads it on every update and writes only the one inverted Boolean on a valid activation.                                                                                     |
| is enabled              | Environment | `Bool`                                                                              | Read on every reconciliation. A transition to `false` clears `isPressed`, removes the node from focusability, and prevents activation immediately.                                             |
| semantic Styles         | Environment | `primary`, `accent`, `secondary`, `disabled`, and `destructive` full `Style` values | Read on every render; nearest environment value wins. These roles are complete Styles, not foreground-color aliases.                                                                           |
| is focused              | Environment | `Bool`                                                                              | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Toggle reads it during rendering and checks `ResponderContext.isFocused` for events.                  |
| is pressed              | NodeState   | `Bool`                                                                              | Set for enabled primary down or phased Enter/Space down. Clear on matching release, cancellation, focus loss, disablement, node removal, and every update when unfocused.                      |
| label size and wrapping | derived     | `TerminalSize` and rendered grapheme range                                          | Recomputed from the proposed label slot on every layout; the label wraps at the slot width and tail-truncates only under a row budget; clamps to the allocated rectangle.                      |
| text value word         | derived     | `String`, `true` or `false`                                                         | Derived from `bound value` on every render; never stored. Read only by the `.text` style. In a host row it is content: it wraps, and a host that fixes one row cuts it with `truncation.mark`. |
| form-row context        | Environment | `Bool`                                                                              | Set by Form on each row; read on every render. Selects the `.text` default and omits the label in `.text`. An explicit `.toggleStyle` overrides the default.                                   |

The label closure is immutable widget configuration, not retained business state. A legacy
press-only Enter or Space event inverts `bound value` once and clears `isPressed` before
dispatch returns.

## Key table

| Key                  | Precondition                    | Effect                                                                                                                                                                                                                                     | Consumed |
| -------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- |
| Enter                | focused and is enabled          | For a phased stream, down sets `isPressed`; matching release inverts `bound value` once only if focus and enabled state still hold, then clears `isPressed`. A legacy press-only event inverts once and clears it before dispatch returns. | yes      |
| Space                | focused and is enabled          | For a phased stream, down sets `isPressed`; matching release inverts `bound value` once only if focus and enabled state still hold, then clears `isPressed`. A legacy press-only event inverts once and clears it before dispatch returns. | yes      |
| Enter                | focused and is enabled is false | Does not mutate `isPressed` or `bound value`; bubbles to ancestors.                                                                                                                                                                        | no       |
| Space                | focused and is enabled is false | Does not mutate `isPressed` or `bound value`; bubbles to ancestors.                                                                                                                                                                        | no       |
| printable characters | focused                         | Does not mutate Toggle state; bubbles to ancestors.                                                                                                                                                                                        | no       |

Press/release pairing uses the normalized key-event phase when available. A release after
focus loss, disablement, or node removal can only clear its ephemeral press state and
cannot invert `bound value`.

## Mouse table

| Event        | Region            | Precondition        | Effect                                                                                                                                                                                                | Consumed |
| ------------ | ----------------- | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| click        | Toggle hit target | is enabled          | Slice 5 first focuses the node when it is focusable; internal primary down sets `isPressed`, and primary release inverts `bound value` once only when both points hit this same node, then clears it. | yes      |
| click        | Toggle hit target | is enabled is false | Does not focus, press, or invert `bound value`; bubbles to an ancestor.                                                                                                                               | no       |
| double-click | Toggle hit target | is enabled          | Has no distinct Toggle gesture; each constituent valid same-node click follows the `click` row and therefore inverts once.                                                                            | yes      |
| drag         | Toggle hit target | is pressed is true  | Clears `isPressed` when release is outside this node; never inverts `bound value` for that release.                                                                                                   | no       |

The raw primary stream is internal so Toggle uses the same pressed feedback throughout its
implemented checkbox presentation. The public pointer contract is Slice 5 same-node tap
semantics, not a marker-only hit test or drag threshold.

## Sizing

The default checkbox style is label-hugging unless a parent forces a horizontal
allocation, and as tall as the wrapped label needs: one row at its natural width. Its
complete final allocation is the `Toggle hit target`.

| Proposal                                                          | Result | Rule                                                                                                                                                                                                                   |
| ----------------------------------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil with `Text("Receive mail")`                             | 14x1   | Natural default: one marker cell, one separator, and twelve label cells in Unicode and Nerd Font; ASCII renders 16x1.                                                                                                  |
| 16x1 with `Text("Receive mail")`                                  | 14x1   | Label-hugging: the proposal is not filled; the control keeps its natural width.                                                                                                                                        |
| 1x1 with an empty label, Unicode charset                          | 0x1    | Below the 2x1 Unicode floor: suppress the control rather than draw a partial marker or advertise an incomplete hit target.                                                                                             |
| 2x1 with an empty label, Unicode charset                          | 2x1    | At the Unicode floor: the one-cell marker and its separator are allocated; the empty label takes no cells.                                                                                                             |
| 3x1 with an empty label, ASCII charset                            | 0x1    | Below the 4x1 ASCII floor: suppress the control rather than draw a partial `[ ]` or advertise an incomplete hit target.                                                                                                |
| 4x1 with an empty label, ASCII charset                            | 4x1    | At the ASCII floor: the complete `[ ]` marker and its separator are allocated; the empty label takes no cells.                                                                                                         |
| 80x24 with `Text("Receive mail")`                                 | 14x1   | Extra available space does not make a label-hugging Toggle grow opportunistically.                                                                                                                                     |
| 40x1 forced frame allocation with `Text("Receive notifications")` | 40x1   | Parent-forced width expands the final hit target while preserving leading marker and label geometry, as shown by the mobile fixture.                                                                                   |
| 9x nil with `Text("Receive mail")`                                | 9x2    | The floor: marker, separator, and `Receive` whole on row 0, `mail` on row 1 (owner decision, 2026-10-18).                                                                                                              |
| 12x nil with `Text("Receive notifications")`                      | 12x3   | Slot is ten cells: `Receive`, then `notifications` starts its own row and breaks between graphemes into `notificati` and `ons`. <!-- codespell:ignore ons -->                                                          |
| 8x nil with `Text("Receive mail")`                                | 8x2    | Below the 9-column floor the slot is six cells: `Receiv` and `e mail`; the word breaks between graphemes and is never clipped. <!-- codespell:ignore receiv -->                                                        |
| 8x1 with `Text("Receive mail")`                                   | 8x1    | A finite height is a one-row budget: the last visible row is `Recei…`, so the control draws `☑ Recei…`.                                                                                                                |
| 4 x nil, `.text` in a host row, false binding                     | 4x2    | The value word is content in a host row (owner decision, 2026-10-18): `false` is wider than the 4-cell value column, so it breaks between graphemes into `fals` and `e`; nothing clips. <!-- codespell:ignore fals --> |
| 4x1, `.text` in a host row, false binding                         | 4x1    | A host that fixes one row gets a marked cut: `fal…`.                                                                                                                                                                   |

## Environment

`Toggle` consumes `isEnabled` and its roles: `primary` for the label, `accent` for a
checked marker, `secondary` for an unchecked marker, and `disabled` while disabled. Focus
is an underline on the label, so no focus Style applies to the mark. The marker glyph
resolves through the charset: Unicode `☑`/`☐`, Nerd Font U+F14A/U+F096, or ASCII
`[x]`/`[ ]`. `lineLimit` and `truncationMode` (environment) reach the label, which is
content, and the `.text` value word in a host row, which is content too; `truncation.mark`
defines overflow under a row budget. The `.text` style reads the bound value as `true` or
`false` and the form-row context to choose its default and omit its label (see Text
style).

> Deferred: custom Toggle styles (an app-defined `ToggleStyle`) and their environment
> inputs land in a later slice. `.toggleStyle(.checkbox)`, `.toggleStyle(.circle)`, and
> `.toggleStyle(.text)` land with Toggle, with the circle's ASCII radio glyphs.

## Primitive dependencies

- [Text](../primitives/text.md) renders labels and applies grapheme-safe truncation.
- [Style modifiers](../primitives/style-modifiers.md) apply the resolved complete semantic
  Styles without reducing them to foreground colors.
- [Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system)
  supplies the focus manager, explicit `FocusID`, focusable list, and key routing.
- [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing) supplies hit testing,
  click-to-focus ordering, and same-node primary tap delivery.

## Requirements

- `toggle displays the bound true value with the checkbox marker` (anatomy: natural
  fixture).
- `toggle displays the bound false value at the minimum floor` (states: minimum fixture).
- `toggle keeps a parent-forced mobile row as one full-width hit target` (states: mobile
  fixture; sizing: forced frame allocation).
- `toggle label word-wraps at a finite width and indents continuation rows under the label`
  (states: label wrapping fixture; sizing: 9x nil, 12x nil).
- `toggle overlong label word breaks between graphemes instead of clipping` (sizing: 8x
  nil).
- `toggle label under a one-row budget ends its last visible row in the truncation mark`
  (sizing: 8x1).
- `toggle minimum is the marker plus the label's widest word` (states: minimum fixtures;
  sizing: 9x nil).
- `toggle preserves checkbox geometry for focus and press feedback` (states: focused and
  pressed fixture).
- `disabled toggle is absent from focus and bubbles activation input` (states: disabled;
  key table: disabled Enter and Space; mouse table: disabled click).
- `enter toggles the bound value exactly once across phased and legacy input` (key table:
  Enter).
- `space toggles the bound value exactly once across phased and legacy input` (key table:
  Space).
- `pointer activation focuses before one same-node value inversion` (mouse table: enabled
  click).
- `toggle clears a pending press when a pointer release leaves its node` (mouse table:
  drag).
- `toggle suppresses rather than partially draws below its minimum floor` (sizing: 1x1
  Unicode; 3x1 ASCII).
- `checkbox marker falls back to [x] and [ ] under the ASCII charset` (states: ASCII
  fixture; degradation: ASCII).
- `toggle draws checked and unchecked markers in accent and secondary` (anatomy: natural
  and unchecked fixtures).
- `toggle draws Nerd Font markers under the Nerd Font charset` (anatomy: Nerd Font
  fixture; degradation: Nerd Font).
- `standalone focused toggle marks its label with an underline and keeps its marker colour`
  (states: focused and pressed fixture).
- `focused toggle in a form row shows the row cursor and a bold focus label without an underline`
  (API direction: Form rows; [Form](form.md) key table).
- `circle style displays a filled marker for true and a hollow marker for false` (circle
  style fixtures).
- `circle style falls back to (*) and ( ) under the ASCII charset` (circle style: ASCII
  fixture).
- `standalone toggle defaults to the checkbox style and a toggle in a form row to the text style`
  (API direction; Text style).
- `explicit toggle style on the toggle or any ancestor, including a form, overrides the form-row text default`
  (API direction: `Form { ... }.toggleStyle(.checkbox)`).
- `text style draws true in success and false in secondary with no marker` (Text style
  fixtures).
- `text style in a form row draws only the value word and keeps the label as accessible name`
  (Text style; Form anatomy).
- `standalone text style draws the value word, one space, then the label` (Text style).
- `text style keeps the checkbox keyboard, pointer, focus, and disabled contract` (key
  table; mouse table; states).
- `a click anywhere on a text-style Form row acts as Enter and inverts the value once`
  (Text style; [Form](form.md) mouse table).
- `text style value word in a host row breaks between graphemes in a narrow value column`
  (sizing: 4 x nil, `.text` in a host row).
- `text style value word under a fixed one-row host ends in the truncation mark` (sizing:
  4x1, `.text` in a host row).

## Degradation

- **Default charset:** Unicode is the default charset of the first implementation (owner
  decision, 2026-10-10); ASCII is the fallback charset.
- **NO_COLOR:** semantic roles retain their attribute-only fallbacks; focus feedback is
  the label underline, which needs no colour, and checkbox glyphs remain unchanged.
- **16-color:** roles follow their slots columns in [roles](../tokens.md#roles); checkbox
  glyphs remain unchanged.
- **ASCII charset:** `☑`, `☐`, and the Nerd Font glyphs are not drawn; the ASCII charset
  draws `[x]` and `[ ]`, each followed by one space. If a label is cut under a row budget,
  `truncation.mark` becomes `~`.
- **Nerd Font:** the Nerd Font charset draws U+F14A and U+F096 in the same two-cell marker
  in place of the Unicode glyphs. It is a charset choice, not a capability.
- **Circle style:** the `◉`/`○` markers become radio glyphs `(*)`/`( )`; the three-cell
  ASCII marker widens the control by two cells without changing interaction.
- **Below minimum:** below the label floor (9 columns for `Receive mail` under Unicode, 11
  under ASCII), the label breaks between graphemes and wraps to more rows; it is never
  clipped, and a fixed height marks the last visible row. Below the marker floor (2x1
  Unicode, 4x1 ASCII), Toggle reports 0x1 and paints no partial marker or hit target.
- **Text style:** the words `true` and `false` draw under every charset. Under NO_COLOR
  the `success` and `secondary` difference is lost, so the words are the only signal; they
  remain.

## Deferred beyond 1.0

- **Label-less Toggle:** deferred beyond 1.0. Unblock only when the public accessibility
  policy defines a non-label accessible-name source and an exact initializer contract.
- **Switch-style presentation:** deferred beyond 1.0. Unblock only when a proposed
  `ToggleStyle` proves a switch can preserve the checkbox keyboard, pointer, focus, and
  disabled contract through fixtures and interaction tables.
- **Custom `ToggleStyle` representation:** concrete configuration, type-erasure, and
  environment key signatures for app-defined styles are deferred to the
  [Slice 7 catalog integration contract](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
  Unblock only when that contract names the custom style representation without weakening
  Toggle's required `Binding<Bool>` initializer. The built-in `.checkbox`, `.circle`, and
  `.text` styles do not wait for it.

## Inspiration

A Toggle should make the app-owned Boolean obvious at a glance and change it with one
unambiguous action. It must never conceal application state behind a widget model.
