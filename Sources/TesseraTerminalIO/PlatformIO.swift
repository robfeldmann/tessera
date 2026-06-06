import Dependencies
import TesseraTerminalCore

/// Minimal platform terminal I/O.
public struct PlatformIO: Sendable {
  private let terminalDevice: TerminalDevice

  /// Reads the terminal size from the output terminal.
  public var size: TerminalSize {
    get async throws {
      try await terminalDevice.size()
    }
  }

  /// Creates platform I/O using the current terminal device dependency.
  public init() {
    @Dependency(\.terminalDevice) var terminalDevice
    self.terminalDevice = terminalDevice
  }

  /// Writes bytes directly to stdout.
  public func write(_ bytes: [UInt8]) async throws {
    try await terminalDevice.write(bytes)
  }
}
