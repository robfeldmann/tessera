import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalInput

struct ParserCase: Sendable {
  var bytes: [UInt8]
  var event: InputEvent

  init(_ string: String, _ event: InputEvent) {
    self.bytes = Array(string.utf8)
    self.event = event
  }
}

let csiKeyCases: [ParserCase] = [
  ParserCase("\u{1B}[A", .key(Key(code: .up))),
  ParserCase("\u{1B}[B", .key(Key(code: .down))),
  ParserCase("\u{1B}[C", .key(Key(code: .right))),
  ParserCase("\u{1B}[D", .key(Key(code: .left))),
  ParserCase("\u{1B}[H", .key(Key(code: .home))),
  ParserCase("\u{1B}[F", .key(Key(code: .end))),
  ParserCase("\u{1B}[Z", .key(Key(code: .tab, modifiers: .shift))),
]

let modifiedCSIKeyCases: [ParserCase] = [
  ParserCase("\u{1B}[1;2A", .key(Key(code: .up, modifiers: .shift))),
  ParserCase("\u{1B}[1;3A", .key(Key(code: .up, modifiers: .alt))),
  ParserCase("\u{1B}[1;4A", .key(Key(code: .up, modifiers: [.shift, .alt]))),
  ParserCase("\u{1B}[1;5A", .key(Key(code: .up, modifiers: .control))),
  ParserCase("\u{1B}[1;6A", .key(Key(code: .up, modifiers: [.shift, .control]))),
  ParserCase("\u{1B}[1;7A", .key(Key(code: .up, modifiers: [.alt, .control]))),
  ParserCase("\u{1B}[1;8A", .key(Key(code: .up, modifiers: [.shift, .alt, .control]))),
  ParserCase("\u{1B}[1;5B", .key(Key(code: .down, modifiers: .control))),
  ParserCase("\u{1B}[1;5C", .key(Key(code: .right, modifiers: .control))),
  ParserCase("\u{1B}[1;5D", .key(Key(code: .left, modifiers: .control))),
  ParserCase("\u{1B}[1;5H", .key(Key(code: .home, modifiers: .control))),
  ParserCase("\u{1B}[1;5F", .key(Key(code: .end, modifiers: .control))),
]

let ss3KeyCases: [ParserCase] = [
  ParserCase("\u{1B}OA", .key(Key(code: .up))),
  ParserCase("\u{1B}OB", .key(Key(code: .down))),
  ParserCase("\u{1B}OC", .key(Key(code: .right))),
  ParserCase("\u{1B}OD", .key(Key(code: .left))),
  ParserCase("\u{1B}OP", .key(Key(code: .function(1)))),
  ParserCase("\u{1B}OQ", .key(Key(code: .function(2)))),
  ParserCase("\u{1B}OR", .key(Key(code: .function(3)))),
  ParserCase("\u{1B}OS", .key(Key(code: .function(4)))),
]

let tildeKeyCases: [ParserCase] = [
  ParserCase("\u{1B}[1~", .key(Key(code: .home))),
  ParserCase("\u{1B}[2~", .key(Key(code: .insert))),
  ParserCase("\u{1B}[3~", .key(Key(code: .delete))),
  ParserCase("\u{1B}[4~", .key(Key(code: .end))),
  ParserCase("\u{1B}[5~", .key(Key(code: .pageUp))),
  ParserCase("\u{1B}[6~", .key(Key(code: .pageDown))),
  ParserCase("\u{1B}[7~", .key(Key(code: .home))),
  ParserCase("\u{1B}[8~", .key(Key(code: .end))),
  ParserCase("\u{1B}[11~", .key(Key(code: .function(1)))),
  ParserCase("\u{1B}[12~", .key(Key(code: .function(2)))),
  ParserCase("\u{1B}[13~", .key(Key(code: .function(3)))),
  ParserCase("\u{1B}[14~", .key(Key(code: .function(4)))),
  ParserCase("\u{1B}[15~", .key(Key(code: .function(5)))),
  ParserCase("\u{1B}[17~", .key(Key(code: .function(6)))),
  ParserCase("\u{1B}[18~", .key(Key(code: .function(7)))),
  ParserCase("\u{1B}[19~", .key(Key(code: .function(8)))),
  ParserCase("\u{1B}[20~", .key(Key(code: .function(9)))),
  ParserCase("\u{1B}[21~", .key(Key(code: .function(10)))),
  ParserCase("\u{1B}[23~", .key(Key(code: .function(11)))),
  ParserCase("\u{1B}[24~", .key(Key(code: .function(12)))),
]

