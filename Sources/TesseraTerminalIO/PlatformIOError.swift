import Foundation
import SystemPackage

/// Errors thrown by platform terminal I/O operations.
public enum PlatformIOError: Error, Equatable, Sendable {
  /// A Windows console mode syscall failed.
  case consoleModeFailed(operation: WindowsConsoleModeOperation, errorCode: UInt32)

  /// Terminal input closed before an event was available.
  case inputClosed

  /// Raw mode could not be enabled or restored.
  case rawModeFailed(errno: Errno)

  /// The terminal size could not be read or decoded.
  case terminalSizeUnavailable(errno: Errno)

  /// The current platform is not supported by the terminal I/O implementation.
  case unsupportedPlatform

  /// The current terminal environment is not a console that Tessera can control.
  case unsupportedTerminalEnvironment

  /// A stdout write failed.
  case writeFailed(errno: Errno)

  /// A stdout write was interrupted before writing bytes.
  case writeInterrupted

  /// A non-blocking stdout write would block.
  case writeWouldBlock
}

extension PlatformIOError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .consoleModeFailed(let operation, let errorCode):
      return "Tessera could not \(operation) (Windows error \(errorCode)). "
        + "Tessera requires a VT-capable Windows console; use Windows Terminal or "
        + "Windows 10 version 1809 or newer."

    case .unsupportedTerminalEnvironment:
      return "Tessera requires a console terminal; PowerShell ISE, redirected "
        + "input/output, Cygwin, and MSYS2 terminals are not supported. Use "
        + "Windows Terminal or PowerShell in a normal console."

    case .inputClosed,
      .rawModeFailed,
      .terminalSizeUnavailable,
      .unsupportedPlatform,
      .writeFailed,
      .writeInterrupted,
      .writeWouldBlock:
      return nil
    }
  }
}
