# ``VirtualTerminal``

A test-only virtual terminal for feeding output and inspecting reconstructed screen
state.

## Topics

### Construction

- ``init(feed:text:cell:cursor:kittyImages:kittyPlacements:snapshot:)``
- ``ghostty(cols:rows:)``
- ``ghosttyOrUnavailable(cols:rows:)``
- ``ghosttyUnavailable``
- ``isGhosttyUnavailable``

### Feeding output

- ``feed``
- ``feed(_:)``

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
