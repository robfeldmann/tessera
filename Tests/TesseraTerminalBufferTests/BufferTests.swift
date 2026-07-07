import InlineSnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminalANSI
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalBuffer

@Test
func `buffer initializes every cell with blank fill`() {
  let buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    ···
    """
  }
}

@Test
func `buffer initializes every cell with custom fill`() {
  let fill = Cell(character: ".")
  let buffer = Buffer(size: TerminalSize(columns: 2, rows: 2), fill: fill)

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ..
    ..
    """
  }
}

@Test
func `package set writes cells by row and column`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))
  let cell = Cell(character: "X")

  try buffer.set(cell, row: 1, column: 2)

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    ··X
    """
  }
}

@Test
func `write stores characters from the requested position`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 2))

  buffer.write("hey", at: TerminalPosition(column: 1, row: 1))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ·····
    ·hey·
    """
  }
}

@Test
func `write clips text past the right edge`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 2))

  buffer.write("hello", at: TerminalPosition(column: 3, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···he
    ·····
    """
  }
}

@Test
func `write clips text before the left edge`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 1))

  buffer.write("hello", at: TerminalPosition(column: -2, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    llo··
    """
  }
}

@Test
func `write outside the vertical bounds does nothing`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))

  buffer.write("top", at: TerminalPosition(column: 0, row: -1))
  buffer.write("end", at: TerminalPosition(column: 0, row: 2))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    ···
    """
  }
}

@Test
func `write stores wide graphemes with continuation cells`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 1))

  buffer.write("你a", at: TerminalPosition(column: 1, row: 0))

  #expect(buffer[0, 1].content == .grapheme("你"))
  #expect(buffer[0, 2].content == .continuation)
  #expect(buffer[0, 3].content == .grapheme("a"))
  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ·你◌a·
    """
  }
}

@Test
func `write drops wide grapheme that does not fit at right edge`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))

  buffer.write("你", at: TerminalPosition(column: 2, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ···
    """
  }
}

@Test
func `write does not render visible half of clipped wide grapheme`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))

  buffer.write("你a", at: TerminalPosition(column: -1, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ·a··
    """
  }
}

@Test
func `write does not wrap to the next row`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))

  buffer.write("abcd", at: TerminalPosition(column: 1, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ·ab
    ···
    """
  }
}

@Test
func `write clears previous wide grapheme when overwriting leading cell`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))

  buffer.write("你", at: TerminalPosition(column: 1, row: 0))
  buffer.write("x", at: TerminalPosition(column: 1, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ·x··
    """
  }
}

@Test
func `write clears previous wide grapheme when overwriting continuation cell`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))

  buffer.write("你", at: TerminalPosition(column: 1, row: 0))
  buffer.write("x", at: TerminalPosition(column: 2, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ··x·
    """
  }
}

@Test
func `write grapheme returns next column`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))

  let result = buffer.write(
    grapheme: "你",
    at: TerminalPosition(column: 1, row: 0)
  )

  #expect(result == .written(nextColumn: 3))
  #expect(buffer[0, 1].content == .grapheme("你"))
  #expect(buffer[0, 2].content == .continuation)
}

@Test
func `write grapheme reports clipped and unsupported results`() {
  var buffer = Buffer(size: TerminalSize(columns: 2, rows: 1))

  #expect(
    buffer.write(grapheme: "你", at: TerminalPosition(column: 1, row: 0))
      == .clipped
  )
  #expect(
    buffer.write(grapheme: "\u{200D}", at: TerminalPosition(column: 0, row: 0))
      == .unsupported
  )

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    ··
    """
  }
}

@Test(arguments: ["你好", "🙂", "👨‍👩‍👧", "🇺🇸", "👍🏽"])
func `write stores two column graphemes with continuations`(text: String) {
  var buffer = Buffer(size: TerminalSize(columns: 6, rows: 1))

  buffer.write(text, at: TerminalPosition(column: 0, row: 0))

  var column = 0
  for character in text {
    #expect(buffer[0, column].content == .grapheme(String(character)))
    #expect(buffer[0, column + 1].content == .continuation)
    column += 2
  }
}

@Test(arguments: ["é", "e\u{0301}"])
func `write stores one column combining graphemes`(grapheme: String) {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))

  buffer.write(grapheme, at: TerminalPosition(column: 1, row: 0))

  #expect(buffer[0, 1].content == .grapheme(grapheme))
  #expect(buffer[0, 1].width == 1)
  #expect(buffer[0, 2].content == .blank)
}

@Test
func `write ignores isolated zero width and control graphemes`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))

  buffer.write("a\tb", at: TerminalPosition(column: 0, row: 0))
  #expect(
    buffer.write(grapheme: "\u{200D}", at: TerminalPosition(column: 2, row: 0))
      == .unsupported
  )
  #expect(
    buffer.write(grapheme: "\u{0085}", at: TerminalPosition(column: 2, row: 0))
      == .unsupported
  )
  buffer.write("cd", at: TerminalPosition(column: 2, row: 0))

  assertInlineSnapshot(of: buffer, as: .customDump) {
    """
    abcd
    """
  }
}

