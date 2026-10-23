import Testing

@testable import TesseraTerminalInput

private let bel: UInt8 = 0x07
private let escape: UInt8 = 0x1B

private func osc(_ body: String, terminator: [UInt8] = [escape, 0x5C]) -> [UInt8] {
  [escape, 0x5D] + Array(body.utf8) + terminator
}

private func reply(
  _ role: TerminalColorRole,
  _ red: UInt8,
  _ green: UInt8,
  _ blue: UInt8
) -> InputEvent {
  .colorReport(
    TerminalColorReply(
      role: role,
      color: TerminalRGBColor(red: red, green: green, blue: blue)
    )
  )
}

struct ColorReplyCase: Sendable, CustomStringConvertible {
  var body: String
  var event: InputEvent

  var description: String {
    body
  }
}

let scalingCases: [ColorReplyCase] = [
  ColorReplyCase(body: "11;rgb:f/0/8", event: reply(.background, 255, 0, 136)),
  ColorReplyCase(body: "11;rgb:ff/00/80", event: reply(.background, 255, 0, 128)),
  ColorReplyCase(body: "11;rgb:fff/000/800", event: reply(.background, 255, 0, 128)),
  ColorReplyCase(body: "11;rgb:ffff/0000/8080", event: reply(.background, 255, 0, 128)),
  ColorReplyCase(body: "11;rgb:1/2/3", event: reply(.background, 17, 34, 51)),
  ColorReplyCase(body: "11;rgb:1234/5678/9abc", event: reply(.background, 18, 86, 154)),
  ColorReplyCase(body: "11;rgb:ABCD/EF01/2345", event: reply(.background, 171, 238, 35)),
  ColorReplyCase(body: "10;rgb:e0e0/e0e0/e0e0", event: reply(.foreground, 224, 224, 224)),
  ColorReplyCase(
    body: "10;rgba:ffff/8080/0000/0000", event: reply(.foreground, 255, 128, 0)),
  ColorReplyCase(body: "11;rgba:0/0/0/f", event: reply(.background, 0, 0, 0)),
  ColorReplyCase(body: "4;0;rgb:00/00/00", event: reply(.slot(0), 0, 0, 0)),
  ColorReplyCase(body: "4;15;rgb:ffff/ffff/ffff", event: reply(.slot(15), 255, 255, 255)),
  ColorReplyCase(body: "4;7;rgba:cc/cc/cc/ff", event: reply(.slot(7), 204, 204, 204)),
]

let malformedCases: [String] = [
  "11;rgb:ggg/000/000",
  "11;rgb:fffff/000/000",
  "11;rgb:/000/000",
  "11;rgb:ff/00",
  "11;rgb:ff/00/00/00",
  "11;rgba:ff/00/00",
  "11;rgba:ff/00/00/",
  "11;",
  "11",
  "10;rgb:00/00/00;00",
  "12;rgb:00/00/00",
  "4;16;rgb:00/00/00",
  "4;rgb:00/00/00",
  "4;;rgb:00/00/00",
  "4;0;1;rgb:00/00/00",
  "4;99999;rgb:00/00/00",
]

@Test(arguments: scalingCases)
func `parser decodes OSC color replies and scales channels to 8 bits`(
  _ testCase: ColorReplyCase
) {
  var stParser = InputParser()
  var belParser = InputParser()

  #expect(stParser.feed(contentsOf: osc(testCase.body)) == [testCase.event])
  #expect(
    belParser.feed(contentsOf: osc(testCase.body, terminator: [bel])) == [testCase.event]
  )
}

@Test(arguments: scalingCases)
func `parser decodes OSC color replies byte by byte`(_ testCase: ColorReplyCase) {
  var parser = InputParser()
  var events: [InputEvent] = []

  for byte in osc(testCase.body) {
    events.append(contentsOf: parser.feed(byte))
  }

  #expect(events == [testCase.event])
}

@Test
func `parser decodes OSC 4 replies for every slot in any order`() {
  var parser = InputParser()
  let order = [9, 3, 15, 0, 12, 1, 7, 14, 5, 2, 11, 8, 4, 13, 6, 10]
  let bytes = order.flatMap { slot in
    let value = String(slot * 16, radix: 16).leftPadded(to: 2)
    return osc("4;\(slot);rgb:\(value)/00/ff")
  }

  let events = parser.feed(contentsOf: bytes)

  #expect(
    events == order.map { reply(.slot($0), UInt8($0 * 16), 0, 255) }
  )
}

@Test
func `parser keeps color replies separate from keys and the DA1 sentinel`() {
  var parser = InputParser()
  let bytes =
    Array("a".utf8) + osc("10;rgb:ff/ff/ff") + osc("11;rgb:00/00/00", terminator: [bel])
    + Array("b".utf8) + Array("\u{1B}[?1;2c".utf8)

  #expect(
    parser.feed(contentsOf: bytes) == [
      .key(Key(code: .character("a"))),
      reply(.foreground, 255, 255, 255),
      reply(.background, 0, 0, 0),
      .key(Key(code: .character("b"))),
      .primaryDeviceAttributes([1, 2]),
    ]
  )
}

