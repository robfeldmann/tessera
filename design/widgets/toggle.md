---
kind: widget
status: ready
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

The implemented presentation is the ASCII-safe checkbox: `[x]` when the binding is true
and `[ ]` when it is false, followed by one space and the required caller-supplied label.
The label supplies the accessible name. The controlled, focus, keyboard, pointer, and
enabled contract is shared by every future presentation.

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

> Deferred: `ToggleStyle`, environment-selected styles, the `.circle` presentation, and
> custom style configuration land in a later slice. They must preserve this controlled and
> focus contract.

## Anatomy

The natural, enabled, unfocused fixture shows an on Toggle with a `Text("Receive mail")`
label. The checkbox marker is ASCII-safe; it needs no alternate glyph under ASCII-only
capability.

```wireframe 16x1
[x] Receive mail
```

```text
Callouts (16x1, 0-based):
1. r0 c0-c15 Toggle hit target -- complete allocated Toggle rectangle; primary press and
   release must both resolve to this same node. It is the sole mouse Region.
2. r0 c0-c2 Checkbox marker -- `[x]` for a true binding and `[ ]` for a false binding;
   system checkbox chrome using `semantic.secondary` when idle.
3. r0 c4-c15 Label slot -- required caller-supplied Label, using `semantic.primary` when
   idle; default textual labels tail-truncate at grapheme boundaries in their allocation.
```

## States

### Mobile

`mobile` is the canonical 40x16 viewport. A parent-forced full-width Toggle keeps its
one-row checkbox geometry while its `Toggle hit target` spans all 40 columns; the blank
rows demonstrate that Toggle does not manufacture vertical fill.

```wireframe 40x16
[x] Receive notifications















```

```text
Callouts (40x16, 0-based):
1. r0 c0-c39 Toggle hit target -- the parent-forced allocation is the target even where
   the trailing cells are visually empty.
2. r0 c0-c2 Checkbox marker -- true binding marker; it remains at the leading edge.
3. r0 c4-c24 Label slot -- caller label within the full-width allocation.
```

### Minimum

The component-specific `min` floor is 3x1: an empty label still preserves one complete
checkbox marker. It is the smallest useful control that neither draws a partial marker nor
loses the value's visible state.

```wireframe 3x1
[ ]
```

```text
Callouts (3x1, 0-based):
1. r0 c0-c2 Toggle hit target -- complete minimum allocation.
2. r0 c0-c2 Checkbox marker -- false binding marker; the empty label has no allocated
   visible cells.
```

### Focused and pressed

Focused and pressed states preserve the checkbox's glyph geometry. An explicit `FocusID`
match selects focus presentation; a phased press applies pressed presentation only from
down through the matching release.

```wireframe 16x1
[x] Receive mail
```

```text
Styled-grid overlay (16x1):
[x] Receive mail
AAAAAAAAAAAAAAAA
Legend: A = `semantic.focus` full Style for the focused checkbox presentation; the
pressed overlay uses that resolved full pressed Style on the same cells.
```

### Disabled

A disabled Toggle has no focus or activation presentation; all visible cells use
`semantic.disabled`.

```wireframe 16x1
[x] Receive mail
```

```text
Styled-grid overlay (16x1):
[x] Receive mail
DDDDDDDDDDDDDDDD
Legend: D = `semantic.disabled` full Style.
```

### ASCII

The default marker is already ASCII-safe. ASCII-only capability changes focus styling to
its shared bold fallback but does not substitute `[x]` or `[ ]`.

```wireframe 16x1
[x] Receive mail
```

```text
Callouts (16x1, 0-based):
1. r0 c0-c15 Toggle hit target -- unchanged ASCII-safe allocation.
2. r0 c0-c2 Checkbox marker -- literal `[x]` marker; no glyph substitution occurs.
3. r0 c4-c15 Label slot -- ordinary textual label; truncation uses the ASCII fallback only
   if truncation is required.
```

### Deferred circle style

> Deferred: The `.circle` presentation lands in a later slice; the following fixtures
> preserve its design intent and are not part of the implemented presentation.

The alternative built-in `.circle` style shows a filled `◉` marker for a true binding and
a hollow `○` marker for a false one, followed by one space and the label. It keeps every
interaction rule of the checkbox; only the marker differs. The Unicode marker is one cell
wide, so the circle style is two cells narrower than the checkbox for the same label until
ASCII-only capability widens the marker.

```wireframe 14x1
◉ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0-c13 Toggle hit target -- complete allocation; interaction matches the checkbox
   style.
2. r0 c0 Circle marker -- filled `◉` for a true binding; `semantic.secondary` when idle.
3. r0 c2-c13 Label slot -- required caller label in `semantic.primary` when idle.
```

The false state uses the hollow marker at the same geometry:

```wireframe 14x1
○ Receive mail
```

```text
Callouts (14x1, 0-based):
1. r0 c0 Circle marker -- hollow `○` for a false binding.
2. r0 c2-c13 Label slot -- required caller label.
```

Under ASCII-only capability the circle markers become the conventional terminal radio
glyphs `(*)` for true and `( )` for false; the three-cell ASCII marker widens the control
by two cells to the checkbox geometry.

```wireframe 16x1
(*) Receive mail
```

- **Idle, enabled, unfocused:** the checkbox marker uses `semantic.secondary` and the
  label uses `semantic.primary`.
- **Focused:** explicit `.focusable(id).focused(binding, equals: id)` composition injects
  `EnvironmentValues.isFocused` for presentation; Toggle accepts keyboard delivery only
  through `ResponderContext.isFocused`.
