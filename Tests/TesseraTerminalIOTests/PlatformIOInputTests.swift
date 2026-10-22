import CustomDump
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  @Test
  func `posix input loop yields bytes written to descriptor as a chunk`() async throws {
    let pipe = try FileDescriptorPipe()
    defer { pipe.closeAll() }

    let stream = POSIXInputLoop.bytes(fileDescriptor: pipe.readDescriptor)
    var iterator = stream.makeAsyncIterator()

    try pipe.write([0x61, 0x62])

    let chunk = await iterator.next()

    expectNoDifference(chunk, [0x61, 0x62])
  }

  @Test
  func `posix input loop finishes on eof`() async throws {
    let pipe = try FileDescriptorPipe()
    defer { pipe.closeAll() }

    let stream = POSIXInputLoop.bytes(fileDescriptor: pipe.readDescriptor)
    var iterator = stream.makeAsyncIterator()

    pipe.closeWriteDescriptor()

    let end = await iterator.next()

    expectNoDifference(end, nil)
  }

  struct POSIXInputLoopSeamTests {
    @Test
    func `input loop finishes when cancellation pipe setup fails`() async {
      let value = await nextValue(with: .pipeStub { _ in -1 })
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop yields empty chunks on poll timeout`() async {
      let value = await nextValue(with: .pollStub { _, _, _ in 0 })

      expectNoDifference(value, [])
    }

    @Test
    func `input loop skips poll timeout then yields readable byte`() async {
      let calls = SyscallCallCounter()
      let value = await nextNonEmptyValue(
        with: .stub(
          poll: { descriptors, _, _ in
            if calls.increment() == 0 {
              return 0
            }
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, buffer, _ in
            buffer?.assumingMemoryBound(to: UInt8.self).pointee = 0x61
            return 1
          }
        )
      )
      expectNoDifference(value, [0x61])
    }

    @Test
    func `input loop ignores interrupted poll before eof`() async {
      let calls = SyscallCallCounter()
      let value = await nextValue(
        with: .stub(
          poll: { descriptors, _, _ in
            if calls.increment() == 0 {
              errno = EINTR
              return -1
            }
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, _, _ in 0 }
        )
      )
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop finishes on fatal poll failure`() async {
      let value = await nextValue(
        with: .pollStub { _, _, _ in
          errno = EIO
          return -1
        }
      )
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop finishes when cancellation pipe wakes poll`() async {
      let value = await nextValue(
        with: .pollStub { descriptors, _, _ in
          descriptors?[1].revents = Int16(POLLIN)
          return 1
        }
      )
      expectNoDifference(value, nil)
    }

    @Test(arguments: [EINTR, EAGAIN])
    func `input loop retries transient read failures`(errorNumber: CInt) async {
      let calls = SyscallCallCounter()
      let value = await nextValue(
        with: .stub(
          poll: { descriptors, _, _ in
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, buffer, _ in
            if calls.increment() == 0 {
              errno = errorNumber
              return -1
            }
            buffer?.assumingMemoryBound(to: UInt8.self).pointee = 0x62
            return 1
          }
        )
      )
      expectNoDifference(value, [0x62])
    }

    @Test
    func `input loop finishes on fatal read failure`() async {
      let value = await nextValue(
        with: .stub(
          poll: { descriptors, _, _ in
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, _, _ in
            errno = EIO
            return -1
          }
        )
      )
      expectNoDifference(value, nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func `input loop restores descriptor flags on termination`() async {
      // The flag-restoring path reports each `fcntl(F_SETFL)` through this stream.
      let (flagChanges, flagChangeContinuation) = AsyncStream.makeStream(of: CInt.self)
      POSIXSystem.$override.withValue(
        .stub(
          fcntlGet: { _, _ in 0x04 },
          fcntlSet: { _, _, flags in
            flagChangeContinuation.yield(flags)
            return 0
          },
          poll: { _, _, _ in 0 }
        )
      ) {
        var stream: AsyncStream<[UInt8]>? = POSIXInputLoop.bytes(fileDescriptor: 0)
        var iterator: AsyncStream<[UInt8]>.Iterator? = stream?.makeAsyncIterator()
        _ = iterator
        iterator = nil
        stream = nil
      }

      var changes = flagChanges.makeAsyncIterator()
      let nonBlocking = await changes.next()
      let restored = await changes.next()

      expectNoDifference(nonBlocking, 0x04 | O_NONBLOCK)
      expectNoDifference(restored, 0x04)
    }

    @Test(.timeLimit(.minutes(1)))
    func `input loop cancel wakes a blocked poll before its timeout`() async throws {
      let input = try FileDescriptorPipe()
      defer { input.closeAll() }
      let (polling, pollingContinuation) = AsyncStream.makeStream(of: Void.self)
      let (wakeups, wakeupContinuation) = AsyncStream.makeStream(of: CInt.self)
      var system = POSIXSystem.live
      // Blocks like a real poll waiting on the cancellation pipe. The 5 s cap only stops a
      // regression from hanging the suite; reaching it reports a timeout (0).
      system.poll = { descriptors, _, _ in
        pollingContinuation.yield()
        let result = poll(descriptors.map { $0 + 1 }, 1, 5_000)
        wakeupContinuation.yield(result)
        return result
      }
      let reader = try #require(
        POSIXInputLoop.InputSource.start(
          fileDescriptor: input.readDescriptor,
          system: system
        )
      )
      var iterator = reader.bytes.makeAsyncIterator()
      var pollingIterator = polling.makeAsyncIterator()
      var wakeupIterator = wakeups.makeAsyncIterator()

      _ = await pollingIterator.next()
      reader.source.cancel()

      let end = await iterator.next()
      let wakeup = await wakeupIterator.next()

      expectNoDifference(end, nil)
      expectNoDifference(wakeup, 1)
    }

    @Test
    func `input loop paces idle chunks when poll returns immediately`() async {
      let clock = ContinuousClock()
      let start = clock.now
      await POSIXSystem.$override.withValue(.pollStub { _, _, _ in 0 }) {
        let stream = POSIXInputLoop.bytes(fileDescriptor: 0, pollTimeoutMilliseconds: 20)
        var iterator = stream.makeAsyncIterator()
        for _ in 0..<3 {
          _ = await iterator.next()
        }
      }

      // Three idle chunks take at least three poll timeouts (60 ms) even though the stub
      // never waits; the margin absorbs timer rounding.
      #expect(start.duration(to: clock.now) >= .milliseconds(50))
    }

    @Test
    func `input loop cancel after the input ends issues no write`() async throws {
      let input = try FileDescriptorPipe()
      defer { input.closeAll() }
      let writes = SyscallCallCounter()
      var system = POSIXSystem.live
      system.write = { descriptor, buffer, count in
        writes.increment()
        return write(descriptor, buffer, count)
      }
      let reader = try #require(
        POSIXInputLoop.InputSource.start(
          fileDescriptor: input.readDescriptor,
          system: system
        )
      )
      var iterator = reader.bytes.makeAsyncIterator()

      input.closeWriteDescriptor()
      let end = await iterator.next()
      reader.source.cancel()

      expectNoDifference(end, nil)
      expectNoDifference(writes.value, 0)
    }

    @Test
    func `input loop cancel writes the cancellation pipe only once`() async throws {
      let input = try FileDescriptorPipe()
      defer { input.closeAll() }
      let writes = SyscallCallCounter()
      var system = POSIXSystem.live
      system.write = { descriptor, buffer, count in
        writes.increment()
        return write(descriptor, buffer, count)
      }
      let reader = try #require(
        POSIXInputLoop.InputSource.start(
          fileDescriptor: input.readDescriptor,
          system: system
        )
      )
      var iterator = reader.bytes.makeAsyncIterator()

      reader.source.cancel()
      reader.source.cancel()
      let end = await iterator.next()

      expectNoDifference(end, nil)
      expectNoDifference(writes.value, 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func `input loop closes its cancel pipe when the source is released`() async throws {
      let input = try FileDescriptorPipe()
      defer { input.closeAll() }
      let closes = SyscallCallCounter()
      let (closed, closedContinuation) = AsyncStream.makeStream(of: Void.self)
      var system = POSIXSystem.live
      system.close = { descriptor in
        closes.increment()
        closedContinuation.yield()
        return close(descriptor)
      }

      do {
        let reader = try #require(
          POSIXInputLoop.InputSource.start(
            fileDescriptor: input.readDescriptor,
            system: system
          )
        )
        var iterator = reader.bytes.makeAsyncIterator()

        input.closeWriteDescriptor()
        _ = await iterator.next()

        // The reader has finished, but the source is still referenced, so a late
        // cancellation could still reach the pipe.
        withExtendedLifetime(reader.source) {
          expectNoDifference(closes.value, 0)
        }
      }

      var closedIterator = closed.makeAsyncIterator()
      _ = await closedIterator.next()
      _ = await closedIterator.next()
      expectNoDifference(closes.value, 2)
    }

    // These helpers mirror AsyncIterator.next(): nil means stream end.
    // An empty array is a real idle chunk emitted by the input loop.
    // swiftlint:disable:next discouraged_optional_collection
    private func nextNonEmptyValue(with system: POSIXSystem) async -> [UInt8]? {
      await POSIXSystem.$override.withValue(system) {
        let stream = POSIXInputLoop.bytes(fileDescriptor: 0)
        var iterator = stream.makeAsyncIterator()
        while let value = await iterator.next() {
          if !value.isEmpty {
            return value
          }
        }
        return nil
      }
    }

    // Same AsyncIterator.next() semantics: nil is stream end.
    // An empty array is a real idle chunk emitted by the input loop.
    // swiftlint:disable:next discouraged_optional_collection
    private func nextValue(with system: POSIXSystem) async -> [UInt8]? {
      await POSIXSystem.$override.withValue(system) {
        let stream = POSIXInputLoop.bytes(fileDescriptor: 0)
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
      }
    }
  }

  // Owned by one test body: it creates, uses, and closes the pipe on that test's task and
  // never passes it to a `@Sendable` closure (only `readDescriptor` integers leave it).
  private final class FileDescriptorPipe {
    private var descriptors: [CInt] = [-1, -1]

    var readDescriptor: CInt {
      descriptors[0]
    }

    init() throws {
      guard pipe(&descriptors) == 0 else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
    }

    func closeAll() {
      if descriptors[0] >= 0 {
        close(descriptors[0])
        descriptors[0] = -1
      }
      closeWriteDescriptor()
    }

    func closeWriteDescriptor() {
      if descriptors[1] >= 0 {
        close(descriptors[1])
        descriptors[1] = -1
      }
    }

    func write(_ bytes: [UInt8]) throws {
      let written = bytes.withUnsafeBufferPointer { buffer in
        systemWrite(descriptors[1], buffer.baseAddress, bytes.count)
      }

      guard written == bytes.count else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
    }
  }

  private func systemWrite(
    _ fileDescriptor: CInt,
    _ buffer: UnsafePointer<UInt8>?,
    _ count: Int
  ) -> Int {
    write(fileDescriptor, buffer, count)
  }
#endif
