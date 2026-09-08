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
   maximum.
```

endpoint behavior visible rather than silently retaining private numeric state.
