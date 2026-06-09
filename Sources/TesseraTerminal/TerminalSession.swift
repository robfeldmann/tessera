import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput

/// A scoped live-terminal capability for Tessera applications.
public actor TerminalSession {
  private let io: PlatformIO

  package init(io: PlatformIO) {
    self.io = io
  }

  /// Runs `body` inside a scoped application terminal session.
  public static func withApplicationTerminal<R>(
    configuration: TerminalApplicationConfiguration,
    _ body: (isolated TerminalSession) async throws -> sending R
  ) async throws -> sending R {
    _ = configuration
    throw PlatformIOError.unsupportedPlatform
  }

  /// Draws one frame. Phase 6 wires this to buffered platform output.
  public func draw<R>(
    _ body: (borrowing Frame) throws -> sending R
  ) async throws -> sending R {
    let size = try await io.size()
    let frame = Frame(size: size)
    return try body(frame)
  }

  /// Reads the next parsed input event. Phase 6 wires this to session input.
  public func nextEvent() async throws -> InputEvent {
    throw PlatformIOError.unsupportedPlatform
  }
}
