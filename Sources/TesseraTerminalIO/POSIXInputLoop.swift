#if os(macOS) || os(Linux)
  /// Async byte stream backed by non-blocking POSIX input.
  package enum POSIXInputLoop {
    /// Creates an input byte-chunk stream for `fileDescriptor`.
    ///
    /// Empty chunks represent input-idle poll timeouts.
    package static func bytes(
      fileDescriptor: CInt,
      pollTimeoutMilliseconds: CInt = 25
    ) -> AsyncStream<[UInt8]> {
      AsyncStream { continuation in
        let system = POSIXSystem.current
        var cancelPipe: [CInt] = [-1, -1]
        guard system.pipe(&cancelPipe) == 0 else {
          continuation.finish()
          return
        }

        let cancelReadDescriptor = cancelPipe[0]
        let cancelWriteDescriptor = cancelPipe[1]
        let originalFlags = system.fcntlGet(fileDescriptor, F_GETFL)
        if originalFlags != -1 {
          _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags | O_NONBLOCK)
        }

        let task = Task { @concurrent in
          inputLoop(
            fileDescriptor: fileDescriptor,
            cancelReadDescriptor: cancelReadDescriptor,
            continuation: continuation,
            pollTimeoutMilliseconds: pollTimeoutMilliseconds,
            system: system
          )
        }

        continuation.onTermination = { _ in
          task.cancel()
          var byte: UInt8 = 0
          _ = withUnsafeBytes(of: &byte) { buffer in
            system.write(cancelWriteDescriptor, buffer.baseAddress, 1)
          }
          _ = system.close(cancelReadDescriptor)
          _ = system.close(cancelWriteDescriptor)
          if originalFlags != -1 {
            _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags)
          }
        }
      }
    }

    // swiftlint:disable cyclomatic_complexity
    // POSIX polling handles several terminal events explicitly.
    private static func inputLoop(
      fileDescriptor: CInt,
      cancelReadDescriptor: CInt,
      continuation: AsyncStream<[UInt8]>.Continuation,
      pollTimeoutMilliseconds: CInt,
      system: POSIXSystem
    ) {
      var buffer = [UInt8](repeating: 0, count: 256)

      while !Task.isCancelled {
        var descriptors = [
          pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0),
          pollfd(fd: cancelReadDescriptor, events: Int16(POLLIN), revents: 0),
        ]

        let result = descriptors.withUnsafeMutableBufferPointer { pointer in
          system.poll(pointer.baseAddress, nfds_t(pointer.count), pollTimeoutMilliseconds)
        }

        if result < 0 {
          if errno == EINTR {
            continue
          }
          continuation.finish()
          return
        }

        guard result > 0 else {
          continuation.yield([])
          continue
        }

        if hasAnyEvent(descriptors[1].revents, POLLIN, POLLHUP, POLLERR, POLLNVAL) {
          continuation.finish()
          return
        }

        if hasAnyEvent(descriptors[0].revents, POLLHUP, POLLERR, POLLNVAL) {
          continuation.finish()
          return
        }

        guard hasAnyEvent(descriptors[0].revents, POLLIN) else {
          continue
        }

        let readCount = buffer.withUnsafeMutableBufferPointer { pointer in
          system.read(fileDescriptor, pointer.baseAddress, pointer.count)
        }

        if readCount > 0 {
          continuation.yield(Array(buffer[..<readCount]))
        } else if readCount == 0 {
          continuation.finish()
          return
        } else if errno == EINTR || errno == EAGAIN {
          continue
        } else {
          continuation.finish()
          return
        }
      }

      continuation.finish()
    }
    // swiftlint:enable cyclomatic_complexity

    private static func hasAnyEvent(_ revents: Int16, _ events: CInt...) -> Bool {
      let mask = events.reduce(Int16(0)) { partialResult, event in
        partialResult | Int16(event)
      }

      return revents & mask != 0
    }
  }
#endif
