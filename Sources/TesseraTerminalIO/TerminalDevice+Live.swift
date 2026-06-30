import SystemPackage
import TesseraTerminalCore

extension TerminalDevice {
  package static var live: Self {
    do {
      return try liveFromStandardHandles()
    } catch {
      return failing(error)
    }
  }

  private static func liveFromStandardHandles() throws -> Self {
    #if os(macOS) || os(Linux) || os(Windows)
      return live(handles: try PlatformHandles.standard())
    #else
      throw PlatformIOError.unsupportedPlatform
    #endif
  }

  private static var unsupported: Self {
    failing(PlatformIOError.unsupportedPlatform)
  }

  private static func failing(_ error: any Error) -> Self {
    Self(
      bytes: { AsyncStream { $0.finish() } },
      enterAltScreen: { throw error },
      enterRawMode: { throw error },
      exitAltScreen: { throw error },
      exitRawMode: { throw error },
      size: { throw error },
      write: { _ in throw error }
    )
  }

  package static func live(handles: consuming PlatformHandles) -> Self {
    #if os(macOS) || os(Linux)
      let mode = LiveTerminalMode()
      let stdin = handles.stdin.rawValue
      let stdout = handles.stdout.rawValue
      let size: @Sendable () throws -> TerminalSize = {
        try readTerminalSize(fileDescriptor: stdout)
      }
      let write: @Sendable (ArraySlice<UInt8>) throws -> Int = { bytes in
        try writeOnce(bytes, to: stdout)
      }

      return Self(
        bytes: { POSIXInputLoop.bytes(fileDescriptor: stdin) },
        cleanupState: PlatformCleanupState(
          inputFileDescriptor: stdin,
          outputFileDescriptor: stdout,
          savedTermios: { await mode.savedTermios() }
        ),
        enterAltScreen: {
          // DEC private mode 1049: enter alternate screen, `CSI ? 1049 h`.
          try writeAll(Array("\u{1B}[?1049h".utf8), to: stdout)
        },
        enterRawMode: { try await mode.enterRawMode(fileDescriptor: stdin) },
        exitAltScreen: {
          // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
          try writeAll(Array("\u{1B}[?1049l".utf8), to: stdout)
        },
        exitRawMode: { try await mode.exitRawMode(fileDescriptor: stdin) },
        size: size,
        sizeChanges: { TerminalResizeRegistry.sizeChanges { try size() } },
        write: write
      )
    #elseif os(Windows)
      let system = WindowsConsoleSystem.current
      let mode = WindowsConsoleMode(
        inputHandle: handles.inputHandle,
        outputHandle: handles.outputHandle,
        system: system
      )
      let inputLoop = WindowsInputLoop(inputHandle: handles.inputHandle, system: system)
      let outputHandle = handles.outputHandle

      return Self(
        bytes: { inputLoop.bytes() },
        cleanupState: PlatformCleanupState(
          inputHandle: handles.inputHandle,
          outputHandle: outputHandle,
          savedConsoleModes: { await mode.savedModes() }
        ),
        enterAltScreen: {
          // DEC private mode 1049: enter alternate screen, `CSI ? 1049 h`.
          try writeAll(Array("\u{1B}[?1049h".utf8), to: outputHandle, system: system)
        },
        enterRawMode: { try await mode.enterRawMode() },
        exitAltScreen: {
          // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
          try writeAll(Array("\u{1B}[?1049l".utf8), to: outputHandle, system: system)
        },
        exitRawMode: { try await mode.exitRawMode() },
        size: { try readTerminalSize(outputHandle: outputHandle, system: system) },
        sizeChanges: { inputLoop.sizeChanges() },
        write: { try writeOnce($0, to: outputHandle, system: system) }
      )
    #else
      return unsupported
    #endif
  }
}

