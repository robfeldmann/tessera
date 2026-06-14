import TesseraTerminalCore
import TesseraTerminalIO

/// An event recorded by an in-memory terminal device.
public enum InMemoryTerminalDeviceEvent: Equatable, Sendable {
  /// The terminal entered its alternate screen buffer.
  case enterAltScreen

  /// The terminal entered raw input mode.
  case enterRawMode

  /// The terminal left its alternate screen buffer.
  case exitAltScreen

  /// The terminal restored its previous input mode.
  case exitRawMode

  /// The terminal flushed bytes to output.
  case flush([UInt8])
}

/// An in-memory terminal device for deterministic terminal I/O tests.
public actor InMemoryTerminalDevice {
  private var recordedEvents: [InMemoryTerminalDeviceEvent] = []
  private var storedBytes: [UInt8] = []
  private var storedInputBytes: [UInt8]
  private var storedSize: TerminalSize

  /// The bytes written to the device so far.
  public var bytes: [UInt8] {
    storedBytes
  }

  /// The terminal lifecycle events recorded so far.
  public var events: [InMemoryTerminalDeviceEvent] {
    recordedEvents
  }

  /// A terminal device seam backed by this actor's in-memory state.
  package var terminalDevice: TerminalDevice {
    let inputBytes = storedInputBytes

    return TerminalDevice(
      bytes: {
        AsyncStream { continuation in
          if !inputBytes.isEmpty {
            continuation.yield(inputBytes)
          }
          continuation.finish()
        }
      },
      enterAltScreen: { await self.enterAltScreen() },
      enterRawMode: { await self.enterRawMode() },
      exitAltScreen: { await self.exitAltScreen() },
      exitRawMode: { await self.exitRawMode() },
      size: { await self.storedSize },
      write: { try await self.write($0) }
    )
  }

  /// Creates an in-memory terminal device with an initial terminal size and input bytes.
  public init(
    size: TerminalSize = TerminalSize(columns: 1, rows: 1),
    inputBytes: [UInt8] = []
  ) {
    self.storedInputBytes = inputBytes
    self.storedSize = size
  }

  private func enterAltScreen() {
    recordedEvents.append(.enterAltScreen)
    storedBytes.append(contentsOf: "\u{1B}[?1049h".utf8)
  }

  private func enterRawMode() {
    recordedEvents.append(.enterRawMode)
  }

  private func exitAltScreen() {
    recordedEvents.append(.exitAltScreen)
    storedBytes.append(contentsOf: "\u{1B}[?1049l".utf8)
  }

  private func exitRawMode() {
    recordedEvents.append(.exitRawMode)
  }

  private func write(_ bytes: ArraySlice<UInt8>) throws -> Int {
    let bytes = Array(bytes)
    recordedEvents.append(.flush(bytes))
    storedBytes.append(contentsOf: bytes)
    return bytes.count
  }
}
