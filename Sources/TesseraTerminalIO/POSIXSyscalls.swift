import SystemPackage

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

/// POSIX syscall wrappers used by platform I/O.
package enum POSIXSyscalls {
  /// Performs one `write(2)` syscall.
  package static func write(
    fileDescriptor: CInt,
    bytes: ArraySlice<UInt8>
  ) throws -> Int {
    let written = bytes.withUnsafeBufferPointer { buffer in
      guard let baseAddress = buffer.baseAddress else {
        return 0
      }

      #if os(macOS)
        return Darwin.write(fileDescriptor, baseAddress, bytes.count)
      #elseif os(Linux)
        return Glibc.write(fileDescriptor, baseAddress, bytes.count)
      #endif
    }

    if written < 0 {
      if errno == EINTR {
        throw PlatformIOError.writeInterrupted
      }

      throw PlatformIOError.writeFailed(errno: Errno(rawValue: errno))
    }

    return written
  }
}
