# ``TesseraTerminalANSI``

@Metadata {
    @PageImage(purpose: icon, source: "ansi-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "ansi-card", alt: "Module card.")
}

ANSI control sequence encoding.

`TesseraTerminalANSI` is the only terminal module that knows the byte-level spelling of
ANSI/VT control sequences. It is pure and synchronous: callers build semantic
``ControlSequence`` values, then encode them into a caller-owned byte buffer.

## Topics

### Encoding

- ``ANSIEncoder``
- ``ControlSequence``

### Colors and attributes

- ``Color``
- ``ANSIColor``

### Erase modes

- ``EraseMode``

### Raw payloads

- ``RawTerminalPayload``
