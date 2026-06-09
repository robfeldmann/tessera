import SystemPackage
import TesseraTerminalCore

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

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
      let stdout = handles.stdout.rawValue
      let write: @Sendable (ArraySlice<UInt8>) throws -> Int = { bytes in
        try POSIXSyscalls.write(fileDescriptor: stdout, bytes: bytes)
      }

      return Self(
        bytes: readStdinBytes,
        enterAltScreen: {
          // DEC private mode 1049: enter alternate screen, `CSI ? 1049 h`.
          try writeAll(Array("\u{1B}[?1049h".utf8), to: stdout)
        },
        enterRawMode: { try await mode.enterRawMode() },
        exitAltScreen: {
          // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
          try writeAll(Array("\u{1B}[?1049l".utf8), to: stdout)
        },
        exitRawMode: { try await mode.exitRawMode() },
        size: readTerminalSize,
        write: write
      )
    #else
      return unsupported
    #endif
  }
}

#if os(macOS) || os(Linux)
  private actor LiveTerminalMode {
    private var originalTermios: termios?

    func enterRawMode() throws {
      if originalTermios != nil {
        return
      }

      var original = termios()
      guard tcgetattr(STDIN_FILENO, &original) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: Errno(rawValue: errno))
      }

      var raw = original
      raw.c_lflag &= ~tcflag_t(ICANON | ECHO)

      guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: Errno(rawValue: errno))
      }

      originalTermios = original
    }

    func exitRawMode() throws {
      guard var originalTermios else {
        return
      }

      guard tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: Errno(rawValue: errno))
      }

      self.originalTermios = nil
    }
  }

  private func readStdinBytes() -> AsyncStream<UInt8> {
    AsyncStream { continuation in
      // This bridges blocking `read(2)` into AsyncStream. Start the task concurrently so
      // the blocking syscall cannot inherit and pin a caller's actor (for example, the
      // main actor). Phase 2 replaces this with poll/nonblocking input handling.
      let task = Task { @concurrent in
        var byte: UInt8 = 0

        while !Task.isCancelled {
          let readCount = withUnsafeMutableBytes(of: &byte) { buffer in
            guard let baseAddress = buffer.baseAddress else {
              return 0
            }

            return systemRead(STDIN_FILENO, baseAddress, 1)
          }

          if readCount == 1 {
            continuation.yield(byte)
          } else if readCount == 0 {
            continuation.finish()
            break
          } else if errno == EINTR {
            continue
          } else {
            continuation.finish()
            break
          }
        }
      }

      continuation.onTermination = { _ in task.cancel() }
    }
  }

  private func readTerminalSize() throws -> TerminalSize {
    var windowSize = winsize()
    let result = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &windowSize)

    guard result != -1, windowSize.ws_col > 0, windowSize.ws_row > 0 else {
      throw PlatformIOError.terminalSizeUnavailable(errno: Errno(rawValue: errno))
    }

    return TerminalSize(
      columns: Int(windowSize.ws_col),
      rows: Int(windowSize.ws_row)
    )
  }

  private func writeAll(_ bytes: [UInt8], to fileDescriptor: CInt) throws {
    var offset = 0

    while offset < bytes.count {
      do {
        let written = try POSIXSyscalls.write(
          fileDescriptor: fileDescriptor,
          bytes: bytes[offset...]
        )

        guard written > 0 else {
          throw PlatformIOError.writeFailed(errno: Errno(rawValue: 0))
        }

        offset += written
      } catch PlatformIOError.writeInterrupted {
        continue
      }
    }
  }

  private func systemRead(
    _ fileDescriptor: Int32,
    _ buffer: UnsafeMutableRawPointer,
    _ count: Int
  ) -> Int {
    #if os(macOS)
      Darwin.read(fileDescriptor, buffer, count)
    #elseif os(Linux)
      Glibc.read(fileDescriptor, buffer, count)
    #endif
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
