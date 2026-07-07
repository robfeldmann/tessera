import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import TesseraTerminalANSI
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
func `enter allows bracketed paste and enables it after alternate screen`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode, .altScreen, .bracketedPaste])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    """
  }
}

@Test
func `enter enables focus tracking after bracketed paste`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode, .altScreen, .bracketedPaste, .focusEvents])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    """
  }
}

@Test
func `enter enables button-event mouse tracking after focus tracking`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(.buttonEvents),
  ])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(
    activeModes,
    [.rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking(.buttonEvents)]
  )
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 32 68 1B 5B 3F 31 30 30 36 68
    """
  }
}

@Test
func `enter enables any-event mouse tracking after focus tracking`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(.anyEvent),
  ])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(
    activeModes,
    [.rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking(.anyEvent)]
  )
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    """
  }
}

@Test
func `enter normalizes mouse granularities to any-event once`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(.buttonEvents),
    .mouseTracking(.anyEvent),
  ])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(
    activeModes,
    [.rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking(.anyEvent)]
  )
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    """
  }
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
func `exit deletes kitty graphics before alternate screen and raw mode`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(
    events,
    [
      .enableRawMode,
      .enableAltScreen,
      .flush(kittyGraphicsDeleteAllBytes),
      .disableAltScreen,
      .disableRawMode,
    ]
  )
}

@Test
func `graphics cleanup flush failure does not block mode teardown`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(1))
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(
    events,
    [
      .enableRawMode,
      .enableAltScreen,
      .flush(kittyGraphicsDeleteAllBytes),
      .disableAltScreen,
      .disableRawMode,
    ]
  )
}

@Test
func `exit disables bracketed paste before other cleanup`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
}

@Test
func `exit disables focus tracking before bracketed paste`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3F 31 30 30 34 6C
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
}

@Test
func `enter enables kitty keyboard after mouse tracking`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(.anyEvent),
    .kittyKeyboard,
  ])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(
    activeModes,
    [
      .rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking(.anyEvent),
      .kittyKeyboard,
    ]
  )
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    flush: 1B 5B 3E 37 75
    """
  }
}

@Test
func `exit pops kitty keyboard before mouse focus and paste`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(.anyEvent),
    .kittyKeyboard,
  ])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    flush: 1B 5B 3E 37 75
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3C 75
    flush: 1B 5B 3F 31 30 30 33 6C 1B 5B 3F 31 30 30 32 6C 1B 5B 3F 31 30 30 36 6C
    flush: 1B 5B 3F 31 30 30 34 6C
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
}

@Test
func `apply enables and disables application modes in deterministic order`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste])
  try await lifecycle.apply(applicationModes: [
    .focusEvents, .mouseTracking(.buttonEvents), .kittyKeyboard,
  ])
  try await lifecycle.apply(applicationModes: [
    .focusEvents, .mouseTracking(.buttonEvents), .kittyKeyboard,
  ])
  try await lifecycle.apply(applicationModes: [.bracketedPaste])

  let activeModes = await lifecycle.activeModes
  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  expectNoDifference(activeModes, [.rawMode, .altScreen, .bracketedPaste])
  expectNoDifference(
    flushes,
    [
      bracketedPasteEnableBytes,
      bracketedPasteDisableBytes,
      focusEnableBytes,
      mouseEnableBytes(.buttonEvents),
      kittyKeyboardPushBytes,
      kittyKeyboardPopBytes,
      mouseDisableBytes,
      focusDisableBytes,
      bracketedPasteEnableBytes,
    ]
  )
}

@Test
func `apply switches mouse tracking granularity`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .mouseTracking(.buttonEvents)])
  try await lifecycle.apply(applicationModes: [.mouseTracking(.anyEvent)])

  let activeModes = await lifecycle.activeModes
  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  expectNoDifference(activeModes, [.rawMode, .altScreen, .mouseTracking(.anyEvent)])
  expectNoDifference(
    flushes,
    [mouseEnableBytes(.buttonEvents), mouseDisableBytes, mouseEnableBytes(.anyEvent)]
  )
}

@Test
func `apply rejects session fixed modes`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])

  await #expect(throws: ModeLifecycleError.unsupportedModes([.rawMode, .altScreen])) {
    try await lifecycle.apply(applicationModes: [.rawMode, .altScreen])
  }
}

@Test
func `apply failure leaves exit safe for succeeded operations`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(2))
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.apply(applicationModes: [.focusEvents, .mouseTracking(.anyEvent)])
  }
  try await lifecycle.exit()

  let events = await device.events
  // swiftlint:disable line_length
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3F 31 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
  // swiftlint:enable line_length
}

