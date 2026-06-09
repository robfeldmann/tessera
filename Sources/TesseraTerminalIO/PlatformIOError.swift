import SystemPackage

/// Errors thrown by platform terminal I/O operations.
public enum PlatformIOError: Error, Equatable, Sendable {
  /// Raw mode could not be enabled or restored.
  case rawModeFailed(errno: Errno)

  /// The terminal size could not be read or decoded.
  case terminalSizeUnavailable(errno: Errno)

  /// The current platform is not supported by the terminal I/O implementation.
  case unsupportedPlatform

  /// A stdout write failed.
  case writeFailed(errno: Errno)

  /// A stdout write was interrupted before writing bytes.
  case writeInterrupted
}
