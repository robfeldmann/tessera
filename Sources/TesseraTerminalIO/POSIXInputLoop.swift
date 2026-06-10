#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

#if os(macOS) || os(Linux)
  /// Async byte stream backed by non-blocking POSIX input.
  package enum POSIXInputLoop {
    /// Creates an input byte stream for `fileDescriptor`.
    package static func bytes(fileDescriptor: CInt) -> AsyncStream<UInt8> {
      AsyncStream { continuation in
        var cancelPipe: [CInt] = [-1, -1]
        guard pipe(&cancelPipe) == 0 else {
          continuation.finish()
          return
        }

        let cancelReadDescriptor = cancelPipe[0]
        let cancelWriteDescriptor = cancelPipe[1]
        let originalFlags = fcntl(fileDescriptor, F_GETFL)
        if originalFlags != -1 {
          _ = fcntl(fileDescriptor, F_SETFL, originalFlags | O_NONBLOCK)
        }

        let task = Task { @concurrent in
          inputLoop(
            fileDescriptor: fileDescriptor,
            cancelReadDescriptor: cancelReadDescriptor,
            continuation: continuation
          )
        }

        continuation.onTermination = { _ in
          task.cancel()
          var byte: UInt8 = 0
          _ = withUnsafeBytes(of: &byte) { buffer in
            systemWrite(cancelWriteDescriptor, buffer.baseAddress, 1)
          }
          _ = close(cancelReadDescriptor)
          _ = close(cancelWriteDescriptor)
          if originalFlags != -1 {
            _ = fcntl(fileDescriptor, F_SETFL, originalFlags)
          }
        }
      }
    }

    // swiftlint:disable cyclomatic_complexity
    // POSIX polling handles several terminal events explicitly.
    private static func inputLoop(
      fileDescriptor: CInt,
      cancelReadDescriptor: CInt,
      continuation: AsyncStream<UInt8>.Continuation
    ) {
      var buffer = [UInt8](repeating: 0, count: 256)

      while !Task.isCancelled {
        var descriptors = [
          pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0),
          pollfd(fd: cancelReadDescriptor, events: Int16(POLLIN), revents: 0),
        ]

        let result = descriptors.withUnsafeMutableBufferPointer { pointer in
          systemPoll(pointer.baseAddress, nfds_t(pointer.count), 100)
        }

        if result < 0 {
          if errno == EINTR {
            continue
          }
          continuation.finish()
          return
        }

        guard result > 0 else {
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
          systemRead(fileDescriptor, pointer.baseAddress, pointer.count)
        }

        if readCount > 0 {
          for index in 0..<readCount {
            continuation.yield(buffer[index])
          }
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

    private static func systemPoll(
      _ descriptors: UnsafeMutablePointer<pollfd>?,
      _ count: nfds_t,
      _ timeout: CInt
    ) -> CInt {
      #if os(macOS)
        Darwin.poll(descriptors, count, timeout)
      #elseif os(Linux)
        Glibc.poll(descriptors, count, timeout)
      #endif
    }

    private static func systemRead(
      _ fileDescriptor: CInt,
      _ buffer: UnsafeMutablePointer<UInt8>?,
      _ count: Int
    ) -> Int {
      #if os(macOS)
        Darwin.read(fileDescriptor, buffer, count)
      #elseif os(Linux)
        Glibc.read(fileDescriptor, buffer, count)
      #endif
    }

    private static func systemWrite(
      _ fileDescriptor: CInt,
      _ buffer: UnsafeRawPointer?,
      _ count: Int
    ) -> Int {
      #if os(macOS)
        Darwin.write(fileDescriptor, buffer, count)
      #elseif os(Linux)
        Glibc.write(fileDescriptor, buffer, count)
      #endif
    }
  }
#endif
