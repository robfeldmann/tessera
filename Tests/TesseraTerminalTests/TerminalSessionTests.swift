import CustomDump
import TesseraTerminalCore
import TesseraTerminalInput
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
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: cursorVisible(true)
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `application configuration stores synchronized output policy`() {
  let configuration = TerminalApplicationConfiguration(
    modes: [.rawMode],
    synchronizedOutput: .disabled
  )

  expectNoDifference(configuration.modes, [.rawMode])
  expectNoDifference(configuration.synchronizedOutput, .disabled)
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
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: cursorVisible(true)
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
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
  let device = InMemoryTerminalDevice(inputBytes: [0x61])
  let session = await makeSession(device)

  let event = try await session.nextEvent()

  expectNoDifference(event, .key(Key(code: .character("a"))))
}

@Test
func `next event can be called repeatedly on one input stream`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x61, 0x62])
  let session = await makeSession(device)

  let first = try await session.nextEvent()
  let second = try await session.nextEvent()

  expectNoDifference(first, .key(Key(code: .character("a"))))
  expectNoDifference(second, .key(Key(code: .character("b"))))
}

@Test
func `events stream exposes parsed input events`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: Array("\u{1B}[A".utf8))
  let session = await makeSession(device)
  var iterator = session.events.makeAsyncIterator()

  let event = await iterator.next()

  expectNoDifference(event, .key(Key(code: .up)))
}

@Test
func `next event returns resize events from semantic stream`() async throws {
  let size = TerminalSize(columns: 80, rows: 24)
  let session = TerminalSession(
    io: PlatformIO(
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
  )

  let event = try await session.nextEvent()

  expectNoDifference(event, .resize(size))
}

@Test
func `pending event read cancellation preserves the next input`() async throws {
  let (bytes, continuation) = AsyncStream.makeStream(of: [UInt8].self)
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

  continuation.yield([0x61])
  let event = try await session.nextEvent()

  expectNoDifference(event, .key(Key(code: .character("a"))))
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
func `next event throws input closed when input finishes without event`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [])
  let session = await makeSession(device)

  await #expect(throws: PlatformIOError.inputClosed) {
    try await session.nextEvent()
  }
}

@Test
func `next event returns control key events`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x01, 0x02])
  let session = await makeSession(device)

  let first = try await session.nextEvent()
  let second = try await session.nextEvent()

  expectNoDifference(first, .key(Key(code: .character("A"), modifiers: .control)))
  expectNoDifference(second, .key(Key(code: .character("B"), modifiers: .control)))
}

@Test
func `draw honors synchronized output policy`() async throws {
  let enabledDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let enabledSession = await makeSession(enabledDevice, synchronizedOutput: .enabled)
  let disabledDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let disabledSession = await makeSession(disabledDevice, synchronizedOutput: .disabled)

  try await enabledSession.draw { _ in }
  try await disabledSession.draw { _ in }

  let enabledBytes = await enabledDevice.bytes
  let disabledBytes = await disabledDevice.bytes

  let syncEnter = Array("\u{1B}[?2026h".utf8)
  let syncExit = Array("\u{1B}[?2026l".utf8)

  #expect(enabledBytes.starts(with: syncEnter))
  #expect(containsBytes(syncExit, in: enabledBytes))
  #expect(disabledBytes.starts(with: syncEnter) == false)
  #expect(containsBytes(syncExit, in: disabledBytes) == false)
}

@Test
func `draw hides cursor when frame does not request a cursor position`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = await makeSession(device, synchronizedOutput: .disabled)

  try await session.draw { _ in }

  let bytes = await device.bytes
  #expect(bytes.suffix(6) == Array("\u{1B}[?25l".utf8)[...])
}

@Test
func `draw shows and moves cursor when frame requests a cursor position`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 3, rows: 2))
  let session = await makeSession(device, synchronizedOutput: .disabled)

  try await session.draw { frame in
    frame.setCursorPosition(TerminalPosition(column: 2, row: 1))
  }

  let bytes = await device.bytes
  expectNoDifference(bytes.suffix(12), Array("\u{1B}[?25h\u{1B}[2;3H".utf8)[...])
}

