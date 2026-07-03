import CustomDump
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalIO

@Test
func `size returns queried terminal size`() async throws {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      size: { TerminalSize(columns: 120, rows: 40) },
      write: { $0.count }
    )
  )

  let size = try await io.size()

  expectNoDifference(size, TerminalSize(columns: 120, rows: 40))
}

@Test
func `size changes yields terminal size notifications`() async throws {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      size: { TerminalSize(columns: 1, rows: 1) },
      sizeChanges: {
        AsyncStream { continuation in
          continuation.yield(TerminalSize(columns: 80, rows: 24))
          continuation.yield(TerminalSize(columns: 100, rows: 30))
          continuation.finish()
        }
      },
      write: { $0.count }
    )
  )
  var iterator = io.sizeChanges.makeAsyncIterator()

  let first = await iterator.next()
  let second = await iterator.next()
  let end = await iterator.next()

  expectNoDifference(first, TerminalSize(columns: 80, rows: 24))
  expectNoDifference(second, TerminalSize(columns: 100, rows: 30))
  expectNoDifference(end, nil)
}

@Test
func `size propagates unavailable size errors`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      size: { throw PlatformIOError.terminalSizeUnavailable(errno: .ioError) },
      write: { $0.count }
    )
  )

  await #expect(throws: PlatformIOError.terminalSizeUnavailable(errno: .ioError)) {
    try await io.size()
  }
}

#if os(Windows)
  @Test
  func `windows live terminal reads console window size`() async throws {
    let system = WindowsConsoleSystem.terminalSizeStub { handle in
      handle == 0x20 ? TerminalSize(columns: 132, rows: 43) : nil
    }

    try await WindowsConsoleSystem.$override.withValue(system) {
      let io = PlatformIO(
        terminalDevice: .live(
          handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
        )
      )

      let size = try await io.size()

      expectNoDifference(size, TerminalSize(columns: 132, rows: 43))
    }
  }

  @Test
  func `windows live terminal maps failed console size reads`() async {
    let system = WindowsConsoleSystem.stub(
      terminalSize: { _ in nil },
      lastErrorCode: { 87 }
    )

    await #expect(
      throws: PlatformIOError.consoleOperationFailed(
        operation: .getConsoleScreenBufferInfo,
        errorCode: 87
      )
    ) {
      try await WindowsConsoleSystem.$override.withValue(system) {
        let io = PlatformIO(
          terminalDevice: .live(
            handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
          )
        )

        try await io.size()
      }
    }
  }
#endif
