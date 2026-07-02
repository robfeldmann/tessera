import InlineSnapshotTesting
import SnapshotTesting
import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalRendering

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `damage render is visually equivalent for ascii edits`() {
  var previous = Buffer(size: TerminalSize(columns: 5, rows: 2))
  previous.write("hello", at: TerminalPosition(column: 0, row: 0))
  previous.write("old", at: TerminalPosition(column: 0, row: 1))
  var current = previous
  current.write("a", at: TerminalPosition(column: 1, row: 0))
  current.write("new", at: TerminalPosition(column: 0, row: 1))

  let snapshot = snapshotAfterDamage(previous: previous, current: current)

  assertInlineSnapshot(of: snapshot, as: .terminalText()) {
    """
    hallo
    new
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `damage render is visually equivalent for styled text`() {
  var previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  previous.write("abc", at: TerminalPosition(column: 0, row: 0))
  var current = previous
  current.write(
    "b",
    at: TerminalPosition(column: 1, row: 0),
    style: Style(foreground: .ansi(.red), attributes: [.bold])
  )

  let snapshot = snapshotAfterDamage(previous: previous, current: current)

  assertInlineSnapshot(of: snapshot, as: .terminalStyledGrid(trim: .none)) {
    """
    ── chars ──
    abc
    ── style ──
    TCT
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `damage render is visually equivalent for wide grapheme replacement`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  previous.write("你好", at: TerminalPosition(column: 0, row: 0))
  var current = Buffer(size: TerminalSize(columns: 4, rows: 1))
  current.write("你x", at: TerminalPosition(column: 0, row: 0))

  let snapshot = snapshotAfterDamage(previous: previous, current: current)

  assertInlineSnapshot(of: snapshot, as: .terminalText()) {
    """
    你 x
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `damage render is visually equivalent for row changes`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 3))
  previous.write("top", at: TerminalPosition(column: 0, row: 0))
  previous.write("mid", at: TerminalPosition(column: 0, row: 1))
  previous.write("end", at: TerminalPosition(column: 0, row: 2))
  var current = previous
  current.write("X", at: TerminalPosition(column: 3, row: 0))
  current.write("Y", at: TerminalPosition(column: 3, row: 2))

  let snapshot = snapshotAfterDamage(previous: previous, current: current)

  assertInlineSnapshot(of: snapshot, as: .terminalText()) {
    """
    topX
    mid
    endY
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `damage render is visually equivalent for visible raw payloads`() {
  let previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  var current = previous
  current.writeRaw(
    RawTerminalPayload(bytes: Array("XY".utf8), declaredWidth: 2),
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 2, rows: 1)
  )

  let snapshot = snapshotAfterDamage(previous: previous, current: current)
  let expectedText = " XY"

  assertInlineSnapshot(of: snapshot, as: .terminalText()) {
    """
    \(expectedText)
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `damage render preserves opaque regions`() {
  var previous = Buffer(size: TerminalSize(columns: 5, rows: 1))
  previous.write("abcde", at: TerminalPosition(column: 0, row: 0))
  var current = previous
  current.write("A", at: TerminalPosition(column: 0, row: 0))
  current.markOpaque(Rect(column: 1, row: 0, columns: 3, rows: 1))
  current.write("E", at: TerminalPosition(column: 4, row: 0))

  let snapshot = snapshotAfterDamage(previous: previous, current: current)

  assertInlineSnapshot(of: snapshot, as: .terminalText()) {
    """
    AbcdE
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `invalidated render erases before repainting`() {
  var previous = Buffer(size: TerminalSize(columns: 4, rows: 1))
  previous.write("stale", at: TerminalPosition(column: 0, row: 0))
  var current = Buffer(size: TerminalSize(columns: 4, rows: 1))
  current.write("ok", at: TerminalPosition(column: 0, row: 0))
  let terminal = terminalPainted(with: previous)
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.invalidate()
  renderer.encodeFrame(
    previous: previous,
    current: current,
    wrapInSynchronizedOutput: false,
    into: &bytes
  )
  terminal.feed(bytes)

  assertInlineSnapshot(of: terminal.snapshot(), as: .terminalText()) {
    """
    ok
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `synchronized damage render is visually equivalent`() {
  let previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  var current = previous
  current.write("x", at: TerminalPosition(column: 1, row: 0))
  let terminal = terminalPainted(with: previous)
  var renderer = Renderer()
  var bytes: [UInt8] = []

  renderer.encodeFrame(
    previous: previous,
    current: current,
    wrapInSynchronizedOutput: true,
    into: &bytes
  )
  terminal.feed(bytes)
  let expectedText = " x"

  assertInlineSnapshot(of: terminal.snapshot(), as: .terminalText()) {
    """
    \(expectedText)
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `zero width raw control payload does not affect visual state`() {
  let previous = Buffer(size: TerminalSize(columns: 3, rows: 1))
  var current = previous
  current.writeRaw(
    RawTerminalPayload(bytes: [0x1B, 0x5B, 0x30, 0x6D], declaredWidth: 0),
    at: TerminalPosition(column: 1, row: 0),
    occupying: Rect(column: 1, row: 0, columns: 0, rows: 0)
  )

  let snapshot = snapshotAfterDamage(previous: previous, current: current)

  assertInlineSnapshot(of: snapshot, as: .terminalText()) {
    """

    """
  }
}

private func snapshotAfterDamage(previous: Buffer, current: Buffer) -> ScreenSnapshot {
  let terminal = terminalPainted(with: previous)
  terminal.feed(Renderer.render(previous: previous, current: current))
  return terminal.snapshot()
}

private func terminalPainted(with buffer: Buffer) -> VirtualTerminal {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(
    cols: buffer.size.columns, rows: buffer.size.rows)
  terminal.feed(Renderer.render(buffer))
  return terminal
}
