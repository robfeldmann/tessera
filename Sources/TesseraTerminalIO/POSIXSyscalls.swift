#if os(macOS) || os(Linux)

  import SystemPackage

  #if os(macOS)
    import Darwin
  #elseif os(Linux)
    import Glibc
  #endif

  /// POSIX syscall wrappers used by platform I/O.
  package enum POSIXSyscalls {
    package struct System: Sendable {
      package var poll: @Sendable (UnsafeMutablePointer<pollfd>?, nfds_t, CInt) -> CInt
      package var write: @Sendable (CInt, UnsafeRawPointer?, Int) -> Int

      package init(
        poll: @escaping @Sendable (UnsafeMutablePointer<pollfd>?, nfds_t, CInt) -> CInt,
        write: @escaping @Sendable (CInt, UnsafeRawPointer?, Int) -> Int
      ) {
        self.poll = poll
        self.write = write
      }
    }

    @TaskLocal package static var systemOverride: System?

    private static var currentSystem: System {
      systemOverride ?? liveSystem
    }

    package static let liveSystem = System(
      poll: { descriptors, count, timeout in
        #if os(macOS)
          Darwin.poll(descriptors, count, timeout)
        #elseif os(Linux)
          Glibc.poll(descriptors, count, timeout)
        #endif
      },
      write: { fileDescriptor, buffer, count in
        #if os(macOS)
          Darwin.write(fileDescriptor, buffer, count)
        #elseif os(Linux)
          Glibc.write(fileDescriptor, buffer, count)
        #endif
      }
    )

    /// Performs one `write(2)` syscall.
    package static func write(
      fileDescriptor: CInt,
      bytes: ArraySlice<UInt8>
    ) throws -> Int {
      guard bytes.isEmpty == false else {
        return 0
      }

      let system = currentSystem
      let written = bytes.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else {
          return 0
        }

        return system.write(fileDescriptor, baseAddress, bytes.count)
      }

      if written < 0 {
        if errno == EINTR {
          throw PlatformIOError.writeInterrupted
        }

        if errno == EAGAIN || errno == EWOULDBLOCK {
          throw PlatformIOError.writeWouldBlock
        }

        throw PlatformIOError.writeFailed(errno: Errno(rawValue: errno))
      }

      return written
    }

    /// Waits until `fileDescriptor` is writable.
    package static func waitUntilWritable(fileDescriptor: CInt) throws {
      while true {
        var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLOUT), revents: 0)
        let result = currentSystem.poll(&descriptor, 1, -1)

        if result > 0 {
          return
        }

        if result == 0 {
          continue
        }

        if errno == EINTR {
          throw PlatformIOError.writeInterrupted
        }

        throw PlatformIOError.writeFailed(errno: Errno(rawValue: errno))
      }
    }
  }

#endif
