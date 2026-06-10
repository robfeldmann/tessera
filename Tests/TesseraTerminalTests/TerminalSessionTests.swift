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
