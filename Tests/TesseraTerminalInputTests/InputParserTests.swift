import Testing

@testable import TesseraTerminalInput

@Test
func `parser maps q to quit`() {
  #expect(InputParser.parse(0x71) == .quit)
}

@Test
func `parser maps printable ascii bytes to characters`() {
  #expect(InputParser.parse(0x20) == .character(" "))
  #expect(InputParser.parse(0x41) == .character("A"))
  #expect(InputParser.parse(0x7E) == .character("~"))
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
