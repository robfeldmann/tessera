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

  init(bytes: [UInt8], _ event: InputEvent) {
    self.bytes = bytes
    self.event = event
  }
}

struct MouseReportCase: Sendable {
  var bytes: [UInt8]
  var event: MouseEvent

  init(_ string: String, _ event: MouseEvent) {
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
  ParserCase("\u{1B}[P", .key(Key(code: .function(1)))),
  ParserCase("\u{1B}[Q", .key(Key(code: .function(2)))),
  ParserCase("\u{1B}[S", .key(Key(code: .function(4)))),
  ParserCase("\u{1B}[1P", .key(Key(code: .function(1)))),
  ParserCase("\u{1B}[1Q", .key(Key(code: .function(2)))),
  ParserCase("\u{1B}[1S", .key(Key(code: .function(4)))),
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
  ParserCase("\u{1B}[1;5P", .key(Key(code: .function(1), modifiers: .control))),
  ParserCase("\u{1B}[1;5Q", .key(Key(code: .function(2), modifiers: .control))),
  ParserCase("\u{1B}[1;5S", .key(Key(code: .function(4), modifiers: .control))),
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
  ParserCase(
    "\u{1B}[3;8~", .key(Key(code: .delete, modifiers: [.shift, .alt, .control]))),
  ParserCase("\u{1B}[5;5~", .key(Key(code: .pageUp, modifiers: .control))),
  ParserCase("\u{1B}[6;5~", .key(Key(code: .pageDown, modifiers: .control))),
  ParserCase("\u{1B}[11;5~", .key(Key(code: .function(1), modifiers: .control))),
]

let focusCSIReportCases: [ParserCase] = [
  ParserCase("\u{1B}[I", .focusGained),
  ParserCase("\u{1B}[O", .focusLost),
]

let malformedFocusCSIReportCases: [ParserCase] = [
  ParserCase("\u{1B}[1I", .unknown([0x1B, 0x5B, 0x31, 0x49])),
  ParserCase("\u{1B}[1O", .unknown([0x1B, 0x5B, 0x31, 0x4F])),
]

let malformedPrimaryDeviceAttributeCases: [ParserCase] = [
  ParserCase(
    "\u{1B}[c",
    .unknown(Array("\u{1B}[c".utf8))
  ),
  ParserCase(
    "\u{1B}[1;2c",
    .unknown(Array("\u{1B}[1;2c".utf8))
  ),
  ParserCase(
    "\u{1B}[?c",
    .unknown(Array("\u{1B}[?c".utf8))
  ),
  ParserCase(
    "\u{1B}[?1;c",
    .unknown(Array("\u{1B}[?1;c".utf8))
  ),
]

let kittyKeyboardEnhancementFlagCases: [ParserCase] = [
  ParserCase("\u{1B}[?0u", .kittyKeyboardEnhancementFlags(0)),
  ParserCase("\u{1B}[?5u", .kittyKeyboardEnhancementFlags(5)),
  ParserCase("\u{1B}[?127u", .kittyKeyboardEnhancementFlags(127)),
]

let malformedKittyKeyboardEnhancementFlagCases: [ParserCase] = [
  ParserCase(
    "\u{1B}[?u",
    .unknown(Array("\u{1B}[?u".utf8))
  ),
  ParserCase(
    "\u{1B}[?-1u",
    .unknown(Array("\u{1B}[?-1u".utf8))
  ),
  ParserCase(
    "\u{1B}[?1;2u",
    .unknown(Array("\u{1B}[?1;2u".utf8))
  ),
]

let privateModeStatusCases: [ParserCase] = [
  ParserCase(
    "\u{1B}[?2004;0$y",
    .privateModeStatus(PrivateModeStatus(mode: 2_004, state: .notRecognized))
  ),
  ParserCase(
    "\u{1B}[?1004;1$y",
    .privateModeStatus(PrivateModeStatus(mode: 1_004, state: .set))
  ),
  ParserCase(
    "\u{1B}[?1000;2$y",
    .privateModeStatus(PrivateModeStatus(mode: 1_000, state: .reset))
  ),
  ParserCase(
    "\u{1B}[?1002;3$y",
    .privateModeStatus(PrivateModeStatus(mode: 1_002, state: .permanentlySet))
  ),
  ParserCase(
    "\u{1B}[?1003;4$y",
    .privateModeStatus(PrivateModeStatus(mode: 1_003, state: .permanentlyReset))
  ),
  ParserCase(
    "\u{1B}[?1006;1$y",
    .privateModeStatus(PrivateModeStatus(mode: 1_006, state: .set))
  ),
  ParserCase(
    "\u{1B}[?2026;2$y",
    .privateModeStatus(PrivateModeStatus(mode: 2_026, state: .reset))
  ),
]

let malformedPrivateModeStatusCases: [ParserCase] = [
  ParserCase(
    "\u{1B}[?2004$y",
    .unknown(Array("\u{1B}[?2004$y".utf8))
  ),
  ParserCase(
    "\u{1B}[2004;1$y",
    .unknown(Array("\u{1B}[2004;1$y".utf8))
  ),
  ParserCase(
    "\u{1B}[?2004;5$y",
    .unknown(Array("\u{1B}[?2004;5$y".utf8))
  ),
  ParserCase(
    "\u{1B}[?;1$y",
    .unknown(Array("\u{1B}[?;1$y".utf8))
  ),
]

let mouseReportCases: [MouseReportCase] = [
  MouseReportCase(
    "\u{1B}[<0;12;34M",
    MouseEvent(kind: .press(.left), position: TerminalPosition(column: 11, row: 33))
  ),
  MouseReportCase(
    "\u{1B}[<1;2;3M",
    MouseEvent(kind: .press(.middle), position: TerminalPosition(column: 1, row: 2))
  ),
  MouseReportCase(
    "\u{1B}[<2;2;3M",
    MouseEvent(kind: .press(.right), position: TerminalPosition(column: 1, row: 2))
  ),
  MouseReportCase(
    "\u{1B}[<0;4;5m",
    MouseEvent(kind: .release(.left), position: TerminalPosition(column: 3, row: 4))
  ),
  MouseReportCase(
    "\u{1B}[<1;4;5m",
    MouseEvent(kind: .release(.middle), position: TerminalPosition(column: 3, row: 4))
  ),
  MouseReportCase(
    "\u{1B}[<2;4;5m",
    MouseEvent(kind: .release(.right), position: TerminalPosition(column: 3, row: 4))
  ),
  MouseReportCase(
    "\u{1B}[<3;4;5m",
    MouseEvent(kind: .release(nil), position: TerminalPosition(column: 3, row: 4))
  ),
  MouseReportCase(
    "\u{1B}[<32;8;9M",
    MouseEvent(kind: .drag(.left), position: TerminalPosition(column: 7, row: 8))
  ),
  MouseReportCase(
    "\u{1B}[<33;8;9M",
    MouseEvent(kind: .drag(.middle), position: TerminalPosition(column: 7, row: 8))
  ),
  MouseReportCase(
    "\u{1B}[<34;8;9M",
    MouseEvent(kind: .drag(.right), position: TerminalPosition(column: 7, row: 8))
  ),
  MouseReportCase(
    "\u{1B}[<35;10;11M",
    MouseEvent(kind: .move, position: TerminalPosition(column: 9, row: 10))
  ),
  MouseReportCase(
    "\u{1B}[<64;6;7M",
    MouseEvent(kind: .scroll(.up), position: TerminalPosition(column: 5, row: 6))
  ),
  MouseReportCase(
    "\u{1B}[<65;6;7M",
    MouseEvent(kind: .scroll(.down), position: TerminalPosition(column: 5, row: 6))
  ),
  MouseReportCase(
    "\u{1B}[<66;6;7M",
    MouseEvent(kind: .scroll(.left), position: TerminalPosition(column: 5, row: 6))
  ),
  MouseReportCase(
    "\u{1B}[<67;6;7M",
    MouseEvent(kind: .scroll(.right), position: TerminalPosition(column: 5, row: 6))
  ),
  MouseReportCase(
    "\u{1B}[<4;2;3M",
    MouseEvent(
      kind: .press(.left),
      position: TerminalPosition(column: 1, row: 2),
      modifiers: .shift
    )
  ),
  MouseReportCase(
    "\u{1B}[<8;2;3M",
    MouseEvent(
      kind: .press(.left),
      position: TerminalPosition(column: 1, row: 2),
      modifiers: .alt
    )
  ),
  MouseReportCase(
    "\u{1B}[<16;2;3M",
    MouseEvent(
      kind: .press(.left),
      position: TerminalPosition(column: 1, row: 2),
      modifiers: .control
    )
  ),
  MouseReportCase(
    "\u{1B}[<63;2;3M",
    MouseEvent(
      kind: .move,
      position: TerminalPosition(column: 1, row: 2),
      modifiers: [.shift, .alt, .control]
    )
  ),
]

let malformedMouseReportCases: [ParserCase] = [
  ParserCase(
    "\u{1B}[<0;0;1M",
    .unknown([0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x30, 0x3B, 0x31, 0x4D])
  ),
  ParserCase(
    "\u{1B}[<0;1;0M",
    .unknown([0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x3B, 0x30, 0x4D])
  ),
  ParserCase(
    "\u{1B}[<128;1;1M",
    .unknown([
      0x1B, 0x5B, 0x3C, 0x31, 0x32, 0x38, 0x3B, 0x31, 0x3B, 0x31, 0x4D,
    ])
  ),
  ParserCase(
    "\u{1B}[<0;1M",
    .unknown([0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x4D])
  ),
  ParserCase(
    "\u{1B}[<;1;1M",
    .unknown([0x1B, 0x5B, 0x3C, 0x3B, 0x31, 0x3B, 0x31, 0x4D])
  ),
]

let malformedKittyGraphicsAPCCases: [ParserCase] = [
  ParserCase(
    bytes: kittyGraphicsAPC("i=7OK"),
    .unknown(kittyGraphicsAPC("i=7OK"))
  ),
  ParserCase(
    bytes: kittyGraphicsAPC("i=not-a-number;OK"),
    .unknown(kittyGraphicsAPC("i=not-a-number;OK"))
  ),
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

@Test(arguments: focusCSIReportCases)
func `parser maps focus reports in one feed`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: focusCSIReportCases)
func `parser maps focus reports byte by byte`(_ testCase: ParserCase) {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in testCase.bytes {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(events == [testCase.event])
}

@Test
func `parser keeps keys around focus reports in order`() {
  var parser = InputParser()
  let bytes = Array("a\u{1B}[Ob".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    key(character("a"), modifiers: none)
    focus lost
    key(character("b"), modifiers: none)
    """
  }
}

@Test
func `parser emits repeated focus reports`() {
  var parser = InputParser()
  let bytes = Array("\u{1B}[I\u{1B}[I\u{1B}[O".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    focus gained
    focus gained
    focus lost
    """
  }
}

@Test(arguments: malformedFocusCSIReportCases)
func `parser emits unknown for malformed focus reports`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test
func `parser decodes primary device attributes response`() {
  var parser = InputParser()

  #expect(
    parser.feed(contentsOf: Array("\u{1B}[?1;2c".utf8)) == [
      .primaryDeviceAttributes([1, 2])
    ]
  )
}

@Test
func `parser decodes primary device attributes byte by byte`() {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in "\u{1B}[?1;2c".utf8 {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(events == [.primaryDeviceAttributes([1, 2])])
}

@Test(arguments: malformedPrimaryDeviceAttributeCases)
func `parser emits unknown for malformed or non private primary device attributes`(
  _ testCase: ParserCase
) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: kittyKeyboardEnhancementFlagCases)
func `parser decodes Kitty keyboard enhancement flags response`(
  _ testCase: ParserCase
) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test
func `parser decodes Kitty keyboard enhancement flags byte by byte`() {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in "\u{1B}[?5u".utf8 {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(events == [.kittyKeyboardEnhancementFlags(5)])
}

@Test(arguments: malformedKittyKeyboardEnhancementFlagCases)
func `parser emits unknown for malformed Kitty keyboard enhancement flags responses`(
  _ testCase: ParserCase
) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: privateModeStatusCases)
func `parser decodes DEC private mode status responses`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test
func `parser decodes DEC private mode status byte by byte`() {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in "\u{1B}[?2004;1$y".utf8 {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(
    events == [
      .privateModeStatus(PrivateModeStatus(mode: 2_004, state: .set))
    ]
  )
}

@Test(arguments: malformedPrivateModeStatusCases)
func `parser emits unknown for malformed DEC private mode status responses`(
  _ testCase: ParserCase
) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test(arguments: mouseReportCases)
func `parser maps SGR mouse reports`(_ testCase: MouseReportCase) throws {
  var parser = InputParser()

  let events = parser.feed(contentsOf: testCase.bytes)
  #expect(events.count == 1)
  let event = try #require(events.first)
  guard case .mouse(let mouse) = event else {
    Issue.record("Expected mouse event, got \(String(reflecting: event))")
    return
  }

  #expect(mouse.kind == testCase.event.kind)
  #expect(mouse.position == testCase.event.position)
  #expect(mouse.modifiers == testCase.event.modifiers)
}

@Test
func `parser emits mouse press and move reports byte by byte`() {
  var pressParser = InputParser()
  var moveParser = InputParser()
  var pressEvents: [InputEvent] = []
  var moveEvents: [InputEvent] = []

  for byte in "\u{1B}[<0;5;3M".utf8 {
    pressEvents.append(contentsOf: pressParser.feed(byte))
  }
  for byte in "\u{1B}[<35;6;4M".utf8 {
    moveEvents.append(contentsOf: moveParser.feed(byte))
  }

  #expect(pressEvents.count == 1)
  #expect(
    pressEvents.first
      == .mouse(
        MouseEvent(
          kind: .press(.left),
          position: TerminalPosition(column: 4, row: 2)
        )
      )
  )
  #expect(moveEvents.count == 1)
  #expect(
    moveEvents.first
      == .mouse(
        MouseEvent(
          kind: .move,
          position: TerminalPosition(column: 5, row: 3)
        )
      )
  )
}

