# ``TesseraTerminalRendering``

@Metadata {
    @PageImage(purpose: icon, source: "rendering-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "rendering-card", alt: "Module card.")
}

Terminal rendering and damage tracking internals.

This target contains package-internal renderer implementation details used by
`TesseraTerminal.TerminalSession`. Public applications render through
`TerminalSession.draw(_:)` rather than importing this target directly.
