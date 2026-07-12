# ``TesseraTerminalRendering``

@Metadata {
    @PageImage(purpose: icon, source: "rendering-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "rendering-card", alt: "Module card.")
}

Terminal rendering and damage tracking implementation details.

## Overview

This target turns successive cell buffers into the minimal terminal updates needed to
present a frame. It owns buffer comparison, span selection, cursor placement, style
transitions, and synchronized-output boundaries.

The renderer is intentionally package-internal. Applications draw through
`TerminalSession.draw(_:)`, which scopes a frame to a terminal session and keeps rendering,
mode control, and output serialization coordinated. Import `TesseraTerminal` rather than
depending on this implementation target directly.
