import TesseraTerminalBuffer
import TesseraTerminalCore

/// A minimal drawing frame for a scoped terminal session.
public final class Frame {
  package var buffer: Buffer

  /// The visible terminal size for this frame.
  public var size: TerminalSize {
    buffer.size
  }

  /// Creates a frame with an empty buffer of `size`.
  public init(size: TerminalSize) {
    self.buffer = Buffer(size: size)
  }

  /// Writes text into the frame buffer.
  public func write(
    _ string: String,
    at position: TerminalPosition,
    style: Style = Style()
  ) {
    buffer.write(string, at: position, style: style)
  }
}
