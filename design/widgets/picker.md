---
kind: widget
status: sketch
---

# Picker

`Picker` is Tessera's controlled single-selection control: the application owns the
selected member of a finite set through `Binding<Selection>`, while only ephemeral focus,
reveal, or open-presentation internals may live in `NodeState`. The terminal presentation
is inline or cycling; it reflects the bound selection without owning the option set or
inventing a selection.

It lands in the
[Phase 4 focus and key-routing slice](../../docs/Spec.md#slice-4-focus-and-key-routing-the-responder-system),
with pointer behavior in the
[mouse and hit-testing slice](../../docs/Spec.md#slice-5-mouse-and-hit-testing). Keyboard
input cycles the selection and click chooses a presented option.

## Prior art

- Ratatui's widgets in `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/` provide
  terminal layout and selection vocabulary, but no direct public Picker contract to copy.
- SwiftUI `Picker` supplies the controlled selection and style vocabulary.
- Textual `Select` provides a contrasting compact selection presentation.

## Future wireframe and specification notes

Promote this sketch to `wireframed` with fixtures for:

- An inline selected value, cycling presentation, one option, and constrained labels.
- Focused, disabled, no-color, and semantic-style states.
- Forward and backward keyboard cycling, click selection, unavailable options, and a bound
  selection changed by the application.

The later `specified` contract must define the option and label-builder anatomy;
`Binding<Selection>` validity when options change; empty-set and unavailable-option
policy; semantic style consumption; and the key, mouse, state, and sizing tables with
fixture-traced requirements.

## Open questions

- Decide whether 1.0 exposes only inline/cycling presentation or also a transient expanded
  option list.
- Define how a Picker handles a binding value absent from its current option set.
- Decide whether disabled options remain visible and navigable before their selection rule
  is specified.

## Inspiration

A Picker should make the current app-owned choice legible in one terminal row and make the
next choice predictable, not hide selection policy in private widget state.
