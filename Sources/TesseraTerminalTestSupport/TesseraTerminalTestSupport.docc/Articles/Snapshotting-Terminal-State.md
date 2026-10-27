# Snapshotting Terminal State

Terminal-output tests do not need sleeps, polling, or a wall-clock deadline. Choose the smallest observable result that proves the behavior: device events and bytes for I/O, a buffer dump for buffer contents, or a rendered screen snapshot for terminal presentation.

This module is deliberately test support. Production code owns its terminal sessions; tests use these helpers to make the output of that code inspectable and deterministic.

## Start with deterministic device evidence

For I/O behavior, run the code over an `InMemoryTerminalDevice` and assert its `events` for lifecycle ordering or its `bytes` for the complete output stream. The device lives in `TesseraTerminalInMemory`, which this module re-exports; that module's Recording Terminal Output article covers it.

## Snapshot the layer that failed

When a buffer is the subject under test, its custom dump renders each cell directly: blanks are shown as `·`, continuations as `◌`, and raw cells as `◆`. Use that dump for buffer-level expectations. When the renderer's exact emitted bytes matter, ``RendererCustomDump`` groups the bytes into readable terminal chunks while retaining their hexadecimal representation.

For presentation-level behavior, a `VirtualTerminal` can interpret output bytes into a terminal screen, whose `ScreenSnapshot` is then supplied to `SnapshotTesting`. `VirtualTerminal` and `ScreenSnapshot` are supplied by snapshot support; this module does not make either a production terminal session.

```swift
import SnapshotTesting
import TesseraTerminalTestSupport

assertSnapshot(of: screen, as: .terminalText())
assertSnapshot(of: screen, as: .terminalStyledGrid())
assertSnapshot(of: screen, as: .terminalLinksGrid())
assertSnapshot(of: screen, as: .terminalDebugDump)
```

Use `Snapshotting.terminalText(trim:)` for the character grid. Add `Snapshotting.terminalStyledGrid(trim:)` when attributes are part of the contract, and `Snapshotting.terminalLinksGrid(trim:)` when hyperlink metadata matters. Use `Snapshotting.terminalDebugDump` for cursor position and detailed per-cell diagnostics. These strategies are alternatives: choose the least detailed snapshot that detects the regression you care about.

## Make whitespace intentional

The text, styled, and link strategies accept ``TerminalSnapshotTrim``. Their default, ``TerminalSnapshotTrim/trailing``, removes trailing blank cells from each row. Select ``TerminalSnapshotTrim/none`` when terminal width, padding, or blank cells are observable behavior. The choice belongs in the assertion rather than in a timing-dependent cleanup step.
