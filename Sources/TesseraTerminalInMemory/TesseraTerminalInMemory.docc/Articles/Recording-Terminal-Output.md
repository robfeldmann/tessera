# Recording Terminal Output

Code that owns a terminal session can be checked without sleeps, polling, or a wall-clock deadline: run it over an in-memory device and read back what the device recorded.

## Start with deterministic device evidence

``InMemoryTerminalDevice`` starts with a chosen terminal size, optional cell-pixel size, and input bytes. Code running through its terminal seam records mode changes and each output flush. Read ``InMemoryTerminalDevice/events`` to assert lifecycle ordering, or ``InMemoryTerminalDevice/bytes`` to inspect the complete output stream.

```swift
let device = InMemoryTerminalDevice(
  size: TerminalSize(columns: 80, rows: 24),
  inputBytes: Array("q".utf8)
)

// Exercise the terminal-owning code with its in-memory device seam.

let events = await device.events
let bytes = await device.bytes
```

The event list distinguishes entering and leaving raw input or the alternate screen from a ``InMemoryTerminalDeviceEvent/flush(_:)``. This lets a check cover protocol lifecycle behavior without coupling it to scheduler timing.

## Run a scoped session

``InMemoryTerminalSession`` builds a device and runs a body in an application terminal scope over it. The scope restores every acquired application mode before it returns or rethrows, so the recorded events end with the matching exits.

```swift
let session = InMemoryTerminalSession(size: TerminalSize(columns: 80, rows: 24))
try await session.withApplicationTerminal { terminal in
  // Draw through `terminal`.
}
let output = await session.bytes
```