@Test
func `write stores halfwidth katakana sound marks as one column graphemes`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))

  _ = buffer.write(grapheme: "\u{FF9E}", at: TerminalPosition(column: 0, row: 0))
  _ = buffer.write(grapheme: "\u{FF9F}", at: TerminalPosition(column: 1, row: 0))

  #expect(buffer[0, 0].content == .grapheme("\u{FF9E}"))
  #expect(buffer[0, 1].content == .grapheme("\u{FF9F}"))
  #expect(buffer[0, 2].content == .blank)
}

@Test
func `raw payload stores anchor and occupied continuations`() {
  var buffer = Buffer(size: TerminalSize(columns: 5, rows: 1))
  let payload = RawTerminalPayload(bytes: [0x1B, 0x5D], declaredWidth: 2)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 2, rows: 1)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · R2! ◌! · ·
    """
  }
}

@Test
func `buffer state snapshots include hyperlink metadata`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))
  let link = try Hyperlink(uri: "https://example.com/docs", id: "docs")

  buffer.write(
    "Hi",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(hyperlink: link)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    H{link=docs:https://example.com/docs} i{link=docs:https://example.com/docs} · ·
    """
  }
}
@Test
func `raw payload clips occupied region`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 4)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 0, row: 0),
    occupying: Rect(column: -1, row: 0, columns: 4, rows: 2),
    repaintPolicy: .opaque
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    R4? ◌? ◌?
    ◌? ◌? ◌?
    """
  }
}

@Test(arguments: [UInt?.none, 0])
func `zero width raw payload anchors without occupying trailing cells`(width: UInt?) {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  buffer.write("abc", at: TerminalPosition(column: 0, row: 0))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: width)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 0, rows: 0)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    a R0! c
    """
  }
}

@Test
func `raw payload clears overlapping wide grapheme`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 1)

  buffer.write("你", at: TerminalPosition(column: 1, row: 0))
  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 2, row: 0),
    occupying: Rect(column: 2, row: 0, columns: 1, rows: 1)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · · R1! ·
    """
  }
}

@Test
func `mark opaque preserves one column visible content`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))

  buffer.write("abcd", at: TerminalPosition(column: 0, row: 0))
  buffer.markOpaque(Rect(column: 1, row: 0, columns: 2, rows: 1))

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    a b? c? d
    """
  }
}

@Test
func `normal write reclaims opaque region`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))

  buffer.markOpaque(Rect(column: 1, row: 0, columns: 1, rows: 1))
  buffer.write("x", at: TerminalPosition(column: 1, row: 0))

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · x ·
    """
  }
}

@Test(arguments: [UInt?.none, 0, 1, 2, 4])
func `raw payload snapshots declared width variants`(width: UInt?) {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: width)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: Int(width ?? 0), rows: 1)
  )

  let rawWidth = Int(width ?? 0)
  let expected: String
  if rawWidth == 0 {
    expected = "· R0! ·"
  } else if rawWidth == 1 {
    expected = "· R1! ·"
  } else if rawWidth == 2 {
    expected = "· R2! ◌!"
  } else {
    expected = "· R4! ◌!"
  }

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    \(expected)
    """
  }
}

@Test
func `raw payload with anchor outside clips occupied region without storing anchor`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 2)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: -1, row: 0),
    occupying: Rect(column: -1, row: 0, columns: 3, rows: 1)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    ◌! ◌! ·
    """
  }
}

@Test
func `raw payload with empty occupied region stores only anchor`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 2)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 0, rows: 0)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · R2! ·
    """
  }
}

@Test
func `raw payload can occupy multiple rows`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 2))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 3)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 2, rows: 2)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · R3! ◌! ·
    · ◌! ◌! ·
    """
  }
}

@Test
func `overlapping raw payload clears previous raw region`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))
  let first = RawTerminalPayload(bytes: [0x31], declaredWidth: 3)
  let second = RawTerminalPayload(bytes: [0x32], declaredWidth: 1)

  buffer.writeRaw(
    first,
    at: TerminalPosition(column: 0, row: 0),
    occupying: Rect(column: 0, row: 0, columns: 3, rows: 1)
  )
  buffer.writeRaw(
    second,
    at: TerminalPosition(column: 2, row: 0),
    occupying: Rect(column: 2, row: 0, columns: 1, rows: 1)
  )

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · · R1! ·
    """
  }
}

@Test
func `clear removes opaque always repaint and continuation cells`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 2)

  buffer.writeRaw(
    payload,
    at: TerminalPosition(column: 0, row: 0),
    occupying: Rect(column: 0, row: 0, columns: 2, rows: 1)
  )
  buffer.markOpaque(Rect(column: 2, row: 0, columns: 1, rows: 1))
  buffer.clear()

  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    · · ·
    """
  }
}

@Test
func `clear resets content style and diff policy using fill cell`() {
  var buffer = Buffer(size: TerminalSize(columns: 2, rows: 1))
  let style = Style(attributes: [.bold])

  buffer.write("你", at: TerminalPosition(column: 0, row: 0), style: style)
  buffer.clear(fill: Cell(content: .blank, style: style, diffPolicy: .alwaysRepaint))

  #expect(buffer[0, 0] == Cell(content: .blank, style: style, diffPolicy: .alwaysRepaint))
  #expect(buffer[0, 1] == Cell(content: .blank, style: style, diffPolicy: .alwaysRepaint))
}
