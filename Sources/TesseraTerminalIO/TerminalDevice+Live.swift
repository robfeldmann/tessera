import SystemPackage
import TesseraTerminalCore

extension TerminalDevice {
  package static var live: Self {
    #if os(macOS) || os(Linux)
      return live(handles: PlatformHandles.standardUnchecked)
    #else
      return unsupported
    #endif
  }

  private static var unsupported: Self {
    Self(
      bytes: { AsyncStream { $0.finish() } },
      enterAltScreen: { throw PlatformIOError.unsupportedPlatform },
      enterRawMode: { throw PlatformIOError.unsupportedPlatform },
      exitAltScreen: { throw PlatformIOError.unsupportedPlatform },
      exitRawMode: { throw PlatformIOError.unsupportedPlatform },
      size: { throw PlatformIOError.unsupportedPlatform },
      write: { _ in throw PlatformIOError.unsupportedPlatform }
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
        inputFileDescriptor: stdin,
        outputFileDescriptor: stdout,
        size: size,
        sizeChanges: { TerminalResizeRegistry.sizeChanges { try size() } },
        write: write
      ).withSavedTermios { await mode.savedTermios() }
    #else
      return unsupported
    #endif
  }

  #if os(macOS) || os(Linux)
    private func withSavedTermios(
      _ savedTermios: @escaping @Sendable () async -> termios?
    ) -> Self {
      var copy = self
      copy.savedTermios = savedTermios
      return copy
    }
  #endif
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

#if os(macOS) || os(Linux)
  extension PlatformHandles {
    fileprivate static var standardUnchecked: Self {
      Self(
        stdin: FileDescriptor(rawValue: STDIN_FILENO),
        stdout: FileDescriptor(rawValue: STDOUT_FILENO)
      )
    }
  }
#endif

#if os(Windows)
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
        enterRawMode: { try await mode.enterRawMode() },
        exitRawMode: { try await mode.exitRawMode() },
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        savedConsoleModes: { await mode.savedModes() },
        size: { throw PlatformIOError.unsupportedPlatform },
        write: { _ in throw PlatformIOError.unsupportedPlatform }
      )
    }
  }
#endif
