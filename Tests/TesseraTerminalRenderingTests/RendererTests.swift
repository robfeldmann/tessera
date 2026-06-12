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

  assertInlineSnapshot(of: RendererCustomDump(bytes: bytes), as: .customDump) {
    """
    [home]
    bytes: 1B 5B 31 3B 31 48
    text:  ␛[1;1H

    [row 0]
    bytes: 1B 5B 30 6D 20 20 20 0D 0A
    text:  ␛[0m···␍␊

    [row 1]
    bytes: 20 20 20 1B 5B 30 6D
    text:  ···␛[0m
    """
  }
}

@Test
func `rendering a buffer with text emits row major cell bytes`() {
  var buffer = Buffer(size: TerminalSize(columns: 4, rows: 2))
  buffer.write("Hi", at: TerminalPosition(column: 1, row: 0))
  buffer.write("q", at: TerminalPosition(column: 3, row: 1))

  let bytes = Renderer.render(buffer)

  assertInlineSnapshot(of: RendererCustomDump(bytes: bytes), as: .customDump) {
    """
    [home]
    bytes: 1B 5B 31 3B 31 48
    text:  ␛[1;1H

    [row 0]
    bytes: 1B 5B 30 6D 20 48 69 20 0D 0A
    text:  ␛[0m·Hi·␍␊

    [row 1]
    bytes: 20 20 20 71 1B 5B 30 6D
    text:  ···q␛[0m
    """
  }
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

  let bytes = Renderer.render(buffer)

  #expect(
    bytes == escape("[1;1H") + escape("[0m") + escape("[1m") + utf8("ab") + escape("[0m")
  )
}

private func escape(_ suffix: String) -> [UInt8] {
  utf8("\u{1B}\(suffix)")
}

private func utf8(_ string: String) -> [UInt8] {
  Array(string.utf8)
}
