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
    into: &bytes
  )

  #expect(bytes == escape("[1;2H") + escape("[0m") + utf8("x") + escape("[0m"))
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
    into: &bytes
  )

  #expect(bytes == escape("[0m"))
}

@Test
func `sgr delta emits reset and full style for unknown old style`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: nil,
    to: Style(foreground: .ansi(.red), attributes: [.bold, .underline]),
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[31m") + escape("[1m") + escape("[4m"))
}

@Test
func `sgr delta emits only added attributes`() {
  var bytes: [UInt8] = []

  sgrDelta(
    from: Style(attributes: [.bold]),
    to: Style(attributes: [.bold, .italic]),
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
    into: &bytes
  )

  #expect(bytes == escape("[0m") + escape("[44m"))
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

private func escape(_ suffix: String) -> [UInt8] {
  utf8("\u{1B}\(suffix)")
}

private func utf8(_ string: String) -> [UInt8] {
  Array(string.utf8)
}