@Test
func `parser keeps keys around mouse reports in order`() {
  var parser = InputParser()
  let bytes = Array("a\u{1B}[<0;5;3Mb".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    key(character("a"), modifiers: none)
    mouse(press(left) at column: 4, row: 2, modifiers: none)
    key(character("b"), modifiers: none)
    """
  }
}

@Test
func `parser keeps focus reports around mouse reports in order`() {
  var parser = InputParser()
  let bytes = Array("\u{1B}[I\u{1B}[<0;5;3M\u{1B}[O".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    focus gained
    mouse(press(left) at column: 4, row: 2, modifiers: none)
    focus lost
    """
  }
}

@Test
func `parser preserves adjacent move press and drag mouse reports`() {
  var parser = InputParser()
  let bytes = Array("\u{1B}[<35;10;4M\u{1B}[<0;10;4M\u{1B}[<32;11;4M".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    mouse(move at column: 9, row: 3, modifiers: none)
    mouse(press(left) at column: 9, row: 3, modifiers: none)
    mouse(drag(left) at column: 10, row: 3, modifiers: none)
    """
  }
}

@Test(arguments: malformedMouseReportCases)
func `parser emits unknown for malformed SGR mouse reports`(_ testCase: ParserCase) {
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
    .focusGained,
    .focusLost,
    .key(Key(code: .character("A"), modifiers: [.shift, .control])),
    .kittyGraphicsResponse(
      KittyGraphicsResponse(
        id: KittyImageID(rawValue: 31),
        placement: KittyPlacementID(rawValue: 4),
        message: "OK"
      )
    ),
    .primaryDeviceAttributes([1, 2]),
    .paste("line\nbreak"),
    .resize(TerminalSize(columns: 2, rows: 1)),
    .unknown([0x1B, 0x5B]),
  ]

  assertInlineSnapshot(of: eventLog(events), as: .lines) {
    """
    focus gained
    focus lost
    key(character("A"), modifiers: shift+control)
    kitty graphics response(id: 31, placement: 4, success: true, message: "OK")
    primary device attributes([1, 2])
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
func `parser treats focus gained report inside bracketed paste as payload`() {
  var parser = InputParser()
  let payload = "before\u{1B}[Iafter"

  #expect(parser.feed(contentsOf: bracketedPaste(payload)) == [.paste(payload)])
}

@Test
func `parser treats focus lost report inside bracketed paste as payload`() {
  var parser = InputParser()
  let payload = "before\u{1B}[Oafter"

  #expect(parser.feed(contentsOf: bracketedPaste(payload)) == [.paste(payload)])
}

@Test
func `parser treats SGR mouse report inside bracketed paste as payload`() {
  var parser = InputParser()
  let payload = "before\u{1B}[<0;5;3Mafter"

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
func `key stores code modifiers and event kind`() {
  let key = Key(code: .up, modifiers: [.control, .shift], kind: .repeat)

  #expect(key.code == .up)
  #expect(key.kind == .repeat)
  #expect(key.modifiers.contains(.control))
  #expect(key.modifiers.contains(.shift))
  #expect(key.modifiers.contains(.alt) == false)
}

@Test
func `modifiers include kitty modifier bits`() {
  let modifiers: Modifiers = [
    .shift, .alt, .control, .super, .hyper, .meta, .capsLock, .numLock,
  ]

  #expect(modifiers.rawValue == 0b1111_1111)
}

@Test
func `parser decodes kitty printable key reports`() {
  var parser = InputParser()

  #expect(
    parser.feed(contentsOf: Array("\u{1B}[75u".utf8)) == [
      .key(Key(code: .character("K")))
    ])
  let expectedModifiedKey = InputEvent.key(
    Key(
      code: .character("k"),
      modifiers: [.shift, .alt, .control, .super, .hyper, .meta]
    )
  )
  #expect(parser.feed(contentsOf: Array("\u{1B}[107;64u".utf8)) == [expectedModifiedKey])
}

@Test
func `parser decodes kitty key event kinds`() {
  var parser = InputParser()

  #expect(
    parser.feed(contentsOf: Array("\u{1B}[107;1:1u".utf8)) == [
      .key(Key(code: .character("k"), kind: .press))
    ])
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[107;1:2u".utf8)) == [
      .key(Key(code: .character("k"), kind: .repeat))
    ])
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[107;1:3u".utf8)) == [
      .key(Key(code: .character("k"), kind: .release))
    ])
}

