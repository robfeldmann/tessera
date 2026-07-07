import CustomDump
import SystemPackage
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalIO

@Test
func `size returns terminal device seam size`() async throws {
  let terminalDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 80, rows: 24))
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  let size = try await io.size()

  expectNoDifference(size, TerminalSize(columns: 80, rows: 24))
}

@Test
func `write buffers bytes until flush`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  await io.write([0x48, 0x69])
  await io.write([0x21])

  let bytesBeforeFlush = await terminalDevice.bytes
  expectNoDifference(bytesBeforeFlush, [])

  try await io.flush()

  let bytesAfterFlush = await terminalDevice.bytes
  expectNoDifference(bytesAfterFlush, [0x48, 0x69, 0x21])
}

@Test
func `array slice write buffers bytes until flush`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)
  let bytes: [UInt8] = [0x00, 0x48, 0x69, 0x21]

  await io.write(bytes[1...2])
  await io.write(bytes[3...])
  try await io.flush()

  let writtenBytes = await terminalDevice.bytes
  expectNoDifference(writtenBytes, [0x48, 0x69, 0x21])
}

@Test
func `many writes flush with one underlying write`() async throws {
  let output = CountingOutputWriter(results: [.success(3)])
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x48])
  await io.write([0x69])
  await io.write([0x21])
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(writes, [[0x48, 0x69, 0x21]])
}

@Test
func `flush retries remaining bytes after partial writes`() async throws {
  let output = CountingOutputWriter(results: [.success(1), .success(2)])
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x48, 0x69, 0x21])
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(writes, [[0x48, 0x69, 0x21], [0x69, 0x21]])
}

@Test
func `flush retries interrupted writes without dropping bytes`() async throws {
  let output = CountingOutputWriter(
    results: [.failure(PlatformIOError.writeInterrupted), .success(3)]
  )
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x48, 0x69, 0x21])
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(writes, [[0x48, 0x69, 0x21], [0x48, 0x69, 0x21]])
}

@Test
func `flush retries temporarily unavailable writes without dropping bytes`() async throws {
  let output = CountingOutputWriter(
    results: [.failure(PlatformIOError.writeWouldBlock), .success(3)]
  )
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x48, 0x69, 0x21])
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(writes, [[0x48, 0x69, 0x21], [0x48, 0x69, 0x21]])
}

@Test
func `bytes reads terminal device seam input byte chunks`() async {
  let terminalDevice = InMemoryTerminalDevice(inputBytes: [0x61, 0x62])
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)
  var iterator = io.bytes.makeAsyncIterator()

  let chunk = await iterator.next()
  let end = await iterator.next()

  expectNoDifference(chunk, [0x61, 0x62])
  expectNoDifference(end, nil)
}

@Test
func `events parses terminal device seam input byte chunks`() async {
  let terminalDevice = InMemoryTerminalDevice(inputBytes: Array("\u{1B}[1;5A".utf8))
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)
  var iterator = io.events.makeAsyncIterator()

  let event = await iterator.next()
  let end = await iterator.next()

  expectNoDifference(event, .key(Key(code: .up, modifiers: .control)))
  expectNoDifference(end, nil)
}

@Test
func `events uses idle chunks to disambiguate escape`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      bytes: {
        AsyncStream { continuation in
          continuation.yield([0x1B])
          continuation.yield([])
          continuation.yield([0x61])
          continuation.finish()
        }
      },
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { $0.count }
    )
  )
  var iterator = io.events.makeAsyncIterator()

  let first = await iterator.next()
  let second = await iterator.next()
  let end = await iterator.next()

  expectNoDifference(first, .key(Key(code: .escape)))
  expectNoDifference(second, .key(Key(code: .character("a"))))
  expectNoDifference(end, nil)
}

@Test
func `events preserves alt keys without intervening idle chunk`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      bytes: {
        AsyncStream { continuation in
          continuation.yield([0x1B])
          continuation.yield([0x61])
          continuation.finish()
        }
      },
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { $0.count }
    )
  )
  var iterator = io.events.makeAsyncIterator()

  let event = await iterator.next()
  let end = await iterator.next()

  expectNoDifference(event, .key(Key(code: .character("a"), modifiers: .alt)))
  expectNoDifference(end, nil)
}

@Test
func `events includes terminal resize notifications`() async throws {
  let size = TerminalSize(columns: 80, rows: 24)
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      bytes: { AsyncStream { _ in } },
      size: { TerminalSize(columns: 1, rows: 1) },
      sizeChanges: {
        AsyncStream { continuation in
          continuation.yield(size)
          continuation.finish()
        }
      },
      write: { $0.count }
    )
  )
  var iterator = io.events.makeAsyncIterator()

  let event = await iterator.next()

  let receivedEvent = try #require(event)
  switch receivedEvent {
  case .resize(let actualSize):
    #expect(actualSize == size)
  default:
    Issue.record("Expected resize event, got \(receivedEvent)")
  }
}

@Test
func `alt screen methods emit alternate screen bytes`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  try await io.enableAltScreen()
  try await io.disableAltScreen()

  let bytes = await terminalDevice.bytes
  expectNoDifference(bytes, Array("\u{1B}[?1049h\u{1B}[?1049l".utf8))
}

@Test
func `raw mode methods call terminal device seam`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  try await io.enableRawMode()
  try await io.disableRawMode()

  let events = await terminalDevice.events
  expectNoDifference(events, [.enterRawMode, .exitRawMode])
}

