import InlineSnapshotTesting
import SnapshotTestingCustomDump
import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalRendering

@Test
func `rendering an empty buffer emits a full repaint`() {
  let buffer = Buffer(size: TerminalSize(columns: 3, rows: 2))
  let bytes = Renderer.render(buffer)

  // swiftlint:disable line_length
  assertInlineSnapshot(of: RendererCustomDump(bytes: bytes), as: .customDump) {
    """
    [row 0]
    bytes: 1B 5B 32 4A 1B 5B 31 3B 31 48 1B 5B 30 6D 20 20 20 1B 5B 32 3B 31 48 20 20 20 1B 5B 30 6D
    text:  ␛[2J␛[1;1H␛[0m···␛[2;1H···␛[0m
    """
  }
  // swiftlint:enable line_length
}

@Test
func `rendering a buffer with text emits row major cell bytes`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 2))
  buffer.write("Hi", at: TerminalPosition(column: 1, row: 0))
  buffer.write("q", at: TerminalPosition(column: 3, row: 1))

  let bytes = Renderer.render(buffer)

  // swiftlint:disable line_length
  assertInlineSnapshot(of: RendererCustomDump(bytes: bytes), as: .customDump) {
    """
    [row 0]
    bytes: 1B 5B 32 4A 1B 5B 31 3B 31 48 1B 5B 30 6D 20 48 69 20 1B 5B 32 3B 31 48 20 20 20 71 1B 5B 30 6D
    text:  ␛[2J␛[1;1H␛[0m·Hi·␛[2;1H···q␛[0m
    """
  }
  // swiftlint:enable line_length
}

