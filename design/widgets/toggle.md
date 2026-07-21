---
kind: widget
status: sketch
---

# Toggle

`Toggle` is Tessera's controlled Boolean control: the application owns its on/off value
through `Binding<Bool>`, while only ephemeral focus and press presentation may live in
`NodeState`. It presents the current off or on state without owning or inventing the
value.

It lands in the
[Phase 4 focus and key-routing slice](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system),
with pointer behavior in the
[mouse and hit-testing slice](../../docs/Spec.md#slice-5-mouse-and-hit-testing). Keyboard
activation toggles with Space or Enter; click toggles the bound value.

## Prior art

- Ratatui has no direct Toggle widget in
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/`; its widget vocabulary is useful
  contrast for a terminal-native on/off presentation without widget-owned application
  state.
- SwiftUI `Toggle` supplies the controlled Boolean vocabulary and accessibility-facing
  naming.
- Textual `Switch` and `Checkbox` provide contrasting terminal and text-mode on/off
  presentations.

## Future wireframe and specification notes

Promote this sketch to `wireframed` with fixtures for:

- Off and on states; focused, pressed, disabled, destructive, and no-color presentation.
- Short and constrained labels, a zero-width proposal, and composition in a dense control
  group.
- Space, Enter, and click activation, including focus acquisition before pointer handling.

The later `specified` contract must define the public initializer and label anatomy;
`Binding<Bool>` mutation; the on/off, focused, and disabled visual rules; semantic style
consumption; and the key, mouse, state, and sizing tables with fixture-traced
requirements.

## Open questions

- Decide whether the terminal default reads as a checkbox, switch, or style-selectable
  family without weakening a common `ToggleStyle` contract.
- Decide whether a label-less Toggle is public in 1.0 and, if so, how it exposes an
  accessible name.
- Define whether a disabled Toggle can receive focus for inspection but never activation.

## Inspiration

A Toggle should make the app-owned Boolean obvious at a glance and change it with one
unambiguous action; it must never conceal application state behind a widget model.
