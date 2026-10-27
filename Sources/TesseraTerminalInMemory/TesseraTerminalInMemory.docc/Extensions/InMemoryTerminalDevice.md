# ``InMemoryTerminalDevice``

A deterministic actor-backed terminal device. Initialize it with the input and geometry the code under test requires, exercise that code through the device's terminal seam, then inspect the recorded state. It does not create or manage a production terminal session.

## Topics

### Creating a device

- ``init(size:cellPixelSize:inputBytes:)``

### Recorded output

- ``bytes``
- ``events``
