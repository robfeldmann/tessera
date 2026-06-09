import TesseraTerminalCore

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

/// Owned platform terminal I/O.
package actor PlatformIO {
  private let terminalDevice: TerminalDevice
  private var outputBuffer: [UInt8] = []

  /// Reads raw bytes from terminal input.
  package nonisolated let bytes: AsyncStream<UInt8>

  /// Streams terminal-size changes.
  package nonisolated let sizeChanges: AsyncStream<TerminalSize>

  /// Creates platform I/O from the live terminal device.
  package init() {
    self.init(terminalDevice: .live)
  }

  /// Creates platform I/O from an owned package-internal terminal device seam.
  package init(terminalDevice: TerminalDevice) {
    self.terminalDevice = terminalDevice
    self.bytes = terminalDevice.bytes()
    self.sizeChanges = terminalDevice.sizeChanges()
  }

  /// Buffers bytes for terminal output.
  package func write(_ bytes: [UInt8]) {
    outputBuffer.append(contentsOf: bytes)
  }

  /// Buffers bytes for terminal output.
  package func write(_ bytes: ArraySlice<UInt8>) {
    outputBuffer.append(contentsOf: bytes)
  }

  /// Flushes buffered output bytes to the terminal device.
  package func flush() async throws {
    guard !outputBuffer.isEmpty else {
      return
    }

    let bytes = outputBuffer
    outputBuffer.removeAll(keepingCapacity: true)

    do {
      try await terminalDevice.write(bytes)
    } catch {
      outputBuffer.insert(contentsOf: bytes, at: 0)
      throw error
    }
  }

  /// Reads the terminal size from the output terminal.
  package func size() async throws -> TerminalSize {
    try await terminalDevice.size()
  }

  /// Enters the terminal's alternate screen buffer.
  package func enableAltScreen() async throws {
    try await terminalDevice.enterAltScreen()
  }

  /// Enables raw input mode.
  package func enableRawMode() async throws {
    try await terminalDevice.enterRawMode()
  }

  /// Leaves the terminal's alternate screen buffer.
  package func disableAltScreen() async throws {
    try await terminalDevice.exitAltScreen()
  }

  /// Restores the terminal input mode captured before entering raw mode.
  package func disableRawMode() async throws {
    try await terminalDevice.exitRawMode()
  }

  /// Returns the terminal attributes captured before raw mode, if available.
  #if os(macOS) || os(Linux)
    package func savedTermios() -> termios? {
      terminalDevice.savedTermios()
    }
  #endif
}
