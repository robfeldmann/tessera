# ``TesseraTerminalSnapshotSupport``

@Metadata {
    @PageImage(purpose: icon, source: "snapshot-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "snapshot-card", alt: "Module card.")
}

Use this test-support module to feed terminal output into a virtual terminal and
inspect its reconstructed screen state. When `CGhosttyVT` is compiled into the build,
the Ghostty-backed ``VirtualTerminal`` factory uses `libghostty-vt`, a high-quality VT
parser for inspecting the resulting screen, cells, cursor, and Kitty graphics state.
That inspection does not prove that every terminal emulator will behave identically.

## Topics

### Terminal construction

- ``VirtualTerminal``
- ``VirtualTerminal/ghostty(cols:rows:)``
- ``VirtualTerminal/ghosttyOrUnavailable(cols:rows:)``
- ``VirtualTerminal/ghosttyUnavailable``
- ``VirtualTerminal/isGhosttyUnavailable``

### Feeding terminal output

- ``VirtualTerminal/feed``
- ``VirtualTerminal/feed(_:)``

### Inspecting terminal state

- ``VirtualTerminal/text(row:)``
- ``VirtualTerminal/cell(row:column:)``
- ``VirtualTerminal/cursorPosition()``
- ``VirtualTerminal/snapshot``

### Screen models, cells, and colors

- ``ScreenSnapshot``
- ``RenderedCell``
- ``RenderedColor``

### Kitty graphics inspection

- ``RenderedKittyImage``
- ``RenderedKittyImageFormat``
- ``RenderedKittyPlacement``
