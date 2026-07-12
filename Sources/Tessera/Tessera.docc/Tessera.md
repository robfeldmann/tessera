# ``Tessera``

@Metadata {
    @PageImage(purpose: icon, source: "tessera-icon", alt: "Tessera logo.")
    @PageImage(purpose: card, source: "tessera-card", alt: "Tessera Swift logo card artwork.")
}

A Swift TUI library for macOS, Linux, and Windows.

## Overview

Tessera provides terminal foundations and a view/rendering layer for building terminal
applications in Swift.

Import `Tessera` when building applications. The target re-exports the terminal
foundation and view-layer modules intended for app authors.

## Topics

### User-facing modules

- ``/TesseraTerminal``

### Core modules

- ``/TesseraCore``
- ``/TesseraCore/View``
- ``/TesseraTerminalCore``

### Terminal foundation modules

- ``/TesseraTerminalANSI``
- ``/TesseraTerminalBuffer``
- ``/TesseraTerminalInput``
- ``/TesseraTerminalIO``
- ``/TesseraTerminalRendering``
- ``/TesseraTerminalSnapshotSupport``
- ``/TesseraTerminalTestSupport``
