# ``TerminalSession``

A scoped, actor-isolated live terminal session for producing frames, receiving input,
managing terminal protocol policy, and performing clipboard writes.

The session is the sole owner of live protocol transitions. ``setBracketedPaste(_:)`` toggles
the application-owned bracketed-paste request through the mode lifecycle and preserves the
other requested keyboard, mouse, focus, and rendering policies. It is a no-op before a live
mode lifecycle exists; when enabled, the session emits the semantic mode transition and keeps
its requested/effective baseline separate from capability evidence and modes owned elsewhere.

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
- ``setBracketedPaste(_:)``
- ``setSynchronizedOutput(_:)``
- ``setUnderlineRendering(_:)``
- ``queryActiveCapabilities()``
- ``queryKittyKeyboardSupport()``
- ``queryPrivateModeStatuses()``

### Graphics

- ``queryKittyGraphicsSupport(id:)``
- ``transmitImage(_:)``
- ``deleteImages(_:)``
