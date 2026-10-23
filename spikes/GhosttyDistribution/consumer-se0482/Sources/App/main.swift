// Spike evidence: prints its round trip for the record.
// swiftlint:disable no_print

import TesseraTerminalSnapshotSupport

let terminal = VirtualTerminal.ghostty(cols: 20, rows: 3)
terminal.feed("hello\r\n\u{1B}[31mred\u{1B}[0m")
print("unavailable:", VirtualTerminal.isGhosttyUnavailable)
print("row0:", terminal.text(row: 0))
print("row1:", terminal.text(row: 1))
print("cell(1,0):", terminal.cell(row: 1, column: 0))
print("cursor:", terminal.cursorPosition())

// swiftlint:enable no_print