@Test
func `stateful renderer encodes second frame as damage only`() {
  var previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  previous.write("abc", at: TerminalPosition(column: 0, row: 0))
  var current = previous
  current.write("x", at: TerminalPosition(column: 1, row: 0))
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.encodeFrame(
    previous: previous,
    current: current,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[1;2H") + escape("[0m") + utf8("x") + escape("[0m"))
}

@Test
func `stateful renderer returns to damage tracking after invalidate repaint`() {
  var renderer = Renderer()
  let initial = Buffer(size: TerminalSize(columns: 2, rows: 1))
  var changed = initial
  changed.write("x", at: TerminalPosition(column: 1, row: 0))
  var bytes: [UInt8] = []

  renderer.invalidate()
  renderer.encodeFrame(
    previous: initial,
    current: initial,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    into: &bytes
  )
  bytes.removeAll()
  renderer.encodeFrame(
    previous: initial,
    current: changed,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[1;2H") + utf8("x") + escape("[0m"))
}

@Test
func `stateful renderer size changes repaint conservatively`() {
  var renderer = Renderer()
  let previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  let current = Buffer(size: TerminalSize(columns: 2, rows: 1))
  var bytes: [UInt8] = []

  renderer.encodeFrame(
    previous: previous,
    current: current,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(
    bytes == escape("[2J") + escape("[1;1H") + escape("[0m") + utf8("  ")
      + escape("[0m")
  )
}

@Test
func `stateful renderer invalidate causes erase before repaint`() {
  let current = Buffer(size: TerminalSize(columns: 2, rows: 1))
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.invalidate()
  renderer.encodeFrame(
    previous: current,
    current: current,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(
    bytes == escape("[2J") + escape("[1;1H") + escape("[0m") + utf8("  ") + escape("[0m")
  )
}

@Test
func `damage render coalesces adjacent same row cells`() {
  let previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  var current = previous
  current.write("ab", at: TerminalPosition(column: 1, row: 0))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(bytes == escape("[1;2H") + escape("[0m") + utf8("ab") + escape("[0m"))
}

@Test
func `damage render moves once per separate dirty row`() {
  let previous = Buffer(size: TerminalSize(columns: 3, rows: 2))
  var current = previous
  current.write("x", at: TerminalPosition(column: 1, row: 0))
  current.write("y", at: TerminalPosition(column: 2, row: 1))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;2H") + escape("[0m") + utf8("x") + escape("[2;3H") + utf8("y")
      + escape("[0m")
  )
}

@Test
func `damage render repositions around opaque gaps`() {
  let previous = Buffer(size: TerminalSize(columns: 5, rows: 1))
  var current = previous
  current.write("abcde", at: TerminalPosition(column: 0, row: 0))
  current.markOpaque(Rect(column: 2, row: 0, columns: 1, rows: 1))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("[0m") + utf8("ab") + escape("[1;4H") + utf8("de")
      + escape("[0m")
  )
}

@Test
func `damage render does not advance cursor for zero width raw payloads`() {
  let previous = Buffer(size: TerminalSize(columns: 2, rows: 1))
  var current = previous
  current.writeRaw(
    RawTerminalPayload(bytes: utf8("R")),
    at: TerminalPosition(column: 0, row: 0),
    occupying: Rect(column: 0, row: 0, columns: 0, rows: 0)
  )
  current.write("x", at: TerminalPosition(column: 1, row: 0))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("[0m") + utf8("R") + escape("[1;2H") + utf8("x")
      + escape("[0m")
  )
}

@Test
func `damage render advances cursor by wide cell width`() {
  let previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  var current = previous
  current.write("你x", at: TerminalPosition(column: 0, row: 0))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(bytes == escape("[1;1H") + escape("[0m") + utf8("你x") + escape("[0m"))
}

@Test
func `damage render precomposes decomposed combining graphemes`() {
  let previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  var current = previous
  current.write("e\u{0301}", at: TerminalPosition(column: 0, row: 0))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(bytes == escape("[1;1H") + escape("[0m") + utf8("é") + escape("[0m"))
}

@Test
func `damage render identical second frame emits final reset only`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  buffer.write("abc", at: TerminalPosition(column: 0, row: 0))

  let bytes = Renderer.render(previous: buffer, current: buffer)

  #expect(bytes == escape("[0m"))
}

@Test
func `damage render emits style only changes`() throws {
  let previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  var current = previous
  try current.set(
    Cell(content: .blank, style: Style(background: .ansi(.blue))),
    row: 0,
    column: 1
  )

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;2H") + escape("[0m") + escape("[44m") + utf8(" ")
      + escape("[0m")
  )
}

@Test
func `damage render repaints underline style and color only changes`() {
  var previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  previous.write("x", at: TerminalPosition(column: 0, row: 0))
  var current = previous
  current.write(
    "x",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
  )

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("[0m") + escape("[58:5:196m") + escape("[4:3m")
      + utf8("x") + escape("[0m")
  )
}

@Test
func `damage render clears previous wide content with blanks`() {
  var previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  previous.write("你", at: TerminalPosition(column: 0, row: 0))
  let current = Buffer(size: TerminalSize(columns: 3, rows: 1))

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(bytes == escape("[1;1H") + escape("[0m") + utf8("  ") + escape("[0m"))
}

@Test
func `damage render emits raw always repaint cells when equal`() {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  buffer.writeRaw(
    RawTerminalPayload(bytes: utf8("R"), declaredWidth: 1),
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 1, rows: 1)
  )

  let bytes = Renderer.render(previous: buffer, current: buffer)

  #expect(bytes == escape("[1;2H") + escape("[0m") + utf8("R") + escape("[0m"))
}

@Test
func `damage render skips opaque cells while rendering surrounding raw payloads`() {
  let previous = Buffer(size: TerminalSize(columns: 5, rows: 1))
  var current = previous
  current.writeRaw(
    RawTerminalPayload(bytes: utf8("A"), declaredWidth: 1),
    at: TerminalPosition(column: 0, row: 0),
    occupying: Rect(column: 0, row: 0, columns: 1, rows: 1)
  )
  current.markOpaque(Rect(column: 1, row: 0, columns: 2, rows: 1))
  current.writeRaw(
    RawTerminalPayload(bytes: utf8("B"), declaredWidth: 1),
    at: TerminalPosition(column: 3, row: 0),
    occupying: Rect(column: 3, row: 0, columns: 1, rows: 1)
  )

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("[0m") + utf8("A") + escape("[1;4H") + utf8("B")
      + escape("[0m")
  )
}

@Test
func `renderer wraps frames when synchronized output is enabled`() {
  let current = Buffer(size: TerminalSize(columns: 1, rows: 1))
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.encodeFrame(
    previous: current,
    current: current,
    wrapInSynchronizedOutput: true,
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[?2026h") + escape("[0m") + escape("[?2026l"))
}

@Test
func `renderer omits synchronized output wrappers when disabled`() {
  let current = Buffer(size: TerminalSize(columns: 1, rows: 1))
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.encodeFrame(
    previous: current,
    current: current,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[0m"))
}

@Test
func `sgr delta emits reset and full style for unknown old style`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: nil,
    to: Style(foreground: .ansi(.red), attributes: [.bold], underlineStyle: .single),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[31m") + escape("[1m") + escape("[4m"))
}

@Test
func `sgr delta full style preserves extended underline facets`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: nil,
    to: Style(
      foreground: .ansi(.red),
      attributes: [.bold],
      underlineStyle: .curly,
      underlineColor: .indexed(196)
    ),
    colorCapability: .truecolor,
    underlineRendering: .extended,
    into: &bytes
  )

  #expect(
    bytes == escape("[0m") + escape("[31m") + escape("[58:5:196m") + escape("[1m")
      + escape("[4:3m")
  )
}

@Test
func `sgr delta custom style-only policy preserves variants while omitting color`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: nil,
    to: Style(underlineStyle: .curly, underlineColor: .indexed(196)),
    colorCapability: .truecolor,
    underlineRendering: UnderlineRenderingPolicy(style: .preserveVariants, color: .omit),
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[4:3m"))
}

@Test
func `sgr delta custom color-only policy emits color while reducing variants`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: nil,
    to: Style(underlineStyle: .curly, underlineColor: .indexed(196)),
    colorCapability: .truecolor,
    underlineRendering: UnderlineRenderingPolicy(style: .singleOnly, color: .emit),
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[58:5:196m") + escape("[4m"))
}

@Test
func `sgr delta emits only added attributes`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(attributes: [.bold]),
    to: Style(attributes: [.bold, .italic]),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[3m"))
}

@Test
func `sgr delta resets and reapplies style when attributes are removed`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(foreground: .ansi(.red), attributes: [.bold, .italic]),
    to: Style(foreground: .ansi(.red), attributes: [.bold]),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[31m") + escape("[1m"))
}

@Test
func `sgr delta emits foreground and background color changes`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(foreground: .ansi(.red), background: .default),
    to: Style(foreground: .ansi(.blue), background: .indexed(42)),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[34m") + escape("[48;5;42m"))
}

@Test
func `sgr delta resets for default color reset`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(foreground: .ansi(.red), background: .ansi(.blue)),
    to: Style(foreground: .default, background: .ansi(.blue)),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[44m"))
}

@Test
func `sgr delta switches plain text to curly underline without reset`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(),
    to: Style(underlineStyle: .curly),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[4:3m"))
}

@Test
func `sgr delta switches single underline to dashed underline without reset`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineStyle: .single),
    to: Style(underlineStyle: .dashed),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[4:5m"))
}

@Test
func `sgr delta switches indexed underline color to RGB`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineColor: .indexed(196)),
    to: Style(underlineColor: .rgb(1, 2, 3)),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[58:2::1:2:3m"))
}

@Test
func `sgr delta resets custom underline facets without broad reset`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineStyle: .curly, underlineColor: .rgb(1, 2, 3)),
    to: Style(),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[59m") + escape("[24m"))
}

@Test
func `sgr delta resets underline color while keeping the style`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineStyle: .curly, underlineColor: .rgb(1, 2, 3)),
    to: Style(underlineStyle: .curly),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[59m"))
}

@Test
func `sgr delta disables underline with a targeted reset only`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineStyle: .curly),
    to: Style(),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(bytes == escape("[24m"))
}

@Test
func `sgr delta omits projection-equivalent baseline underline transitions`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineStyle: .curly, underlineColor: .indexed(196)),
    to: Style(underlineStyle: .dashed, underlineColor: .rgb(1, 2, 3)),
    colorCapability: .truecolor,
    underlineRendering: .baseline,
    into: &bytes
  )

  #expect(bytes.isEmpty)
}

@Test
func `sgr delta resets baseline underline without an extended color reset`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(underlineStyle: .dotted, underlineColor: .rgb(1, 2, 3)),
    to: Style(),
    colorCapability: .truecolor,
    underlineRendering: .baseline,
    into: &bytes
  )

  #expect(bytes == escape("[24m"))
}

@Test
func `sgr delta replays underline facets after broad reset`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(
      foreground: .ansi(.red),
      background: .ansi(.blue),
      attributes: [.bold, .italic],
      underlineStyle: .single,
      underlineColor: .indexed(42)
    ),
    to: Style(
      foreground: .ansi(.red),
      background: .ansi(.blue),
      attributes: [.bold],
      underlineStyle: .dotted,
      underlineColor: .rgb(1, 2, 3)
    ),
    colorCapability: .truecolor,
    into: &bytes
  )

  #expect(
    bytes == escape("[0m") + escape("[31m") + escape("[44m") + escape("[58:2::1:2:3m")
      + escape("[1m") + escape("[4:4m")
  )
}

