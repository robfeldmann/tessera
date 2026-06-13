# ``TesseraTerminalRendering``

Terminal rendering and damage tracking internals.

This target contains package-internal renderer implementation details used by
`TesseraTerminal.TerminalSession`. Public applications render through
`TerminalSession.draw(_:)` rather than importing this target directly.
