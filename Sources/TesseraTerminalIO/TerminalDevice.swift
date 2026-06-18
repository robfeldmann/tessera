import TesseraTerminalCore

/// Package-internal terminal device operations used to build owned platform I/O seams.
package struct TerminalDevice: Sendable {
  /// Reads raw input byte chunks from terminal input.
  package var bytes: @Sendable () -> AsyncStream<[UInt8]>

  /// Enters the terminal's alternate screen buffer.
  package var enterAltScreen: @Sendable () async throws -> Void

  /// Enables raw input mode.
  package var enterRawMode: @Sendable () async throws -> Void

  /// Leaves the terminal's alternate screen buffer.
  package var exitAltScreen: @Sendable () async throws -> Void

  /// Restores the terminal input mode captured before entering raw mode.
  package var exitRawMode: @Sendable () async throws -> Void

  #if os(macOS) || os(Linux)
    /// The input file descriptor for emergency cleanup, if available.
    package var inputFileDescriptor: CInt

    /// The output file descriptor for emergency cleanup, if available.
    package var outputFileDescriptor: CInt

    /// Returns the saved terminal attributes captured before raw mode, if available.
    package var savedTermios: @Sendable () async -> termios?
  #elseif os(Windows)
    /// The input console handle for emergency cleanup, if available.
    package var inputHandle: UInt

    /// The output console handle for emergency cleanup, if available.
    package var outputHandle: UInt

    /// Returns the saved console modes captured before terminal mode changes, if available.
    package var savedConsoleModes: @Sendable () async -> (input: UInt32, output: UInt32)?
  #endif

  /// Reads the terminal's current size.
  package var size: @Sendable () async throws -> TerminalSize

  /// Streams terminal-size changes.
  package var sizeChanges: @Sendable () -> AsyncStream<TerminalSize>

  /// Performs one output write operation and returns the number of bytes written.
  package var write: @Sendable (ArraySlice<UInt8>) async throws -> Int

  package init(
    bytes: @escaping @Sendable () -> AsyncStream<[UInt8]> = { AsyncStream { $0.finish() } },
    enterAltScreen: @escaping @Sendable () async throws -> Void = {},
    enterRawMode: @escaping @Sendable () async throws -> Void = {},
    exitAltScreen: @escaping @Sendable () async throws -> Void = {},
    exitRawMode: @escaping @Sendable () async throws -> Void = {},
    inputFileDescriptor: CInt = -1,
    outputFileDescriptor: CInt = -1,
    inputHandle: UInt = 0,
    outputHandle: UInt = 0,
    savedConsoleModes: @escaping @Sendable () async -> (input: UInt32, output: UInt32)? = {
      nil
    },
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
    #if os(macOS) || os(Linux)
      self.inputFileDescriptor = inputFileDescriptor
      self.outputFileDescriptor = outputFileDescriptor
      self.savedTermios = { nil }
    #elseif os(Windows)
      self.inputHandle = inputHandle
      self.outputHandle = outputHandle
      self.savedConsoleModes = savedConsoleModes
    #endif
    self.size = size
    self.sizeChanges = sizeChanges
    self.write = write
  }
}
