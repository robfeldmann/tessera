#if os(macOS) || os(Linux)
  import Foundation
  import Synchronization

  /// Async byte stream backed by non-blocking POSIX input.
  package enum POSIXInputLoop {
    /// The reader thread behind one input stream, and the handle that stops it.
    ///
    /// Each source owns a private cancellation pipe. Writing a byte to it wakes the
    /// reader out of `poll`, so cancelling never waits for a poll timeout.
    ///
    /// The pipe is closed only in `deinit`. The reader thread and the stream's
    /// termination handler both hold the source, so neither can touch a descriptor that
    /// was already closed, and possibly reused for an unrelated file. That lifetime
    /// replaces a lock around the descriptor. The stop flag is an atomic instead of
    /// actor state because the reader is a blocking thread that cannot `await`, and
    /// cancelling must never queue behind it.
    package final class InputSource: Sendable {
      private let cancelReadDescriptor: CInt
      private let cancelWriteDescriptor: CInt
      private let fileDescriptor: CInt
      private let isStopRequested = Atomic<Bool>(false)
      private let originalFlags: CInt
      private let pollTimeoutMilliseconds: CInt
      private let system: POSIXSystem

      private init(
        fileDescriptor: CInt,
        cancelReadDescriptor: CInt,
        cancelWriteDescriptor: CInt,
        pollTimeoutMilliseconds: CInt,
        system: POSIXSystem
      ) {
        self.cancelReadDescriptor = cancelReadDescriptor
        self.cancelWriteDescriptor = cancelWriteDescriptor
        self.fileDescriptor = fileDescriptor
        self.originalFlags = system.fcntlGet(fileDescriptor, F_GETFL)
        self.pollTimeoutMilliseconds = pollTimeoutMilliseconds
        self.system = system
        if originalFlags != -1 {
          _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags | O_NONBLOCK)
        }
      }

      /// Starts the reader thread for `fileDescriptor`.
      ///
      /// Returns `nil` when the cancellation pipe cannot be created. The stream
      /// finishes when the input ends, and cancels the source when the consumer cancels
      /// or releases it.
      package static func start(
        fileDescriptor: CInt,
        pollTimeoutMilliseconds: CInt = 25,
        system: POSIXSystem = .current
      ) -> (source: InputSource, bytes: AsyncStream<[UInt8]>)? {
        var cancelPipe: [CInt] = [-1, -1]
        guard system.pipe(&cancelPipe) == 0 else {
          return nil
        }

        let source = InputSource(
          fileDescriptor: fileDescriptor,
          cancelReadDescriptor: cancelPipe[0],
          cancelWriteDescriptor: cancelPipe[1],
          pollTimeoutMilliseconds: pollTimeoutMilliseconds,
          system: system
        )
        let (bytes, continuation) = AsyncStream<[UInt8]>.makeStream()
        continuation.onTermination = { _ in
          source.cancel()
        }

        let thread = Thread {
          source.run(continuation)
        }
        thread.name = "TesseraTerminalIO.POSIXInputLoop"
        thread.start()

        return (source, bytes)
      }

      /// Wakes the reader and tells it to stop.
      ///
      /// Only the first call, and only while the reader is still running, writes to
      /// the cancellation pipe.
      package func cancel() {
        guard !isStopRequested.exchange(true, ordering: .acquiringAndReleasing) else {
          return
        }

        var byte: UInt8 = 0
        _ = withUnsafeBytes(of: &byte) { buffer in
          system.write(cancelWriteDescriptor, buffer.baseAddress, 1)
        }
      }

      private func run(_ continuation: AsyncStream<[UInt8]>.Continuation) {
        var buffer = [UInt8](repeating: 0, count: 256)
        while let chunk = nextChunk(into: &buffer) {
          if case .terminated = continuation.yield(chunk) {
            break
          }
        }

        isStopRequested.store(true, ordering: .releasing)
        if originalFlags != -1 {
          _ = system.fcntlSet(fileDescriptor, F_SETFL, originalFlags)
        }
        continuation.finish()
      }

      // `nil` ends the input; an empty chunk is a timeout event.
      // swiftlint:disable:next discouraged_optional_collection
      private func nextChunk(into buffer: inout [UInt8]) -> [UInt8]? {
        while !isStopRequested.load(ordering: .acquiring) {
          var descriptors = [
            pollfd(fd: fileDescriptor, events: Int16(POLLIN), revents: 0),
            pollfd(fd: cancelReadDescriptor, events: Int16(POLLIN), revents: 0),
          ]
          let pollStart = ContinuousClock.now
          let result = descriptors.withUnsafeMutableBufferPointer { pointer in
            system.poll(
              pointer.baseAddress, nfds_t(pointer.count), pollTimeoutMilliseconds)
          }

          if result < 0 {
            if errno == EINTR {
              continue
            }
            return nil
          }
          guard result > 0 else {
            waitOutIdleTimeout(since: pollStart)
            return []
          }
          if POSIXInputLoop.hasAnyEvent(
            descriptors[1].revents,
            POLLIN,
            POLLHUP,
            POLLERR,
            POLLNVAL
          ) {
            return nil
          }
          if POSIXInputLoop.hasAnyEvent(
            descriptors[0].revents,
            POLLHUP,
            POLLERR,
            POLLNVAL
          ) {
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
            return nil
          }
          if errno == EINTR || errno == EAGAIN {
            continue
          }
          return nil
        }
        return nil
      }

      /// Sleeps out the rest of the poll timeout after `poll` reports no events.
      ///
      /// A real `poll` returns zero only once the full timeout has elapsed, so this
      /// returns at once. A `poll` that returns early, such as a test stub, would
      /// otherwise turn idle chunks into a busy loop that floods the stream.
      private func waitOutIdleTimeout(since start: ContinuousClock.Instant) {
        let remaining =
          Duration.milliseconds(pollTimeoutMilliseconds) - start.duration(to: .now)
        if remaining > .zero {
          Thread.sleep(forTimeInterval: remaining / .seconds(1))
        }
      }

      deinit {
        _ = system.close(cancelReadDescriptor)
        _ = system.close(cancelWriteDescriptor)
      }
    }

    /// Creates an input byte-chunk stream for `fileDescriptor`.
    ///
    /// A dedicated thread polls and reads the descriptor and yields chunks into the
    /// stream, so no blocking wait occupies an actor or a cooperative-pool thread. Empty
    /// chunks represent input-idle poll timeouts. The thread stops, and the descriptor's
    /// original flags are restored, when the input ends or fails, or when the consumer
    /// cancels or releases the stream.
    package static func bytes(
      fileDescriptor: CInt,
      pollTimeoutMilliseconds: CInt = 25
    ) -> AsyncStream<[UInt8]> {
      InputSource.start(
        fileDescriptor: fileDescriptor,
        pollTimeoutMilliseconds: pollTimeoutMilliseconds,
        system: .current
      )?.bytes ?? AsyncStream { $0.finish() }
    }

    private static func hasAnyEvent(_ revents: Int16, _ events: CInt...) -> Bool {
      let mask = events.reduce(Int16(0)) { partialResult, event in
        partialResult | Int16(event)
      }

      return revents & mask != 0
    }
  }
#endif
