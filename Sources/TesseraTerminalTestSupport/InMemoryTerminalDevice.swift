import TesseraTerminalCore
import TesseraTerminalIO

/// An in-memory terminal device for dependency-controlled tests.
public actor InMemoryTerminalDevice {
  private var storedBytes: [UInt8] = []
  private var storedSize: TerminalSize

  /// The bytes written to the device so far.
  public var bytes: [UInt8] {
    storedBytes
  }

  /// A terminal device dependency backed by this actor's in-memory state.
  public var terminalDevice: TerminalDevice {
    TerminalDevice(
      size: { await self.storedSize },
      write: { await self.write($0) }
    )
  }

  /// Creates an in-memory terminal device with an initial terminal size.
  public init(size: TerminalSize = TerminalSize(columns: 1, rows: 1)) {
    self.storedSize = size
  }

  private func write(_ bytes: [UInt8]) {
    storedBytes.append(contentsOf: bytes)
  }
}
