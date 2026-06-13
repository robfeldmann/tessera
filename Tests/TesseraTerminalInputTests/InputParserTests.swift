import TesseraTerminalCore
import Testing

@testable import TesseraTerminalInput

@Test
func `parser maps q to a character key`() {
  #expect(InputParser.parse(0x71) == .key(Key(code: .character("q"))))
}

@Test
func `parser maps printable ascii bytes to character keys`() {
  var parser = InputParser()

  #expect(parser.feed(0x20) == [.key(Key(code: .character(" ")))])
  #expect(parser.feed(0x41) == [.key(Key(code: .character("A")))])
  #expect(parser.feed(0x7E) == [.key(Key(code: .character("~")))])
}

@Test
func `parser maps control bytes to key codes`() {
  var parser = InputParser()

  #expect(parser.feed(0x00) == [.key(Key(code: .character(" "), modifiers: .control))])
  #expect(parser.feed(0x01) == [.key(Key(code: .character("A"), modifiers: .control))])
  #expect(parser.feed(0x08) == [.key(Key(code: .character("H"), modifiers: .control))])
  #expect(parser.feed(0x1A) == [.key(Key(code: .character("Z"), modifiers: .control))])
}

@Test
func `parser maps tab enter and backspace controls to key codes`() {
  var parser = InputParser()

  #expect(parser.feed(0x09) == [.key(Key(code: .tab))])
  #expect(parser.feed(0x0A) == [.key(Key(code: .enter))])
  #expect(parser.feed(0x0D) == [.key(Key(code: .enter))])
  #expect(parser.feed(0x7F) == [.key(Key(code: .backspace))])
}

@Test
func `parser emits unknown for unsupported control and non ascii bytes`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B) == [.unknown([0x1B])])
  #expect(parser.feed(0x80) == [.unknown([0x80])])
  #expect(parser.feed(0xFF) == [.unknown([0xFF])])
}

@Test
func `parser feeds byte sequences in order`() {
  var parser = InputParser()

  let events = parser.feed(contentsOf: [0x61, 0x62, 0x0D])

  #expect(
    events == [
      .key(Key(code: .character("a"))),
      .key(Key(code: .character("b"))),
      .key(Key(code: .enter)),
    ])
}

@Test
func `parser assembles utf8 split across feeds`() {
  var parser = InputParser()

  #expect(parser.feed(0xE4).isEmpty)
  #expect(parser.feed(0xBD).isEmpty)
  #expect(parser.feed(0xA0) == [.key(Key(code: .character("你")))])
  #expect(
    parser.feed(contentsOf: Array("🙂".utf8)) == [.key(Key(code: .character("🙂")))])
}

@Test
func `parser flushes partial utf8 as unknown`() {
  var parser = InputParser()

  #expect(parser.feed(0xE4).isEmpty)
  #expect(parser.flush() == [.unknown([0xE4])])
  #expect(parser.flush().isEmpty)
}

@Test
func `parser emits unknown for invalid utf8`() {
  var parser = InputParser()

  #expect(parser.feed(0xE4).isEmpty)
  #expect(parser.feed(0x41) == [.unknown([0xE4, 0x41])])
  #expect(parser.feed(0x62) == [.key(Key(code: .character("b")))])
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