@Test
func `draw second frame emits only damage bytes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 3, rows: 1))
  let session = await makeSession(device, synchronizedOutput: .disabled)

  try await session.draw { frame in
    frame.write("abc", at: TerminalPosition(column: 0, row: 0))
  }
  try await session.draw { frame in
    frame.write("axc", at: TerminalPosition(column: 0, row: 0))
  }

  let events = await device.events
  let flushes = events.filter(\.isFlush).map(\.flushBytes)
  #expect(flushes.count == 2)
  #expect(flushes[1] == Array("\u{1B}[1;2Hx\u{1B}[0m\u{1B}[?25l".utf8))
}

@Test
func `draw does not write when body throws`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = await makeSession(device)

  await #expect(throws: TerminalSessionTestError.bodyFailed) {
    try await session.draw { _ in
      throw TerminalSessionTestError.bodyFailed
    }
  }

  let events = await device.events
  #expect(events.isEmpty)
}

@Test
func `invalidate renderer causes next draw to repaint`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = await makeSession(device, synchronizedOutput: .disabled)

  try await session.draw { frame in
    frame.write("x", at: TerminalPosition(column: 0, row: 0))
  }
  await session.invalidateRenderer()
  try await session.draw { frame in
    frame.write("x", at: TerminalPosition(column: 0, row: 0))
  }

  let events = await device.events
  let flushes = events.filter(\.isFlush).map(\.flushBytes)
  #expect(flushes.count == 2)
  #expect(flushes[1] == Array("\u{1B}[2J\u{1B}[1;1H\u{1B}[0mx\u{1B}[0m\u{1B}[?25l".utf8))
}

@Test
func `draw invalidates renderer after flush failure`() async throws {
  let device = FailOnceTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice)
  )

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await session.draw { frame in
      frame.write("x", at: TerminalPosition(column: 0, row: 0))
    }
  }
  try await session.draw { frame in
    frame.write("y", at: TerminalPosition(column: 0, row: 0))
  }

  let bytes = await device.bytes
  let eraseDisplayAll = Array("\u{1B}[2J".utf8)
  #expect(containsBytes(eraseDisplayAll, in: bytes))
  let bytesAfterFirstErase = Array(bytes.dropFirst(eraseDisplayAll.count))
  #expect(containsBytes(eraseDisplayAll, in: bytesAfterFirstErase))
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

private func makeSession(
  _ device: InMemoryTerminalDevice,
  synchronizedOutput: SynchronizedOutputPolicy = .enabled
) async -> TerminalSession {
  TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: synchronizedOutput
  )
}

private enum TerminalSessionTestError: Error, Equatable {
  case bodyFailed
}

private func terminalSessionEventLog(_ events: [InMemoryTerminalDeviceEvent]) -> String {
  events.map { event in
    switch event {
    case .enterAltScreen:
      "enterAltScreen"

    case .enterRawMode:
      "enterRawMode"

    case .exitAltScreen:
      "exitAltScreen"

    case .exitRawMode:
      "exitRawMode"

    case .flush(let bytes):
      "flush: \(terminalFlushName(bytes))"
    }
  }
  .joined(separator: "\n")
}

private func terminalFlushName(_ bytes: [UInt8]) -> String {
  if bytes == Array("\u{1B}[?25h".utf8) {
    return "cursorVisible(true)"
  }
  if bytes == Array("\u{1B}[?1004h".utf8) {
    return "enableFocusTracking(true)"
  }
  if bytes == Array("\u{1B}[?1004l".utf8) {
    return "enableFocusTracking(false)"
  }
  if bytes == Array("\u{1B}[?2004h".utf8) {
    return "enableBracketedPaste(true)"
  }
  if bytes == Array("\u{1B}[?2004l".utf8) {
    return "enableBracketedPaste(false)"
  }
  return String(describing: bytes)
}

private func containsBytes(_ needle: [UInt8], in haystack: [UInt8]) -> Bool {
  guard needle.isEmpty == false, haystack.count >= needle.count else {
    return false
  }

  return haystack.indices.contains { index in
    let endIndex = index + needle.count
    guard endIndex <= haystack.endIndex else {
      return false
    }
    return Array(haystack[index..<endIndex]) == needle
  }
}

private actor FailOnceTerminalDevice {
  private var shouldFail = true
  private var storedBytes: [UInt8] = []
  private let storedSize: TerminalSize

  var bytes: [UInt8] {
    storedBytes
  }

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      size: { self.storedSize },
      write: { try await self.write($0) }
    )
  }

  init(size: TerminalSize) {
    self.storedSize = size
  }

  private func write(_ bytes: ArraySlice<UInt8>) throws -> Int {
    if shouldFail {
      shouldFail = false
      throw PlatformIOError.writeFailed(errno: .ioError)
    }

    storedBytes.append(contentsOf: bytes)
    return bytes.count
  }
}

extension InMemoryTerminalDeviceEvent {
  fileprivate var flushBytes: [UInt8] {
    if case .flush(let bytes) = self {
      return bytes
    }
    return []
  }

  fileprivate var isFlush: Bool {
    if case .flush = self {
      return true
    }
    return false
  }
}
