#if os(macOS) || os(Linux)
  /// Async byte stream backed by non-blocking POSIX input.
  package enum POSIXInputLoop {
    // swiftlint:disable cyclomatic_complexity
    // POSIX polling handles several terminal events explicitly.
    private actor InputSource {
      private let cancelReadDescriptor: CInt
      nonisolated private let cancelWriteDescriptor: CInt
      private let fileDescriptor: CInt
      private let originalFlags: CInt
      nonisolated private let system: POSIXSystem
      private var buffer = [UInt8](repeating: 0, count: 256)
      private var isClosed = false

      init(
        fileDescriptor: CInt,
        cancelReadDescriptor: CInt,
        cancelWriteDescriptor: CInt,
        system: POSIXSystem
      ) {
        self.cancelReadDescriptor = cancelReadDescriptor
        self.cancelWriteDescriptor = cancelWriteDescriptor
        self.fileDescriptor = fileDescriptor
        self.originalFlags = system.fcntlGet(fileDescriptor, F_GETFL)
        self.system = system
        if originalFlags != -1 {
          _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags | O_NONBLOCK)
        }
      }

      // Actor deinitializers are misclassified as other methods by SwiftLint.
      // swiftlint:disable:next type_contents_order
      deinit {
        guard !isClosed else {
          return
        }
        _ = system.close(cancelReadDescriptor)
        _ = system.close(cancelWriteDescriptor)
        if originalFlags != -1 {
          _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags)
        }
      }

      func cancel() {
        close()
      }

      nonisolated func signalCancellation() {
        var byte: UInt8 = 0
        _ = withUnsafeBytes(of: &byte) { buffer in
          system.write(cancelWriteDescriptor, buffer.baseAddress, 1)
        }
      }

      // `nil` is the AsyncStream unfolding sentinel; an empty chunk is a timeout event.
      // swiftlint:disable:next discouraged_optional_collection
      func next(pollTimeoutMilliseconds: CInt) -> [UInt8]? {
        while !isClosed {
          if Task.isCancelled {
            close()
            return nil
          }

          var descriptors = [
            pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0),
            pollfd(fd: cancelReadDescriptor, events: Int16(POLLIN), revents: 0),
          ]
          let result = descriptors.withUnsafeMutableBufferPointer { pointer in
            system.poll(
              pointer.baseAddress, nfds_t(pointer.count), pollTimeoutMilliseconds)
          }

          if result < 0 {
            if errno == EINTR {
              continue
            }
            close()
            return nil
          }
          guard result > 0 else {
            return []
          }
          if POSIXInputLoop.hasAnyEvent(
            descriptors[1].revents,
            POLLIN,
            POLLHUP,
            POLLERR,
            POLLNVAL
          ) {
            close()
            return nil
          }
          if POSIXInputLoop.hasAnyEvent(
            descriptors[0].revents,
            POLLHUP,
            POLLERR,
            POLLNVAL
          ) {
            close()
            return nil
          }
          guard POSIXInputLoop.hasAnyEvent(descriptors[0].revents, POLLIN) else {
            continue
          }

          let readCount = buffer.withUnsafeMutableBufferPointer { pointer in
            system.read(fileDescriptor, pointer.baseAddress, pointer.count)
          }
          if readCount > 0 {
            return Array(buffer[..<readCount])
          }
          if readCount == 0 {
            close()
            return nil
          }
          if errno == EINTR || errno == EAGAIN {
            continue
          }
          close()
          return nil
        }
        return nil
      }

      private func close() {
        guard !isClosed else {
          return
        }
        isClosed = true
        _ = system.close(cancelReadDescriptor)
        _ = system.close(cancelWriteDescriptor)
        if originalFlags != -1 {
          _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags)
        }
      }
    }
    // swiftlint:enable cyclomatic_complexity

    /// Creates an input byte-chunk stream for `fileDescriptor`.
    ///
    /// Empty chunks represent input-idle poll timeouts.
    package static func bytes(
      fileDescriptor: CInt,
      pollTimeoutMilliseconds: CInt = 25
    ) -> AsyncStream<[UInt8]> {
      let system = POSIXSystem.current
      var cancelPipe: [CInt] = [-1, -1]
      guard system.pipe(&cancelPipe) == 0 else {
        return AsyncStream { $0.finish() }
      }

      let source = InputSource(
        fileDescriptor: fileDescriptor,
        cancelReadDescriptor: cancelPipe[0],
        cancelWriteDescriptor: cancelPipe[1],
        system: system
      )
      return AsyncStream(
        unfolding: {
          await source.next(pollTimeoutMilliseconds: pollTimeoutMilliseconds)
        },
        onCancel: {
          source.signalCancellation()
          _ = Task {
            await source.cancel()
          }
        }
      )
    }

    private static func hasAnyEvent(_ revents: Int16, _ events: CInt...) -> Bool {
      let mask = events.reduce(Int16(0)) { partialResult, event in
        partialResult | Int16(event)
      }

      return revents & mask != 0
    }
  }
#endif
