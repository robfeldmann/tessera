---
kind: widget
status: ready
---

# Picker

`Picker` is Tessera's controlled, single-selection control over an app-supplied finite
option set. The application owns both that set and the selected value through
`Binding<Selection>`; Picker only derives which supplied option is selected and renders it
between inline navigation chevrons. It retains no business data and never invents a
selection. This is a widget-layer design following the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase),
with explicit focus supplied by
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system) and
pointer delivery supplied by [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

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
  the controlled selection binding, finite choices, label-builder vocabulary, and
  environment-selected style direction. Reject a menu, wheel, or popover presentation in
  1.0; the terminal standard is inline cycling only.
- Textual [Select](https://textual.textualize.io/widgets/select/) -- copy its compact
  presentation of the current choice. Reject its transient expanded list and
  widget-retained choice state; both are outside this controlled first release.

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

Picker renders from `EnvironmentValues.isFocused` and handles keys only when
`ResponderContext.isFocused` is true.

> Deferred: `PickerStyle`, `pickerStyle`, custom chrome, and style configuration land in a
> later slice. They must preserve the implemented selection, keyboard, pointer, enabled,
> and focus behavior.

## Anatomy

The 1.0 standard presentation is one inline cycling row. `Medium` is the currently
selected option's label. Both chevrons stay visible at an endpoint so the control keeps a
stable, recognizable shape; unavailable directions are inert rather than wrapping.

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

## States

### Mobile

`mobile` is the canonical 40x16 viewport. Picker keeps its natural one-row, label-hugging
geometry; the fifteen blank rows are not Picker output.

```wireframe 40x16
‹ Medium ›















```

```text
Callouts (40x16, 0-based):
1. r0 c0-c9 Picker hit target -- the inline row stays label-hugging at the mobile viewport.
2. r0 c0    previous chevron -- visible navigation affordance.
3. r0 c2-c7 value slot -- selected option label, not stretched to viewport width.
4. r0 c9    next chevron -- visible navigation affordance.
5. r1-r15  Unoccupied viewport -- not Picker output; blank buffer cells remain blank.
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
row `semantic.accent`; its cells and geometry do not change.

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

## State model

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
state. 1.0 has no expanded presentation, so it needs no open or reveal `NodeState`.
`NodeState`.

## Key table

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
the boundary behavior of [ScrollView](scroll-view.md).

## Mouse table

`click` means a primary click. Picker uses Slice 5 hit testing: a click in the value slot
installs this Picker's explicit focus before it attempts selection.

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

## Sizing

Results use the `Medium` fixture label. Picker is one row high, measures the selected
label or placeholder at its ideal width, and does not opportunistically grow into surplus
space.

| Proposal  | Result | Rule                                                                                                                  |
| --------- | ------ | --------------------------------------------------------------------------------------------------------------------- |
| nil x nil | 10x1   | Natural inline result: six `Medium` label cells, two spaces, and two one-cell chevrons.                               |
| 10x1      | 10x1   | Tight fit retains the full natural presentation.                                                                      |
| 4x1       | 4x1    | Below the `5x1` floor, omit the value slot and retain the two directional affordances without drawing partial glyphs. |
| 80x24     | 10x1   | Extra width and height do not enlarge a label-hugging inline Picker.                                                  |

## Environment

next choice predictable, not hide selection policy in private widget state.
