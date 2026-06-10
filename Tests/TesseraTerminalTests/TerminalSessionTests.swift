import CustomDump
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminal
@testable import TesseraTerminalIO

@Test
func `application terminal returns body result and cleans up modes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  let result = try await TerminalSession.withApplicationTerminal(
    configuration: .default,
    io: io
  ) { _ in
    "done"
  }

  let events = await device.events

  expectNoDifference(result, "done")
  expectNoDifference(
    events,
    [.enterRawMode, .enterAltScreen, .exitAltScreen, .exitRawMode]
  )
}

@Test
func `application terminal rethrows body error after cleanup`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  await #expect(throws: TerminalSessionTestError.bodyFailed) {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default,
      io: io
    ) { _ in
      throw TerminalSessionTestError.bodyFailed
    }
  }

  let events = await device.events
  expectNoDifference(
    events,
    [.enterRawMode, .enterAltScreen, .exitAltScreen, .exitRawMode]
  )
}

@Test
func `draw writes rendered frame and flushes once`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  let result = try await session.draw { frame in
    frame.write("Hi", at: TerminalPosition(column: 0, row: 0))
    return 42
  }

  let bytes = await device.bytes
  let events = await device.events

  expectNoDifference(result, 42)
  #expect(!bytes.isEmpty)
  expectNoDifference(events.filter(\.isFlush).count, 1)
}

@Test
func `next event returns first parsed input event`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x01, 0x61])
  let session = await makeSession(device)

  let event = try await session.nextEvent()

  expectNoDifference(event, .character("a"))
}

@Test
func `next event can be called repeatedly on one input stream`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x61, 0x62])
  let session = await makeSession(device)

  let first = try await session.nextEvent()
  let second = try await session.nextEvent()

  expectNoDifference(first, .character("a"))
  expectNoDifference(second, .character("b"))
}

@Test
func `pending event read cancellation preserves the next input`() async throws {
  let (bytes, continuation) = AsyncStream.makeStream(of: UInt8.self)
  let session = TerminalSession(
    io: PlatformIO(
      terminalDevice: TerminalDevice(
        bytes: { bytes },
        size: { TerminalSize(columns: 1, rows: 1) },
        write: { $0.count }
      )
    )
  )
  let pendingEvent = Task {
    try await session.nextEvent()
  }

  await Task.yield()
  pendingEvent.cancel()
  await #expect(throws: CancellationError.self) {
    try await pendingEvent.value
  }

  continuation.yield(0x61)
  let event = try await session.nextEvent()

  expectNoDifference(event, .character("a"))
}

@Test
func `event buffer cancellation preserves later values`() async throws {
  let buffer = AsyncEventBuffer<Int>()
  let pendingValue = Task {
    try await buffer.next()
  }

  while await buffer.waiterCount == 0 {
    await Task.yield()
  }

  pendingValue.cancel()
  await #expect(throws: CancellationError.self) {
    try await pendingValue.value
  }

  await buffer.yield(42)
  let value = try await buffer.next()

  expectNoDifference(value, 42)
}

@Test
func `event buffer delivers buffered values before waiting`() async throws {
  let buffer = AsyncEventBuffer<Int>()

  await buffer.yield(1)
  await buffer.yield(2)

  let first = try await buffer.next()
  let second = try await buffer.next()

  expectNoDifference(first, 1)
  expectNoDifference(second, 2)
}

@Test
func `event buffer delivers values fifo to multiple waiters`() async throws {
  let buffer = AsyncEventBuffer<Int>()
  let first = Task { try await buffer.next() }
  while await buffer.waiterCount == 0 {
    await Task.yield()
  }
  let second = Task { try await buffer.next() }
  while await buffer.waiterCount < 2 {
    await Task.yield()
  }

  await buffer.yield(1)
  await buffer.yield(2)

  let firstValue = try await first.value
  let secondValue = try await second.value

  expectNoDifference(firstValue, 1)
  expectNoDifference(secondValue, 2)
}

@Test
func `event buffer finish wakes waiters and is idempotent`() async throws {
  let buffer = AsyncEventBuffer<Int>()
  let pending = Task { try await buffer.next() }

  while await buffer.waiterCount == 0 {
    await Task.yield()
  }

  await buffer.finish()
  await buffer.finish()

  let pendingValue = try await pending.value
  let nextValue = try await buffer.next()

  expectNoDifference(pendingValue, nil)
  expectNoDifference(nextValue, nil)
}

@Test
func `event buffer ignores yielded values after finish`() async throws {
  let buffer = AsyncEventBuffer<Int>()

  await buffer.finish()
  await buffer.yield(1)

  let value = try await buffer.next()

  expectNoDifference(value, nil)
}

@Test
func `event buffer cancellation before waiter append throws cancellation`() async throws {
  let buffer = AsyncEventBuffer<Int>()
  let pending = Task {
    try await buffer.next()
  }

  pending.cancel()

  await #expect(throws: CancellationError.self) {
    try await pending.value
  }
  let waiterCount = await buffer.waiterCount
  expectNoDifference(waiterCount, 0)
}

@Test
func `next event throws input closed when input finishes without parsed event`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [])
  let session = await makeSession(device)

  await #expect(throws: PlatformIOError.inputClosed) {
    try await session.nextEvent()
  }
}

@Test
func `next event ignores control bytes before input closes`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x01, 0x02])
  let session = await makeSession(device)

  await #expect(throws: PlatformIOError.inputClosed) {
    try await session.nextEvent()
  }
}

@Test
func `draw propagates size errors`() async throws {
  let session = TerminalSession(
    io: PlatformIO(
      terminalDevice: TerminalDevice(
        size: { throw PlatformIOError.terminalSizeUnavailable(errno: .ioError) },
        write: { $0.count }
      )
    )
  )

  await #expect(throws: PlatformIOError.terminalSizeUnavailable(errno: .ioError)) {
    try await session.draw { _ in }
  }
}

@Test
func `draw propagates flush errors`() async throws {
  let session = TerminalSession(
    io: PlatformIO(
      terminalDevice: TerminalDevice(
        size: { TerminalSize(columns: 1, rows: 1) },
        write: { _ in throw PlatformIOError.writeFailed(errno: .ioError) }
      )
    )
  )

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await session.draw { frame in
      frame.write("x", at: TerminalPosition(column: 0, row: 0))
    }
  }
}

private func makeSession(_ device: InMemoryTerminalDevice) async -> TerminalSession {
  TerminalSession(io: PlatformIO(terminalDevice: await device.terminalDevice))
}

private enum TerminalSessionTestError: Error, Equatable {
  case bodyFailed
}

extension InMemoryTerminalDeviceEvent {
  fileprivate var isFlush: Bool {
    if case .flush = self {
      return true
    }
    return false
  }
}
