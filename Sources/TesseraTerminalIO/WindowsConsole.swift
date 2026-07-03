#if os(Windows)

  @_exported import WinSDK
  import TesseraTerminalCore

  /// Input records relevant to Tessera's shared Windows console input loop.
  package enum WindowsInputRecord: Equatable, Sendable {
    case key
    case other
    case resize(TerminalSize)

    package var isKey: Bool {
      if case .key = self {
        return true
      }
      return false
    }
  }

  /// Injectable Windows console syscall surface.
  package struct WindowsConsoleSystem: Sendable {
    @TaskLocal package static var override: Self?

    package static var current: Self {
      override ?? live
    }

    package static let live = Self(
      standardInputHandle: { windowsStandardHandle(STD_INPUT_HANDLE) },
      standardOutputHandle: { windowsStandardHandle(STD_OUTPUT_HANDLE) },
      getConsoleMode: { rawHandle in
        var mode: DWORD = 0
        guard GetConsoleMode(windowsHandlePointer(from: rawHandle), &mode) else {
          return nil
        }
        return UInt32(mode)
      },
      setConsoleMode: { rawHandle, mode in
        SetConsoleMode(windowsHandlePointer(from: rawHandle), DWORD(mode))
      },
      terminalSize: windowsTerminalSize,
      waitForSingleObject: { rawHandle, timeoutMilliseconds in
        UInt32(WaitForSingleObject(windowsHandlePointer(from: rawHandle), timeoutMilliseconds))
      },
      peekConsoleInput: windowsPeekConsoleInput,
      readConsoleInput: windowsReadConsoleInput,
      readFile: windowsReadFile,
      writeFile: windowsWriteFile
    ) { UInt32(GetLastError()) }

    package var standardInputHandle: @Sendable () -> UInt?
    package var standardOutputHandle: @Sendable () -> UInt?
    package var getConsoleMode: @Sendable (UInt) -> UInt32?
    package var setConsoleMode: @Sendable (UInt, UInt32) -> Bool
    package var terminalSize: @Sendable (UInt) -> TerminalSize?
    package var waitForSingleObject: @Sendable (UInt, UInt32) -> UInt32
    package var peekConsoleInput: @Sendable (UInt, UInt32) -> [WindowsInputRecord]?
    package var readConsoleInput: @Sendable (UInt, UInt32) -> [WindowsInputRecord]?
    package var readFile: @Sendable (UInt, UnsafeMutableRawPointer?, UInt32) -> Int?
    package var writeFile: @Sendable (UInt, UnsafeRawPointer?, UInt32) -> Int?
    package var lastErrorCode: @Sendable () -> UInt32

    package init(
      standardInputHandle: @escaping @Sendable () -> UInt?,
      standardOutputHandle: @escaping @Sendable () -> UInt?,
      getConsoleMode: @escaping @Sendable (UInt) -> UInt32?,
      setConsoleMode: @escaping @Sendable (UInt, UInt32) -> Bool,
      terminalSize: @escaping @Sendable (UInt) -> TerminalSize?,
      waitForSingleObject: @escaping @Sendable (UInt, UInt32) -> UInt32,
      peekConsoleInput: @escaping @Sendable (UInt, UInt32) -> [WindowsInputRecord]?,
      readConsoleInput: @escaping @Sendable (UInt, UInt32) -> [WindowsInputRecord]?,
      readFile: @escaping @Sendable (UInt, UnsafeMutableRawPointer?, UInt32) -> Int?,
      writeFile: @escaping @Sendable (UInt, UnsafeRawPointer?, UInt32) -> Int?,
      lastErrorCode: @escaping @Sendable () -> UInt32
    ) {
      self.standardInputHandle = standardInputHandle
      self.standardOutputHandle = standardOutputHandle
      self.getConsoleMode = getConsoleMode
      self.setConsoleMode = setConsoleMode
      self.terminalSize = terminalSize
      self.waitForSingleObject = waitForSingleObject
      self.peekConsoleInput = peekConsoleInput
      self.readConsoleInput = readConsoleInput
      self.readFile = readFile
      self.writeFile = writeFile
      self.lastErrorCode = lastErrorCode
    }
  }

  package enum WindowsWaitStatus {
    package static let object = UInt32(WAIT_OBJECT_0)
    package static let timeout = UInt32(WAIT_TIMEOUT)
    package static let failed = UInt32(WAIT_FAILED)
  }

  package func windowsHandlePointer(from rawHandle: UInt) -> HANDLE {
    HANDLE(bitPattern: rawHandle)!
  }

  private func windowsStandardHandle(_ standardHandle: DWORD) -> UInt? {
    let handle = GetStdHandle(standardHandle)
    let rawHandle = unsafeBitCast(handle, to: UInt.self)
    guard rawHandle != 0, rawHandle != UInt.max else {
      return nil
    }
    return rawHandle
  }

  private func windowsTerminalSize(rawHandle: UInt) -> TerminalSize? {
    var info = CONSOLE_SCREEN_BUFFER_INFO()
    guard GetConsoleScreenBufferInfo(windowsHandlePointer(from: rawHandle), &info) else {
      return nil
    }

    let columns = Int(info.srWindow.Right - info.srWindow.Left + 1)
    let rows = Int(info.srWindow.Bottom - info.srWindow.Top + 1)
    guard columns > 0, rows > 0 else {
      return nil
    }

    return TerminalSize(columns: columns, rows: rows)
  }

  private func windowsPeekConsoleInput(
    rawHandle: UInt,
    maxRecordCount: UInt32
  ) -> [WindowsInputRecord]? {
    var records = [INPUT_RECORD](repeating: INPUT_RECORD(), count: Int(maxRecordCount))
    var readCount: DWORD = 0
    let succeeded = records.withUnsafeMutableBufferPointer { buffer in
      PeekConsoleInputW(
        windowsHandlePointer(from: rawHandle),
        buffer.baseAddress,
        DWORD(buffer.count),
        &readCount
      )
    }
    guard succeeded else {
      return nil
    }

    return records.prefix(Int(readCount)).map(windowsInputRecord)
  }

  private func windowsReadConsoleInput(
    rawHandle: UInt,
    maxRecordCount: UInt32
  ) -> [WindowsInputRecord]? {
    var records = [INPUT_RECORD](repeating: INPUT_RECORD(), count: Int(maxRecordCount))
    var readCount: DWORD = 0
    let succeeded = records.withUnsafeMutableBufferPointer { buffer in
      ReadConsoleInputW(
        windowsHandlePointer(from: rawHandle),
        buffer.baseAddress,
        DWORD(buffer.count),
        &readCount
      )
    }
    guard succeeded else {
      return nil
    }

    return records.prefix(Int(readCount)).map(windowsInputRecord)
  }

  private func windowsReadFile(
    rawHandle: UInt,
    buffer: UnsafeMutableRawPointer?,
    count: UInt32
  ) -> Int? {
    var readCount: DWORD = 0
    guard ReadFile(windowsHandlePointer(from: rawHandle), buffer, DWORD(count), &readCount, nil)
    else {
      return nil
    }
    return Int(readCount)
  }

  private func windowsWriteFile(
    rawHandle: UInt,
    buffer: UnsafeRawPointer?,
    count: UInt32
  ) -> Int? {
    var writtenCount: DWORD = 0
    guard WriteFile(windowsHandlePointer(from: rawHandle), buffer, DWORD(count), &writtenCount, nil)
    else {
      return nil
    }
    return Int(writtenCount)
  }

  private func windowsInputRecord(_ record: INPUT_RECORD) -> WindowsInputRecord {
    switch record.EventType {
    case WORD(KEY_EVENT):
      return .key

    case WORD(WINDOW_BUFFER_SIZE_EVENT):
      let size = record.Event.WindowBufferSizeEvent.dwSize
      let columns = Int(size.X)
      let rows = Int(size.Y)
      guard columns > 0, rows > 0 else {
        return .other
      }
      return .resize(TerminalSize(columns: columns, rows: rows))

    default:
      return .other
    }
  }

#endif
