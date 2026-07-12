# Modern Terminal Protocols

Tessera models implemented terminal protocols as semantic operations and session policy.
Applications select intent in ``TerminalApplicationConfiguration``; a ``TerminalSession``
then applies the resulting modes and exposes the observed ``TerminalCapabilities``. This
keeps protocol choices explicit without requiring applications to construct control bytes
or own terminal I/O.

## Choose policy before emitting protocol output

Use capability detection to decide how startup obtains evidence. ``CapabilityDetectionMode/passive``
uses local process-environment hints, while ``CapabilityDetectionMode/active`` also performs
bounded protocol-native probes after startup. For a live session, use
``TerminalSession/queryActiveCapabilities()`` when the application needs to request another
active probe round.

```swift
import TesseraTerminal

let configuration = TerminalApplicationConfiguration(
  capabilityDetection: .active,
  enableBracketedPaste: true,
  enableFocusEvents: true,
  mouseTracking: .buttonEvents,
  keyboardProtocol: .kittyIfAvailable,
  hyperlinkRendering: .enabled,
  synchronizedOutput: .enabled,
  underlineRendering: .extended,
  clipboardWriting: .enabled(.default)
)
```

The configuration expresses policy rather than a promise about a particular terminal.
Inspect ``TerminalSession/capabilities`` and ``TerminalSession/protocolModeReport`` when
application behavior depends on the evidence or on the mode lifecycle. The report separates
requested modes, modes believed effective, and modes that may still be active after an I/O
failure.

## Input and lifecycle protocols

The session supports bracketed paste, focus-event reporting, mouse tracking, and Kitty
keyboard mode through its configuration and runtime policy methods. Use
``KeyboardProtocolMode/kittyIfAvailable`` when Kitty keyboard should be enabled only after
active support evidence, or ``KeyboardProtocolMode/legacyOnly`` to retain legacy input
parsing. ``TerminalSession/events`` delivers their decoded
`TesseraTerminalInput/InputEvent` values through one semantic stream.

During a session, update focus, mouse, keyboard, and cursor requests with
``TerminalSession/setFocusEvents(_:)``, ``TerminalSession/setMouseTracking(_:)``,
``TerminalSession/setKeyboardProtocol(_:)``, and ``TerminalSession/setCursorStyle(_:)``.
The session owns those mode transitions.

## Rendering and output protocols

Frame rendering can encode OSC 8 hyperlinks, extended underline styling, and DEC
synchronized output according to ``HyperlinkRenderingMode``,
`TesseraTerminalANSI/UnderlineRenderingPolicy`, and ``SynchronizedOutputPolicy``. Color
policy is selected with ``ColorCapabilityOverride`` and is reflected by
``TerminalSession/effectiveColorCapability``. These policies apply to future draws and
can be changed through the corresponding session methods.

OSC 52 clipboard writes are separately gated by ``ClipboardWriteMode`` and
``ClipboardWritePolicy``. Calling `TerminalSession.copyToClipboard(_:selection:intent:)`
requires a ``ClipboardUserIntent`` as well as an enabled session policy.

## Kitty graphics

Kitty Graphics Protocol support is session-scoped. Send image data with
``TerminalSession/transmitImage(_:)`` and delete it with
``TerminalSession/deleteImages(_:)``. During a draw, ``Frame/placeImage(_:at:occupying:)``
anchors a placement to its occupied cell region so normal frame updates can account for that
geometry. ``TerminalSession/queryKittyGraphicsSupport(id:)`` requests an active graphics
support probe when needed.

## Topics

### Capability and policy

- ``TerminalApplicationConfiguration``
- ``TerminalCapabilities``
- ``CapabilityDetectionMode``
- ``ActiveCapabilityProbeResult``
- ``TerminalProtocolModeReport``

### Protocol families

- ``KeyboardProtocolMode``
- ``MouseTrackingMode``
- ``HyperlinkRenderingMode``
- ``SynchronizedOutputPolicy``
- ``ClipboardWriteMode``
- ``ClipboardWritePolicy``
