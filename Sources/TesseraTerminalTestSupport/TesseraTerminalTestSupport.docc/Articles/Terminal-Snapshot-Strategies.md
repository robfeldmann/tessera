# Terminal Snapshot Strategies

Terminal strategies for `SnapshotTesting` when the value is a `ScreenSnapshot` and the format is a
string. `ScreenSnapshot` comes from snapshot support; these strategies are test-only views of that
state, not terminal-session APIs.

## Choose a strategy

### Terminal content

- `Snapshotting.terminalText(trim:)`
- `Snapshotting.terminalStyledGrid(trim:)`
- `Snapshotting.terminalLinksGrid(trim:)`

### Terminal diagnostics

- `Snapshotting.terminalDebugDump`

### Whitespace policy

- ``TerminalSnapshotTrim``
