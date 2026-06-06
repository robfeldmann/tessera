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

  /// Enters the terminal's alternate screen buffer.
  public func enterAltScreen() async throws {
    try await terminalDevice.enterAltScreen()
  }

  /// Enables raw input mode.
  public func enterRawMode() async throws {
    try await terminalDevice.enterRawMode()
  }

  /// Leaves the terminal's alternate screen buffer.
  public func exitAltScreen() async throws {
    try await terminalDevice.exitAltScreen()
  }

  /// Restores the terminal input mode captured before entering raw mode.
  public func exitRawMode() async throws {
    try await terminalDevice.exitRawMode()
  }

  /// Writes bytes directly to stdout.
  public func write(_ bytes: [UInt8]) async throws {
    try await terminalDevice.write(bytes)
  }
}
