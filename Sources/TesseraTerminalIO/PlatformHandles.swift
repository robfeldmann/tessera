#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

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
    #if os(macOS) || os(Linux)
      Self(
        stdin: FileDescriptor(rawValue: STDIN_FILENO),
        stdout: FileDescriptor(rawValue: STDOUT_FILENO)
      )
    #else
      throw PlatformIOError.unsupportedPlatform
    #endif
  }
}
