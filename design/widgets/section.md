---
kind: widget
status: sketch
---

# Section

`Section` is Tessera's grouping and structure element for `List` and future `Form`
composition: it presents a header and grouped rows while forwarding the app-owned bindings
of its content. It is controlled only insofar as it forwards that content; any ephemeral
layout or presentation internals belong in `NodeState`, never in a private data or
selection model. The Showcase uses it as flat catalog grouping rather than a source of
application state.

It lands with List and Section in the
[catalog-integration slice](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

## Prior art

- Ratatui `List` grouping begins in
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/list.rs`; its composition model is
  useful for terminal row grouping without adopting widget-owned selection.
- SwiftUI `Section` supplies header, footer, and grouped-content vocabulary.
- Textual offers contrasting grouped composition patterns for terminal-style applications.

## Future wireframe and specification notes

Promote this sketch to `wireframed` with fixtures for:

- Header plus grouped rows, an empty section, a long or absent header, and adjacent
  sections in a List.
- Constrained width, zero-height viewport, no-color presentation, and catalog grouping in
  the Showcase.
- Focusable child controls and selectable rows, proving that Section forwards rather than
  intercepts their focus, input, or bindings.

The later `specified` contract must define header/footer and row-builder anatomy; its List
and Showcase composition rules; inherited style/environment behavior; any separator and
spacing policy; and the state, sizing, and fixture-traced requirements needed to prove it
forwards child contracts without private selection or data state.

## Open questions

- Decide whether 1.0 exposes a footer and whether empty headers reserve vertical space.
- Define the relationship between List section separators and a Section's own grouping
  chrome.
- Decide whether Section is public outside List before Form lands after 1.0.

## Inspiration

A Section should make a flat catalog or list easier to scan without becoming a second
container state model; its value is visible structure and faithful forwarding.
