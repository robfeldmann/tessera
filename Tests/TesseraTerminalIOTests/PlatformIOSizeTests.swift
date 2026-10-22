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
func `cell pixel size returns terminal device value`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      cellPixelSize: { CellPixelSize(height: 18, width: 9) },
      size: { TerminalSize(columns: 120, rows: 40) },
      write: { $0.count }
    )
  )

  let pixelSize = await io.cellPixelSize()

  expectNoDifference(pixelSize, CellPixelSize(height: 18, width: 9))
}

@Test
func `size changes queued before a read deliver only the newest size`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      inputStreamsShareLifetime: true,
      size: { TerminalSize(columns: 1, rows: 1) },
      sizeChanges: {
        AsyncStream { continuation in
          continuation.yield(TerminalSize(columns: 80, rows: 24))
          continuation.yield(TerminalSize(columns: 90, rows: 27))
          continuation.yield(TerminalSize(columns: 100, rows: 30))
          continuation.finish()
        }
      },
      write: { $0.count }
    )
  )
  // With finished input and a shared lifetime, `events` ends only after every size change
  // has been forwarded, so all three are queued before `sizeChanges` is read.
  for await _ in io.events {}

  var sizes: [TerminalSize] = []
  for await size in io.sizeChanges {
    sizes.append(size)
  }

  expectNoDifference(sizes, [TerminalSize(columns: 100, rows: 30)])
}

@Test
func `platform io subscribes to device size changes once`() async {
  let (subscriptions, subscription) = AsyncStream.makeStream(of: Void.self)
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      size: { TerminalSize(columns: 1, rows: 1) },
      sizeChanges: {
        subscription.yield()
        return AsyncStream { $0.finish() }
      },
      write: { $0.count }
    )
  )
  subscription.finish()

  var subscriptionCount = 0
  for await _ in subscriptions {
    subscriptionCount += 1
  }

  #expect(subscriptionCount == 1)
  withExtendedLifetime(io) {}
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
