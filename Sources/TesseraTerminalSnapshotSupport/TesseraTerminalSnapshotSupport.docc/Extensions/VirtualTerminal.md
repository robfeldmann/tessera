# ``VirtualTerminal``

A test-only virtual terminal for feeding output and inspecting reconstructed screen
state.

## Topics

### Construction

- ``init(feed:resize:text:cell:cursor:kittyImages:kittyPlacements:snapshot:)``
- ``ghostty(cols:rows:)``
- ``ghosttyOrUnavailable(cols:rows:)``
- ``ghosttyUnavailable``
- ``isGhosttyUnavailable``

### Feeding output

- ``feed``
- ``feed(_:)``

### Resizing retained state

- ``resize``
- ``resize(to:)``
- ``VirtualTerminalError``

### Inspecting screen state

- ``text``
- ``cell``
- ``cursor``
- ``text(row:)``
- ``cell(row:column:)``
- ``cursorPosition()``
- ``snapshot``

### Inspecting Kitty graphics

- ``kittyImages``
- ``kittyPlacements``