@Test
func `parser decodes kitty escape controls and lock keys`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: Array("\u{1B}[27u".utf8)) == [.key(Key(code: .escape))])
  #expect(parser.feed(contentsOf: Array("\u{1B}[9u".utf8)) == [.key(Key(code: .tab))])
  #expect(parser.feed(contentsOf: Array("\u{1B}[13u".utf8)) == [.key(Key(code: .enter))])
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[127u".utf8)) == [.key(Key(code: .backspace))]
  )
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[57358u".utf8)) == [
      .key(Key(code: .capsLock))
    ]
  )
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[57359u".utf8)) == [
      .key(Key(code: .scrollLock))
    ]
  )
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[57360u".utf8)) == [
      .key(Key(code: .numLock))
    ]
  )
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[57361u".utf8)) == [
      .key(Key(code: .printScreen))
    ]
  )
}

@Test
func `parser preserves malformed kitty reports as unknown`() {
  var parser = InputParser()

  #expect(
    parser.feed(contentsOf: Array("\u{1B}[107;0u".utf8)) == [
      .unknown(Array("\u{1B}[107;0u".utf8))
    ])
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[107;1:4u".utf8)) == [
      .unknown(Array("\u{1B}[107;1:4u".utf8))
    ])
  #expect(
    parser.feed(contentsOf: Array("\u{1B}[107;1:<u".utf8)) == [
      .unknown(Array("\u{1B}[107;1:<u".utf8))
    ])
}

