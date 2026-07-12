# ``TesseraTerminalTestSupport``

@Metadata {
    @PageImage(purpose: icon, source: "test-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "test-card", alt: "Module card.")
}

Build deterministic terminal-output tests without waiting for wall-clock timing.

This module is test support, not a production terminal-session API. It records a terminal
device's lifecycle and output in memory, exposes readable buffer and renderer dumps, and adds
terminal-focused strategies to `SnapshotTesting`. Assert the event sequence or captured bytes when
you are testing I/O behavior; snapshot a rendered terminal state when you are testing what a user
would see.

The snapshot strategies cover a character grid, an aligned style grid, hyperlink metadata, and a
per-cell debug dump: `Snapshotting.terminalText(trim:)`,
`Snapshotting.terminalStyledGrid(trim:)`, `Snapshotting.terminalLinksGrid(trim:)`, and
`Snapshotting.terminalDebugDump`. ``TerminalSnapshotTrim`` makes the whitespace contract explicit,
so a test can preserve every cell or ignore row-ending blanks deliberately.

``TestTerminal`` is currently an empty public marker type. It does not open, own, or emulate a
terminal session; use the in-memory device and snapshot helpers for observable test behavior.

## Topics

### In-memory terminal I/O

- ``InMemoryTerminalDevice``
- ``InMemoryTerminalDeviceEvent``

### Snapshot options and strategies

- ``TerminalSnapshotTrim``
- <doc:Terminal-Snapshot-Strategies>

### Buffer and renderer dumps
Use `Buffer.customDumpDescription` to inspect buffer cells directly.

- ``RendererCustomDump``

### Test terminal

- ``TestTerminal``
