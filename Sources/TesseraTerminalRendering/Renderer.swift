import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore

/// Renders terminal buffers into full-repaint byte streams.
public enum Renderer {
  /// Returns bytes that move the cursor home and redraw every cell in the buffer.
  public static func render(_ buffer: Buffer) -> [UInt8] {
    var bytes: [UInt8] = []

    ControlSequence
      .cursorPosition(TerminalPosition(column: 0, row: 0))
      .encode(into: &bytes)

    var currentStyle: Style?
    for row in 0..<buffer.size.rows {
      for column in 0..<buffer.size.columns {
        let cell = buffer[row, column]
        switch cell.content {
        case .blank:
          sgrDelta(from: currentStyle, to: cell.style, into: &bytes)
          currentStyle = cell.style
          ControlSequence.text(" ").encode(into: &bytes)
        case .continuation:
          break
        case .grapheme(let grapheme):
          sgrDelta(from: currentStyle, to: cell.style, into: &bytes)
          currentStyle = cell.style
          ControlSequence.text(grapheme).encode(into: &bytes)
        case .raw(let payload):
          sgrDelta(from: currentStyle, to: cell.style, into: &bytes)
          currentStyle = cell.style
          ControlSequence.raw(payload).encode(into: &bytes)
        }
      }

      if row < buffer.size.rows - 1 {
        ControlSequence.text("\r\n").encode(into: &bytes)
      }
    }

    ControlSequence.resetAttributes.encode(into: &bytes)
    return bytes
  }
}
