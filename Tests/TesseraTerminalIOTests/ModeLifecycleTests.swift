import CustomDump
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@testable import TesseraTerminalIO

@Test
func `enter records raw mode and alternate screen as active`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode, .altScreen])
  expectNoDifference(events, [.enableRawMode, .enableAltScreen])
}

@Test
func `enter rejects unsupported phase three modes`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: ModeLifecycleError.unsupportedModes([.mouseTracking])) {
    try await lifecycle.enter([.mouseTracking])
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(events, [])
}

@Test
func `enter rejects overlapping active modes`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode])

  await #expect(throws: ModeLifecycleError.modesAlreadyActive([.rawMode])) {
    try await lifecycle.enter([.rawMode, .altScreen])
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode])
  expectNoDifference(events, [.enableRawMode])
}

@Test
func `enter rolls back raw mode when alternate screen fails`() async throws {
  let device = LifecycleTestDevice(failure: .enableAltScreen)
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: LifecycleTestDevice.Failure.enableAltScreen) {
    try await lifecycle.enter([.rawMode, .altScreen])
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(events, [.enableRawMode, .enableAltScreen, .disableRawMode])
}

@Test
func `exit unwinds alternate screen before raw mode`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(
    events,
    [.enableRawMode, .enableAltScreen, .disableAltScreen, .disableRawMode]
  )
}

@Test
func `exit keeps cleaning up after alternate screen cleanup fails`() async throws {
  let device = LifecycleTestDevice(failure: .disableAltScreen)
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])

  await #expect(throws: LifecycleTestDevice.Failure.disableAltScreen) {
    try await lifecycle.exit()
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(
    events,
    [.enableRawMode, .enableAltScreen, .disableAltScreen, .disableRawMode]
  )
}

@Test
func `exit is idempotent after cleanup`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  try await lifecycle.exit()
  try await lifecycle.exit()

  let events = await device.events

  expectNoDifference(
    events,
    [.enableRawMode, .enableAltScreen, .disableAltScreen, .disableRawMode]
  )
}

@Test(
  .disabled(
    if: VirtualTerminal.isPlatformUnsupported,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."))
func `alternate screen bytes round trip through virtual terminal`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  try await lifecycle.exit()

  let terminal = VirtualTerminal.ghosttyOrPlatformUnsupported(cols: 4, rows: 2)
  terminal.feed(await device.bytes)

  expectNoDifference(terminal.cursorPosition(), .init(column: 0, row: 0))
  expectNoDifference(terminal.text(row: 0), "    ")
  expectNoDifference(terminal.text(row: 1), "    ")
}

private func makeLifecycle(_ device: LifecycleTestDevice) async -> ModeLifecycle {
  ModeLifecycle(io: PlatformIO(terminalDevice: await device.terminalDevice))
}

private actor LifecycleTestDevice {
  enum Event: Equatable, Sendable {
    case disableAltScreen
    case disableRawMode
    case enableAltScreen
    case enableRawMode
    case flush([UInt8])
  }

  enum Failure: Error, Equatable {
    case disableAltScreen
    case disableRawMode
    case enableAltScreen
    case enableRawMode
    case write
  }

  private let failure: Failure?
  private var recordedBytes: [UInt8] = []
  private var recordedEvents: [Event] = []

  var bytes: [UInt8] {
    recordedBytes
  }

  var events: [Event] {
    recordedEvents
  }

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      enterAltScreen: { try await self.enableAltScreen() },
      enterRawMode: { try await self.enableRawMode() },
      exitAltScreen: { try await self.disableAltScreen() },
      exitRawMode: { try await self.disableRawMode() },
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  init(failure: Failure? = nil) {
    self.failure = failure
  }

  private func disableAltScreen() throws {
    recordedEvents.append(.disableAltScreen)
    if failure == .disableAltScreen {
      throw Failure.disableAltScreen
    }
    // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
    recordedBytes.append(contentsOf: "\u{1B}[?1049l".utf8)
  }

  private func disableRawMode() throws {
    recordedEvents.append(.disableRawMode)
    if failure == .disableRawMode {
      throw Failure.disableRawMode
    }
  }

  private func enableAltScreen() throws {
    recordedEvents.append(.enableAltScreen)
    if failure == .enableAltScreen {
      throw Failure.enableAltScreen
    }
    // DEC private mode 1049: enter alternate screen, `CSI ? 1049 h`.
    recordedBytes.append(contentsOf: "\u{1B}[?1049h".utf8)
  }

  private func enableRawMode() throws {
    recordedEvents.append(.enableRawMode)
    if failure == .enableRawMode {
      throw Failure.enableRawMode
    }
  }

  private func write(_ bytes: ArraySlice<UInt8>) throws -> Int {
    let bytes = Array(bytes)
    recordedEvents.append(.flush(bytes))
    if failure == .write {
      throw Failure.write
    }
    recordedBytes.append(contentsOf: bytes)
    return bytes.count
  }
}
