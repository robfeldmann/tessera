---
kind: primitive
status: sketch
---

# Style modifiers

Style modifiers are stateless wrapper nodes that establish or override inherited terminal
`Style` attributes for a subtree. Slice 3 supplies `defaultStyle` plus `.foreground`,
`.background(Color)`, `.bold`, `.italic`, `.underline`, and `.style`. The later contract
must preserve the Spec's per-attribute nearest-ancestor-wins merge rule, with a view's own
explicit attributes winning over inherited attributes. This document covers style and
environment inheritance only; view-builder Background, Border, Overlay, and Box each have
their own component sketches.

## Prior art

- Ratatui `Stylize`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/style/stylize.rs`
  — copy fluent value-style composition. Reject per-widget mutable style state.
- Ratatui `Color`: `~/Developer/ratatui/ratatui/main/ratatui-core/src/style/color.rs` —
  reuse as contrast for terminal-color capability handling; Tessera has one buffer `Style`
  type rather than a second view-layer type.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns the API and normative inheritance precedence.

## Future wireframe and specification notes

Promote this sketch with styled-grid fixtures for nested inheritance, sibling isolation,
explicit false attributes such as `.bold(false)`, whole-style merging, foreground versus
background fills, and `NO_COLOR`/ASCII attribute fallbacks. The specified contract must
name `defaultStyle` environment ownership, per-attribute precedence, and whether a color
background fills the final allocated region before or after descendant rendering.

## Open questions

- Settle the exact `defaultStyle` environment-key API alongside the buffer `Style` fluent
  API; no duplicate view-layer `Style` type is permitted.
- Decide whether `.background(Color)` is represented by the style wrapper or a dedicated
  fill wrapper while preserving the public Slice 3 overload.

## Inspiration

Style is inherited presentation, not widget state. A modifier chain should lower to
ordinary wrapper nodes without new rendering machinery.