let modifiedTildeKeyCases: [ParserCase] = [
  ParserCase("\u{1B}[3;2~", .key(Key(code: .delete, modifiers: .shift))),
  ParserCase("\u{1B}[3;3~", .key(Key(code: .delete, modifiers: .alt))),
  ParserCase("\u{1B}[3;4~", .key(Key(code: .delete, modifiers: [.shift, .alt]))),
  ParserCase("\u{1B}[3;5~", .key(Key(code: .delete, modifiers: .control))),
  ParserCase("\u{1B}[3;6~", .key(Key(code: .delete, modifiers: [.shift, .control]))),
  ParserCase("\u{1B}[3;7~", .key(Key(code: .delete, modifiers: [.alt, .control]))),
  ParserCase("\u{1B}[3;8~", .key(Key(code: .delete, modifiers: [.shift, .alt, .control]))),
  ParserCase("\u{1B}[5;5~", .key(Key(code: .pageUp, modifiers: .control))),
  ParserCase("\u{1B}[6;5~", .key(Key(code: .pageDown, modifiers: .control))),
  ParserCase("\u{1B}[11;5~", .key(Key(code: .function(1), modifiers: .control))),
]

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

  #expect(parser.feed(0x80) == [.unknown([0x80])])
  #expect(parser.feed(0xFF) == [.unknown([0xFF])])
}

@Test
func `parser flushes bare escape as escape key`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B).isEmpty)
  #expect(parser.flush() == [.key(Key(code: .escape))])
  #expect(parser.flush().isEmpty)
}

@Test
func `parser maps escape followed by printable character to alt key`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B).isEmpty)
  #expect(parser.feed(0x61) == [.key(Key(code: .character("a"), modifiers: .alt))])
}

@Test
func `parser keeps escape separated when flushed before next character`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B).isEmpty)
  #expect(parser.flush() == [.key(Key(code: .escape))])
  #expect(parser.feed(0x61) == [.key(Key(code: .character("a")))])
}

@Test
func `parser buffers csi sequences across feeds and emits unknown on final byte`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B).isEmpty)
  #expect(parser.feed(contentsOf: [0x5B, 0x39, 0x39]).isEmpty)
  #expect(parser.feed(0x58) == [.unknown([0x1B, 0x5B, 0x39, 0x39, 0x58])])
}

@Test
func `parser flushes incomplete csi and ss3 sequences as unknown`() {
  var csiParser = InputParser()
  var ss3Parser = InputParser()

  #expect(csiParser.feed(contentsOf: [0x1B, 0x5B, 0x31]).isEmpty)
  #expect(csiParser.flush() == [.unknown([0x1B, 0x5B, 0x31])])

  #expect(ss3Parser.feed(contentsOf: [0x1B, 0x4F]).isEmpty)
  #expect(ss3Parser.flush() == [.unknown([0x1B, 0x4F])])
}

@Test(arguments: csiKeyCases)
func `parser maps csi key sequences`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: modifiedCSIKeyCases)
func `parser maps modified csi key sequences`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: ss3KeyCases)
func `parser maps ss3 key sequences`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: tildeKeyCases)
func `parser maps tilde key sequences`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: modifiedTildeKeyCases)
func `parser maps modified tilde key sequences`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test
func `parser maps modified csi split across feeds`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B).isEmpty)
  #expect(parser.feed(contentsOf: [0x5B, 0x31, 0x3B]).isEmpty)
  #expect(
    parser.feed(contentsOf: [0x35, 0x41]) == [
      .key(Key(code: .up, modifiers: .control))
    ])
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
func `event log formats parser transcripts deterministically`() {
  let events: [InputEvent] = [
    .key(Key(code: .character("A"), modifiers: [.shift, .control])),
    .paste("line\nbreak"),
    .resize(TerminalSize(columns: 2, rows: 1)),
    .unknown([0x1B, 0x5B]),
  ]

  assertInlineSnapshot(of: eventLog(events), as: .lines) {
    """
    key(character("A"), modifiers: shift+control)
    paste("line\\nbreak")
    resize(columns: 2, rows: 1)
    unknown(1B 5B)
    """
  }
}

@Test
func `parser emits one paste event for complete bracketed paste`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: bracketedPaste("hello")) == [.paste("hello")])
}

@Test
func `parser emits empty paste event for empty bracketed paste payload`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: bracketedPaste("")) == [.paste("")])
}

@Test
func `parser emits one paste event when bracketed paste arrives byte by byte`() {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in bracketedPaste("bytewise") {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(events == [.paste("bytewise")])
}

@Test
func `parser recognizes bracketed paste start marker split across feeds`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: Array("\u{1B}[2".utf8)).isEmpty)
  #expect(parser.feed(contentsOf: Array("00~".utf8)).isEmpty)
  #expect(parser.feed(contentsOf: Array("split\u{1B}[201~".utf8)) == [.paste("split")])
}

