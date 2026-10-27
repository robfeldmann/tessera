# ``TesseraTerminalInMemory``

Run terminal-owning code against a terminal that lives in memory, and read back what it did.

``InMemoryTerminalDevice`` is a terminal device that is an actor holding a size, optional cell-pixel size, and input bytes. A `TerminalSession` opened over it records every mode change and every output flush, so a test or a development executable can assert lifecycle ordering or inspect the complete output stream without a real terminal and without waiting on wall-clock timing. ``InMemoryTerminalSession`` wraps a device in a scoped application terminal.

This module links neither a test framework nor the snapshot-testing library, so an executable can link it. It is not a production terminal: it never touches a file descriptor or the host's terminal modes. `TesseraTerminalTestSupport` re-exports it and adds snapshot strategies for tests.

## Topics

### In-memory terminal I/O

- ``InMemoryTerminalDevice``
- ``InMemoryTerminalDeviceEvent``
- ``InMemoryTerminalSession``
- <doc:Recording-Terminal-Output>