@Test
func `renderer defaults to extended underline output`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "C",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
  )

  let bytes = Renderer.render(buffer)

  #expect(
    bytes == escape("[2J") + escape("[1;1H") + escape("[0m") + escape("[58:5:196m")
      + escape("[4:3m") + utf8("C") + escape("[0m")
  )
}

@Test
func `renderer baseline underline output retains SGR 4 and visible text`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 1))
  buffer.write(
    "D",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(underlineStyle: .double, underlineColor: .indexed(196))
  )
  buffer.write(
    "C",
    at: TerminalPosition(column: 1, row: 0),
    style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
  )
  buffer.write(
    "O",
    at: TerminalPosition(column: 2, row: 0),
    style: Style(underlineStyle: .dotted, underlineColor: .indexed(196))
  )
  buffer.write(
    "H",
    at: TerminalPosition(column: 3, row: 0),
    style: Style(underlineStyle: .dashed, underlineColor: .indexed(196))
  )

  let bytes = Renderer.render(buffer, underlineRendering: .baseline)

  #expect(
    bytes == escape("[2J") + escape("[1;1H") + escape("[0m") + escape("[4m")
      + utf8("DCOH") + escape("[0m")
  )
}

@Test
func `renderer emits no redundant sgr for adjacent same style cells`() {
  var buffer = Buffer(size: TerminalSize(columns: 2, rows: 1))
  buffer.write(
    "ab",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(attributes: [.bold])
  )

  let bytes = Renderer.render(previous: Buffer(size: buffer.size), current: buffer)

  #expect(
    bytes == escape("[1;1H") + escape("[0m") + escape("[1m") + utf8("ab")
      + escape("[0m")
  )
}

