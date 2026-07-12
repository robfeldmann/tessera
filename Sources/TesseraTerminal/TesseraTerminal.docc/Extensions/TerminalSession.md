# ``TerminalSession``

A scoped, actor-isolated live terminal session for producing frames, receiving input,
managing terminal protocol policy, and performing clipboard writes.

## Topics

### Creating a terminal session

- ``withApplicationTerminal(configuration:_:)``

### Drawing

- ``draw(_:)``
- ``invalidateRenderer()``

### Events and size

- ``events``
- ``nextEvent()``
- ``sizeChanges``
- ``cellPixelSize``

### Capability and policy

- ``capabilities``
- ``colorCapability``
- ``effectiveColorCapability``
- ``hasNoColorEnvironment``
- ``hasDumbTerminal``
- ``clipboardWriting``
- ``cursorStyling``
- ``enabledProtocolModes``
- ``focusEventsEnabled``
- ``hyperlinkRendering``
- ``synchronizedOutput``
- ``keyboardProtocol``
- ``kittyKeyboardFlags``
- ``mouseTracking``
- ``possiblyActiveProtocolModes``
- ``protocolModeReport``
- ``underlineRendering``
- ``effectiveCursorStyle``
- ``setColorCapability(_:)``
- ``setCursorStyle(_:)``
- ``setFocusEvents(_:)``
- ``setHyperlinkRendering(_:)``
- ``setKeyboardProtocol(_:)``
- ``setMouseTracking(_:)``
- ``setSynchronizedOutput(_:)``
- ``setUnderlineRendering(_:)``
- ``queryActiveCapabilities()``
- ``queryKittyKeyboardSupport()``
- ``queryPrivateModeStatuses()``

### Graphics

- ``queryKittyGraphicsSupport(id:)``
- ``transmitImage(_:)``
- ``deleteImages(_:)``