- **Pressed:** `isPressed` exists from an enabled primary down or phased keyboard down
  until matching release, cancellation, focus loss, disablement, or node removal. It is
  visual feedback only and never records application work.
- **Disabled:** Toggle is absent from the focusable list, never activates, and leaves
  keyboard and pointer input unconsumed so an ancestor may handle it. It does not receive
  focus for inspection in 1.0.
- **Overflow:** default textual labels tail-truncate within their allocated label slot at
  grapheme boundaries using `truncation.mark`.
- **Pointer and touch:** a primary contact toggles only when press and release hit the
  same `Toggle hit target` node. Click-to-focus occurs before pointer activation.

## State model

| State                     | Owner       | Type                                                                                                                             | Reset or clamp rule                                                                                                                                                           |
| ------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| bound value               | Binding     | `Bool`                                                                                                                           | App-owned; Toggle reads it on every update and writes only the one inverted Boolean on a valid activation.                                                                    |
| is enabled                | Environment | `Bool`                                                                                                                           | Read on every reconciliation. A transition to `false` clears `isPressed`, removes the node from focusability, and prevents activation immediately.                            |
| semantic Styles           | Environment | `semantic.primary`, `semantic.secondary`, `semantic.accent`, `semantic.disabled`, and `semantic.destructive` full `Style` values | Read on every render; nearest environment value wins. These roles are complete Styles, not foreground-color aliases.                                                          |
| is focused                | Environment | `Bool`                                                                                                                           | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Toggle reads it during rendering and checks `ResponderContext.isFocused` for events. |
| is pressed                | NodeState   | `Bool`                                                                                                                           | Set for enabled primary down or phased Enter/Space down. Clear on matching release, cancellation, focus loss, disablement, node removal, and every update when unfocused.     |
| label size and truncation | derived     | `TerminalSize` and rendered grapheme range                                                                                       | Recomputed from the proposed label slot on every layout; clamps to the allocated rectangle and tail-truncates default text.                                                   |

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

The default checkbox style is one row high and label-hugging unless a parent forces a
horizontal allocation. Its complete final allocation is the `Toggle hit target`.

| Proposal                                                          | Result | Rule                                                                                                                                   |
| ----------------------------------------------------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil with `Text("Receive mail")`                             | 16x1   | Natural default: three marker cells, one separator, and twelve label cells.                                                            |
| 16x1 with `Text("Receive mail")`                                  | 16x1   | Tight fit preserves the complete on checkbox and full label.                                                                           |
| 2x1 with an empty label                                           | 0x1    | Below the 3x1 floor, suppress the control rather than draw a partial checkbox or advertise an incomplete hit target.                   |
| 80x24 with `Text("Receive mail")`                                 | 16x1   | Extra available space does not make a label-hugging Toggle grow opportunistically.                                                     |
| 40x1 forced frame allocation with `Text("Receive notifications")` | 40x1   | Parent-forced width expands the final hit target while preserving leading checkbox and label geometry, as shown by the mobile fixture. |

## Environment

`Toggle` consumes `isEnabled` and its implemented semantic Styles: `semantic.primary` for
the label, `semantic.secondary` for the checkbox marker, `semantic.focus` while focused,
and `semantic.disabled` while disabled. The checkbox marker is literal ASCII and needs no
`ascii` substitution; `truncation.mark` defines default-label overflow.

> Deferred: custom Toggle styles, `toggleStyle`, `focus.border`, circle glyph degradation,
> and custom-style environment inputs land in a later slice.

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
- `toggle suppresses rather than partially draws below its minimum floor` (sizing: 2x1).
- `default checkbox marker remains literal under ascii-only capability` (states: ASCII
  fixture; degradation: ASCII-only).

> Deferred: Circle-style rendering and its ASCII radio-glyph degradation land in a later
> slice. The circle fixtures above preserve that design intent.

## Degradation

- **NO_COLOR:** semantic roles retain their attribute-only fallbacks; focus feedback is
  bold, and checkbox glyphs remain unchanged.
- **16-color:** semantic roles use their indexed-color-plus-attribute fallbacks; checkbox
  glyphs remain unchanged.
- **ASCII-only:** `[x]` and `[ ]` are already ASCII-safe. If a label truncates,
  `truncation.mark` becomes `~`.
- **Deferred circle style:** the `◉`/`○` markers become radio glyphs `(*)`/`( )`; the
  three-cell ASCII marker widens the control by two cells without changing interaction.
- **Below minimum:** below 3x1, Toggle reports 0x1 and paints no partial marker or hit
  target.

## Open questions

- **Label-less Toggle:** deferred beyond 1.0. Unblock only when the public accessibility
  policy defines a non-label accessible-name source and an exact initializer contract.
- **Switch-style presentation:** deferred beyond 1.0. Unblock only when a proposed
  `ToggleStyle` proves a switch can preserve the checkbox keyboard, pointer, focus, and
  disabled contract through fixtures and interaction tables.
- **`ToggleStyle` representation:** concrete configuration, type-erasure, and environment
  key signatures are deferred to the
  [Slice 7 catalog integration contract](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
  Unblock only when that contract names the standard/custom style representation without
  weakening Toggle's required `Binding<Bool>` initializer.

## Inspiration

A Toggle should make the app-owned Boolean obvious at a glance and change it with one
unambiguous action. It must never conceal application state behind a widget model.
