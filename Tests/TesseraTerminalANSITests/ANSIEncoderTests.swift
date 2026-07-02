import Foundation
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@testable import TesseraTerminalANSI

@Test
func `empty sequence list encodes no bytes`() {
  expectBytes(ANSIEncoder.encode([]), [])
}

@Test
func `control sequence bytes convenience uses encode into`() {
  #expect(ControlSequence.bell.bytes == ANSIEncoder.encode([.bell]))
}

@Test
func `cursor control sequences encode exact bytes`() {
  expectBytes(.cursorPosition(TerminalPosition(column: 0, row: 0)), esc("[1;1H"))
  expectBytes(.cursorPosition(TerminalPosition(column: 10, row: 5)), esc("[6;11H"))
  expectBytes(.cursorUp(3), esc("[3A"))
  expectBytes(.cursorDown(4), esc("[4B"))
  expectBytes(.cursorForward(5), esc("[5C"))
  expectBytes(.cursorBack(6), esc("[6D"))
  expectBytes(.cursorVisible(true), esc("[?25h"))
  expectBytes(.cursorVisible(false), esc("[?25l"))
  expectBytes(.cursorSave, esc("7"))
  expectBytes(.cursorRestore, esc("8"))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `cursor position round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 4)

  feed([.cursorPosition(TerminalPosition(column: 3, row: 2))], into: terminal)

  #expect(terminal.cursorPosition() == TerminalPosition(column: 3, row: 2))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `relative cursor movement round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 10, rows: 5)

  feed(
    [
      .cursorPosition(TerminalPosition(column: 4, row: 2)),
      .cursorUp(1),
      .cursorBack(2),
      .cursorDown(2),
      .cursorForward(3),
    ],
    into: terminal
  )

  #expect(terminal.cursorPosition() == TerminalPosition(column: 5, row: 3))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `cursor save and restore round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 6, rows: 2)

  feed(
    [
      .cursorPosition(TerminalPosition(column: 2, row: 0)),
      .cursorSave,
      .cursorPosition(TerminalPosition(column: 0, row: 1)),
      .cursorRestore,
      .text("X"),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "  X   ")
  #expect(terminal.cursorPosition() == TerminalPosition(column: 3, row: 0))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `cursor visibility sequences are accepted by virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 1)

  feed(
    [.cursorVisible(false), .text("A"), .cursorVisible(true), .text("B")],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "AB  ")
  #expect(terminal.cursorPosition() == TerminalPosition(column: 2, row: 0))
}

@Test
func `erase display sequences encode exact bytes`() {
  expectBytes(.eraseInDisplay(.toEnd), esc("[J"))
  expectBytes(.eraseInDisplay(.toBeginning), esc("[1J"))
  expectBytes(.eraseInDisplay(.all), esc("[2J"))
  expectBytes(.eraseInDisplay(.allAndScrollback), esc("[3J"))
}

