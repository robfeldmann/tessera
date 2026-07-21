import TesseraTerminal

/// A scoped, in-memory terminal session for deterministic renderer integration tests.
public struct InMemoryTerminalSession: Sendable {
  /// The device that captures the session's output and lifecycle events.
  public let device: InMemoryTerminalDevice

  /// Bytes emitted by the session, including application lifecycle and draw output.
  public var bytes: [UInt8] {
    get async {
      await device.bytes
    }
  }

  /// Terminal lifecycle and flush events emitted by the session.
  public var events: [InMemoryTerminalDeviceEvent] {
    get async {
      await device.events
    }
  }

  /// Creates a session backed by an in-memory terminal device.
  public init(
    size: TerminalSize = TerminalSize(columns: 1, rows: 1),
    cellPixelSize: CellPixelSize? = nil,
    inputBytes: [UInt8] = []
  ) {
    self.device = InMemoryTerminalDevice(
      size: size,
      cellPixelSize: cellPixelSize,
      inputBytes: inputBytes
    )
  }

  /// Runs a body in an application terminal scope backed by this in-memory device.
  ///
  /// The terminal scope restores every acquired application mode before this method
  /// returns or rethrows an error from `body`.
  public func withApplicationTerminal<R>(
    configuration: TerminalApplicationConfiguration = .init(
      modes: [],
      synchronizedOutput: .disabled,
      colorCapability: .force(.noColor)
    ),
    environment: [String: String] = [:],
    _ body: (isolated TerminalSession) async throws -> sending R
  ) async throws -> sending R {
    let io = PlatformIO(terminalDevice: await device.terminalDevice)
    return try await TerminalSession.withApplicationTerminal(
      configuration: configuration,
      io: io,
      environment: environment,
      body
    )
  }
}
