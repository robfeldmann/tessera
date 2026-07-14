---
kind: widget
status: sketch
---

# Stepper

`Stepper` is Tessera's controlled bounded numeric control: the application owns a
`Binding<Int>` (or another explicitly supported value) together with minimum, maximum, and
step policy, while only ephemeral focus and press presentation may live in `NodeState`. It
presents increment and decrement affordances without owning the numeric value.

It lands in the
[Phase 4 focus and key-routing slice](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system),
with pointer behavior in the
[mouse and hit-testing slice](../../docs/Spec.md#slice-5-mouse-and-hit-testing). Arrow
keys or buttons increment and decrement the binding; click activates the corresponding
affordance.

## Prior art

- Ratatui's widgets in `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/` provide
  compact terminal-control and layout vocabulary, but no direct Stepper contract.
- SwiftUI `Stepper` supplies the bounded-value and increment/decrement vocabulary.

## Future wireframe and specification notes

Promote this sketch to `wireframed` with fixtures for:

- Minimum, interior, and maximum values; disabled increment/decrement affordances; and
  focused, pressed, no-color, and constrained-width states.
- Positive and negative values, a step greater than one, and a range whose endpoint is not
  reached by a whole step.
- Up/Down or Left/Right key handling, button activation, and click-to-focus before the
  chosen affordance handles the pointer event.

The later `specified` contract must define the generic value scope, min/max/step
validation, endpoint clamping, displayed-value formatting, semantic style consumption, and
the key, mouse, state, and sizing tables with fixture-traced requirements.

## Open questions

- Decide whether 1.0 is `Int`-only or supports a generic strideable numeric value.
- Decide which arrow directions the default horizontal terminal presentation consumes.
- Define whether an app-supplied out-of-range binding is displayed, clamped through the
  binding, or diagnosed.

## Inspiration

A Stepper should expose bounded app-owned arithmetic as two obvious actions and make
endpoint behavior visible rather than silently retaining private numeric state.
