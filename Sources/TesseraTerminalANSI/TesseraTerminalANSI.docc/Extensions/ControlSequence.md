# ``ControlSequence``

A semantic ANSI/VT operation. Encode one operation with ``encode(into:)``, or encode an
ordered sequence with ``ANSIEncoder/encode(_:)``.

## Topics

### Encoding

- ``bytes``
- ``encode(into:)``

### Text and signaling

- ``bell``
- ``text(_:)``

### Screen and cursor

- ``cursorBack(_:)``
- ``cursorDown(_:)``
- ``cursorForward(_:)``
- ``cursorPosition(_:)``
- ``cursorRestore``
- ``cursorSave``
- ``cursorUp(_:)``
- ``cursorVisible(_:)``
- ``eraseInDisplay(_:)``
- ``eraseInLine(_:)``

### Color and graphic rendition

- ``resetAttributes``
- ``setBackground(_:)``
- ``setBold(_:)``
- ``setDim(_:)``
- ``setForeground(_:)``
- ``setItalic(_:)``
- ``setReverse(_:)``
- ``setStrikethrough(_:)``
- ``setUnderlineColor(_:)``
- ``setUnderlineStyle(_:)``

### Cursor styling

- ``resetCursorColor``
- ``setCursorColor(_:)``
- ``setCursorShape(_:)``

### Protocol modes and input

- ``disableMouseTracking``
- ``enableBracketedPaste(_:)``
- ``enableFocusTracking(_:)``
- ``enableLineWrap(_:)``
- ``enableMouseTracking(_:)``
- ``enterAltScreen``
- ``enterSynchronizedOutput``
- ``exitAltScreen``
- ``exitSynchronizedOutput``
- ``popKittyKeyboard``
- ``pushKittyKeyboard(_:)``

### OSC metadata

- ``closeHyperlink``
- ``copyToClipboard(_:)``
- ``openHyperlink(_:)``
- ``setWindowTitle(_:)``

### Kitty graphics

- ``kittyGraphics(_:)``

### Raw escape hatch

- ``raw(_:)``
