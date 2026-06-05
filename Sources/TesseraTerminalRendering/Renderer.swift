import TesseraTerminalBuffer

/// Renders terminal buffers into Phase 1 full-repaint byte streams.
public enum Renderer {
  /// Returns bytes that move the cursor home and redraw every cell in the buffer.
  public static func render(_ buffer: Buffer) -> [UInt8] {
    var bytes: [UInt8] = []

    bytes.append(contentsOf: "\u{1B}[H".utf8)

    for row in 0..<buffer.size.rows {
      for column in 0..<buffer.size.columns {
        bytes.append(contentsOf: String(buffer[row, column].character).utf8)
      }

      if row < buffer.size.rows - 1 {
        bytes.append(0x0D)
        bytes.append(0x0A)
      }
    }

    return bytes
  }
}
