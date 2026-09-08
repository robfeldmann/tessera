# ``InputEvent``

A semantic event decoded from terminal input bytes.
Graph responders normalize ``InputEvent/mouse(_:)`` into ``PointerEvent`` phases before hit testing; the parser event itself remains the terminal-facing mouse value.

## Topics

### Keyboard

- ``key(_:)``

### Paste

- ``paste(_:)``

### Focus

- ``focusGained``
- ``focusLost``

### Mouse

- ``mouse(_:)``

### Terminal responses

- ``kittyGraphicsResponse(_:)``
- ``kittyKeyboardEnhancementFlags(_:)``
- ``primaryDeviceAttributes(_:)``
- ``privateModeStatus(_:)``

### Other terminal input

- ``resize(_:)``
- ``unknown(_:)``