@Test(arguments: [MouseTracking.buttonEvents, .anyEvent])
func `exit disables mouse before focus`(_ granularity: MouseTracking) async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(granularity),
  ])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events
  let flushes = events.filter(\.isFlush).map(\.flushBytes)

  expectNoDifference(activeModes, [])
  expectNoDifference(
    flushes,
    [
      bracketedPasteEnableBytes,
      focusEnableBytes,
      mouseEnableBytes(granularity),
      kittyGraphicsDeleteAllBytes,
      mouseDisableBytes,
      focusDisableBytes,
      bracketedPasteDisableBytes,
    ]
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
    [
      .enableRawMode,
      .enableAltScreen,
      .flush(kittyGraphicsDeleteAllBytes),
      .disableAltScreen,
      .disableRawMode,
    ]
  )
}

@Test
func `enter rolls back optional modes when focus enable fails`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(2))
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
}

@Test
func `enter rolls back protocol modes when mouse enable fails`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(3))
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.enter([
      .rawMode,
      .altScreen,
      .bracketedPaste,
      .focusEvents,
      .mouseTracking(.anyEvent),
    ])
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    flush: 1B 5B 3F 31 30 30 34 6C
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
}

@Test
func `exit is idempotent after focus cleanup`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])
  try await lifecycle.exit()
  try await lifecycle.exit()

  let events = await device.events

  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3F 31 30 30 34 6C
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    """
  }
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Windows snapshot coverage is deferred until libghostty-vt builds on Windows."
  )
)
func `alternate screen bytes round trip through virtual terminal`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  try await lifecycle.exit()

  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)
  terminal.feed(await device.bytes)

  expectNoDifference(terminal.cursorPosition(), .init(column: 0, row: 0))
  expectNoDifference(terminal.text(row: 0), "    ")
  expectNoDifference(terminal.text(row: 1), "    ")
}

#if os(macOS) || os(Linux)
  @Suite(.serialized)
  struct ModeLifecycleEmergencyCleanupTests {
    @Test
    func `cleanup bytes disable focus before bracketed paste`() async throws {
      try await CleanupRegistryTestIsolation.withExclusiveAccess {
        let pipe = try LifecycleCleanupPipe()
        defer {
          CleanupRegistry.clear()
          pipe.closeAll()
        }
        let device = LifecycleTestDevice(
          cleanupState: PlatformCleanupState(
            inputFileDescriptor: -1,
            outputFileDescriptor: pipe.writeDescriptor
          ) { nil }
        )
        let lifecycle = await makeLifecycle(device)

        try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])
        CleanupRegistry.performEmergencyCleanupForTesting()
        pipe.closeWriteDescriptor()

        let bytes = try pipe.readAll()
        assertInlineSnapshot(of: wrappedHex(bytes, bytesPerLine: 16), as: .lines) {
          """
          1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C 1B 5B 3F 31
          30 30 34 6C 1B 5B 3F 32 30 30 34 6C 1B 5B 3F 31
          30 34 39 6C 1B 5B 3F 32 35 68
          """
        }
      }
    }

    @Test(arguments: [MouseTracking.buttonEvents, .anyEvent])
    func `cleanup bytes defensively disable mouse tracking for either granularity`(
      _ granularity: MouseTracking
    ) async throws {
      try await CleanupRegistryTestIsolation.withExclusiveAccess {
        let pipe = try LifecycleCleanupPipe()
        defer {
          CleanupRegistry.clear()
          pipe.closeAll()
        }
        let device = LifecycleTestDevice(
          cleanupState: PlatformCleanupState(
            inputFileDescriptor: -1,
            outputFileDescriptor: pipe.writeDescriptor
          ) { nil }
        )
        let lifecycle = await makeLifecycle(device)

        try await lifecycle.enter([
          .rawMode,
          .altScreen,
          .bracketedPaste,
          .focusEvents,
          .mouseTracking(granularity),
        ])
        CleanupRegistry.performEmergencyCleanupForTesting()
        pipe.closeWriteDescriptor()

        let bytes = try pipe.readAll()
        expectNoDifference(
          bytes,
          kittyGraphicsDeleteAllBytes
            + mouseDisableBytes
            + focusDisableBytes
            + bracketedPasteDisableBytes
            + Array("\u{1B}[?1049l".utf8)
            + Array("\u{1B}[?25h".utf8)
        )
      }
    }

    @Test
    func `cleanup bytes pop kitty keyboard before mouse focus and paste`() async throws {
      try await CleanupRegistryTestIsolation.withExclusiveAccess {
        let pipe = try LifecycleCleanupPipe()
        defer {
          CleanupRegistry.clear()
          pipe.closeAll()
        }
        let device = LifecycleTestDevice(
          cleanupState: PlatformCleanupState(
            inputFileDescriptor: -1,
            outputFileDescriptor: pipe.writeDescriptor
          ) { nil }
        )
        let lifecycle = await makeLifecycle(device)

        try await lifecycle.enter([
          .rawMode,
          .altScreen,
          .bracketedPaste,
          .focusEvents,
          .mouseTracking(.anyEvent),
          .kittyKeyboard,
        ])
        CleanupRegistry.performEmergencyCleanupForTesting()
        pipe.closeWriteDescriptor()

        let bytes = try pipe.readAll()
        expectNoDifference(
          bytes,
          kittyGraphicsDeleteAllBytes
            + kittyKeyboardPopBytes
            + mouseDisableBytes
            + focusDisableBytes
            + bracketedPasteDisableBytes
            + Array("\u{1B}[?1049l".utf8)
            + Array("\u{1B}[?25h".utf8)
        )
      }
    }
  }
#endif

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

    var flushBytes: [UInt8] {
      if case .flush(let bytes) = self {
        return bytes
      }
      return []
    }

    var isFlush: Bool {
      if case .flush = self {
        return true
      }
      return false
    }
  }

  enum Failure: Error, Equatable {
    case disableAltScreen
    case disableRawMode
    case enableAltScreen
    case enableRawMode
    case write
    case writeOnAttempt(Int)
  }

  private let cleanupState: PlatformCleanupState
  private let failure: Failure?
  private var recordedBytes: [UInt8] = []
  private var recordedEvents: [Event] = []
  private var writeCount = 0

  var bytes: [UInt8] {
    recordedBytes
  }

  var events: [Event] {
    recordedEvents
  }

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      cleanupState: cleanupState,
      enterAltScreen: { try await self.enableAltScreen() },
      enterRawMode: { try await self.enableRawMode() },
      exitAltScreen: { try await self.disableAltScreen() },
      exitRawMode: { try await self.disableRawMode() },
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  init(
    cleanupState: PlatformCleanupState = .unavailable,
    failure: Failure? = nil
  ) {
    self.cleanupState = cleanupState
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
    writeCount += 1
    if failure == .write || failure == .writeOnAttempt(writeCount) {
      throw Failure.write
    }
    recordedBytes.append(contentsOf: bytes)
    return bytes.count
  }
}

private func lifecycleEventLog(_ events: [LifecycleTestDevice.Event]) -> String {
  events.map { event in
    switch event {
    case .disableAltScreen:
      "disableAltScreen"

    case .disableRawMode:
      "disableRawMode"

    case .enableAltScreen:
      "enableAltScreen"

    case .enableRawMode:
      "enableRawMode"

    case .flush(let bytes):
      "flush: \(hex(bytes))"
    }
  }
  .joined(separator: "\n")
}

private let bracketedPasteEnableBytes = Array("\u{1B}[?2004h".utf8)
private let bracketedPasteDisableBytes = Array("\u{1B}[?2004l".utf8)
private let focusEnableBytes = Array("\u{1B}[?1004h".utf8)
private let focusDisableBytes = Array("\u{1B}[?1004l".utf8)
private let mouseDisableBytes =
  Array("\u{1B}[?1003l\u{1B}[?1002l\u{1B}[?1006l".utf8)
private let kittyKeyboardPushBytes = Array("\u{1B}[>7u".utf8)
private let kittyKeyboardPopBytes = Array("\u{1B}[<u".utf8)
private let kittyGraphicsDeleteAllBytes = Array("\u{1B}_Ga=d,d=A\u{1B}\\".utf8)

private func mouseEnableBytes(_ granularity: MouseTracking) -> [UInt8] {
  switch granularity {
  case .anyEvent:
    Array("\u{1B}[?1003h\u{1B}[?1006h".utf8)
  case .buttonEvents:
    Array("\u{1B}[?1002h\u{1B}[?1006h".utf8)
  }
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}

private func wrappedHex(_ bytes: [UInt8], bytesPerLine: Int) -> String {
  stride(from: bytes.startIndex, to: bytes.endIndex, by: bytesPerLine)
    .map { index in
      let end =
        bytes.index(index, offsetBy: bytesPerLine, limitedBy: bytes.endIndex)
        ?? bytes.endIndex
      return hex(Array(bytes[index..<end]))
    }
    .joined(separator: "\n")
}

#if os(macOS) || os(Linux)
  private struct LifecycleCleanupReadError: Error, Equatable, CustomStringConvertible {
    let errno: CInt

    var description: String {
      "read failed while draining lifecycle cleanup pipe (errno: \(errno))"
    }
  }

  private final class LifecycleCleanupPipe: @unchecked Sendable {
    private var descriptors: [CInt] = [-1, -1]

    var writeDescriptor: CInt {
      descriptors[1]
    }

    init() throws {
      guard pipe(&descriptors) == 0 else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
    }

    func closeAll() {
      if descriptors[0] >= 0 {
        close(descriptors[0])
        descriptors[0] = -1
      }
      closeWriteDescriptor()
    }

    func closeWriteDescriptor() {
      if descriptors[1] >= 0 {
        close(descriptors[1])
        descriptors[1] = -1
      }
    }

    func readAll() throws -> [UInt8] {
      var bytes: [UInt8] = []
      var buffer = [UInt8](repeating: 0, count: 32)

      while true {
        let capacity = buffer.count
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
          read(descriptors[0], pointer.baseAddress, capacity)
        }

        if count > 0 {
          bytes.append(contentsOf: buffer.prefix(count))
        } else if count == 0 {
          return bytes
        } else if errno == EINTR {
          continue
        } else {
          throw LifecycleCleanupReadError(errno: errno)
        }
      }
    }
  }
#endif
