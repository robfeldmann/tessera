// Spike evidence: prints its round trip for the record.
// swiftlint:disable no_print

import GhosttyVt

var terminal: GhosttyTerminal?
precondition(ghostty_terminal_new(nil, &terminal, 20, 3) == GHOSTTY_SUCCESS)
let bytes = Array("hello\r\nred".utf8)
ghostty_terminal_vt_write(terminal, bytes, bytes.count)
var x: UInt16 = 0
var y: UInt16 = 0
_ = ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_X, &x)
_ = ghostty_terminal_get(terminal, GHOSTTY_TERMINAL_DATA_CURSOR_Y, &y)
print("cursor:", x, y)
ghostty_terminal_free(terminal)

// swiftlint:enable no_print
