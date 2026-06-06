import Dependencies
import TesseraTerminalCore

/// A dependency client for the current terminal device.
public struct TerminalDevice: Sendable {
  /// Reads raw bytes from terminal input.
  public var bytes: @Sendable () -> AsyncStream<UInt8>

  /// Enters the terminal's alternate screen buffer.
  public var enterAltScreen: @Sendable () async throws -> Void

  /// Enables raw input mode.
  public var enterRawMode: @Sendable () async throws -> Void

  /// Leaves the terminal's alternate screen buffer.
  public var exitAltScreen: @Sendable () async throws -> Void

  /// Restores the terminal input mode captured before entering raw mode.
  public var exitRawMode: @Sendable () async throws -> Void

  /// Reads the terminal's current size.
  public var size: @Sendable () async throws -> TerminalSize

  /// Writes bytes to terminal output.
  public var write: @Sendable ([UInt8]) async throws -> Void

  public init(
    bytes: @escaping @Sendable () -> AsyncStream<UInt8> = { AsyncStream { $0.finish() } },
    enterAltScreen: @escaping @Sendable () async throws -> Void = {},
    enterRawMode: @escaping @Sendable () async throws -> Void = {},
    exitAltScreen: @escaping @Sendable () async throws -> Void = {},
    exitRawMode: @escaping @Sendable () async throws -> Void = {},
    size: @escaping @Sendable () async throws -> TerminalSize,
    write: @escaping @Sendable ([UInt8]) async throws -> Void
  ) {
    self.bytes = bytes
    self.enterAltScreen = enterAltScreen
    self.enterRawMode = enterRawMode
    self.exitAltScreen = exitAltScreen
    self.exitRawMode = exitRawMode
    self.size = size
    self.write = write
  }
}

extension TerminalDevice: TestDependencyKey {
  public static var testValue: Self {
    Self(
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { _ in }
    )
  }
}

extension DependencyValues {
  /// The current terminal device dependency.
  public var terminalDevice: TerminalDevice {
    get { self[TerminalDevice.self] }
    set { self[TerminalDevice.self] = newValue }
  }
}