@Test
func `parser decodes byte by byte kitty reports`() {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in "\u{1B}[107;17:2u".utf8 {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(
    events == [
      .key(Key(code: .character("k"), modifiers: .hyper, kind: .repeat))
    ])
}

@Test
func `parser keeps kitty reports isolated from paste and mixed protocol events`() {
  var parser = InputParser()
  let events = parser.feed(contentsOf: Array("\u{1B}[<0;1;1M\u{1B}[I\u{1B}[107;9:3u".utf8))

  assertInlineSnapshot(of: eventLog(events), as: .lines) {
    #"""
    mouse(press(left) at column: 0, row: 0, modifiers: none)
    focus gained
    key(character("k"), modifiers: super, kind: release)
    """#
  }

  #expect(
    parser.feed(contentsOf: bracketedPaste("\u{1B}[107;9:3u")) == [
      .paste("\u{1B}[107;9:3u")
    ])
}

@Test
func `parser decodes byte by byte Kitty graphics OK response as one event`() {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in kittyGraphicsAPC("i=1;OK") {
    events.append(contentsOf: parser.feed(byte))
  }

  let expected = InputEvent.kittyGraphicsResponse(
    KittyGraphicsResponse(id: KittyImageID(rawValue: 1), message: "OK")
  )
  #expect(events == [expected])
}

@Test
func `parser does not regress APC introducer ESC underscore into Alt underscore key`() {
  var parser = InputParser()

  #expect(parser.feed(0x1B).isEmpty)
  #expect(parser.feed(0x5F).isEmpty)
  #expect(
    parser.feed(contentsOf: Array("Xhello\u{1B}\\".utf8)) == [
      .unknown(apc("Xhello"))
    ]
  )
}

@Test
func `parser decodes Kitty graphics response placement id`() throws {
  var parser = InputParser()

  let events = parser.feed(contentsOf: kittyGraphicsAPC("i=42,p=9;OK"))

  #expect(events.count == 1)
  let event = try #require(events.first)
  let response = try #require(kittyGraphicsResponse(from: event))
  #expect(response.id == KittyImageID(rawValue: 42))
  #expect(response.placement == KittyPlacementID(rawValue: 9))
  #expect(response.message == "OK")
  #expect(response.success)
}

@Test
func `parser decodes Kitty graphics error response with success false`() throws {
  var parser = InputParser()

  let events = parser.feed(contentsOf: kittyGraphicsAPC("i=7;ENOENT:no such image"))

  #expect(events.count == 1)
  let event = try #require(events.first)
  let response = try #require(kittyGraphicsResponse(from: event))
  #expect(response.id == KittyImageID(rawValue: 7))
  #expect(response.placement == nil)
  #expect(response.message == "ENOENT:no such image")
  #expect(response.success == false)
}

@Test
func `parser emits one unknown event for non G APC`() {
  var parser = InputParser()
  let bytes = apc("Xhello")

  #expect(parser.feed(contentsOf: bytes) == [.unknown(bytes)])
}

@Test
func `parser preserves foreign Kitty graphics responses as semantic events`() {
  var parser = InputParser()

  #expect(
    parser.feed(contentsOf: kittyGraphicsAPC("a=q,i=99;OK")) == [
      .kittyGraphicsResponse(
        KittyGraphicsResponse(
          id: KittyImageID(rawValue: 99),
          message: "OK"
        )
      )
    ]
  )
}

@Test(arguments: malformedKittyGraphicsAPCCases)
func `parser emits unknown for malformed KGP APC`(_ testCase: ParserCase) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: testCase.bytes) == [testCase.event])
}

@Test
func `parser aborts APC on CAN or SUB and returns to ground`() {
  for abortByte in [UInt8(0x18), UInt8(0x1A)] {
    var parser = InputParser()
    let events = parser.feed(contentsOf: [0x1B, 0x5F, 0x47, abortByte, 0x61])

    #expect(
      events == [
        .unknown([0x1B, 0x5F, 0x47]),
        .key(Key(code: .character("a"))),
      ])
  }
}

@Test
func `parser flushes unterminated APC as unknown bytes`() {
  var parser = InputParser()
  let bytes = [0x1B, 0x5F] + Array("Gi=1;OK".utf8)

  #expect(parser.feed(contentsOf: bytes).isEmpty)
  #expect(parser.flush() == [.unknown(bytes)])
  #expect(parser.flush().isEmpty)
}

@Test
func `parser emits unknown for APC byte cap overflow and resynchronizes`() {
  var parser = InputParser()
  let overflow = [0x1B, 0x5F] + Array(repeating: UInt8(ascii: "x"), count: 4_094)
  let events = parser.feed(contentsOf: overflow + [UInt8(ascii: "z")])

  #expect(
    events == [
      .unknown(overflow),
      .key(Key(code: .character("z"))),
    ])
}

@Test
func `parser keeps Kitty graphics APC literal inside bracketed paste`() throws {
  var parser = InputParser()
  let payloadBytes =
    Array("before".utf8) + kittyGraphicsAPC("i=2;OK") + Array("after".utf8)
  let bytes = bracketedPasteStart + payloadBytes + bracketedPasteEnd
  let payload = try #require(String(bytes: payloadBytes, encoding: .utf8))

  #expect(parser.feed(contentsOf: bytes) == [.paste(payload)])
}

@Test
func `parser keeps APC responses interleaved with ordinary keys in order`() {
  var parser = InputParser()
  let bytes =
    Array("a".utf8) + kittyGraphicsAPC("i=3;OK") + Array("b".utf8) + apc("Xignored")
    + Array("c".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    key(character("a"), modifiers: none)
    kitty graphics response(id: 3, placement: nil, success: true, message: "OK")
    key(character("b"), modifiers: none)
    unknown(1B 5F 58 69 67 6E 6F 72 65 64 1B 5C)
    key(character("c"), modifiers: none)
    """
  }
}

@Test
func `parser preserves Kitty graphics response before following DA1`() {
  var parser = InputParser()
  let bytes = kittyGraphicsAPC("i=11;OK") + Array("\u{1B}[?1;2c".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    kitty graphics response(id: 11, placement: nil, success: true, message: "OK")
    primary device attributes([1, 2])
    """
  }
}

@Test
func `parser preserves Kitty keyboard flags before following DA1`() {
  var parser = InputParser()
  let bytes = Array("\u{1B}[?5u\u{1B}[?1;2c".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    kitty keyboard enhancement flags(5)
    primary device attributes([1, 2])
    """
  }
}

@Test
func `parser preserves DEC private mode status before following DA1`() {
  var parser = InputParser()
  let bytes = Array("\u{1B}[?2004;1$y\u{1B}[?1;2c".utf8)

  assertInlineSnapshot(of: eventLog(parser.feed(contentsOf: bytes)), as: .lines) {
    """
    private mode status(mode: 2004, state: set)
    primary device attributes([1, 2])
    """
  }
}

private func kittyGraphicsResponse(from event: InputEvent) -> KittyGraphicsResponse? {
  guard case .kittyGraphicsResponse(let response) = event else {
    return nil
  }
  return response
}

private func kittyGraphicsAPC(_ payload: String) -> [UInt8] {
  apc("G" + payload)
}

private func apc(_ payload: String) -> [UInt8] {
  [0x1B, 0x5F] + Array(payload.utf8) + [0x1B, 0x5C]
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
  case .focusGained:
    return "focus gained"

  case .focusLost:
    return "focus lost"

  case .key(let key):
    let kind = key.kind == .press ? "" : ", kind: \(key.kind)"
    return "key(\(key.code), modifiers: \(modifierLog(key.modifiers))\(kind))"

  case .kittyGraphicsResponse(let response):
    let id = response.id.map { String($0.rawValue) } ?? "nil"
    let placement = response.placement.map { String($0.rawValue) } ?? "nil"
    return
      "kitty graphics response(id: \(id), placement: \(placement), success: \(response.success), message: \(String(reflecting: response.message)))"

  case .kittyKeyboardEnhancementFlags(let flags):
    return "kitty keyboard enhancement flags(\(flags))"

  case .primaryDeviceAttributes(let attributes):
    let values = attributes.map { String($0) }.joined(separator: ", ")
    return "primary device attributes([\(values)])"

  case .privateModeStatus(let status):
    return "private mode status(mode: \(status.mode), state: \(status.state))"

  case .mouse(let mouse):
    return
      "mouse(\(mouseKindLog(mouse.kind)) at column: \(mouse.position.column), row: \(mouse.position.row), modifiers: \(modifierLog(mouse.modifiers)))"

  case .paste(let string):
    return "paste(\(String(reflecting: string)))"

  case .resize(let size):
    return "resize(columns: \(size.columns), rows: \(size.rows))"

  case .unknown(let bytes):
    return "unknown(\(hex(bytes)))"
  }
}
private func mouseKindLog(_ kind: MouseEventKind) -> String {
  switch kind {
  case .drag(let button):
    "drag(\(button))"
  case .move:
    "move"
  case .press(let button):
    "press(\(button))"
  case .release(let button):
    if let button {
      "release(\(button))"
    } else {
      "release(nil)"
    }
  case .scroll(let direction):
    "scroll(\(direction))"
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
  if modifiers.contains(.super) {
    names.append("super")
  }
  if modifiers.contains(.hyper) {
    names.append("hyper")
  }
  if modifiers.contains(.meta) {
    names.append("meta")
  }
  if modifiers.contains(.capsLock) {
    names.append("capsLock")
  }
  if modifiers.contains(.numLock) {
    names.append("numLock")
  }
  return names.isEmpty ? "none" : names.joined(separator: "+")
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
