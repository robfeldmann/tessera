#if os(Windows)

  import TesseraTerminalCore

  @testable import TesseraTerminalIO

  extension WindowsConsoleSystem {
    static func terminalSizeStub(
      _ terminalSize: @escaping @Sendable (UInt) -> TerminalSize?
    ) -> Self {
      stub(terminalSize: terminalSize)
    }

    static func stub(
      standardInputHandle: @escaping @Sendable () -> UInt? = { 0x11 },
      standardOutputHandle: @escaping @Sendable () -> UInt? = { 0x22 },
      getConsoleMode: @escaping @Sendable (UInt) -> UInt32? = { _ in 0 },
      setConsoleMode: @escaping @Sendable (UInt, UInt32) -> Bool = { _, _ in true },
      terminalSize: @escaping @Sendable (UInt) -> TerminalSize? = { _ in nil },
      waitForSingleObject: @escaping @Sendable (UInt, UInt32) -> UInt32 = { _, _ in
        WindowsWaitStatus.failed
      },
      peekConsoleInput:
        @escaping @Sendable (
          UInt, UInt32
        ) throws -> [WindowsInputRecord] = { _, _ in
          throw PlatformIOError.consoleOperationFailed(
            operation: .peekConsoleInput,
            errorCode: 0
          )
        },
      readConsoleInput:
        @escaping @Sendable (
          UInt, UInt32
        ) throws -> [WindowsInputRecord] = { _, _ in
          throw PlatformIOError.consoleOperationFailed(
            operation: .readConsoleInput,
            errorCode: 0
          )
        },
      readFile:
        @escaping @Sendable (
          UInt, UnsafeMutableRawPointer?, UInt32
        ) -> Int? = { _, _, _ in nil },
      writeFile:
        @escaping @Sendable (
          UInt, UnsafeRawPointer?, UInt32
        ) -> Int? = { _, _, _ in nil },
      lastErrorCode: @escaping @Sendable () -> UInt32 = { 0 }
    ) -> Self {
      Self(
        standardInputHandle: standardInputHandle,
        standardOutputHandle: standardOutputHandle,
        getConsoleMode: getConsoleMode,
        setConsoleMode: setConsoleMode,
        terminalSize: terminalSize,
        waitForSingleObject: waitForSingleObject,
        peekConsoleInput: peekConsoleInput,
        readConsoleInput: readConsoleInput,
        readFile: readFile,
        writeFile: writeFile,
        lastErrorCode: lastErrorCode
      )
    }
  }

#endif
