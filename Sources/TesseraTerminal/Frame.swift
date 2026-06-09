import TesseraTerminalBuffer
import TesseraTerminalCore

/// A minimal drawing frame for a scoped terminal session.
public struct Frame: ~Copyable {
  private var buffer: Buffer

  /// The visible terminal size for this frame.
  public var size: TerminalSize {
    buffer.size
  }

  /// Creates a frame with an empty buffer of `size`.
  public init(size: TerminalSize) {
    self.buffer = Buffer(size: size)
  }

  /// Provides mutable access to the frame buffer.
  public borrowing func withBuffer<R>(
    _ body: (inout Buffer) throws -> sending R
  ) throws -> sending R {
    var buffer = self.buffer
    return try body(&buffer)
  }
}
