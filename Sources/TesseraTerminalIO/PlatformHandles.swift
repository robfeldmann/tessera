#if os(macOS) || os(Linux)
  /// POSIX terminal handles for standard input and output.
  package struct PlatformHandles: ~Copyable {
    package let stdin: FileDescriptor
    package let stdout: FileDescriptor

    package init(stdin: consuming FileDescriptor, stdout: consuming FileDescriptor) {
      self.stdin = stdin
      self.stdout = stdout
    }

    /// Creates handles for this process's standard terminal file descriptors.
    package static func standard() throws -> Self {
      Self(
        stdin: FileDescriptor(rawValue: STDIN_FILENO),
        stdout: FileDescriptor(rawValue: STDOUT_FILENO)
      )
    }
  }

  package struct PlatformCleanupState: Sendable {
    package static let unavailable = Self(
      inputFileDescriptor: -1,
      outputFileDescriptor: -1
    ) { nil }

    private let inputFileDescriptor: CInt
    private let outputFileDescriptor: CInt
    private let savedTermios: @Sendable () async -> termios?

    package init(
      inputFileDescriptor: CInt,
      outputFileDescriptor: CInt,
      savedTermios: @escaping @Sendable () async -> termios?
    ) {
      self.inputFileDescriptor = inputFileDescriptor
      self.outputFileDescriptor = outputFileDescriptor
      self.savedTermios = savedTermios
    }

    package func install(teardownBytes: [UInt8]) async {
      CleanupRegistry.install(
        inputFileDescriptor: inputFileDescriptor,
        outputFileDescriptor: outputFileDescriptor,
        teardownBytes: teardownBytes,
        savedTermios: await savedTermios()
      )
    }
  }
#elseif os(Windows)
  /// Windows terminal handles for standard input and output consoles.
  package struct PlatformHandles: ~Copyable {
    package let inputHandle: UInt
    package let outputHandle: UInt

    package init(inputHandle: UInt, outputHandle: UInt) {
      self.inputHandle = inputHandle
      self.outputHandle = outputHandle
    }

    /// Creates handles for this process's standard terminal console handles.
    package static func standard() throws -> Self {
      let system = WindowsConsoleSystem.current
      guard let inputHandle = system.standardInputHandle(),
        let outputHandle = system.standardOutputHandle()
      else {
        throw PlatformIOError.unsupportedTerminalEnvironment
      }

      guard system.getConsoleMode(inputHandle) != nil,
        system.getConsoleMode(outputHandle) != nil
      else {
        throw PlatformIOError.unsupportedTerminalEnvironment
      }

      return Self(inputHandle: inputHandle, outputHandle: outputHandle)
    }
  }

  package struct PlatformCleanupState: Sendable {
    package static let unavailable = Self(
      inputHandle: 0,
      outputHandle: 0
    ) { nil }

    private let inputHandle: UInt
    private let outputHandle: UInt
    private let savedConsoleModes: @Sendable () async -> WindowsConsoleMode.SavedModes?

    package init(
      inputHandle: UInt,
      outputHandle: UInt,
      savedConsoleModes: @escaping @Sendable () async -> WindowsConsoleMode.SavedModes?
    ) {
      self.inputHandle = inputHandle
      self.outputHandle = outputHandle
      self.savedConsoleModes = savedConsoleModes
    }

    package func install(teardownBytes: [UInt8]) async {
      guard let modes = await savedConsoleModes() else {
        return
      }

      CleanupRegistry.install(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        teardownBytes: teardownBytes,
        savedInputMode: modes.input,
        savedOutputMode: modes.output
      )
    }
  }
#else
  /// Unsupported-platform placeholder handles.
  package struct PlatformHandles: ~Copyable {
    package static func standard() throws -> Self {
      throw PlatformIOError.unsupportedPlatform
    }
  }

  package struct PlatformCleanupState: Sendable {
    package static let unavailable = Self()

    package func install(teardownBytes: [UInt8]) async {}
  }
#endif
