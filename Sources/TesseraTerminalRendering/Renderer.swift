import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore

/// Renders terminal buffers into byte streams.
public enum Renderer {
  /// Returns bytes that redraw every non-opaque cell in the buffer.
  public static func render(_ buffer: Buffer) -> [UInt8] {
    render(previous: nil, current: buffer)
  }

  package static func render(previous: Buffer?, current: Buffer) -> [UInt8] {
    var bytes: [UInt8] = []
    encodeFrame(previous: previous, current: current, into: &bytes)
    return bytes
  }

  package static func encodeFrame(
    previous: Buffer?,
    current: Buffer,
    into bytes: inout [UInt8]
  ) {
    var cursor: TerminalPosition?
    var style: Style?

    for run in BufferDiff.damageRuns(previous: previous, current: current) {
      for column in run.columns {
        let cell = current[run.row, column]
        guard cell.content != .continuation else {
          continue
        }

        let position = TerminalPosition(column: column, row: run.row)
        if cursor != position {
          ControlSequence.cursorPosition(position).encode(into: &bytes)
          cursor = position
        }

        sgrDelta(from: style, to: cell.style, into: &bytes)
        style = cell.style
        encodeContent(cell.content, into: &bytes)
        cursor = TerminalPosition(column: column + cell.width, row: run.row)
      }
    }

    ControlSequence.resetAttributes.encode(into: &bytes)
  }

  private static func encodeContent(_ content: Cell.Content, into bytes: inout [UInt8]) {
    switch content {
    case .blank:
      ControlSequence.text(" ").encode(into: &bytes)
    case .continuation:
      break
    case .grapheme(let grapheme):
      ControlSequence.text(grapheme).encode(into: &bytes)
    case .raw(let payload):
      ControlSequence.raw(payload).encode(into: &bytes)
    }
  }
}
