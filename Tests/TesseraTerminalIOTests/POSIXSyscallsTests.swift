import CustomDump
import SystemPackage
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  struct POSIXSyscallsTests {
    @Test
    func `write returns successful byte count`() throws {
      try POSIXSystem.$override.withValue(.stub { _, _, _ in 2 }) {
        let written = try POSIXSyscalls.write(fileDescriptor: 1, bytes: [1, 2, 3][...])
        expectNoDifference(written, 2)
      }
    }

    @Test
    func `empty write returns zero without calling system write`() throws {
      try POSIXSystem.$override.withValue(
        .stub { _, _, _ in
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
        case EINTR: .writeInterrupted
        case EAGAIN: .writeWouldBlock
        default: .writeFailed(errno: Errno(rawValue: errorNumber))
        }

      POSIXSystem.$override.withValue(
        .stub { _, _, _ in
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
      try POSIXSystem.$override.withValue(.stub { _, _, _ in 1 }) {
        try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
      }
    }

    @Test
    func `wait until writable ignores timeout then succeeds`() throws {
      final class PollState: @unchecked Sendable { var calls = 0 }
      let state = PollState()
      try POSIXSystem.$override.withValue(
        .stub { _, _, _ in
          defer { state.calls += 1 }
          return state.calls == 0 ? 0 : 1
        }
      ) {
        try POSIXSyscalls.waitUntilWritable(fileDescriptor: 1)
      }
      expectNoDifference(state.calls, 2)
    }

    @Test
    func `wait until writable maps interrupted poll`() throws {
      POSIXSystem.$override.withValue(
        .stub { _, _, _ in
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
        .stub { _, _, _ in
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
