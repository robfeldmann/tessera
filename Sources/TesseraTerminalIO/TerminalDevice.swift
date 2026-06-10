import TesseraTerminalCore

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

/// Package-internal terminal device operations used to build owned platform I/O seams.
package struct TerminalDevice: Sendable {
  /// Reads raw bytes from terminal input.
  package var bytes: @Sendable () -> AsyncStream<UInt8>

  /// Enters the terminal's alternate screen buffer.
  package var enterAltScreen: @Sendable () async throws -> Void

  /// Enables raw input mode.
  package var enterRawMode: @Sendable () async throws -> Void

  /// Leaves the terminal's alternate screen buffer.
  package var exitAltScreen: @Sendable () async throws -> Void

  /// Restores the terminal input mode captured before entering raw mode.
  package var exitRawMode: @Sendable () async throws -> Void

  /// The input file descriptor for emergency cleanup, if available.
  package var inputFileDescriptor: CInt

  /// The output file descriptor for emergency cleanup, if available.
  package var outputFileDescriptor: CInt

  /// Returns the saved terminal attributes captured before raw mode, if available.
  #if os(macOS) || os(Linux)
    package var savedTermios: @Sendable () -> termios?
  #endif

  /// Reads the terminal's current size.
  package var size: @Sendable () async throws -> TerminalSize

  /// Streams terminal-size changes.
  package var sizeChanges: @Sendable () -> AsyncStream<TerminalSize>

  /// Performs one output write operation and returns the number of bytes written.
  package var write: @Sendable (ArraySlice<UInt8>) async throws -> Int

  package init(
    bytes: @escaping @Sendable () -> AsyncStream<UInt8> = { AsyncStream { $0.finish() } },
    enterAltScreen: @escaping @Sendable () async throws -> Void = {},
    enterRawMode: @escaping @Sendable () async throws -> Void = {},
    exitAltScreen: @escaping @Sendable () async throws -> Void = {},
    exitRawMode: @escaping @Sendable () async throws -> Void = {},
    inputFileDescriptor: CInt = -1,
    outputFileDescriptor: CInt = -1,
    size: @escaping @Sendable () async throws -> TerminalSize,
    sizeChanges: @escaping @Sendable () -> AsyncStream<TerminalSize> = {
      AsyncStream { $0.finish() }
    },
    write: @escaping @Sendable (ArraySlice<UInt8>) async throws -> Int
  ) {
    self.bytes = bytes
    self.enterAltScreen = enterAltScreen
    self.enterRawMode = enterRawMode
    self.exitAltScreen = exitAltScreen
    self.exitRawMode = exitRawMode
    self.inputFileDescriptor = inputFileDescriptor
    self.outputFileDescriptor = outputFileDescriptor
    #if os(macOS) || os(Linux)
      self.savedTermios = { nil }
    #endif
    self.size = size
    self.sizeChanges = sizeChanges
    self.write = write
  }
}
