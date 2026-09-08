# ``TesseraLayout``

@Metadata {
    @PageImage(purpose: icon, source: "layout-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "layout-card", alt: "Module card.")
}

Deterministic layout protocols and containers for composing Tessera views.

Layout is integer-cell based. A proposal, measured size, and placement are expressed in
terminal cells, with grapheme width measured by the shared display-width policy. Layout
rounding is deterministic and diagnostics expose the proposal, size, and frame for each
runtime node.

## Containers and solvers

- ``VStack``, ``HStack``, and ``ZStack`` compose children without owning application state.
- ``Flex`` distributes finite cells using min/ideal/max constraints and deterministic
  remainder assignment. The solver never mutates a child's value or binding.
- ``Grid`` lays children out in row-major order using measured column widths and row heights.
  It intentionally has no spanning or implicit reordering contract.
- ``Spacer`` and the layout modifiers (`frame`, `padding`, and `layoutPriority`) affect
  geometry only; input and identity still follow the view graph.

`ScrollView` and `SplitView` are widget-layer consumers of these layout protocols. Their
viewport and pane policies preserve the same integer-cell measurements and application-owned
bindings.

## Topics

### Layout containers

- ``Layout``
- ``VStack``
- ``HStack``
- ``ZStack``
- ``Spacer``
- ``Flex``
- ``Grid``
