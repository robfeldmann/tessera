# ``TesseraTerminalCore``

@Metadata {
    @PageImage(purpose: icon, source: "terminal-core-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "terminal-core-card", alt: "Module card.")
}

Value types shared across terminal encoding, buffers, input, I/O, and rendering.

Use terminal geometry types to describe cell-based sizes, positions, pixel dimensions, and regions. Use Kitty graphics types to identify images and placements and represent parsed graphics responses.

## Topics

### Terminal Geometry

- ``TerminalSize``
- ``TerminalPosition``
- ``CellPixelSize``
- ``Rect``

### Kitty Graphics Responses

- ``KittyImageID``
- ``KittyPlacementID``
- ``KittyGraphicsResponse``
