import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
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
  let unsupportedModes: Set<ModeLifecycle.Mode> = [
    .focusEvents,
    .kittyKeyboard,
    .mouseTracking,
  ]

  await #expect(throws: ModeLifecycleError.unsupportedModes(unsupportedModes)) {
    try await lifecycle.enter(unsupportedModes)
  }

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  expectNoDifference(events, [])
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
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
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

  try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste])
  try await lifecycle.exit()
  try await lifecycle.exit()

  let events = await device.events

  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5B 3F 32 30 30 34 6C
    disableAltScreen
    disableRawMode
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
    func `cleanup bytes disable bracketed paste before alt screen`() async throws {
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

      try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste])
      CleanupRegistry.performEmergencyCleanupForTesting()
      pipe.closeWriteDescriptor()

      let bytes = try pipe.readAll()
      assertInlineSnapshot(of: hex(bytes), as: .lines) {
        """
        1B 5B 3F 32 30 30 34 6C 1B 5B 3F 31 30 34 39 6C 1B 5B 3F 32 35 68
        """
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
  }

  enum Failure: Error, Equatable {
    case disableAltScreen
    case disableRawMode
    case enableAltScreen
    case enableRawMode
    case write
  }

  private let cleanupState: PlatformCleanupState
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
    if failure == .write {
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

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
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
