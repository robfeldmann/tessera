#if os(macOS) || os(Linux)

  import SystemPackage

  /// POSIX syscall wrappers used by platform I/O.
  package enum POSIXSyscalls {
    /// How long one `waitUntilWritable` poll blocks, in milliseconds.
    ///
    /// This bounds how long a cancelled task keeps waiting on a stalled terminal.
    package static let writableWaitSliceMilliseconds: CInt = 50

    /// Performs one `write(2)` syscall.
    package static func write(
      fileDescriptor: CInt,
      bytes: ArraySlice<UInt8>
    ) throws -> Int {
      guard bytes.isEmpty == false else {
        return 0
      }

      let system = POSIXSystem.current
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
    ///
    /// The wait runs in slices of `writableWaitSliceMilliseconds`, and the task's
    /// cancellation is checked after each slice that ends without the descriptor
    /// becoming writable. The caller keeps whatever it has not written yet.
    ///
    /// - Throws: `CancellationError` when the current task is cancelled while the
    ///   descriptor stays unwritable.
    package static func waitUntilWritable(fileDescriptor: CInt) throws {
      while true {
        var descriptor = pollfd(fd: fileDescriptor, events: Int16(POLLOUT), revents: 0)
        let result = POSIXSystem.current.poll(
          &descriptor, 1, writableWaitSliceMilliseconds)

        if result > 0 {
          return
        }

        if result == 0 {
          try Task.checkCancellation()
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
