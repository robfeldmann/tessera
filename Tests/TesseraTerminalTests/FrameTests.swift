import CustomDump
import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import Testing

@testable import TesseraTerminal

/// Lends a borrowed `Frame` over caller-owned buffer storage and returns the buffer after
/// the body runs, mirroring how `TerminalSession.draw` scopes the frame's lifetime.
private func withFrame(
  size: TerminalSize,
  _ body: (borrowing Frame) -> Void
) -> Buffer {
  var buffer = Buffer(size: size)
  withUnsafeMutablePointer(to: &buffer) { storage in
    body(Frame(buffer: storage))
  }
  return buffer
}

@Test
func `frame exposes configured terminal size`() {
  let size = TerminalSize(columns: 12, rows: 3)
  var observed: TerminalSize?

  _ = withFrame(size: size) { frame in
    observed = frame.size
  }

  expectNoDifference(observed, size)
}

@Test
func `frame write stores styled cells in backing buffer`() {
  let style = Style()

  let buffer = withFrame(size: TerminalSize(columns: 4, rows: 2)) { frame in
    frame.write("Hi", at: TerminalPosition(column: 1, row: 1), style: style)
  }

  expectNoDifference(buffer[1, 1], Cell(character: "H", style: style))
  expectNoDifference(buffer[1, 2], Cell(character: "i", style: style))
}

@Test
func `frame forwards raw writes to backing buffer`() {
  let payload = RawTerminalPayload(bytes: [0x1B], declaredWidth: 2)

  let buffer = withFrame(size: TerminalSize(columns: 3, rows: 1)) { frame in
    frame.writeRaw(
      payload,
      at: TerminalPosition(column: 1, row: 0),
      occupying: Rect(column: 1, row: 0, columns: 2, rows: 1)
    )
  }

  #expect(buffer[0, 1].content == .raw(payload))
  #expect(buffer[0, 2].content == .continuation)
}

@Test
func `frame forwards opaque regions to backing buffer`() {
  let buffer = withFrame(size: TerminalSize(columns: 3, rows: 1)) { frame in
    frame.markOpaque(Rect(column: 1, row: 0, columns: 1, rows: 1))
  }

  #expect(buffer[0, 1].diffPolicy == .opaque)
}