@Test
func `erase line sequences encode exact bytes`() {
  expectBytes(.eraseInLine(.toEnd), esc("[K"))
  expectBytes(.eraseInLine(.toBeginning), esc("[1K"))
  expectBytes(.eraseInLine(.all), esc("[2K"))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase to end of line round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 1)

  feed(
    [
      .text("Hello"),
      .cursorPosition(TerminalPosition(column: 1, row: 0)),
      .eraseInLine(.toEnd),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "H    ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase to beginning of line round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 1)

  feed(
    [
      .text("Hello"),
      .cursorPosition(TerminalPosition(column: 2, row: 0)),
      .eraseInLine(.toBeginning),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "   lo")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase all of line round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 1)

  feed(
    [
      .text("Hello"),
      .cursorPosition(TerminalPosition(column: 2, row: 0)),
      .eraseInLine(.all),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "     ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase display to end round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 2)

  feed(
    [
      .text("HelloWorld"),
      .cursorPosition(TerminalPosition(column: 2, row: 0)),
      .eraseInDisplay(.toEnd),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "He   ")
  #expect(terminal.text(row: 1) == "     ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase display to beginning round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 2)

  feed(
    [
      .text("HelloWorld"),
      .cursorPosition(TerminalPosition(column: 2, row: 1)),
      .eraseInDisplay(.toBeginning),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "     ")
  #expect(terminal.text(row: 1) == "   ld")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase display all round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 2)

  feed([.text("Again"), .eraseInDisplay(.all)], into: terminal)

  #expect(terminal.text(row: 0) == "     ")
  #expect(terminal.text(row: 1) == "     ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `erase display all and scrollback is accepted by virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 2)

  // Ghostty accepts CSI 3J as a scrollback purge without clearing visible cells.
  feed([.text("Again"), .eraseInDisplay(.allAndScrollback)], into: terminal)

  #expect(terminal.text(row: 0) == "Again")
  #expect(terminal.text(row: 1) == "     ")
}

@Test
func `foreground colors encode exact bytes`() {
  for (color, parameter) in ansiForegroundParameters() {
    expectBytes(.setForeground(.ansi(color)), sgr(parameter))
  }

  expectBytes(.setForeground(.default), sgr(39))
  expectBytes(.setForeground(.indexed(0)), sgr(38, 5, 0))
  expectBytes(.setForeground(.indexed(15)), sgr(38, 5, 15))
  expectBytes(.setForeground(.indexed(255)), sgr(38, 5, 255))
  expectBytes(.setForeground(.rgb(0, 127, 255)), sgr(38, 2, 0, 127, 255))
}

@Test
func `background colors encode exact bytes`() {
  for (color, parameter) in ansiBackgroundParameters() {
    expectBytes(.setBackground(.ansi(color)), sgr(parameter))
  }

  expectBytes(.setBackground(.default), sgr(49))
  expectBytes(.setBackground(.indexed(0)), sgr(48, 5, 0))
  expectBytes(.setBackground(.indexed(15)), sgr(48, 5, 15))
  expectBytes(.setBackground(.indexed(255)), sgr(48, 5, 255))
  expectBytes(.setBackground(.rgb(255, 127, 0)), sgr(48, 2, 255, 127, 0))
}

@Test
func `ansi colors and indexed colors stay distinct`() {
  expectBytes(.setForeground(.ansi(.red)), sgr(31))
  expectBytes(.setForeground(.indexed(1)), sgr(38, 5, 1))
  expectBytes(.setBackground(.default), sgr(49))
  expectBytes(.setBackground(.ansi(.black)), sgr(40))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `colors round trip through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 3, rows: 1)

  feed(
    [
      .setForeground(.indexed(196)),
      .setBackground(.rgb(1, 2, 3)),
      .text("X"),
    ],
    into: terminal
  )
  let cell = terminal.cell(row: 0, column: 0)

  #expect(cell.foreground == .indexed(196))
  #expect(cell.background == .rgb(1, 2, 3))
}

@Test
func `attributes encode exact bytes`() {
  expectBytes(.resetAttributes, sgr(0))
  expectBytes(.setBold(true), sgr(1))
  expectBytes(.setBold(false), sgr(22))
  expectBytes(.setDim(true), sgr(2))
  expectBytes(.setDim(false), sgr(22))
  expectBytes(.setItalic(true), sgr(3))
  expectBytes(.setItalic(false), sgr(23))
  expectBytes(.setReverse(true), sgr(7))
  expectBytes(.setReverse(false), sgr(27))
  expectBytes(.setStrikethrough(true), sgr(9))
  expectBytes(.setStrikethrough(false), sgr(29))
  expectBytes(.setUnderline(true), sgr(4))
  expectBytes(.setUnderline(false), sgr(24))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `attributes round trip through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 1)

  feed(
    [
      .setBold(true),
      .setDim(true),
      .setItalic(true),
      .setReverse(true),
      .setStrikethrough(true),
      .setUnderline(true),
      .text("X"),
      .resetAttributes,
      .text("Y"),
    ],
    into: terminal
  )
  let styledCell = terminal.cell(row: 0, column: 0)
  let resetCell = terminal.cell(row: 0, column: 1)

  #expect(styledCell.bold)
  #expect(styledCell.dim)
  #expect(styledCell.italic)
  #expect(styledCell.reverse)
  #expect(styledCell.strikethrough)
  #expect(styledCell.underline)
  #expect(!resetCell.bold)
  #expect(!resetCell.dim)
  #expect(!resetCell.italic)
  #expect(!resetCell.reverse)
  #expect(!resetCell.strikethrough)
  #expect(!resetCell.underline)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `normal intensity disables bold and dim`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 1)

  feed([.setBold(true), .setDim(true), .setBold(false), .text("X")], into: terminal)
  let cell = terminal.cell(row: 0, column: 0)

  #expect(!cell.bold)
  #expect(!cell.dim)
}

@Test
func `mode sequences encode exact bytes`() {
  expectBytes(.enterAltScreen, esc("[?1049h"))
  expectBytes(.exitAltScreen, esc("[?1049l"))
  expectBytes(.enterSynchronizedOutput, esc("[?2026h"))
  expectBytes(.exitSynchronizedOutput, esc("[?2026l"))
  expectBytes(.enableLineWrap(true), esc("[?7h"))
  expectBytes(.enableLineWrap(false), esc("[?7l"))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `alternate screen round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 1)

  feed([.text("Main"), .enterAltScreen], into: terminal)
  #expect(terminal.text(row: 0) == "     ")

  feed([.text("Alt"), .exitAltScreen], into: terminal)
  #expect(terminal.text(row: 0) == "Main ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `line wrap mode round trips through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)

  feed([.enableLineWrap(true), .text("ABCDE")], into: terminal)
  #expect(terminal.text(row: 0) == "ABCD")
  #expect(terminal.text(row: 1) == "E   ")

  feed(
    [.eraseInDisplay(.all), .cursorPosition(TerminalPosition(column: 0, row: 0))],
    into: terminal
  )
  feed([.enableLineWrap(false), .text("ABCDE")], into: terminal)
  #expect(terminal.text(row: 0) == "ABCE")
  #expect(terminal.text(row: 1) == "    ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `synchronized output mode is accepted by virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 6, rows: 1)

  feed([.enterSynchronizedOutput, .text("Sync"), .exitSynchronizedOutput], into: terminal)

  #expect(terminal.text(row: 0) == "Sync  ")
  #expect(terminal.cursorPosition() == TerminalPosition(column: 4, row: 0))
}

@Test
func `window title encodes exact bytes`() {
  expectBytes(.setWindowTitle("Tessera"), esc("]2;Tessera") + [0x07])
  expectBytes(.setWindowTitle("A\u{07}B\u{1B}C"), esc("]2;ABC") + [0x07])
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `window title is accepted without changing visible state`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 1)

  feed([.text("A"), .setWindowTitle("Tessera"), .text("B")], into: terminal)

  #expect(terminal.text(row: 0) == "AB  ")
  #expect(terminal.cursorPosition() == TerminalPosition(column: 2, row: 0))
}

@Test
func `text bell and raw payload sequences encode exact bytes`() {
  let oscPayload = RawTerminalPayload(bytes: esc("]2;Title") + [0x07])
  let visiblePayload = RawTerminalPayload(bytes: utf8("XY"), declaredWidth: 2)

  expectBytes(.text("Hi"), utf8("Hi"))
  expectBytes(.text("é👩‍💻"), utf8("é👩‍💻"))
  expectBytes(.bell, [0x07])
  expectBytes(.raw(oscPayload), oscPayload.bytes)
  expectBytes(.raw(visiblePayload), utf8("XY"))
  #expect(visiblePayload.declaredWidth == 2)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows.")
)
func `text bell and raw payloads round trip through virtual terminal`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 6, rows: 1)
  let titlePayload = RawTerminalPayload(bytes: esc("]2;Tessera") + [0x07])

  feed(
    [
      .text("A"),
      .bell,
      .raw(titlePayload),
      .raw(RawTerminalPayload(bytes: utf8("BC"))),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "ABC   ")
  #expect(terminal.cursorPosition() == TerminalPosition(column: 3, row: 0))
}

@Test
func `encode into appends without clearing existing bytes`() {
  var bytes = utf8("prefix")

  ControlSequence.cursorForward(2).encode(into: &bytes)

  expectBytes(bytes, utf8("prefix") + esc("[2C"))
}

@Test
func `multiple sequences compose in order and preserve utf8 text`() {
  let bytes = ANSIEncoder.encode([
    .cursorSave,
    .text("é"),
    .setWindowTitle("Tessera"),
    .cursorRestore,
  ])

  expectBytes(bytes, esc("7") + utf8("é") + esc("]2;Tessera") + [0x07] + esc("8"))
}

@Test
func `window title strips osc terminators and uses bel terminator`() {
  expectBytes(
    .setWindowTitle("A\u{07}B\u{1B}C"),
    esc("]2;ABC") + [0x07]
  )
}

func expectBytes(
  _ sequence: ControlSequence,
  _ expected: [UInt8]
) {
  expectBytes(sequence.bytes, expected)
}

func expectBytes(
  _ actual: [UInt8],
  _ expected: [UInt8]
) {
  #expect(
    actual == expected,
    "expected bytes: \(hex(expected)); actual bytes: \(hex(actual))"
  )
}

