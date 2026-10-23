// Prints a Ghostty round trip, so the CI log shows the linked library working.
// swiftlint:disable no_print

import TesseraTerminalSnapshotSupport

let terminal = VirtualTerminal.ghostty(cols: 20, rows: 3)
terminal.feed("hello\r\n\u{1B}[31mred\u{1B}[0m")
let cell = terminal.cell(row: 1, column: 0)
let cursor = terminal.cursorPosition()
print("row 0: \"\(terminal.text(row: 0))\"")
print("row 1: \"\(terminal.text(row: 1))\"")
print("cell(1,0): \(cell.character) \(cell.foreground)")
print("cursor: column \(cursor.column), row \(cursor.row)")

// swiftlint:enable no_print
