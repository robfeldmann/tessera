# ``InMemoryTerminalDevice``

A deterministic actor-backed terminal device for tests. Initialize it with the input and geometry
the test requires, exercise code through its test seam, then inspect the recorded state. It is test
support and does not create or manage a production terminal session.

## Topics

### Creating a device

- ``init(size:cellPixelSize:inputBytes:)``

### Recorded output

- ``bytes``
- ``events``
