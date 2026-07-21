---
kind: widget
status: sketch
---

# List

`List` is Tessera's controlled, focusable collection widget for a `RandomAccessCollection`
whose elements are `Identifiable`. Its app-owned `Binding<Data.Element.ID?>` is the
selected row; ephemeral scroll position belongs to `NodeState`. The widget will compose
row views, selection presentation, viewport clipping, and optional shared scroll-indicator
geometry without owning collection data or inventing a selection.

This is the catalog placeholder for the
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase)
`List` API. It deliberately does not wireframe or specify behavior yet.

## Prior art

- Ratatui `List`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/list.rs`,
  `list/state.rs`, and `list/rendering.rs` — copy a visible-viewport rendering model and
  selection reveal behavior. Reject state ownership in the widget: Tessera selection is an
  app Binding, while only scroll offset may be ephemeral node state.
- Ratatui `Scrollbar`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs`
  — use as contrast for optional, output-only overflow geometry; Tessera shares
  [ScrollIndicator](../primitives/scroll-indicator.md) rather than embedding a private
  scrollbar model.
- Tessera [Table](table.md) — reuse controlled-selection, structured-row, degradation, and
  fixture conventions where they apply; List must not inherit Table's column model.

## Future wireframe and specification notes

Promote this sketch to `wireframed` with fixtures for:

- Empty data, one row, mixed/multiline rows, constrained width, zero-height viewport, and
  selected-row removal after an app data update.
- Focused and unfocused selection, no-color and ASCII presentation, and composition with
  [ScrollIndicator](../primitives/scroll-indicator.md).
- Keyboard transitions for Up, Down, Page Up, Page Down, Home, End, and deliberately
  bubbling keys.
- Slice 5 pointer scenarios: row click, wheel routing, click-to-focus before row handling,
  clipped viewport hit testing, and selection dispatch.

The later `specified` contract must define the row-builder anatomy and element identity;
`Binding<Data.Element.ID?>` selection; `NodeState` scroll-offset clamp/visibility
behavior; `listSelectionStyle` environment consumption; optional scroll-indicator
placement; and the key/mouse/state tables with fixture-traced requirements. It must also
record the Slice 3 style/environment and Slice 5 mouse/hit-testing dependencies rather
than creating private selection, scrolling, or pointer infrastructure.

## Open questions

- Resolve the public spelling and scope of `listSelectionStyle` with the Slice 3
  style/environment contract.
- Decide whether List supports a non-selectable presentation in 1.0 without weakening the
  controlled selection binding model.
- Confirm whether variable-height row visibility uses the first fully visible row, any
  visible selected cell, or a dedicated row-alignment policy.

## Inspiration

A List should make application data and selection obvious, not hide them behind a widget
state object. Scrolling is an implementation detail; selected identity remains app state.
