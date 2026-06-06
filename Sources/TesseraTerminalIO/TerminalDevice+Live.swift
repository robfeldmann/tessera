import Dependencies
import SystemPackage
import TesseraTerminalCore

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

extension TerminalDevice: DependencyKey {
  public static var liveValue: Self {
    #if os(macOS) || os(Linux)
      Self(
        size: readTerminalSize,
        write: writeToStdout
      )
    #else
      Self(
        size: { throw PlatformIOError.unsupportedPlatform },
        write: { _ in throw PlatformIOError.unsupportedPlatform }
      )
    #endif
  }
}

#if os(macOS) || os(Linux)
  private func readTerminalSize() throws -> TerminalSize {
    var windowSize = winsize()
    let result = ioctl(STDOUT_FILENO, TIOCGWINSZ, &windowSize)

    guard result != -1, windowSize.ws_col > 0, windowSize.ws_row > 0 else {
      throw PlatformIOError.terminalSizeUnavailable(errno: Errno(rawValue: errno))
    }

    return TerminalSize(
      columns: Int(windowSize.ws_col),
      rows: Int(windowSize.ws_row)
    )
  }

  private func writeToStdout(_ bytes: [UInt8]) throws {
    var offset = 0

    while offset < bytes.count {
      let written = bytes.withUnsafeBytes { buffer in
        guard let baseAddress = buffer.baseAddress else {
          return 0
        }

        return systemWrite(
          STDOUT_FILENO,
          baseAddress.advanced(by: offset),
          bytes.count - offset
        )
      }

      if written < 0 {
        if errno == EINTR {
          continue
        }

        throw PlatformIOError.writeFailed(errno: Errno(rawValue: errno))
      }

      guard written > 0 else {
        throw PlatformIOError.writeFailed(errno: Errno(rawValue: 0))
      }

      offset += written
    }
  }

  private func systemWrite(
    _ fileDescriptor: Int32,
    _ buffer: UnsafeRawPointer,
    _ count: Int
  ) -> Int {
    #if os(macOS)
      Darwin.write(fileDescriptor, buffer, count)
    #elseif os(Linux)
      Glibc.write(fileDescriptor, buffer, count)
    #endif
  }
#endif