@Test
func `renderer opens shared hyperlink once and closes at frame end`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 2, rows: 1))
  let link = try Hyperlink(uri: "https://example.com/docs")
  buffer.write(
    "ab",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(hyperlink: link)
  )

  let bytes = Renderer.render(previous: Buffer(size: buffer.size), current: buffer)

  #expect(
    bytes == escape("[1;1H") + escape("]8;;https://example.com/docs") + escape("\\")
      + escape("[0m") + utf8("ab") + escape("]8;;") + escape("\\") + escape("[0m")
  )
}

@Test
func `renderer disables OSC 8 but preserves text`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 2, rows: 1))
  let link = try Hyperlink(uri: "https://example.com/docs")
  buffer.write(
    "ab",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(hyperlink: link)
  )
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.encodeFrame(
    previous: Buffer(size: buffer.size),
    current: buffer,
    wrapInSynchronizedOutput: false,
    colorCapability: .truecolor,
    renderHyperlinks: false,
    into: &bytes
  )

  #expect(bytes == escape("[1;1H") + escape("[0m") + utf8("ab") + escape("[0m"))
}

@Test
func `renderer switches and closes hyperlinks independently from sgr`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 3, rows: 1))
  let first = try Hyperlink(uri: "https://example.com/a")
  let second = try Hyperlink(uri: "https://example.com/b", id: "b")
  buffer.write(
    "a",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(hyperlink: first)
  )
  buffer.write(
    "b",
    at: TerminalPosition(column: 1, row: 0),
    style: Style(hyperlink: second)
  )
  buffer.write("c", at: TerminalPosition(column: 2, row: 0))

  let bytes = Renderer.render(previous: Buffer(size: buffer.size), current: buffer)

  #expect(
    bytes == escape("[1;1H") + escape("]8;;https://example.com/a") + escape("\\")
      + escape("[0m") + utf8("a") + escape("]8;;") + escape("\\")
      + escape("]8;id=b;https://example.com/b") + escape("\\") + utf8("b")
      + escape("]8;;") + escape("\\") + utf8("c") + escape("[0m")
  )
}

