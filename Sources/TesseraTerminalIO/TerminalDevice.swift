import Dependencies
import TesseraTerminalCore

/// A dependency client for the current terminal device.
public struct TerminalDevice: Sendable {
  public var size: @Sendable () async throws -> TerminalSize
  public var write: @Sendable ([UInt8]) async throws -> Void

  public init(
    size: @escaping @Sendable () async throws -> TerminalSize,
    write: @escaping @Sendable ([UInt8]) async throws -> Void
  ) {
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
