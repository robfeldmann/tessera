# ``TesseraTerminalBuffer``

@Metadata {
    @PageImage(purpose: icon, source: "buffer-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "buffer-card", alt: "Module card.")
}

Build width-aware terminal output from a rectangular grid of cells.

``TesseraTerminalBuffer`` stores text as Swift grapheme clusters, rather than assuming one character occupies one terminal column. A wide grapheme has one leading ``Cell`` and explicit ``Cell/Content/continuation`` cells for its covered trailing columns. This preserves the grid geometry when later writes replace, inspect, or clear text.

Each cell combines its content with a ``Style`` and a ``CellDiffPolicy``. Styles describe foreground and background colors, ``TextAttributes``, underline styling, and an optional hyperlink. Diff policies make damage behavior explicit: normal cells diff by equality, opaque cells identify a region managed by another subsystem, and always-repaint cells are considered for output even when equal.

Raw terminal payloads use the same explicit-region model. ``Buffer/writeRaw(_:at:occupying:repaintPolicy:)`` anchors the payload and records continuation cells throughout the portion of its occupied rectangle that lies within the buffer. This lets damage tracking account for raw and opaque regions without exposing rendering internals.

The module's value types are `Sendable`, so they can move safely across Swift concurrency isolation boundaries.

## Topics

### Buffer operations

- ``Buffer``
- ``Buffer/init(size:fill:)``
- ``Buffer/clear(fill:)``
- ``Buffer/write(_:at:style:)``
- ``Buffer/write(grapheme:at:style:)``
- ``Buffer/writeRaw(_:at:occupying:repaintPolicy:)``
- ``Buffer/markOpaque(_:)``

### Cells and diff policies

- ``Cell``
- ``Cell/Content``
- ``CellDiffPolicy``

### Styles and attributes

- ``Style``
- ``TextAttributes``

### Write outcomes

- ``GraphemeWriteResult``