@Test
func `damage render emits hyperlink only changes`() throws {
  var previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  previous.write("x", at: TerminalPosition(column: 0, row: 0))
  var current = previous
  let link = try Hyperlink(uri: "https://example.com/x")
  current.write(
    "x",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(hyperlink: link)
  )

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("]8;;https://example.com/x") + escape("\\")
      + escape("[0m") + utf8("x") + escape("]8;;") + escape("\\") + escape("[0m")
  )
}

@Test
func `renderer keeps underline SGR independent from hyperlinks`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  let link = try Hyperlink(uri: "https://example.com/underline")
  buffer.write(
    "U",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(
      underlineStyle: .curly,
      underlineColor: .indexed(196),
      hyperlink: link
    )
  )

  let bytes = Renderer.render(previous: Buffer(size: buffer.size), current: buffer)

  #expect(
    bytes == escape("[1;1H") + escape("]8;;https://example.com/underline") + escape("\\")
      + escape("[0m") + escape("[58:5:196m") + escape("[4:3m") + utf8("U")
      + escape("]8;;") + escape("\\") + escape("[0m")
  )
}

@Test
func `damage render keeps an unchanged hyperlink while underline style changes`() throws {
  let link = try Hyperlink(uri: "https://example.com/underline")
  var previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  previous.write(
    "U",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(underlineStyle: .curly, hyperlink: link)
  )
  var current = previous
  current.write(
    "U",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(underlineStyle: .dashed, hyperlink: link)
  )

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("]8;;https://example.com/underline") + escape("\\")
      + escape("[0m") + escape("[4:5m") + utf8("U") + escape("]8;;") + escape("\\")
      + escape("[0m")
  )
}

@Test
func `damage render keeps underline state while only the hyperlink changes`() throws {
  var previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  previous.write(
    "U",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(
      underlineStyle: .curly, hyperlink: try Hyperlink(uri: "https://example.com/a"))
  )
  var current = previous
  current.write(
    "U",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(
      underlineStyle: .curly, hyperlink: try Hyperlink(uri: "https://example.com/b"))
  )

  let bytes = Renderer.render(previous: previous, current: current)

  #expect(
    bytes == escape("[1;1H") + escape("]8;;https://example.com/b") + escape("\\")
      + escape("[0m") + escape("[4:3m") + utf8("U") + escape("]8;;") + escape("\\")
      + escape("[0m")
  )
}

@Test
func `renderer resolves underline color by color capability`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "U",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(underlineStyle: .curly, underlineColor: .rgb(255, 0, 0))
  )

  #expect(
    Renderer.render(buffer, colorCapability: .truecolor)
      == escape("[2J") + escape("[1;1H") + escape("[0m") + escape("[58:2::255:0:0m")
      + escape("[4:3m") + utf8("U") + escape("[0m")
  )
  #expect(
    Renderer.render(buffer, colorCapability: .indexed256)
      == escape("[2J") + escape("[1;1H") + escape("[0m") + escape("[58:5:196m")
      + escape("[4:3m") + utf8("U") + escape("[0m")
  )
  #expect(
    Renderer.render(buffer, colorCapability: .ansi16)
      == escape("[2J") + escape("[1;1H") + escape("[0m") + escape("[58:5:9m")
      + escape("[4:3m") + utf8("U") + escape("[0m")
  )
  #expect(
    Renderer.render(buffer, colorCapability: .noColor)
      == escape("[2J") + escape("[1;1H") + escape("[0m") + escape("[4:3m") + utf8("U")
      + escape("[0m")
  )
}

@Test
func `renderer emits truecolor foreground when capability allows RGB`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "R",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0))
  )

  let bytes = Renderer.render(buffer, colorCapability: .truecolor)

  #expect(bytes == fullRepaint(sgr: "[38;2;255;0;0m", text: "R"))
}