@Test(arguments: malformedCases)
func `parser emits unknown for malformed OSC color replies`(_ body: String) {
  var parser = InputParser()
  let bytes = osc(body)

  #expect(parser.feed(contentsOf: bytes) == [.unknown(bytes)])
}

@Test
func `parser flushes an unterminated OSC reply as unknown bytes`() {
  var parser = InputParser()
  let bytes = [escape, 0x5D] + Array("11;rgb:00/00".utf8)

  #expect(parser.feed(contentsOf: bytes).isEmpty)
  #expect(parser.flush() == [.unknown(bytes)])
}

@Test
func `parser abandons an overlong OSC reply as unknown bytes`() {
  var parser = InputParser()
  let bytes = [escape, 0x5D] + Array(String(repeating: "1", count: 80).utf8)

  let events = parser.feed(contentsOf: bytes)

  // The reply is abandoned at the 64-byte cap; the 18 bytes after it parse as keys.
  #expect(events.first == .unknown(Array(bytes.prefix(64))))
  #expect(
    Array(events.dropFirst())
      == Array(repeating: InputEvent.key(Key(code: .character("1"))), count: 18)
  )
}

@Test
func `parser keeps the byte that abandons an OSC reply`() {
  var parser = InputParser()
  let abandoned = [escape, 0x5D] + Array("11;".utf8)

  #expect(
    parser.feed(contentsOf: abandoned + Array("xy".utf8)) == [
      .unknown(abandoned),
      .key(Key(code: .character("x"))),
      .key(Key(code: .character("y"))),
    ]
  )
}

@Test
func `parser keeps the escape that does not terminate an OSC reply`() {
  var parser = InputParser()
  let abandoned = [escape, 0x5D] + Array("11;rgb:00".utf8)

  #expect(
    parser.feed(contentsOf: abandoned + [escape, 0x5B, 0x41]) == [
      .unknown(abandoned),
      .key(Key(code: .up)),
    ]
  )
}

@Test
func `parser does not swallow Alt right bracket into an OSC reply`() {
  var parser = InputParser()

  #expect(parser.feed(escape).isEmpty)
  #expect(parser.feed(0x5D).isEmpty)
  #expect(parser.isWaitingForEscape)
  #expect(
    parser.feed(contentsOf: Array("hello".utf8)) == [
      .key(Key(code: .character("]"), modifiers: .alt)),
      .key(Key(code: .character("h"))),
      .key(Key(code: .character("e"))),
      .key(Key(code: .character("l"))),
      .key(Key(code: .character("l"))),
      .key(Key(code: .character("o"))),
    ]
  )
}

@Test
func `parser flushes Alt right bracket when input goes idle after the introducer`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: [escape, 0x5D]).isEmpty)
  #expect(
    parser.flushPendingEscape() == [.key(Key(code: .character("]"), modifiers: .alt))])
  #expect(!parser.isWaitingForEscape)
  #expect(parser.feed(contentsOf: Array("1".utf8)) == [.key(Key(code: .character("1")))])
}

@Test
func `parser keeps a started OSC reply across an idle notification`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: [escape, 0x5D] + Array("11;rgb:".utf8)).isEmpty)
  #expect(!parser.isWaitingForEscape)
  #expect(parser.flushPendingEscape().isEmpty)
  #expect(
    parser.feed(contentsOf: Array("00/00/00".utf8) + [bel]) == [
      reply(.background, 0, 0, 0)
    ]
  )
}

@Test
func `parser flushes Alt right bracket at the end of input`() {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: [escape, 0x5D]).isEmpty)
  #expect(parser.flush() == [.key(Key(code: .character("]"), modifiers: .alt))])
}

@Test(arguments: [
  ("\u{1B}[?997;1n", InputEvent.colorSchemeChanged(.dark)),
  ("\u{1B}[?997;2n", InputEvent.colorSchemeChanged(.light)),
])
func `parser decodes color scheme notifications`(
  _ bytes: String,
  _ event: InputEvent
) {
  var parser = InputParser()
  var byteByByte = InputParser()
  var events: [InputEvent] = []

  #expect(parser.feed(contentsOf: Array(bytes.utf8)) == [event])
  for byte in bytes.utf8 {
    events.append(contentsOf: byteByByte.feed(byte))
  }
  #expect(events == [event])
}

@Test(arguments: [
  "\u{1B}[?997;0n",
  "\u{1B}[?997;3n",
  "\u{1B}[?997n",
  "\u{1B}[997;1n",
  "\u{1B}[?996;1n",
])
func `parser emits unknown for other device status reports`(_ bytes: String) {
  var parser = InputParser()

  #expect(parser.feed(contentsOf: Array(bytes.utf8)) == [.unknown(Array(bytes.utf8))])
}

extension String {
  fileprivate func leftPadded(to width: Int) -> String {
    String(repeating: "0", count: max(0, width - count)) + self
  }
}
