# ``TesseraTerminalInput``

@Metadata {
    @PageImage(purpose: icon, source: "input-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "input-card", alt: "Module card.")
}

Terminal input events and parsing.

`TesseraTerminalInput` converts caller-supplied terminal bytes into a bounded vocabulary
of semantic ``InputEvent`` values. ``InputParser`` retains only the parsing state needed
between byte chunks, so callers can feed input as it arrives without treating terminal
escape sequences as complete messages.

The module performs no terminal I/O. An application or another module owns the byte source,
feeds its bytes to the parser, and handles the resulting events.

## Topics

### Articles

- <doc:Understanding-Terminal-Input>

### Parsing

- ``InputParser``

### Input events and protocol responses

- ``InputEvent``
- ``PrivateModeStatus``
- ``PrivateModeState``

### Keyboard values and modifiers

- ``Key``
- ``KeyCode``
- ``KeyEventKind``
- ``Modifiers``

### Mouse values

- ``MouseEvent``
- ``MouseEventKind``
- ``MouseButton``
- ``MouseScrollDirection``