@Test
func `renderer degrades RGB foreground to indexed color`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "R",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0))
  )

  let bytes = Renderer.render(buffer, colorCapability: .indexed256)

  #expect(bytes == fullRepaint(sgr: "[38;5;196m", text: "R"))
}

@Test(arguments: [ColorCapability.ansi16, .unknown])
func `renderer degrades RGB foreground to ANSI sixteen`(_ capability: ColorCapability) {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "R",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0))
  )

  let bytes = Renderer.render(buffer, colorCapability: capability)

  #expect(bytes == fullRepaint(sgr: "[91m", text: "R"))
}

@Test
func `renderer suppresses foreground color under no-color`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "R",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0))
  )

  let bytes = Renderer.render(buffer, colorCapability: .noColor)

  #expect(bytes == fullRepaint(text: "R"))
}

@Test
func `renderer degrades RGB background by color capability`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "B",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(background: .rgb(255, 0, 0))
  )

  #expect(
    Renderer.render(buffer, colorCapability: .truecolor)
      == fullRepaint(sgr: "[48;2;255;0;0m", text: "B")
  )
  #expect(
    Renderer.render(buffer, colorCapability: .indexed256)
      == fullRepaint(sgr: "[48;5;196m", text: "B")
  )
  #expect(
    Renderer.render(buffer, colorCapability: .ansi16)
      == fullRepaint(sgr: "[101m", text: "B")
  )
  #expect(
    Renderer.render(buffer, colorCapability: .noColor) == fullRepaint(text: "B")
  )
}

@Test
func `renderer omits redundant colors that degrade to same ANSI color`() {
  var buffer = Buffer(size: TerminalSize(columns: 2, rows: 1))
  buffer.write(
    "R",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0))
  )
  buffer.write(
    "I",
    at: TerminalPosition(column: 1, row: 0),
    style: Style(foreground: .indexed(196))
  )

  let bytes = Renderer.render(buffer, colorCapability: .ansi16)

  #expect(bytes == fullRepaint(sgr: "[91m", text: "RI"))
}

@Test
func `renderer still emits attributes under no-color`() {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  buffer.write(
    "B",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0), attributes: [.bold])
  )

  let bytes = Renderer.render(buffer, colorCapability: .noColor)

  #expect(bytes == fullRepaint(sgr: "[1m", text: "B"))
}

@Test
func `renderer keeps hyperlinks while suppressing no-color SGR`() throws {
  var buffer = Buffer(size: TerminalSize(columns: 1, rows: 1))
  let link = try Hyperlink(uri: "https://example.com/color")
  buffer.write(
    "L",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0), hyperlink: link)
  )

  let bytes = Renderer.render(buffer, colorCapability: .noColor)

  #expect(
    bytes == escape("[2J") + escape("[1;1H")
      + escape("]8;;https://example.com/color") + escape("\\")
      + escape("[0m") + utf8("L") + escape("]8;;") + escape("\\") + escape("[0m")
  )
}

@Test
func `damage render repaints semantic color changes that no-color suppresses`() {
  var previous = Buffer(size: TerminalSize(columns: 1, rows: 1))
  previous.write(
    "x",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(255, 0, 0))
  )
  var current = previous
  current.write(
    "x",
    at: TerminalPosition(column: 0, row: 0),
    style: Style(foreground: .rgb(0, 255, 0))
  )

  let bytes = Renderer.render(
    previous: previous,
    current: current,
    colorCapability: .noColor
  )

  #expect(bytes == escape("[1;1H") + escape("[0m") + utf8("x") + escape("[0m"))
}

private func fullRepaint(sgr: String? = nil, text: String) -> [UInt8] {
  var bytes = escape("[2J") + escape("[1;1H") + escape("[0m")
  if let sgr {
    bytes += escape(sgr)
  }
  bytes += utf8(text)
  bytes += escape("[0m")
  return bytes
}

private func escape(_ suffix: String) -> [UInt8] {
  utf8("\u{1B}\(suffix)")
}

private func utf8(_ string: String) -> [UInt8] {
  Array(string.utf8)
}
