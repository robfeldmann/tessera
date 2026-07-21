# Building on the Terminal Substrate

Build terminal producers around a scoped ``TerminalSession``, rather than around open
standard-stream handles. The session actor owns the live terminal lifecycle and publishes
semantic `TesseraTerminalInput/InputEvent` values and
`TesseraTerminalCore/TerminalSize` changes. Its scoped entry point keeps terminal setup
and restoration together with the application body.

```swift
import TesseraTerminal

try await TerminalSession.withApplicationTerminal(
  configuration: TerminalApplicationConfiguration(
    capabilityDetection: .active,
    keyboardProtocol: .kittyIfAvailable
  )
) { session in
  try await session.draw { frame in
    frame.write("Ready", at: TerminalPosition(column: 0, row: 0))
  }

  for await event in session.events {
    // Update application state from the semantic input event.
    _ = event
  }
}
```

The closure receives an isolated session, so session state and terminal work remain under
the actor’s isolation. The public entry point accepts configuration, not raw I/O handles.
It creates the standard-stream transport for the scope and returns only after the body has
completed or thrown.

## Draw a frame synchronously

Call ``TerminalSession/draw(_:)`` to produce one frame. Its closure receives a borrowed
``/TesseraTerminalBuffer/Frame`` that is noncopyable and nonescaping, so it cannot outlive
the render transaction.
Write text, reserve terminal cells, and set cursor position in that closure; the session
then renders and flushes the frame.

The buffer remains cell-oriented even when output is not printable text. Use
`TesseraTerminalANSI/RawTerminalPayload` with
``/TesseraTerminalBuffer/Frame/writeRaw(_:at:occupying:repaintPolicy:)`` for a payload
Tessera does not model
semantically, and declare the cells it occupies. This keeps
raw terminal bytes a typed producer input with geometry and repaint behavior, rather than
an application-owned terminal handle.

## Keep application state outside the substrate

The terminal substrate does not prescribe a view hierarchy or state model. Keep application
state in your own domain, translate it to frame writes during ``TerminalSession/draw(_:)``,
and react to ``TerminalSession/events`` and ``TerminalSession/sizeChanges``. This leaves
terminal lifecycle, input decoding, cell storage, and rendering in the substrate while the
application owns its presentation decisions.

## Topics

### Session and drawing

- ``TerminalSession``
- ``TerminalSession/withApplicationTerminal(configuration:_:)``
- ``TerminalSession/draw(_:)``
- ``/TesseraTerminalBuffer/Frame``
