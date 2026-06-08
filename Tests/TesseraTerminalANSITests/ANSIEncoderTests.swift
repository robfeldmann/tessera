import Dependencies
import DependenciesTestSupport
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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 8, rows: 4)
  }
)
func `cursor position round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

  feed([.cursorPosition(TerminalPosition(column: 3, row: 2))], into: terminal)

  #expect(terminal.cursorPosition() == TerminalPosition(column: 3, row: 2))
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 10, rows: 5)
  }
)
func `relative cursor movement round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 6, rows: 2)
  }
)
func `cursor save and restore round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 4, rows: 1)
  }
)
func `cursor visibility sequences are accepted by virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  expectBytes(.eraseInLine(.allAndScrollback), esc("[2K"))
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 1)
  }
)
func `erase to end of line round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 1)
  }
)
func `erase to beginning of line round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 1)
  }
)
func `erase all of line round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 1)
  }
)
func `erase all and scrollback in line aliases whole line erase`() {
  @Dependency(\.virtualTerminal) var terminal

  feed(
    [
      .text("Hello"),
      .cursorPosition(TerminalPosition(column: 2, row: 0)),
      .eraseInLine(.allAndScrollback),
    ],
    into: terminal
  )

  #expect(terminal.text(row: 0) == "     ")
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 2)
  }
)
func `erase display to end round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 2)
  }
)
func `erase display to beginning round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 2)
  }
)
func `erase display all round trips through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

  feed([.text("Again"), .eraseInDisplay(.all)], into: terminal)

  #expect(terminal.text(row: 0) == "     ")
  #expect(terminal.text(row: 1) == "     ")
}

@Test(
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 5, rows: 2)
  }
)
func `erase display all and scrollback is accepted by virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal

  // Ghostty accepts CSI 3J as a scrollback purge without clearing visible cells.
  feed([.text("Again"), .eraseInDisplay(.allAndScrollback)], into: terminal)

  #expect(terminal.text(row: 0) == "Again")
  #expect(terminal.text(row: 1) == "     ")
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
  .dependencies {
    $0.virtualTerminal = .ghostty(cols: 6, rows: 1)
  }
)
func `text bell and raw payloads round trip through virtual terminal`() {
  @Dependency(\.virtualTerminal) var terminal
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

func utf8(_ string: String) -> [UInt8] {
  Array(string.utf8)
}

func feed(
  _ sequences: [ControlSequence],
  into terminal: VirtualTerminal
) {
  terminal.feed(ANSIEncoder.encode(sequences))
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
