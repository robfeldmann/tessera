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
func `enter enables cursor style after alt screen before bracketed paste`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)
  let cursorStyle = CursorStyle(
    shape: .steadyBar,
    color: CursorColor(red: 0x12, green: 0xAB, blue: 0xF0)
  )

  try await lifecycle.enter([
    .rawMode, .altScreen, .cursorStyle(cursorStyle), .bracketedPaste,
  ])

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(
    activeModes,
    [.rawMode, .altScreen, .cursorStyle(cursorStyle), .bracketedPaste]
  )
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 36 20 71 1B 5D 31 32 3B 23 31 32 41 42 46 30 1B 5C
    flush: 1B 5B 3F 32 30 30 34 68
    """
  }
}

@Test
func `exit resets cursor style before leaving alt screen and raw mode`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)
  let cursorStyle = CursorStyle(
    shape: .steadyBar,
    color: CursorColor(red: 0x12, green: 0xAB, blue: 0xF0)
  )

  try await lifecycle.enter([
    .rawMode, .altScreen, .cursorStyle(cursorStyle), .bracketedPaste,
  ])
  try await lifecycle.exit()

  let activeModes = await lifecycle.activeModes
  let events = await device.events

  expectNoDifference(activeModes, [])
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 36 20 71 1B 5D 31 32 3B 23 31 32 41 42 46 30 1B 5C
    flush: 1B 5B 3F 32 30 30 34 68
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3F 32 30 30 34 6C
    flush: 1B 5B 30 20 71 1B 5D 31 31 32 1B 5C
    disableAltScreen
    disableRawMode
    """
  }
}

@Test
func `shape-only cursor style emits shape bytes without color bytes`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode, .altScreen, .cursorStyle(CursorStyle(shape: .steadyBlock)),
  ])
  try await lifecycle.exit()

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  #expect(flushes.contains(cursorShapeSteadyBlockBytes))
  #expect(flushes.contains(cursorShapeResetBytes))
  #expect(!flushes.contains { $0 == cursorColorSetBytes })
  #expect(!flushes.contains { $0 == cursorColorResetBytes })
}