@Test
func `parser recognizes bracketed paste end marker split across feeds`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: bracketedPasteStart + Array("payload".utf8)).isEmpty)
  #expect(parser.feed(contentsOf: Array("\u{1B}[20".utf8)).isEmpty)
  #expect(parser.feed(0x31).isEmpty)
  #expect(parser.feed(0x7E) == [.paste("payload")])
}

@Test
func `parser preserves multiline bracketed paste payloads`() {
  var parser = InputParser()

  #expect(
    parser.feed(contentsOf: bracketedPaste("one\ntwo\r\nthree")) == [
      .paste("one\ntwo\r\nthree")
    ])
}

@Test
func `parser decodes utf8 bracketed paste payloads`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: bracketedPaste("你好🙂")) == [.paste("你好🙂")])
}

@Test
func `parser decodes invalid utf8 paste payloads with replacement characters`() {
  var parser = InputParser()
  let bytes = bracketedPasteStart + [0xE4, 0x41] + bracketedPasteEnd

  #expect(parser.feed(contentsOf: bytes) == [.paste("\u{FFFD}A")])
}

@Test
func `parser treats ansi looking bytes inside bracketed paste as payload`() {
  var parser = InputParser()
  let payload = "\u{1B}[A\u{1B}[200~literal"

  #expect(parser.feed(contentsOf: bracketedPaste(payload)) == [.paste(payload)])
}

@Test
func `parser treats bracketed paste start marker inside active paste as payload`() {
  var parser = InputParser()
  let payload = "before\u{1B}[200~after"

  #expect(parser.feed(contentsOf: bracketedPaste(payload)) == [.paste(payload)])
}

@Test
func `parser emits distinct events for consecutive bracketed pastes`() {
  var parser = InputParser()
  let bytes = bracketedPaste("first") + bracketedPaste("second")

  #expect(parser.feed(contentsOf: bytes) == [.paste("first"), .paste("second")])
}

@Test
func `parser keeps ordinary keys around bracketed paste separate`() {
  var parser = InputParser()
  let bytes = Array("a".utf8) + bracketedPaste("bulk") + Array("b".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    key(character("a"), modifiers: none)
    paste("bulk")
    key(character("b"), modifiers: none)
    """
  }
}

@Test
func `parser does not emit partial key events for incomplete bracketed paste`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: bracketedPasteStart + Array("abc\u{1B}[A".utf8)).isEmpty)
}

@Test
func `parser does not flush pending escape while bracketed paste is active`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: bracketedPasteStart + Array("p".utf8)).isEmpty)
  #expect(parser.flushPendingEscape().isEmpty)
  #expect(parser.feed(contentsOf: bracketedPasteEnd) == [.paste("p")])
}

@Test
func `parser flushes unterminated bracketed paste as unknown bytes`() {
  var parser = InputParser()
  let bytes = bracketedPasteStart + Array("abc\u{1B}[20".utf8)

  #expect(parser.feed(contentsOf: bytes).isEmpty)
  #expect(parser.flush() == [.unknown(bytes)])
  #expect(parser.flush().isEmpty)
}

@Test
func `input event can represent paste resize and unknown sequences`() {
  let paste = InputEvent.paste("hello")
  let resize = InputEvent.resize(TerminalSize(columns: 80, rows: 24))
  let unknown = InputEvent.unknown([0x1B, 0x5B, 0x39, 0x39, 0x58])

  #expect(paste == .paste("hello"))
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

private let bracketedPasteStart = Array("\u{1B}[200~".utf8)
private let bracketedPasteEnd = Array("\u{1B}[201~".utf8)

private func bracketedPaste(_ string: String) -> [UInt8] {
  bracketedPasteStart + Array(string.utf8) + bracketedPasteEnd
}

private func eventLog(_ events: [InputEvent]) -> String {
  events.map(eventLogLine).joined(separator: "\n")
}

private func eventLogLine(_ event: InputEvent) -> String {
  switch event {
  case .key(let key):
    "key(\(key.code), modifiers: \(modifierLog(key.modifiers)))"

  case .paste(let string):
    "paste(\(String(reflecting: string)))"

  case .resize(let size):
    "resize(columns: \(size.columns), rows: \(size.rows))"

  case .unknown(let bytes):
    "unknown(\(hex(bytes)))"
  }
}

private func modifierLog(_ modifiers: Modifiers) -> String {
  var names: [String] = []
  if modifiers.contains(.shift) {
    names.append("shift")
  }
  if modifiers.contains(.alt) {
    names.append("alt")
  }
  if modifiers.contains(.control) {
    names.append("control")
  }
  return names.isEmpty ? "none" : names.joined(separator: "+")
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