#if os(macOS) || os(Linux)
  private actor LiveTerminalMode {
    private var originalTermios: termios?

    func enterRawMode(fileDescriptor: CInt) throws {
      if originalTermios != nil {
        return
      }

      var original = termios()
      guard tcgetattr(fileDescriptor, &original) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: Errno(rawValue: errno))
      }

      var raw = original
      raw.c_lflag &= ~tcflag_t(ICANON | ECHO)

      guard tcsetattr(fileDescriptor, TCSANOW, &raw) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: Errno(rawValue: errno))
      }

      originalTermios = original
    }

    func exitRawMode(fileDescriptor: CInt) throws {
      guard var originalTermios else {
        return
      }

      guard tcsetattr(fileDescriptor, TCSANOW, &originalTermios) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: Errno(rawValue: errno))
      }

      self.originalTermios = nil
    }

    func savedTermios() -> termios? {
      originalTermios
    }
  }

  private func readTerminalSize(fileDescriptor: CInt) throws -> TerminalSize {
    var windowSize = winsize()
    let result = ioctl(fileDescriptor, UInt(TIOCGWINSZ), &windowSize)

    guard result != -1, windowSize.ws_col > 0, windowSize.ws_row > 0 else {
      throw PlatformIOError.terminalSizeUnavailable(errno: Errno(rawValue: errno))
    }

    return TerminalSize(
      columns: Int(windowSize.ws_col),
      rows: Int(windowSize.ws_row)
    )
  }

  private func writeOnce(
    _ bytes: ArraySlice<UInt8>,
    to fileDescriptor: CInt
  ) throws -> Int {
    while true {
      do {
        return try POSIXSyscalls.write(fileDescriptor: fileDescriptor, bytes: bytes)
      } catch PlatformIOError.writeWouldBlock {
        try POSIXSyscalls.waitUntilWritable(fileDescriptor: fileDescriptor)
      } catch PlatformIOError.writeInterrupted {
        continue
      }
    }
  }

  private func writeAll(_ bytes: [UInt8], to fileDescriptor: CInt) throws {
    var offset = 0

    while offset < bytes.count {
      do {
        let written = try writeOnce(bytes[offset...], to: fileDescriptor)

        guard written > 0 else {
          throw PlatformIOError.writeFailed(errno: Errno(rawValue: 0))
        }

        offset += written
      } catch PlatformIOError.writeInterrupted {
        continue
      }
    }
  }
#endif

#if os(Windows)
  private func readTerminalSize(
    outputHandle: UInt,
    system: WindowsConsoleSystem
  ) throws -> TerminalSize {
    guard let size = system.terminalSize(outputHandle) else {
      throw PlatformIOError.consoleOperationFailed(
        operation: .getConsoleScreenBufferInfo,
        errorCode: system.lastErrorCode()
      )
    }
    return size
  }

  private func writeOnce(
    _ bytes: ArraySlice<UInt8>,
    to outputHandle: UInt,
    system: WindowsConsoleSystem
  ) throws -> Int {
    guard bytes.isEmpty == false else {
      return 0
    }

    let count = min(bytes.count, Int(UInt32.max))
    guard
      let written = bytes.withUnsafeBufferPointer({ buffer in
        system.writeFile(outputHandle, buffer.baseAddress, UInt32(count))
      })
    else {
      throw PlatformIOError.consoleOperationFailed(
        operation: .writeFile,
        errorCode: system.lastErrorCode()
      )
    }

    return written
  }

  private func writeAll(
    _ bytes: [UInt8],
    to outputHandle: UInt,
    system: WindowsConsoleSystem
  ) throws {
    var offset = 0

    while offset < bytes.count {
      let written = try writeOnce(bytes[offset...], to: outputHandle, system: system)

      guard written > 0 else {
        throw PlatformIOError.writeFailed(errno: Errno(rawValue: 0))
      }

      offset += written
    }
  }

  extension TerminalDevice {
    package static func windowsConsoleMode(
      inputHandle: UInt,
      outputHandle: UInt,
      system: WindowsConsoleSystem = .current
    ) -> Self {
      let mode = WindowsConsoleMode(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        system: system
      )

      return Self(
        cleanupState: PlatformCleanupState(
          inputHandle: inputHandle,
          outputHandle: outputHandle,
          savedConsoleModes: { await mode.savedModes() }
        ),
        enterRawMode: { try await mode.enterRawMode() },
        exitRawMode: { try await mode.exitRawMode() },
        size: { throw PlatformIOError.unsupportedPlatform },
        write: { _ in throw PlatformIOError.unsupportedPlatform }
      )
    }
  }
#endif