func esc(_ suffix: String) -> [UInt8] {
  [0x1B] + utf8(suffix)
}

func sgr(_ parameters: Int...) -> [UInt8] {
  esc("[" + parameters.map(String.init).joined(separator: ";") + "m")
}

func utf8(_ string: String) -> [UInt8] {
  Array(string.utf8)
}

func feed(
  _ sequences: [ControlSequence],
  into terminal: VirtualTerminal
) {
  terminal.feed(ANSIEncoder.encode(sequences))
}

private func ansiForegroundParameters() -> [(ANSIColor, Int)] {
  [
    (.black, 30),
    (.blue, 34),
    (.brightBlack, 90),
    (.brightBlue, 94),
    (.brightCyan, 96),
    (.brightGreen, 92),
    (.brightMagenta, 95),
    (.brightRed, 91),
    (.brightWhite, 97),
    (.brightYellow, 93),
    (.cyan, 36),
    (.green, 32),
    (.magenta, 35),
    (.red, 31),
    (.white, 37),
    (.yellow, 33),
  ]
}

private func ansiBackgroundParameters() -> [(ANSIColor, Int)] {
  [
    (.black, 40),
    (.blue, 44),
    (.brightBlack, 100),
    (.brightBlue, 104),
    (.brightCyan, 106),
    (.brightGreen, 102),
    (.brightMagenta, 105),
    (.brightRed, 101),
    (.brightWhite, 107),
    (.brightYellow, 103),
    (.cyan, 46),
    (.green, 42),
    (.magenta, 45),
    (.red, 41),
    (.white, 47),
    (.yellow, 43),
  ]
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
