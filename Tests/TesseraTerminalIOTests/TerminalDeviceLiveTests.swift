import CustomDump
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalIO

#if os(macOS)
  import Darwin

  @Suite(.serialized)
  struct TerminalDeviceLiveTests {
    @Test
    func `live terminal writes alternate screen bytes to pty`() async throws {
      let pty = try PTYFixture()
      defer { pty.closeAll() }
      let io = try PlatformIO(handles: pty.handles())

      try await io.enableAltScreen()
      try await io.disableAltScreen()

      expectNoDifference(try pty.readAvailable(), Array("\u{1B}[?1049h\u{1B}[?1049l".utf8))
    }

    @Test
    func `live terminal raw mode disables canonical echo and restores termios`() async throws {
      let pty = try PTYFixture()
      defer { pty.closeAll() }
      let original = try pty.termios()
      let io = try PlatformIO(handles: pty.handles())

      try await io.enableRawMode()
      let raw = try pty.termios()
      try await io.disableRawMode()
      let restored = try pty.termios()

      #expect(raw.c_lflag & tcflag_t(ICANON) == 0)
      #expect(raw.c_lflag & tcflag_t(ECHO) == 0)
      expectNoDifference(restored.c_lflag, original.c_lflag)
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
    private var master: CInt = -1
    private var slave: CInt = -1

    init() throws {
      guard openpty(&master, &slave, nil, nil, nil) == 0 else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
      _ = fcntl(master, F_SETFL, fcntl(master, F_GETFL) | O_NONBLOCK)
    }

    func handles() -> PlatformHandles {
      PlatformHandles(
        stdin: FileDescriptor(rawValue: slave),
        stdout: FileDescriptor(rawValue: slave)
      )
    }

    func closeAll() {
      if master >= 0 { close(master); master = -1 }
      if slave >= 0 { close(slave); slave = -1 }
    }

    func readAvailable() throws -> [UInt8] {
      var bytes: [UInt8] = []
      var buffer = [UInt8](repeating: 0, count: 1024)
      while true {
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
          read(master, pointer.baseAddress, pointer.count)
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
      guard ioctl(slave, UInt(TIOCSWINSZ), &size) == 0 else {
        throw PlatformIOError.terminalSizeUnavailable(errno: .init(rawValue: errno))
      }
    }

    func termios() throws -> termios {
      var value = Darwin.termios()
      guard tcgetattr(slave, &value) == 0 else {
        throw PlatformIOError.rawModeFailed(errno: .init(rawValue: errno))
      }
      return value
    }
  }
#endif
