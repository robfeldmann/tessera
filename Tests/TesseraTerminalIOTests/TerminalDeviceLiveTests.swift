import CustomDump
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalIO

#if os(macOS)
  @Suite(.serialized)
  struct TerminalDeviceLiveTests {
    @Test
    func `live terminal writes alternate screen bytes to pty`() async throws {
      let pty = try PTYFixture()
      defer { pty.closeAll() }
      let io = try PlatformIO(handles: pty.handles())

      try await io.enableAltScreen()
      try await io.disableAltScreen()

      expectNoDifference(
        try pty.readAvailable(),
        Array("\u{1B}[?1049h\u{1B}[?1049l".utf8)
      )
    }

    @Test
    func `live terminal raw mode disables echo and restores termios`() async throws {
      let pty = try PTYFixture()
      defer { pty.closeAll() }
      let original = try pty.termios()
      let io = try PlatformIO(handles: pty.handles())

      try await io.enableRawMode()
      let raw = try pty.termios()
      try await io.disableRawMode()
      let restored = try pty.termios()

      let rawModeMask = tcflag_t(ICANON | ECHO)
      #expect(raw.c_lflag & tcflag_t(ICANON) == 0)
      #expect(raw.c_lflag & tcflag_t(ECHO) == 0)
      expectNoDifference(restored.c_lflag & rawModeMask, original.c_lflag & rawModeMask)
    }

    @Test
    func `live terminal reads configured pty size`() async throws {
      let pty = try PTYFixture()
      defer { pty.closeAll() }
      try pty.setSize(columns: 132, rows: 43)
      let io = try PlatformIO(handles: pty.handles())

      let size = try await io.size()

      expectNoDifference(size, TerminalSize(columns: 132, rows: 43))
    }

    @Test
    func `live terminal flush writes bytes to pty`() async throws {
      let pty = try PTYFixture()
      defer { pty.closeAll() }
      let io = try PlatformIO(handles: pty.handles())

      await io.write([0x48, 0x69])
      try await io.flush()

      expectNoDifference(try pty.readAvailable(), [0x48, 0x69])
    }

    @Test
    func `live terminal reports unsupported invalid descriptors`() async throws {
      let io = try PlatformIO(
        handles: PlatformHandles(
          stdin: FileDescriptor(rawValue: -1),
          stdout: FileDescriptor(rawValue: -1)
        )
      )

      await #expect(throws: PlatformIOError.rawModeFailed(errno: .badFileDescriptor)) {
        try await io.enableRawMode()
      }
    }
  }

  private final class PTYFixture: @unchecked Sendable {
    private var primaryFileDescriptor: CInt = -1
    private var replicaFileDescriptor: CInt = -1

    init() throws {
      guard
        openpty(
          &primaryFileDescriptor,
          &replicaFileDescriptor,
          nil,
          nil,
          nil
        ) == 0
      else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
      let flags = fcntl(primaryFileDescriptor, F_GETFL)
      _ = fcntl(primaryFileDescriptor, F_SETFL, flags | O_NONBLOCK)
    }

    func handles() -> PlatformHandles {
      PlatformHandles(
        stdin: FileDescriptor(rawValue: replicaFileDescriptor),
        stdout: FileDescriptor(rawValue: replicaFileDescriptor)
      )
    }

    func closeAll() {
      if primaryFileDescriptor >= 0 {
        close(primaryFileDescriptor)
        primaryFileDescriptor = -1
      }
      if replicaFileDescriptor >= 0 {
        close(replicaFileDescriptor)
        replicaFileDescriptor = -1
      }
    }

    func readAvailable() throws -> [UInt8] {
      var bytes: [UInt8] = []
      var buffer = [UInt8](repeating: 0, count: 1_024)
      while true {
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
          read(primaryFileDescriptor, pointer.baseAddress, pointer.count)
        }
        if count > 0 {
          bytes.append(contentsOf: buffer.prefix(count))
        } else if count < 0, errno == EAGAIN || errno == EWOULDBLOCK {
          return bytes
        } else if count == 0 {
          return bytes
        } else if errno == EINTR {
          continue
        } else {
          throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
        }
      }
    }

    func setSize(columns: UInt16, rows: UInt16) throws {
      var size = winsize(ws_row: rows, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
      guard ioctl(replicaFileDescriptor, UInt(TIOCSWINSZ), &size) == 0 else {
        throw PlatformIOError.terminalSizeUnavailable(errno: .init(rawValue: errno))
      }
    }

    func termios() throws -> termios {
      var value = Darwin.termios()
      guard tcgetattr(replicaFileDescriptor, &value) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: .init(rawValue: errno))
      }
      return value
    }
  }
#endif
