import CustomDump
import SystemPackage
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  struct POSIXSyscallsTests {
    // The stalled-poll stubs cap their zero-returning polls at `stalledPollLimit`, then
    // report the descriptor writable. A wait that ignores cancellation therefore fails
    // the test instead of spinning forever.
    private static let stalledPollLimit = 1_000

    @Test
    func `write returns successful byte count`() throws {
      try POSIXSystem.$override.withValue(.writeStub { _, _, _ in 2 }) {
        let written = try POSIXSyscalls.write(fileDescriptor: 1, bytes: [1, 2, 3][...])
        expectNoDifference(written, 2)
      }
    }

    @Test
    func `empty write returns zero without calling system write`() throws {
      try POSIXSystem.$override.withValue(
        .writeStub { _, _, _ in
          Issue.record("write should not be called")
          return -1
        }
      ) {
        let written = try POSIXSyscalls.write(fileDescriptor: 1, bytes: [UInt8]()[...])
        expectNoDifference(written, 0)
      }
    }

    @Test(arguments: [EINTR, EAGAIN, EIO])
    func `write maps errno failures`(errorNumber: CInt) throws {
      let expected: PlatformIOError =
        switch errorNumber {
        case EINTR:
          .writeInterrupted
        case EAGAIN:
          .writeWouldBlock
        default:
          .writeFailed(errno: Errno(rawValue: errorNumber))
        }

      POSIXSystem.$override.withValue(
        .writeStub { _, _, _ in
          errno = errorNumber
          return -1
        }
      ) {
        #expect(throws: expected) {
          try POSIXSyscalls.write(fileDescriptor: 1, bytes: [1][...])
        }
      }
    }

    @Test
    func `wait until writable returns after successful poll`() throws {
      try POSIXSystem.$override.withValue(.pollStub { _, _, _ in 1 }) {
        try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
      }
    }

    @Test
    func `wait until writable polls in bounded slices until writable`() throws {
      let polls = SyscallCallCounter()
      try POSIXSystem.$override.withValue(
        .pollStub { _, _, timeout in
          #expect(timeout == POSIXSyscalls.writableWaitSliceMilliseconds)
          return polls.increment() == 0 ? 0 : 1
        }
      ) {
        try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
      }
      expectNoDifference(polls.value, 2)
    }

    @Test
    func `cancelled wait until writable throws within one slice`() async {
      let polls = SyscallCallCounter()
      let wait = Task {
        try POSIXSystem.$override.withValue(
          .pollStub { _, _, _ in
            let previousPolls = polls.increment()
            // The task is cancelled while this slice is waiting, and the slice times out.
            withUnsafeCurrentTask { $0?.cancel() }
            return previousPolls < Self.stalledPollLimit ? 0 : 1
          }
        ) {
          try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
        }
      }

      await #expect(throws: CancellationError.self) {
        try await wait.value
      }
      expectNoDifference(polls.value, 1)
    }

    @Test
    func `cancelled device write throws within one slice`() async {
      let polls = SyscallCallCounter()
      let device = TerminalDevice.live(
        handles: PlatformHandles(
          stdin: FileDescriptor(rawValue: STDIN_FILENO),
          stdout: FileDescriptor(rawValue: STDOUT_FILENO)
        )
      )
      let system = POSIXSystem.stub(
        poll: { _, _, _ in
          let previousPolls = polls.increment()
          withUnsafeCurrentTask { $0?.cancel() }
          return previousPolls < Self.stalledPollLimit ? 0 : 1
        },
        write: { _, _, count in
          guard polls.value < Self.stalledPollLimit else {
            return count
          }
          errno = EAGAIN
          return -1
        }
      )
      let write = Task {
        try await POSIXSystem.$override.withValue(system) {
          try await device.write([0x41, 0x42][...])
        }
      }

      await #expect(throws: CancellationError.self) {
        try await write.value
      }
      expectNoDifference(polls.value, 1)
    }

    @Test
    func `wait until writable maps interrupted poll`() throws {
      POSIXSystem.$override.withValue(
        .pollStub { _, _, _ in
          errno = EINTR
          return -1
        }
      ) {
        #expect(throws: PlatformIOError.writeInterrupted) {
          try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
        }
      }
    }

    @Test
    func `wait until writable maps fatal poll failure`() throws {
      POSIXSystem.$override.withValue(
        .pollStub { _, _, _ in
          errno = EIO
          return -1
        }
      ) {
        #expect(throws: PlatformIOError.writeFailed(errno: Errno(rawValue: EIO))) {
          try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
        }
      }
    }
  }
#endif
