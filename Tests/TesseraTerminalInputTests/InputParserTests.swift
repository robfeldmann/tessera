import TesseraTerminalCore
import Testing

@testable import TesseraTerminalInput

@Test
func `parser maps q to a character key`() {
  #expect(InputParser.parse(0x71) == .key(Key(code: .character("q"))))
}

@Test
func `parser maps printable ascii bytes to character keys`() {
  #expect(InputParser.parse(0x20) == .key(Key(code: .character(" "))))
  #expect(InputParser.parse(0x41) == .key(Key(code: .character("A"))))
  #expect(InputParser.parse(0x7E) == .key(Key(code: .character("~"))))
}

@Test
func `parser ignores control bytes`() {
  #expect(InputParser.parse(0x00) == nil)
  #expect(InputParser.parse(0x1B) == nil)
  #expect(InputParser.parse(0x7F) == nil)
}

@Test
func `parser ignores non ascii bytes`() {
  #expect(InputParser.parse(0x80) == nil)
  #expect(InputParser.parse(0xC3) == nil)
  #expect(InputParser.parse(0xFF) == nil)
}

@Test
func `input event can represent resize and unknown sequences`() {
  let resize = InputEvent.resize(TerminalSize(columns: 80, rows: 24))
  let unknown = InputEvent.unknown([0x1B, 0x5B, 0x39, 0x39, 0x58])

  #expect(resize == .resize(TerminalSize(columns: 80, rows: 24)))
  #expect(unknown == .unknown([0x1B, 0x5B, 0x39, 0x39, 0x58]))
}

@Test
func `key stores code and modifiers`() {
  let key = Key(code: .up, modifiers: [.control, .shift])

  #expect(key.code == .up)
  #expect(key.modifiers.contains(.control))
  #expect(key.modifiers.contains(.shift))
  #expect(key.modifiers.contains(.alt) == false)
}