@Test
func `flush preserves unwritten buffered bytes after errors`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { _ in throw PlatformIOError.writeFailed(errno: .ioError) }
    )
  )

  await io.write([0x00])

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await io.flush()
  }

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await io.flush()
  }
}

@Test
func `flush treats zero byte write as failure and preserves bytes`() async throws {
  let output = CountingOutputWriter(results: [.success(0), .success(1)])
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x41])

  await #expect(throws: PlatformIOError.writeFailed(errno: Errno(rawValue: 0))) {
    try await io.flush()
  }
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(writes, [[0x41], [0x41]])
}

@Test
func `flush removes only bytes written before a later failure`() async throws {
  let output = CountingOutputWriter(
    results: [
      .success(1),
      .failure(PlatformIOError.writeFailed(errno: .ioError)),
      .success(2),
    ]
  )
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x41, 0x42, 0x43])

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await io.flush()
  }
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(writes, [[0x41, 0x42, 0x43], [0x42, 0x43], [0x42, 0x43]])
}

@Test
func `flush retries after transient write errors`() async throws {
  let output = CountingOutputWriter(
    results: [
      .failure(PlatformIOError.writeWouldBlock),
      .failure(PlatformIOError.writeInterrupted),
      .success(2),
    ]
  )
  let io = PlatformIO(terminalDevice: await output.terminalDevice)

  await io.write([0x41, 0x42])
  try await io.flush()

  let writes = await output.writes
  expectNoDifference(
    writes,
    [[0x41, 0x42], [0x41, 0x42], [0x41, 0x42]]
  )
}

#if os(Windows)
  @Suite
  struct WindowsPlatformIOTests {
    @Test
    func `windows live terminal flush writes output bytes`() async throws {
      let state = WindowsOutputState(writeResults: [.success(2)])

      try await WindowsConsoleSystem.$override.withValue(state.system) {
        let io = PlatformIO(
          terminalDevice: .live(
            handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
          )
        )

        await io.write([0x48, 0x69])
        try await io.flush()
      }

      expectNoDifference(state.writeCalls, [[0x48, 0x69]])
    }

    @Test
    func `windows live terminal retries after partial writes`() async throws {
      let state = WindowsOutputState(writeResults: [.success(1), .success(2)])

      try await WindowsConsoleSystem.$override.withValue(state.system) {
        let io = PlatformIO(
          terminalDevice: .live(
            handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
          )
        )

        await io.write([0x48, 0x69, 0x21])
        try await io.flush()
      }

      expectNoDifference(
        state.writeCalls,
        [[0x48, 0x69, 0x21], [0x69, 0x21]]
      )
    }

    @Test
    func `windows live terminal maps failed writes`() async {
      let state = WindowsOutputState(writeResults: [.failure(123)])

      await #expect(
        throws: PlatformIOError.consoleOperationFailed(
          operation: .writeFile,
          errorCode: 123
        )
      ) {
        try await WindowsConsoleSystem.$override.withValue(state.system) {
          let io = PlatformIO(
            terminalDevice: .live(
              handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
            )
          )

          await io.write([0x41])
          try await io.flush()
        }
      }

      expectNoDifference(state.writeCalls, [[0x41]])
    }

    @Test
    func `windows live terminal writes alternate screen bytes`() async throws {
      let state = WindowsOutputState(writeResults: [.success(8), .success(8)])

      try await WindowsConsoleSystem.$override.withValue(state.system) {
        let io = PlatformIO(
          terminalDevice: .live(
            handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
          )
        )

        try await io.enableAltScreen()
        try await io.disableAltScreen()
      }

      expectNoDifference(
        state.writeCalls,
        [
          Array("\u{1B}[?1049h".utf8),
          Array("\u{1B}[?1049l".utf8),
        ]
      )
    }
  }

  private final class WindowsOutputState: @unchecked Sendable {
    enum WriteResult: Sendable {
      case failure(UInt32)
      case success(Int)
    }

    private var lastErrorCode: UInt32 = 0
    private var writeResults: [WriteResult]
    private(set) var writeCalls: [[UInt8]] = []

    var system: WindowsConsoleSystem {
      .stub(
        writeFile: { _, buffer, count in self.write(buffer: buffer, count: count) },
        lastErrorCode: { self.lastErrorCode }
      )
    }

    init(writeResults: [WriteResult]) {
      self.writeResults = writeResults
    }

    private func write(buffer: UnsafeRawPointer?, count: UInt32) -> Int? {
      if let buffer {
        let bytes = Array(
          UnsafeBufferPointer(
            start: buffer.assumingMemoryBound(to: UInt8.self),
            count: Int(count)
          )
        )
        writeCalls.append(bytes)
      } else {
        writeCalls.append([])
      }

      guard writeResults.isEmpty == false else {
        return Int(count)
      }

      switch writeResults.removeFirst() {
      case .success(let count):
        return count

      case .failure(let errorCode):
        lastErrorCode = errorCode
        return nil
      }
    }
  }
#endif

private actor CountingOutputWriter {
  private var recordedWrites: [[UInt8]] = []
  private var results: [Result<Int, any Error>]

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { try await self.write($0) }
    )
  }

  var writes: [[UInt8]] {
    recordedWrites
  }

  init(results: [Result<Int, any Error>]) {
    self.results = results
  }

  private func write(_ bytes: ArraySlice<UInt8>) throws -> Int {
    recordedWrites.append(Array(bytes))

    guard !results.isEmpty else {
      return bytes.count
    }

    switch results.removeFirst() {
    case .success(let count):
      return count

    case .failure(let error):
      throw error
    }
  }
}