@Test
func `color-only cursor style emits color bytes without shape bytes`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([
    .rawMode, .altScreen, .cursorStyle(CursorStyle(color: cursorColor)),
  ])
  try await lifecycle.exit()

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  #expect(flushes.contains(cursorColorSetBytes))
  #expect(flushes.contains(cursorColorResetBytes))
  #expect(!flushes.contains { $0 == cursorShapeSteadyBlockBytes })
  #expect(!flushes.contains { $0 == cursorShapeResetBytes })
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
func `enter retains successful state when alternate screen fails`() async throws {
  let device = LifecycleTestDevice(failure: .enableAltScreen)
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: LifecycleTestDevice.Failure.enableAltScreen) {
    try await lifecycle.enter([.rawMode, .altScreen])
  }

  let activeModes = await lifecycle.activeModes
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode])
  expectNoDifference(possiblyActiveModes, [.altScreen])
  expectNoDifference(events, [.enableRawMode, .enableAltScreen])
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
func `enter pushes configured Kitty keyboard flags`() async throws {
  let device = LifecycleTestDevice()
  let flags: KittyKeyboardFlags = [
    .disambiguateEscapeCodes,
    .reportEventTypes,
    .reportAlternateKeys,
    .reportAllKeysAsEscapeCodes,
    .reportAssociatedText,
  ]
  let lifecycle = await makeLifecycle(device, kittyKeyboardFlags: flags)

  try await lifecycle.enter([.kittyKeyboard])

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  expectNoDifference(flushes, [Array("\u{1B}[>31u".utf8)])
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
func `apply switches cursor style and applying same style is no-op`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)
  let styleA = CursorStyle(shape: .steadyBlock, color: cursorColor)
  let styleB = CursorStyle(
    shape: .steadyBar,
    color: CursorColor(red: 0xFE, green: 0xDC, blue: 0xBA)
  )

  try await lifecycle.enter([.rawMode, .altScreen, .cursorStyle(styleA)])
  let eventsAfterEnter = await device.events

  try await lifecycle.apply(applicationModes: [.cursorStyle(styleA)])
  let eventsAfterNoOp = await device.events

  try await lifecycle.apply(applicationModes: [.cursorStyle(styleB)])
  let activeModes = await lifecycle.activeModes
  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  expectNoDifference(eventsAfterNoOp, eventsAfterEnter)
  expectNoDifference(activeModes, [.rawMode, .altScreen, .cursorStyle(styleB)])
  expectNoDifference(
    flushes,
    [
      cursorStyleABytes,
      cursorStyleResetBytes,
      cursorStyleBBytes,
    ]
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
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 3F 31 30 30 34 68
    flush: 1B 5B 3F 31 30 30 33 68 1B 5B 3F 31 30 30 36 68
    flush: 1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C
    flush: 1B 5B 3F 31 30 30 33 6C 1B 5B 3F 31 30 30 32 6C 1B 5B 3F 31 30 30 36 6C
    flush: 1B 5B 3F 31 30 30 34 6C
    disableAltScreen
    disableRawMode
    """
  }
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
func `exit retains failed teardown state while continuing cleanup`() async throws {
  let device = LifecycleTestDevice(failure: .disableAltScreen)
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])

  await #expect(throws: LifecycleTestDevice.Failure.disableAltScreen) {
    try await lifecycle.exit()
  }

  let activeModes = await lifecycle.activeModes
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting
  let events = await device.events

  expectNoDifference(activeModes, [.altScreen])
  expectNoDifference(possiblyActiveModes, [.altScreen])
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
func `focus enable failure retains successful and possible modes`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(2))
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])
  }

  let activeModes = await lifecycle.activeModes
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode, .altScreen, .bracketedPaste])
  expectNoDifference(possiblyActiveModes, [.focusEvents])
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
func `cursor enable failure retains successful and possible fixed modes`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(1))
  let lifecycle = await makeLifecycle(device)

  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.enter([
      .rawMode,
      .altScreen,
      .cursorStyle(CursorStyle(shape: .steadyBlock, color: cursorColor)),
      .bracketedPaste,
    ])
  }

  let activeModes = await lifecycle.activeModes
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode, .altScreen])
  expectNoDifference(
    possiblyActiveModes,
    [.cursorStyle(CursorStyle(shape: .steadyBlock, color: cursorColor))]
  )
  assertInlineSnapshot(of: lifecycleEventLog(events), as: .lines) {
    """
    enableRawMode
    enableAltScreen
    flush: 1B 5B 32 20 71 1B 5D 31 32 3B 23 31 32 41 42 46 30 1B 5C
    """
  }
}

@Test
func `cursor styling request succeeds without capability responses`() async throws {
  let device = LifecycleTestDevice()
  let lifecycle = await makeLifecycle(device)
  let cursorStyle = CursorStyle(shape: .steadyBlock, color: cursorColor)

  try await lifecycle.enter([.rawMode, .altScreen, .cursorStyle(cursorStyle)])

  let activeModes = await lifecycle.activeModes

  expectNoDifference(activeModes, [.rawMode, .altScreen, .cursorStyle(cursorStyle)])
}

@Test
func `mouse enable failure retains successful and possible protocol modes`() async throws {
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
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting
  let events = await device.events

  expectNoDifference(activeModes, [.rawMode, .altScreen, .bracketedPaste, .focusEvents])
  expectNoDifference(possiblyActiveModes, [.mouseTracking(.anyEvent)])
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
func `apply discards stale partial enable suffix before exit recovery`() async throws {
  let device = LifecycleTestDevice(failure: .partialWriteThenFailOnAttempt(1, 4))
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.apply(applicationModes: [.focusEvents])
  }
  try await lifecycle.exit()

  let bytes = await device.bytes
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting

  expectNoDifference(possiblyActiveModes, [])
  #expect(!bytes.containsSubsequence(focusEnableBytes))
  #expect(bytes.containsSubsequence(kittyGraphicsDeleteAllBytes))
  #expect(bytes.containsSubsequence(focusDisableBytes))
}

@Test
func `failed Kitty push remains possible and exits with pop`() async throws {
  let device = LifecycleTestDevice(failure: .writeOnAttempt(1))
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  await #expect(throws: LifecycleTestDevice.Failure.write) {
    try await lifecycle.apply(applicationModes: [.kittyKeyboard])
  }
  let possiblyActiveModes = await lifecycle.possiblyActiveModesForTesting
  expectNoDifference(possiblyActiveModes, [.kittyKeyboard])

  try await lifecycle.exit()

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  expectNoDifference(
    flushes,
    [kittyKeyboardPushBytes, kittyGraphicsDeleteAllBytes, kittyKeyboardPopBytes]
  )
}

@Test
func `failed exit keeps cleanup belief until a successful retry`() async throws {
  let device = LifecycleTestDevice(failure: .disableAltScreenOnce)
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  await #expect(throws: LifecycleTestDevice.Failure.disableAltScreen) {
    try await lifecycle.exit()
  }
  let activeModesAfterFailure = await lifecycle.activeModes
  let possiblyActiveModesAfterFailure = await lifecycle.possiblyActiveModesForTesting
  expectNoDifference(activeModesAfterFailure, [.altScreen])
  expectNoDifference(possiblyActiveModesAfterFailure, [.altScreen])

  try await lifecycle.exit()

  let activeModesAfterRetry = await lifecycle.activeModes
  let possiblyActiveModesAfterRetry = await lifecycle.possiblyActiveModesForTesting
  expectNoDifference(activeModesAfterRetry, [])
  expectNoDifference(possiblyActiveModesAfterRetry, [])
}

@Test
func `concurrent apply transitions serialize`() async throws {
  let device = LifecycleTestDevice(suspendWriteOnAttempt: 1)
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  let first = Task {
    try await lifecycle.apply(applicationModes: [.focusEvents])
  }
  await device.waitForWriteSuspension()
  let second = Task {
    try await lifecycle.apply(applicationModes: [.focusEvents, .mouseTracking(.anyEvent)])
  }
  await Task.yield()

  let flushesBeforeResume = await device.events.filter(\.isFlush).map(\.flushBytes)
  expectNoDifference(flushesBeforeResume, [focusEnableBytes])

  await device.resumeWrite()
  try await first.value
  try await second.value

  let activeModes = await lifecycle.activeModes
  expectNoDifference(
    activeModes,
    [.rawMode, .altScreen, .focusEvents, .mouseTracking(.anyEvent)]
  )
}

@Test
func `cancelled queued transition does not mutate lifecycle state`() async throws {
  let device = LifecycleTestDevice(suspendWriteOnAttempt: 1)
  let lifecycle = await makeLifecycle(device)

  try await lifecycle.enter([.rawMode, .altScreen])
  let first = Task {
    try await lifecycle.apply(applicationModes: [.focusEvents])
  }
  await device.waitForWriteSuspension()
  let queued = Task {
    try await lifecycle.apply(applicationModes: [.focusEvents, .mouseTracking(.anyEvent)])
  }
  await Task.yield()
  queued.cancel()

  await device.resumeWrite()
  try await first.value
  await #expect(throws: CancellationError.self) {
    try await queued.value
  }

  let activeModes = await lifecycle.activeModes
  expectNoDifference(activeModes, [.rawMode, .altScreen, .focusEvents])
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
    "Ghostty virtual terminal support is unavailable in this build."
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

@Suite
struct ModeLifecycleEmergencyCleanupTests {
  @Test
  func `cleanup bytes disable focus before bracketed paste`() async throws {
    let registry = TestCleanupRegistry()
    let lifecycle = await makeLifecycle(
      LifecycleTestDevice(cleanupState: testCleanupState()),
      cleanupRegistry: registry.client
    )

    try await lifecycle.enter([.rawMode, .altScreen, .bracketedPaste, .focusEvents])

    let bytes = await registry.teardownBytes
    assertInlineSnapshot(of: wrappedHex(bytes, bytesPerLine: 16), as: .lines) {
      """
      1B 5F 47 61 3D 64 2C 64 3D 41 1B 5C 1B 5B 3F 31
      30 30 34 6C 1B 5B 3F 32 30 30 34 6C 1B 5B 3F 31
      30 34 39 6C 1B 5B 3F 32 35 68
      """
    }
  }

  @Test(arguments: [MouseTracking.buttonEvents, .anyEvent])
  func `cleanup bytes defensively disable mouse tracking for either granularity`(
    _ granularity: MouseTracking
  ) async throws {
    let registry = TestCleanupRegistry()
    let lifecycle = await makeLifecycle(
      LifecycleTestDevice(cleanupState: testCleanupState()),
      cleanupRegistry: registry.client
    )

    try await lifecycle.enter([
      .rawMode,
      .altScreen,
      .bracketedPaste,
      .focusEvents,
      .mouseTracking(granularity),
    ])

    let bytes = await registry.teardownBytes
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

  @Test
  func `cleanup bytes pop kitty keyboard before mouse focus and paste`() async throws {
    let registry = TestCleanupRegistry()
    let lifecycle = await makeLifecycle(
      LifecycleTestDevice(cleanupState: testCleanupState()),
      cleanupRegistry: registry.client
    )

    try await lifecycle.enter([
      .rawMode,
      .altScreen,
      .bracketedPaste,
      .focusEvents,
      .mouseTracking(.anyEvent),
      .kittyKeyboard,
    ])

    let bytes = await registry.teardownBytes
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

  @Test
  func `failed cursor enable installs cleanup before output`() async throws {
    let registry = TestCleanupRegistry()
    let lifecycle = await makeLifecycle(
      LifecycleTestDevice(
        cleanupState: testCleanupState(),
        failure: .writeOnAttempt(1)
      ),
      cleanupRegistry: registry.client
    )

    await #expect(throws: LifecycleTestDevice.Failure.write) {
      try await lifecycle.enter([
        .rawMode,
        .altScreen,
        .cursorStyle(CursorStyle(shape: .steadyBlock, color: cursorColor)),
      ])
    }

    let bytes = await registry.teardownBytes
    expectNoDifference(
      bytes,
      kittyGraphicsDeleteAllBytes
        + cursorShapeResetBytes
        + cursorColorResetBytes
        + Array("\u{1B}[?1049l".utf8)
        + Array("\u{1B}[?25h".utf8)
    )
  }

  @Test
  func `failed exit retains emergency cleanup until retry succeeds`() async throws {
    let registry = TestCleanupRegistry()
    let lifecycle = await makeLifecycle(
      LifecycleTestDevice(
        cleanupState: testCleanupState(),
        failure: .disableAltScreenOnce
      ),
      cleanupRegistry: registry.client
    )

    try await lifecycle.enter([.rawMode, .altScreen])
    await #expect(throws: LifecycleTestDevice.Failure.disableAltScreen) {
      try await lifecycle.exit()
    }

    let retainedBytes = await registry.teardownBytes
    expectNoDifference(
      retainedBytes,
      kittyGraphicsDeleteAllBytes
        + Array("\u{1B}[?1049l".utf8)
        + Array("\u{1B}[?25h".utf8)
    )

    try await lifecycle.exit()
    #expect(await registry.hasRegistration == false)
  }

  @Test
  func `cleanup bytes reset only requested cursor style facets`() async throws {
    let shapeRegistry = TestCleanupRegistry()
    let shapeLifecycle = await makeLifecycle(
      LifecycleTestDevice(cleanupState: testCleanupState()),
      cleanupRegistry: shapeRegistry.client
    )
    try await shapeLifecycle.enter([
      .rawMode,
      .altScreen,
      .cursorStyle(CursorStyle(shape: .steadyBlock)),
    ])
    let shapeBytes = await shapeRegistry.teardownBytes

    let colorRegistry = TestCleanupRegistry()
    let colorLifecycle = await makeLifecycle(
      LifecycleTestDevice(cleanupState: testCleanupState()),
      cleanupRegistry: colorRegistry.client
    )
    try await colorLifecycle.enter([
      .rawMode,
      .altScreen,
      .cursorStyle(CursorStyle(color: cursorColor)),
    ])
    let colorBytes = await colorRegistry.teardownBytes

    let unownedRegistry = TestCleanupRegistry()
    let unownedLifecycle = await makeLifecycle(
      LifecycleTestDevice(cleanupState: testCleanupState()),
      cleanupRegistry: unownedRegistry.client
    )
    try await unownedLifecycle.enter([.rawMode, .altScreen])
    let unownedBytes = await unownedRegistry.teardownBytes

    #expect(shapeBytes.containsSubsequence(cursorShapeResetBytes))
    #expect(!shapeBytes.containsSubsequence(cursorColorResetBytes))
    #expect(colorBytes.containsSubsequence(cursorColorResetBytes))
    #expect(!colorBytes.containsSubsequence(cursorShapeResetBytes))
    #expect(!unownedBytes.containsSubsequence(cursorShapeResetBytes))
    #expect(!unownedBytes.containsSubsequence(cursorColorResetBytes))
  }
}

private func testCleanupState() -> PlatformCleanupState {
  #if os(macOS) || os(Linux)
    PlatformCleanupState(
      inputFileDescriptor: -1,
      outputFileDescriptor: -1
    ) { nil }
  #elseif os(Windows)
    PlatformCleanupState(
      inputHandle: 0,
      outputHandle: 0
    ) { .init(input: 0, output: 0) }
  #else
    .unavailable
  #endif
}

private func makeLifecycle(
  _ device: LifecycleTestDevice,
  kittyKeyboardFlags: KittyKeyboardFlags = .tesseraDefault,
  cleanupRegistry: CleanupRegistryClient = .disabled
) async -> ModeLifecycle {
  ModeLifecycle(
    io: PlatformIO(
      terminalDevice: await device.terminalDevice,
      cleanupRegistry: cleanupRegistry
    ),
    kittyKeyboardFlags: kittyKeyboardFlags
  )
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
    case disableAltScreenOnce
    case disableRawMode
    case enableAltScreen
    case enableRawMode
    case write
    case writeOnAttempt(Int)
    case partialWriteThenFailOnAttempt(Int, Int)
  }

  private let cleanupState: PlatformCleanupState
  private let failure: Failure?
  private let suspendWriteOnAttempt: Int?
  private var didFailAltScreen = false
  private var didSuspendWrite = false
  private var recordedBytes: [UInt8] = []
  private var recordedEvents: [Event] = []
  private var suspendedWriteContinuation: CheckedContinuation<Void, Never>?
  private var suspensionObserver: CheckedContinuation<Void, Never>?
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
    failure: Failure? = nil,
    suspendWriteOnAttempt: Int? = nil
  ) {
    self.cleanupState = cleanupState
    self.failure = failure
    self.suspendWriteOnAttempt = suspendWriteOnAttempt
  }

  private func disableAltScreen() throws {
    recordedEvents.append(.disableAltScreen)
    if failure == .disableAltScreen {
      throw Failure.disableAltScreen
    }
    if failure == .disableAltScreenOnce, !didFailAltScreen {
      didFailAltScreen = true
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

  func waitForWriteSuspension() async {
    guard !didSuspendWrite else {
      return
    }
    await withCheckedContinuation { continuation in
      suspensionObserver = continuation
    }
  }

  func resumeWrite() {
    suspendedWriteContinuation?.resume()
    suspendedWriteContinuation = nil
  }

  private func write(_ bytes: ArraySlice<UInt8>) async throws -> Int {
    let bytes = Array(bytes)
    recordedEvents.append(.flush(bytes))
    writeCount += 1

    if suspendWriteOnAttempt == writeCount {
      didSuspendWrite = true
      suspensionObserver?.resume()
      suspensionObserver = nil
      await withCheckedContinuation { continuation in
        suspendedWriteContinuation = continuation
      }
    }

    if case .partialWriteThenFailOnAttempt(let attempt, let count) = failure {
      if writeCount == attempt {
        recordedBytes.append(contentsOf: bytes.prefix(count))
        return count
      }
      if writeCount == attempt + 1 {
        throw Failure.write
      }
    }
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
private let cursorColor = CursorColor(red: 0x12, green: 0xAB, blue: 0xF0)
private let cursorShapeSteadyBlockBytes =
  ControlSequence.setCursorShape(.steadyBlock).bytes
private let cursorShapeResetBytes = ControlSequence.setCursorShape(.defaultUserShape).bytes
private let cursorColorSetBytes = ControlSequence.setCursorColor(cursorColor).bytes
private let cursorColorResetBytes = ControlSequence.resetCursorColor.bytes
private let cursorStyleABytes =
  cursorShapeSteadyBlockBytes + cursorColorSetBytes
private let cursorStyleBBytes =
  ControlSequence.setCursorShape(.steadyBar).bytes
  + ControlSequence.setCursorColor(CursorColor(red: 0xFE, green: 0xDC, blue: 0xBA)).bytes
private let cursorStyleResetBytes =
  cursorShapeResetBytes + cursorColorResetBytes

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

extension Array where Element == UInt8 {
  fileprivate func containsSubsequence(_ needle: [UInt8]) -> Bool {
    guard !needle.isEmpty else {
      return true
    }

    return indices.contains { index in
      self[index...].starts(with: needle)
    }
  }
}
