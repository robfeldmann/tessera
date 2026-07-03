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
      let value = await nextValue(with: .stub { _ in -1 })
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop yields empty chunks on poll timeout`() async {
      let value = await nextValue(with: .stub { _, _, _ in 0 })

      expectNoDifference(value, [])
    }

    @Test
    func `input loop skips poll timeout then yields readable byte`() async {
      final class State: @unchecked Sendable { var calls = 0 }
      let state = State()
      let value = await nextNonEmptyValue(
        with: .stub(
          poll: { descriptors, _, _ in
            defer { state.calls += 1 }
            if state.calls == 0 { return 0 }
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, buffer, _ in
            buffer?.assumingMemoryBound(to: UInt8.self).pointee = 0x61
            return 1
          }
        ))
      expectNoDifference(value, [0x61])
    }

    @Test
    func `input loop ignores interrupted poll before eof`() async {
      final class State: @unchecked Sendable { var calls = 0 }
      let state = State()
      let value = await nextValue(
        with: .stub(
          poll: { descriptors, _, _ in
            defer { state.calls += 1 }
            if state.calls == 0 {
              errno = EINTR
              return -1
            }
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, _, _ in 0 }
        ))
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop finishes on fatal poll failure`() async {
      let value = await nextValue(
        with: .stub { _, _, _ in
          errno = EIO
          return -1
        })
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop finishes when cancellation pipe wakes poll`() async {
      let value = await nextValue(
        with: .stub { descriptors, _, _ in
          descriptors?[1].revents = Int16(POLLIN)
          return 1
        })
      expectNoDifference(value, nil)
    }

    @Test(arguments: [EINTR, EAGAIN])
    func `input loop retries transient read failures`(errorNumber: CInt) async {
      final class State: @unchecked Sendable { var calls = 0 }
      let state = State()
      let value = await nextValue(
        with: .stub(
          poll: { descriptors, _, _ in
            descriptors?[0].revents = Int16(POLLIN)
            return 1
          },
          read: { _, buffer, _ in
            defer { state.calls += 1 }
            if state.calls == 0 {
              errno = errorNumber
              return -1
            }
            buffer?.assumingMemoryBound(to: UInt8.self).pointee = 0x62
            return 1
          }
        ))
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
        ))
      expectNoDifference(value, nil)
    }

    @Test
    func `input loop restores descriptor flags on termination`() async {
      final class State: @unchecked Sendable { var setFlags: [CInt] = [] }
      let state = State()
      await POSIXSystem.$override.withValue(
        .stub(
          fcntlGet: { _, _ in 0x04 },
          fcntlSet: { _, _, flags in
            state.setFlags.append(flags)
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
        for _ in 0..<20 where state.setFlags.count < 2 {
          await Task.yield()
        }
      }
      expectNoDifference(state.setFlags, [0x04 | O_NONBLOCK, 0x04])
    }

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

    private func nextValue(with system: POSIXSystem) async -> [UInt8]? {
      await POSIXSystem.$override.withValue(system) {
        let stream = POSIXInputLoop.bytes(fileDescriptor: 0)
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
      }
    }
  }

  private final class FileDescriptorPipe: @unchecked Sendable {
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
