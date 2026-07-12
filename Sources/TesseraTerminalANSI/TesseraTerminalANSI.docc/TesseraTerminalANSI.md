# ``TesseraTerminalANSI``

@Metadata {
    @PageImage(purpose: icon, source: "ansi-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "ansi-card", alt: "Module card.")
}

ANSI/VT control sequence encoding.

`TesseraTerminalANSI` is the pure, synchronous boundary between semantic terminal
operations and their ANSI/VT byte spelling. Build ``ControlSequence`` values and encode
them into a caller-owned buffer with ``ControlSequence/encode(into:)`` or
``ANSIEncoder/encode(_:)``; this module performs no terminal I/O.

Higher-level terminal sessions choose operations and write the resulting bytes. Keep
protocol spelling here, while higher layers own session lifetime, output, and frame
composition.

## Topics

### Encoding

- ``ANSIEncoder``
- ``ControlSequence``

### Text, screen, and cursor operations

- ``EraseMode``
- ``LineEraseMode``

### Color and graphic rendition

- ``Color``
- ``ANSIColor``

### Capability and color degradation

- ``ColorCapability``

### Underline and cursor styling

- ``UnderlineRenderingPolicy``
- ``UnderlineColorRendering``
- ``UnderlineStyleRendering``
- ``UnderlineStyle``
- ``CursorStyle``
- ``CursorShape``
- ``CursorColor``

### Protocol modes and input

- ``MouseTracking``
- ``KittyKeyboardFlags``

### OSC metadata

- ``ClipboardTarget``
- ``ClipboardSelection``
- ``ClipboardWrite``
- ``Hyperlink``

### Kitty graphics

- ``KittyImageFormat``
- ``KittyGraphicsQuiet``
- ``KittyGraphicsTransmission``
- ``KittyGraphicsPlacement``
- ``KittyGraphicsDelete``
- ``KittyGraphicsCommand``

### Raw escape hatch

- ``RawTerminalPayload``
