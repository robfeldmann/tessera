---
kind: widget
status: ready
---

# Stepper

`Stepper<Value>` is Tessera's controlled bounded numeric control for values where `Value`
is `Comparable & Strideable` and `Value.Stride` is `Comparable & SignedNumeric`. The
application owns its `Binding<Value>` and supplies immutable closed-range and stride
configuration; Stepper only derives its formatted display and a pending step, while
retaining at most transient press feedback in `NodeState`. It presents two obvious
affordances for bounded arithmetic without privately retaining or silently normalizing the
numeric value.

This widget follows the controlled-widget rule in
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).
Its explicit focus and key delivery come from
[Slice 4](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system), and its
pointer delivery from [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Prior art

- Ratatui's widgets in `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/` provide
  compact terminal-control and layout vocabulary, but no direct Stepper contract. Copy
  their compact, adjacent-control presentation; reject application-owned event dispatch
  and any private numeric state because a Tessera Stepper writes its binding through the
  responder chain.
- Apple SwiftUI [Stepper](https://developer.apple.com/documentation/swiftui/stepper)
  supplies the bounded-value and increment/decrement vocabulary. Copy its generic numeric
  surface and single focusable control with directional adjustment; reject custom labels
  and platform-specific presentation variants.

## API direction

The implemented public API is `Stepper<Value>`:

```swift
public struct Stepper<Value>: View
where Value: Comparable & Strideable,
      Value.Stride: Comparable & SignedNumeric {
    public init(
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value.Stride = 1
    )

    public init<Format>(
        value: Binding<Value>,
        in range: ClosedRange<Value>,
        step: Value.Stride = 1,
        format: Format
    ) where Format: FormatStyle,
            Format.FormatInput == Value,
            Format.FormatOutput == String
}
```

Focus stays explicit at the call site:

```swift
Stepper(value: value, in: 0...10)
    .focusable(stepperFocusID)
    .focused(focused, equals: stepperFocusID)
```

Stepper renders from `EnvironmentValues.isFocused` and handles keys only when
`ResponderContext.isFocused` is true.

`step` MUST be positive (`step > .zero`); invalid configuration is a programmer error
before a Stepper node is created. For an in-range binding, each enabled user action
advances or retreats by that signed stride and clamps the resulting write to the supplied
closed range, so a final partial stride lands exactly on its endpoint. For fixed-width
integers whose `Stride` is `Int`, Stepper instead uses reporting-overflow arithmetic: it
converts the positive `Int` stride exactly to `Value`, and an unrepresentable stride
writes the requested range endpoint directly. The implemented presentation is
`[-] 42 [+]`: an ASCII-safe decrement affordance, the formatted binding value, and an
ASCII-safe increment affordance. The default display is `String(describing: value)`; the
format overload instead renders with the supplied `FormatStyle`. Formatting is not a
second binding or an editing surface, and it preserves any app-supplied out-of-range value
until the user activates a step.

The Showcase's Layout Explorer demonstrates a decimal specimen: one `Double` `ratio`
binding with range `0...1` and step `0.25`. Its ratio summary and Stepper display decimal
text, then map the selected quarter deterministically to the existing
`FlexConstraint.ratio(Int, Int)` representation.

> Deferred: `StepperStyle`, custom chrome, endpoint-specific affordance styles, and the
> `.compact` presentation land in a later slice. They must preserve this stepping and
> focus contract.

## Anatomy

Natural fixture: an enabled, unfocused Stepper with an interior value of `42`.

```wireframe 10x1
[-] 42 [+]
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Stepper hit target -- the one allocated, focusable node; it contains both
   affordances and the value slot.
2. r0 c0-c2 decrement affordance -- literal `[-]`; inherits the Stepper row's resolved
   Style.
3. r0 c4-c5 value slot -- formatted binding value; the default presentation reserves its
   full formatted width rather than silently rewriting it.
4. r0 c7-c9 increment affordance -- literal `[+]`; inherits the Stepper row's resolved
   Style.
```

## States

### Mobile

`mobile` is the canonical 40x16 viewport. The Stepper retains its natural one-row,
label-hugging size at the top-left; the remaining cells are unoccupied viewport, not
component padding.

```wireframe 40x16
[-] 42 [+]















```

```text
Callouts (40x16, 0-based):
1. r0 c0-c9 Stepper hit target -- the complete 10-cell focusable control; it does not
   stretch merely because the viewport is wider.
2. r0 c0-c2 decrement affordance -- available decrement action.
3. r0 c4-c5 value slot -- formatted interior binding value.
4. r0 c7-c9 increment affordance -- available increment action.
5. r1-r15 Unoccupied viewport -- not Stepper output; blank buffer cells remain blank.
```

### Minimum

The declared normal-rendering floor is `9x1`: both three-cell affordances, their two
separators, and at least one value cell remain visible. This fixture is the minimum value;
the decrement affordance is inert.

```wireframe 9x1
[-] 0 [+]
```

```text
Callouts (9x1, 0-based):
1. r0 c0-c8 Stepper hit target -- declared component floor and the one focusable node.
2. r0 c0-c2 decrement affordance -- `semantic.disabled` because the binding equals its
   configured minimum; it remains visible but is not an activation target.
3. r0 c4 value slot -- one-cell formatted minimum value.
4. r0 c6-c8 increment affordance -- available increment action.
```

### Interior value

An interior value leaves both actions available. The control remains one focusable node,
not three separately focusable buttons.

```wireframe 10x1
[-] 42 [+]
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Stepper hit target -- one focusable node for keyboard and pointer routing.
2. r0 c0-c2 decrement affordance -- available decrement action.
3. r0 c4-c5 value slot -- formatted binding value `42`.
4. r0 c7-c9 increment affordance -- available increment action.
```

### Maximum

At the configured maximum, the increment affordance remains visible but renders inert in
`semantic.disabled`. The decrement affordance remains available.

```wireframe 10x1
[-] 99 [+]
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Stepper hit target -- one focusable node despite an inert child affordance.
2. r0 c0-c2 decrement affordance -- available decrement action.
3. r0 c4-c5 value slot -- formatted maximum binding value `99`.
4. r0 c7-c9 increment affordance -- `semantic.disabled` because the binding equals its
   configured maximum; it is visible but does not activate.
```

### Focused

Only an explicit app-installed `FocusID` match makes the control focused; focus is never
inferred from layout position. The implemented borderless presentation applies
`semantic.focus` to its complete resolved row without changing geometry.

```wireframe 10x1
[-] 42 [+]
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Stepper hit target -- focused through explicit modifier composition.
2. r0 c0-c2 decrement affordance -- available action in the resolved focused Style.
3. r0 c4-c5 value slot -- unchanged formatted binding value.
4. r0 c7-c9 increment affordance -- available action in the resolved focused Style.
```

### Disabled

A disabled Stepper is absent from the focusable list, never activates, and leaves every
key and click unconsumed so an ancestor may handle it. All visible cells use
`semantic.disabled`.

```wireframe 10x1
[-] 42 [+]
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Stepper hit target -- rendered but not focusable or interactive.
2. r0 c0-c2 decrement affordance -- disabled presentation and inert pointer region.
3. r0 c4-c5 value slot -- disabled presentation of the unchanged binding value.
4. r0 c7-c9 increment affordance -- disabled presentation and inert pointer region.
```

### Out-of-range binding value

An application may supply an out-of-range binding value. Stepper displays that value
through its selected format and never rewrites the binding during reconciliation. The next
enabled user step clamps the supplied value to `minimum...maximum` and writes that
in-range result; for example, either enabled step from a displayed `101` with maximum `99`
writes `99` rather than preserving `101`.

```wireframe 11x1
[-] 101 [+]
```

```text
Callouts (11x1, 0-based):
1. r0 c0-c10 Stepper hit target -- natural width expands for the three-cell value slot.
2. r0 c0-c2 decrement affordance -- available because the value is not exactly the
   configured minimum.
3. r0 c4-c6 value slot -- verbatim formatted rendering of the app-owned out-of-range
   value `101`; no display clamp occurs.
4. r0 c8-c10 increment affordance -- available because the value is not exactly the
   configured maximum; its next step writes a clamped value.
```

### Degraded

The default fixture already uses ASCII-only delimiters. `NO_COLOR` preserves those glyphs
and resolves semantic roles to their attribute-only fallbacks; 16-color uses indexed
semantic roles. In ASCII-only mode no glyph substitution is necessary for the implemented
default presentation.

```wireframe 10x1
[-] 42 [+]
```

```text
Callouts (10x1, 0-based):
1. r0 c0-c9 Stepper hit target -- unchanged ASCII-safe geometry under degradation.
2. r0 c0-c2 decrement affordance -- literal ASCII chrome in the resolved semantic Style.
3. r0 c4-c5 value slot -- formatted text retains its measured width and value.
4. r0 c7-c9 increment affordance -- literal ASCII chrome in the resolved semantic Style.
```

### Deferred compact style

> Deferred: The `.compact` presentation lands in a later slice; the following fixtures
> preserve its design intent and are not part of the implemented presentation.

The minimal built-in `.compact` style drops the square brackets and renders bare `−` and
`+` affordances around the value. It keeps the one focusable node, endpoint inertness,
clamping, and out-of-range rules; only the chrome is lighter. Its ideal width is
`4 + formatted value width`.

```wireframe 6x1
− 42 +
```

```text
Callouts (6x1, 0-based):
1. r0 c0-c5 Stepper hit target -- complete compact allocation and focusable node.
2. r0 c0 decrement affordance -- bare `−`; `semantic.disabled` when the value is at
   minimum.
3. r0 c2-c3 value slot -- formatted binding value in `semantic.primary`.
4. r0 c5 increment affordance -- bare `+`; `semantic.disabled` when the value is at
   maximum.
```

Under ASCII-only capability the decrement affordance uses the ASCII hyphen-minus `-`; the
value and `+` are already ASCII-safe.

```wireframe 6x1
- 42 +
```

## State model

| State                  | Owner       | Type                                                                              | Reset or clamp rule                                                                                                                                                                                                                                                                                                                                                                                       |
| ---------------------- | ----------- | --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| value                  | Binding     | `Binding<Value>`                                                                  | App-owned source of truth. Reconciliation displays any supplied `Value` through its selected format. An enabled user step alone writes a value clamped to `minimum...maximum` through this binding.                                                                                                                                                                                                       |
| is enabled             | Environment | `Bool`                                                                            | Read on every reconciliation. `false` removes the node from focusability, clears `pressed affordance`, prevents activation, and leaves input unconsumed.                                                                                                                                                                                                                                                  |
| semantic Styles        | Environment | `semantic.primary`, `semantic.focus`, and `semantic.disabled` full `Style` values | Read on every render; the resolved row Style is primary when enabled and unfocused, focus when focused, and disabled when disabled.                                                                                                                                                                                                                                                                       |
| is focused             | Environment | `Bool`                                                                            | Injected below the explicit `.focusable` modifier from the FocusManager's live identity; Stepper reads it during rendering and checks `ResponderContext.isFocused` for events.                                                                                                                                                                                                                            |
| formatted value        | derived     | `String`                                                                          | Recompute on every update with either `String(describing: value)` or the supplied `FormatStyle`. It preserves the app-supplied value in display and never mutates the binding.                                                                                                                                                                                                                            |
| stepped value          | derived     | `Value`                                                                           | For an in-range value, advance or retreat by positive `Value.Stride` and clamp the write to `minimum...maximum`; a non-divisible final stride lands exactly on its endpoint. Fixed-width integers whose `Stride` is `Int` use reporting-overflow arithmetic and write the requested endpoint directly when that `Int` cannot be represented as `Value`. For an out-of-range value, write its range clamp. |
| decrement is available | derived     | `Bool`                                                                            | Recompute on every update; false only when `value` equals `minimum`, otherwise true so an out-of-range value can be repaired by the next user step.                                                                                                                                                                                                                                                       |
| increment is available | derived     | `Bool`                                                                            | Recompute on every update; false only when `value` equals `maximum`, otherwise true so an out-of-range value can be repaired by the next user step.                                                                                                                                                                                                                                                       |
| pressed affordance     | NodeState   | `StepperDirection?`                                                               | Set only during a valid primary down or phased key down; clear on matching release, cancellation, focus loss, disablement, node removal, or when its affordance becomes unavailable. It never represents numeric data.                                                                                                                                                                                    |

`minimum`, `maximum`, and `step` are immutable initializer configuration, not widget
state. The closed range must have `minimum <= maximum`, and `step` must satisfy
`step > .zero`; both are checked before node creation.

## Key table

| Key                   | Precondition                                                  | Effect                                                                                      | Consumed |
| --------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------- |
| Up                    | is focused and is enabled and increment is available          | Writes `stepped value` for increment through value binding, clamped to `minimum...maximum`. | yes      |
| Right                 | is focused and is enabled and increment is available          | Writes `stepped value` for increment through value binding, clamped to `minimum...maximum`. | yes      |
| Down                  | is focused and is enabled and decrement is available          | Writes `stepped value` for decrement through value binding, clamped to `minimum...maximum`. | yes      |
| Left                  | is focused and is enabled and decrement is available          | Writes `stepped value` for decrement through value binding, clamped to `minimum...maximum`. | yes      |
| Up                    | is focused and is enabled and increment is available is false | Leaves value binding unchanged at the maximum endpoint so an ancestor may handle the key.   | no       |
| Right                 | is focused and is enabled and increment is available is false | Leaves value binding unchanged at the maximum endpoint so an ancestor may handle the key.   | no       |
| Down                  | is focused and is enabled and decrement is available is false | Leaves value binding unchanged at the minimum endpoint so an ancestor may handle the key.   | no       |
| Left                  | is focused and is enabled and decrement is available is false | Leaves value binding unchanged at the minimum endpoint so an ancestor may handle the key.   | no       |
| Up, Right, Down, Left | is enabled is false                                           | Leaves value binding and pressed affordance unchanged; disabled nodes do not consume keys.  | no       |

## Mouse table

| Event | Region               | Precondition                                   | Effect                                                                                                              | Consumed |
| ----- | -------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | -------- |
| click | decrement affordance | is enabled and decrement is available          | Sets the Stepper's explicitly composed focus identity, then writes decremented stepped value through value binding. | yes      |
| click | increment affordance | is enabled and increment is available          | Sets the Stepper's explicitly composed focus identity, then writes incremented stepped value through value binding. | yes      |
| click | decrement affordance | is enabled and decrement is available is false | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged at the minimum endpoint. | no       |
| click | increment affordance | is enabled and increment is available is false | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged at the maximum endpoint. | no       |
| click | decrement affordance | is enabled is false                            | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged; disabled input bubbles. | no       |
| click | increment affordance | is enabled is false                            | Leaves explicitly composed focus identity, value binding, and pressed affordance unchanged; disabled input bubbles. | no       |

A click on the value slot or either separator has no Stepper activation handler and is
unconsumed. A valid affordance click establishes explicit focus before it writes the one
clamped step, as required by [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing).

## Sizing

The default Stepper is one row high and label-hugging. Its ideal width is the three-cell
decrement affordance, two separator cells, the full formatted value, and the three-cell
increment affordance: `8 + formatted value width`. It does not grow to fill extra proposal
width.

| Proposal                    | Result | Rule                                                                                                                |
| --------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------- |
| nil x nil with value `7`    | 9x1    | Unconstrained ideal uses the one-cell value width plus both affordances and separators.                             |
| nil x nil with value `1234` | 12x1   | Unconstrained ideal expands by the full four-cell formatted value width.                                            |
| 10x1 with value `42`        | 10x1   | Tight proposal exactly fits both affordances, separators, and the two-cell value.                                   |
| 8x1 with value `7`          | 9x1    | Under-minimum proposal reports the declared 9x1 floor rather than clipping either affordance or the one-cell value. |
| 40x16 with value `42`       | 10x1   | Over-maximum proposal keeps the content-hugging 10x1 result; extra cells remain parent-owned.                       |

## Environment

Stepper consumes `isEnabled` and applies one resolved semantic Style to its implemented
row: `semantic.primary` when enabled and unfocused, `semantic.focus` when focused, and
`semantic.disabled` when disabled. The default presentation is ASCII-safe and reports its
content width instead of silently truncating a numeric value.

> Deferred: endpoint-specific affordance styling, `StepperStyle`, `focus.border`,
> `truncation.mark` customization, and `.compact` style-specific degradation land in a
> later slice.

## Primitive dependencies

- [Text](../primitives/text.md) renders the formatted value and the default affordance
  glyphs with their resolved semantic Styles.

## Requirements

- `stepper increments its binding from an interior value` (key table: Up).
- `stepper decrements its binding from an interior value` (key table: Down).
- `stepper leaves an increment key unconsumed at maximum` (key table: Up with increment
  unavailable).
- `stepper leaves a decrement key unconsumed at minimum` (key table: Down with decrement
  unavailable).
- `stepper clamps a non-divisible final increment exactly to maximum` (state model:
  stepped value; key table: Up).
- `stepper clamps a non-divisible final decrement exactly to minimum` (state model:
  stepped value; key table: Down).
- `stepper displays an app-supplied out-of-range value verbatim until user activation`
  (out-of-range binding value state).
- `stepper clamps an out-of-range value through its binding on user activation` (state
  model: stepped value; key table: Up or Down).
- `stepper applies a positive non-unit stride through its binding` (state model: stepped
  value; key table: Up).
- `stepper renders a bound value with its supplied format style` (state model: formatted
  value).
- `stepper focuses before increment-affordance activation` (mouse table: click increment
  affordance).
- `stepper leaves endpoint-affordance clicks unconsumed` (mouse table: click increment or
  decrement affordance when unavailable).
- `disabled stepper leaves keys and clicks unconsumed` (disabled state; key and mouse
  tables).
- `stepper retains both affordances and a value cell at its declared floor` (minimum
  state).

> Deferred: Compact-style rendering and its ASCII degradation land in a later slice. The
> design intent remains bare affordances without brackets, with `−` degrading to `-`.

## Degradation

The default presentation uses only ASCII glyphs, so the ASCII-only rung preserves `[-]`,
`[+]`, formatted value text, and the 9x1 floor. `NO_COLOR` resolves semantic roles to
their attribute-only fallbacks; 16-color resolves them to indexed semantic Styles.

Below the 9x1 floor, default Stepper reports its 9x1 minimum result rather than hiding an
affordance, rewriting the value, or creating a second interaction mode.

> Deferred: The `.compact` style's `−` glyph degradation and `4 + formatted value width`
> floor land in a later slice.

## Open questions

- Arrow-direction consumption is **RESOLVED**: Up and Right consume an available
  increment; Down and Left consume an available decrement. At their corresponding
  endpoints they are unconsumed and bubble.

## Inspiration

A Stepper should expose bounded app-owned arithmetic as two obvious actions and make
endpoint behavior visible rather than silently retaining private numeric state.
