import CustomDump
import TesseraTerminalANSI
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
    io: io,
    environment: [:]
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
      flush: deleteKittyGraphicsAll
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `application terminal exposes cursor styling and default style`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let cursorStyle = CursorStyle(shape: .steadyBlock)
  let configuration = TerminalApplicationConfiguration(
    cursorStyling: .enabled(default: cursorStyle)
  )
  var observedPolicy: CursorStylingPolicy?
  var observedStyle: CursorStyle?

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    observedPolicy = session.cursorStyling
    observedStyle = session.effectiveCursorStyle
  }

  let events = await device.events

  expectNoDifference(observedPolicy, .enabled(default: cursorStyle))
  expectNoDifference(observedStyle, cursorStyle)
  #expect(events.contains { $0.flushBytes == cursorShapeSteadyBlockBytes })
}

@Test
func `set cursor style overrides then restores the default`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let defaultStyle = CursorStyle(shape: .steadyBlock)
  let overrideStyle = CursorStyle(shape: .steadyBar, color: cursorColor)
  let configuration = TerminalApplicationConfiguration(
    cursorStyling: .enabled(default: defaultStyle)
  )
  var effectiveAfterOverride: CursorStyle?
  var effectiveAfterRestore: CursorStyle?

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    try await session.setCursorStyle(overrideStyle)
    effectiveAfterOverride = session.effectiveCursorStyle
    try await session.setCursorStyle(defaultStyle)
    effectiveAfterRestore = session.effectiveCursorStyle
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  expectNoDifference(effectiveAfterOverride, overrideStyle)
  expectNoDifference(effectiveAfterRestore, defaultStyle)
  expectNoDifference(
    flushes,
    [
      cursorShapeSteadyBlockBytes,
      bracketedPasteEnableBytes,
      focusEnableBytes,
      cursorShapeResetBytes,
      cursorStyleOverrideBytes,
      cursorStyleResetBytes,
      cursorShapeSteadyBlockBytes,
      cursorVisibleBytes,
      kittyGraphicsDeleteAllBytes,
      focusDisableBytes,
      bracketedPasteDisableBytes,
      cursorShapeResetBytes,
    ]
  )
}

@Test
func `application threads configured Kitty flags into lifecycle and session state`()
  async throws
{
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let flags: KittyKeyboardFlags = [
    .disambiguateEscapeCodes,
    .reportEventTypes,
    .reportAlternateKeys,
    .reportAllKeysAsEscapeCodes,
    .reportAssociatedText,
  ]
  let configuration = TerminalApplicationConfiguration(
    keyboardProtocol: .kittyRequired,
    kittyKeyboardFlags: flags
  )
  var observedFlags = KittyKeyboardFlags()

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    observedFlags = session.kittyKeyboardFlags
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  expectNoDifference(observedFlags, flags)
  #expect(flushes.contains(Array("\u{1B}[>31u".utf8)))
}

@Test
func `set cursor style preserves configured application mode requests`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let style = CursorStyle(shape: .steadyBar, color: cursorColor)
  let configuration = TerminalApplicationConfiguration(
    mouseTracking: .anyEvent,
    keyboardProtocol: .kittyRequired,
    cursorStyling: .enabled(default: nil)
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    try await session.setCursorStyle(style)
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)

  expectNoDifference(
    flushes,
    [
      bracketedPasteEnableBytes,
      focusEnableBytes,
      mouseEnableBytes(.anyEvent),
      kittyKeyboardPushBytes,
      cursorStyleOverrideBytes,
      cursorVisibleBytes,
      kittyGraphicsDeleteAllBytes,
      kittyKeyboardPopBytes,
      mouseDisableBytes,
      focusDisableBytes,
      bracketedPasteDisableBytes,
      cursorStyleResetBytes,
    ]
  )
}

@Test
func `runtime application mode setters preserve policy and lifecycle state`()
  async throws
{
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let cursorStyle = CursorStyle(shape: .steadyBlock)
  let configuration = TerminalApplicationConfiguration(
    keyboardProtocol: .legacyOnly,
    cursorStyling: .enabled(default: cursorStyle)
  )
  var reports: [TerminalProtocolModeReport] = []

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    reports.append(session.protocolModeReport)
    try await session.setMouseTracking(.buttonEvents)
    #expect(session.mouseTracking == .buttonEvents)
    reports.append(session.protocolModeReport)
    try await session.setMouseTracking(.anyEvent)
    #expect(session.mouseTracking == .anyEvent)
    try await session.setFocusEvents(false)
    #expect(session.focusEventsEnabled == false)
    try await session.setKeyboardProtocol(.kittyRequired)
    #expect(session.keyboardProtocol == .kittyRequired)
    try await session.setMouseTracking(.disabled)
    try await session.setFocusEvents(true)
    try await session.setKeyboardProtocol(.legacyOnly)
    reports.append(session.protocolModeReport)
    #expect(session.effectiveCursorStyle == cursorStyle)
  }

  expectNoDifference(
    reports,
    [
      TerminalProtocolModeReport(
        requested: [.cursorStyle(cursorStyle), .bracketedPaste, .focusEvents],
        effective: [
          .rawMode, .altScreen, .cursorStyle(cursorStyle), .bracketedPaste, .focusEvents,
        ],
        possiblyActive: []
      ),
      TerminalProtocolModeReport(
        requested: [
          .cursorStyle(cursorStyle), .bracketedPaste, .focusEvents,
          .mouseTracking(.buttonEvents),
        ],
        effective: [
          .rawMode, .altScreen, .cursorStyle(cursorStyle), .bracketedPaste, .focusEvents,
          .mouseTracking(.buttonEvents),
        ],
        possiblyActive: []
      ),
      TerminalProtocolModeReport(
        requested: [.cursorStyle(cursorStyle), .bracketedPaste, .focusEvents],
        effective: [
          .rawMode, .altScreen, .cursorStyle(cursorStyle), .bracketedPaste, .focusEvents,
        ],
        possiblyActive: []
      ),
    ]
  )

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  expectNoDifference(
    flushes,
    [
      cursorShapeSteadyBlockBytes,
      bracketedPasteEnableBytes,
      focusEnableBytes,
      mouseEnableBytes(.buttonEvents),
      mouseDisableBytes,
      mouseEnableBytes(.anyEvent),
      focusDisableBytes,
      kittyKeyboardPushBytes,
      mouseDisableBytes,
      focusEnableBytes,
      kittyKeyboardPopBytes,
      cursorVisibleBytes,
      kittyGraphicsDeleteAllBytes,
      focusDisableBytes,
      bracketedPasteDisableBytes,
      cursorShapeResetBytes,
    ]
  )
}

@Test
func `equal runtime application mode assignments emit no bytes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  try await TerminalSession.withApplicationTerminal(
    configuration: .default,
    io: io,
    environment: [:]
  ) { session in
    let before = await device.events
    try await session.setMouseTracking(.disabled)
    try await session.setFocusEvents(true)
    try await session.setKeyboardProtocol(.kittyIfAvailable)
    let after = await device.events
    expectNoDifference(after, before)
  }
}

@Test
func `disabling focus preserves an event parsed before the transition`() async throws {
  let device = InMemoryTerminalDevice(
    size: TerminalSize(columns: 4, rows: 2),
    inputBytes: Array("\u{1B}[I".utf8)
  )
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  try await TerminalSession.withApplicationTerminal(
    configuration: .default,
    io: io,
    environment: [:]
  ) { session in
    try await session.setFocusEvents(false)
    let event = try await session.nextEvent()
    expectNoDifference(event, .focusGained)
  }
}

@Test
func `conditional keyboard setter ignores passive supported metadata`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let lifecycle = ModeLifecycle(io: io)
  let initialModes: Set<ModeLifecycle.Mode> = [.rawMode, .altScreen, .kittyKeyboard]
  try await lifecycle.enter(initialModes)
  let session = TerminalSession(
    io: io,
    capabilities: TerminalCapabilities(kittyKeyboard: .supported),
    enabledProtocolModes: initialModes,
    requestedProtocolModes: [.kittyKeyboard],
    keyboardProtocol: .kittyRequired,
    modeLifecycle: lifecycle
  )

  try await session.setKeyboardProtocol(.kittyIfAvailable)

  #expect(await session.keyboardProtocol == .kittyIfAvailable)
  #expect(await session.enabledProtocolModes.contains(.kittyKeyboard) == false)
  #expect(await session.protocolModeReport.requested.contains(.kittyKeyboard) == false)
  try await lifecycle.exit()
}

@Test
func `conditional keyboard setter consumes cached supported probe evidence`()
  async throws
{
  let device = KeyboardProbeResponseTerminalDevice(
    size: TerminalSize(columns: 4, rows: 2),
    keyboardSupported: true
  )
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let lifecycle = ModeLifecycle(io: io)
  let fixedModes: Set<ModeLifecycle.Mode> = [.rawMode, .altScreen]
  try await lifecycle.enter(fixedModes)
  let session = TerminalSession(
    io: io,
    enabledProtocolModes: fixedModes,
    keyboardProtocol: .legacyOnly,
    modeLifecycle: lifecycle
  )
  _ = try await session.queryActiveCapabilities()

  try await session.setKeyboardProtocol(.kittyIfAvailable)

  #expect(await session.keyboardProtocol == .kittyIfAvailable)
  #expect(await session.enabledProtocolModes.contains(.kittyKeyboard))
  #expect(await session.protocolModeReport.requested.contains(.kittyKeyboard))
  try await session.setKeyboardProtocol(.legacyOnly)
  #expect(await session.enabledProtocolModes.contains(.kittyKeyboard) == false)
  try await lifecycle.exit()
}

@Test
func `queued runtime mode setters preserve unrelated requests`() async throws {
  let device = RuntimeModeTerminalDevice()
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  try await TerminalSession.withApplicationTerminal(
    configuration: .default,
    io: io,
    environment: [:]
  ) { session in
    await device.suspendNextWrite(matching: mouseEnableBytes(.buttonEvents))
    let mouseTask = Task {
      try await session.setMouseTracking(.buttonEvents)
    }
    await device.waitForSuspension()
    let focusTask = Task {
      try await session.setFocusEvents(false)
    }
    await Task.yield()
    await device.resumeSuspendedWrite()

    try await mouseTask.value
    try await focusTask.value

    let report = session.protocolModeReport
    #expect(report.requested.contains(.mouseTracking(.buttonEvents)))
    #expect(report.effective.contains(.mouseTracking(.buttonEvents)))
    #expect(report.requested.contains(.focusEvents) == false)
    #expect(report.effective.contains(.focusEvents) == false)
    #expect(report.possiblyActive.isEmpty)
  }
}

@Test
func `cancelled queued runtime setter does not mutate requested policy`() async throws {
  let device = RuntimeModeTerminalDevice()
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  try await TerminalSession.withApplicationTerminal(
    configuration: .default,
    io: io,
    environment: [:]
  ) { session in
    await device.suspendNextWrite(matching: mouseEnableBytes(.buttonEvents))
    let mouseTask = Task {
      try await session.setMouseTracking(.buttonEvents)
    }
    await device.waitForSuspension()
    let focusTask = Task {
      try await session.setFocusEvents(false)
    }
    await Task.yield()
    focusTask.cancel()
    await device.resumeSuspendedWrite()

    try await mouseTask.value
    await #expect(throws: CancellationError.self) {
      try await focusTask.value
    }
    let focusEventsEnabled = session.focusEventsEnabled
    let report = session.protocolModeReport
    #expect(focusEventsEnabled)
    #expect(report.effective.contains(.focusEvents))
  }
}

@Test
func `failed runtime mode transition publishes ambiguity and retries`() async throws {
  let device = RuntimeModeTerminalDevice()
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  try await TerminalSession.withApplicationTerminal(
    configuration: .default,
    io: io,
    environment: [:]
  ) { session in
    await device.failPartwayThroughNextWrite(matching: mouseEnableBytes(.buttonEvents))

    await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
      try await session.setMouseTracking(.buttonEvents)
    }
    var report = session.protocolModeReport
    #expect(report.requested.contains(.mouseTracking(.buttonEvents)) == false)
    #expect(report.effective.contains(.mouseTracking(.buttonEvents)) == false)
    #expect(report.possiblyActive.contains(.mouseTracking(.buttonEvents)))

    try await session.setMouseTracking(.buttonEvents)
    report = session.protocolModeReport
    #expect(report.requested.contains(.mouseTracking(.buttonEvents)))
    #expect(report.effective.contains(.mouseTracking(.buttonEvents)))
    #expect(report.possiblyActive.isEmpty)
  }
}

@Test
func `session exposes nil cell pixel size`() async {
  let device = InMemoryTerminalDevice(
    size: TerminalSize(columns: 4, rows: 2),
    cellPixelSize: nil
  )
  let session = await makeSession(device)

  let pixelSize = await session.cellPixelSize

  expectNoDifference(pixelSize, nil)
}

@Test
func `session exposes terminal device cell pixel size`() async {
  let device = InMemoryTerminalDevice(
    size: TerminalSize(columns: 4, rows: 2),
    cellPixelSize: CellPixelSize(height: 18, width: 9)
  )
  let session = await makeSession(device)

  let pixelSize = await session.cellPixelSize

  expectNoDifference(pixelSize, CellPixelSize(height: 18, width: 9))
}

@Test
func `transmit image writes exact kitty graphics bytes and flushes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  try await session.transmitImage(
    KittyGraphicsTransmission(
      id: KittyImageID(rawValue: 7),
      format: .png,
      data: [0x48, 0x69]
    )
  )

  let events = await device.events

  expectNoDifference(events, [.flush(kittyGraphicsTransmitBytes)])
}

@Test
func `delete images writes exact kitty graphics bytes and flushes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  try await session.deleteImages(
    .placement(KittyImageID(rawValue: 7), KittyPlacementID(rawValue: 9))
  )

  let events = await device.events

  expectNoDifference(events, [.flush(kittyGraphicsDeletePlacementBytes)])
}

@Test
func `graphics query runs one serialized active probe generation`() async throws {
  let device = KeyboardProbeResponseTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  let result = try await session.queryKittyGraphicsSupport(id: KittyImageID(rawValue: 17))

  let events = await device.events

  expectNoDifference(result, .resolved)
  expectNoDifference(events, serializedActiveProbeEvents)
}

@Test
func `keyboard query runs one serialized active probe generation`() async throws {
  let device = KeyboardProbeResponseTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  let result = try await session.queryKittyKeyboardSupport()

  let events = await device.events

  expectNoDifference(result, .resolved)
  expectNoDifference(events, serializedActiveProbeEvents)
}

@Test
func `private mode query runs one serialized active probe generation`() async throws {
  let device = KeyboardProbeResponseTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  let result = try await session.queryPrivateModeStatuses()

  let events = await device.events

  expectNoDifference(result, .resolved)
  expectNoDifference(events, serializedActiveProbeEvents)
}

@Test
func `active capability query serializes rounds and caches the generation`() async throws {
  let device = KeyboardProbeResponseTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  let first = try await session.queryActiveCapabilities()
  let second = try await session.queryActiveCapabilities()

  let events = await device.events

  expectNoDifference(first, .resolved)
  expectNoDifference(second, .alreadyResolved)
  expectNoDifference(events, serializedActiveProbeEvents)
}

@Test
func `default configuration denies clipboard writes without flushing`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let resolution = TerminalApplicationConfiguration.default.resolve(environment: [:])
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: resolution.synchronizedOutput,
    capabilities: resolution.capabilities,
    enabledProtocolModes: resolution.enabledProtocolModes,
    hyperlinkRendering: resolution.hyperlinkRendering,
    clipboardWriting: resolution.clipboardWriting
  )

  let result = try await session.copyToClipboard("denied", intent: .userInitiated)

  let events = await device.events

  let hasFlush = events.contains(where: \.isFlush)

  expectNoDifference(result, .denied(.disabledByConfiguration))
  #expect(!hasFlush)
}

@Test
func `enabled user-initiated clipboard write emits OSC 52 bytes once`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let write = ClipboardWrite(selection: .clipboard, text: "Layer 2")
  let expectedBytes = ControlSequence.copyToClipboard(write).bytes
  let session = await makeSession(
    device,
    clipboardWriting: .enabled(.default)
  )

  let result = try await session.copyToClipboard(
    "Layer 2",
    selection: .clipboard,
    intent: .userInitiated
  )

  let events = await device.events

  expectNoDifference(result, .sent(bytesWritten: expectedBytes.count))
  expectNoDifference(events, [.flush(expectedBytes)])
}

@Test
func `package clipboard seam denies writes without explicit user intent`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let write = ClipboardWrite(text: "requires intent")
  let session = await makeSession(
    device,
    clipboardWriting: .enabled(.default)
  )

  let result = try await session.clipboardWrite(write, intent: nil)

  let events = await device.events

  let hasFlush = events.contains(where: \.isFlush)

  expectNoDifference(result, .denied(.missingUserIntent))
  #expect(!hasFlush)
}

@Test
func `clipboard policy rejects disallowed primary selection`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let policy = ClipboardWritePolicy(allowedTargets: [.clipboard])
  let session = await makeSession(
    device,
    clipboardWriting: .enabled(policy)
  )

  let result = try await session.copyToClipboard(
    "primary",
    selection: .primary,
    intent: .userInitiated
  )

  let events = await device.events

  let hasFlush = events.contains(where: \.isFlush)

  expectNoDifference(result, .denied(.selectionNotAllowed(.primary)))
  #expect(!hasFlush)
}

@Test
func `clipboard payload at limit sends and one byte over limit is denied`() async throws {
  let allowedDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let deniedDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let policy = ClipboardWritePolicy(maximumPayloadBytes: 3)
  let allowedWrite = ClipboardWrite(bytes: [0x41, 0x42, 0x43])
  let expectedBytes = ControlSequence.copyToClipboard(allowedWrite).bytes
  let allowedSession = await makeSession(
    allowedDevice,
    clipboardWriting: .enabled(policy)
  )
  let deniedSession = await makeSession(
    deniedDevice,
    clipboardWriting: .enabled(policy)
  )

  let allowedResult = try await allowedSession.copyToClipboard(
    [0x41, 0x42, 0x43],
    intent: .userInitiated
  )
  let deniedResult = try await deniedSession.copyToClipboard(
    [0x41, 0x42, 0x43, 0x44],
    intent: .userInitiated
  )

  let allowedEvents = await allowedDevice.events
  let deniedEvents = await deniedDevice.events

  let deniedHasFlush = deniedEvents.contains(where: \.isFlush)

  expectNoDifference(allowedResult, .sent(bytesWritten: expectedBytes.count))
  expectNoDifference(allowedEvents, [.flush(expectedBytes)])
  expectNoDifference(
    deniedResult,
    .denied(.payloadTooLarge(actualBytes: 4, maximumBytes: 3))
  )
  #expect(!deniedHasFlush)
}

@Test(arguments: clipboardNestedTerminalCases)
private func `nested clipboard writes require explicit passthrough`(
  _ testCase: ClipboardNestedTerminalCase
) async throws {
  let write = ClipboardWrite(text: "nested")
  let expectedBytes = ControlSequence.copyToClipboard(write).bytes
  let deniedDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let deniedIO = PlatformIO(terminalDevice: await deniedDevice.terminalDevice)
  let deniedConfiguration = TerminalApplicationConfiguration(
    clipboardWriting: .enabled(.default)
  )

  let deniedResult = try await TerminalSession.withApplicationTerminal(
    configuration: deniedConfiguration,
    io: deniedIO,
    environment: testCase.environment
  ) { session in
    try await session.copyToClipboard("nested", intent: .userInitiated)
  }

  let deniedEvents = await deniedDevice.events
  let deniedWroteExpectedBytes = deniedEvents.contains { $0.flushBytes == expectedBytes }

  expectNoDifference(
    deniedResult,
    .denied(.nestedTerminalRequiresExplicitPassthrough(testCase.identity))
  )
  #expect(!deniedWroteExpectedBytes)

  let allowedDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let allowedIO = PlatformIO(terminalDevice: await allowedDevice.terminalDevice)
  let allowedPolicy = ClipboardWritePolicy(allowsNestedTerminalPassthrough: true)
  let allowedConfiguration = TerminalApplicationConfiguration(
    clipboardWriting: .enabled(allowedPolicy)
  )

  let allowedResult = try await TerminalSession.withApplicationTerminal(
    configuration: allowedConfiguration,
    io: allowedIO,
    environment: testCase.environment
  ) { session in
    try await session.copyToClipboard("nested", intent: .userInitiated)
  }

  let allowedEvents = await allowedDevice.events
  expectNoDifference(allowedResult, .sent(bytesWritten: expectedBytes.count))
  #expect(allowedEvents.filter { $0.flushBytes == expectedBytes }.count == 1)
}

@Test(arguments: clipboardNestedCapabilityCases)
private func `nested clipboard capability hints require explicit passthrough`(
  _ testCase: ClipboardNestedCapabilityCase
) async throws {
  let write = ClipboardWrite(text: "nested")
  let expectedBytes = ControlSequence.copyToClipboard(write).bytes
  let deniedDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let allowedDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let deniedSession = await makeSession(
    deniedDevice,
    capabilities: testCase.capabilities,
    clipboardWriting: .enabled(.default)
  )
  let allowedPolicy = ClipboardWritePolicy(allowsNestedTerminalPassthrough: true)
  let allowedSession = await makeSession(
    allowedDevice,
    capabilities: testCase.capabilities,
    clipboardWriting: .enabled(allowedPolicy)
  )

  let deniedResult = try await deniedSession.copyToClipboard(
    "nested",
    intent: .userInitiated
  )
  let allowedResult = try await allowedSession.copyToClipboard(
    "nested",
    intent: .userInitiated
  )

  let deniedEvents = await deniedDevice.events
  let allowedEvents = await allowedDevice.events

  let deniedHasFlush = deniedEvents.contains(where: \.isFlush)

  expectNoDifference(
    deniedResult,
    .denied(.nestedTerminalRequiresExplicitPassthrough(testCase.capabilities.identity))
  )
  #expect(!deniedHasFlush)
  expectNoDifference(allowedResult, .sent(bytesWritten: expectedBytes.count))
  expectNoDifference(allowedEvents, [.flush(expectedBytes)])
}

@Test
func `SSH-only environment allows clipboard writes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let write = ClipboardWrite(text: "ssh")
  let expectedBytes = ControlSequence.copyToClipboard(write).bytes
  let configuration = TerminalApplicationConfiguration(
    clipboardWriting: .enabled(.default)
  )

  let result = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [
      "SSH_CONNECTION": "192.0.2.1 50000 192.0.2.2 22",
      "SSH_TTY": "/dev/ttys001",
    ]
  ) { session in
    try await session.copyToClipboard("ssh", intent: .userInitiated)
  }

  let events = await device.events

  expectNoDifference(result, .sent(bytesWritten: expectedBytes.count))
  #expect(events.filter { $0.flushBytes == expectedBytes }.count == 1)
}

@Test
func `clipboard write does not invalidate rendered frame cache`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let write = ClipboardWrite(text: "copy")
  let expectedClipboardBytes = ControlSequence.copyToClipboard(write).bytes
  let session = await makeSession(
    device,
    synchronizedOutput: .disabled,
    clipboardWriting: .enabled(.default)
  )

  try await session.draw { frame in
    frame.write("x", at: TerminalPosition(column: 0, row: 0))
  }
  let result = try await session.copyToClipboard("copy", intent: .userInitiated)
  try await session.draw { frame in
    frame.write("x", at: TerminalPosition(column: 0, row: 0))
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let clipboardFlush = try #require(flushes.dropFirst().first)
  let secondDrawFlush = try #require(flushes.last)

  expectNoDifference(result, .sent(bytesWritten: expectedClipboardBytes.count))
  #expect(flushes.count == 3)
  #expect(clipboardFlush == expectedClipboardBytes)
  #expect(secondDrawFlush == Array("\u{1B}[0m\u{1B}[?25l".utf8))
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
func `app terminal enables kitty keyboard when requested`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    modes: applicationModes(including: [.mouseTracking(.anyEvent), .kittyKeyboard])
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io
  ) { _ in }

  let events = await device.events
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: enableMouseTracking(anyEvent)
      flush: pushKittyKeyboard
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: popKittyKeyboard
      flush: disableMouseTracking
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `application terminal rethrows body error after cleanup`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  await #expect(throws: TerminalSessionTestError.bodyFailed) {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default,
      io: io,
      environment: [:]
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
      flush: deleteKittyGraphicsAll
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `probe failure exits before application body`() async throws {
  let device = LifecycleFailureTerminalDevice(failures: [.probe])
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(capabilityDetection: .active)
  var bodyRan = false

  await #expect(throws: LifecycleFailureTerminalDevice.Failure.probe) {
    try await TerminalSession.withApplicationTerminal(
      configuration: configuration,
      io: io,
      environment: [:]
    ) { _ in
      bodyRan = true
    }
  }

  let events = await device.events

  #expect(!bodyRan)
  expectNoDifference(
    Array(events.prefix(3)),
    [.enterRawMode, .enterAltScreen, .flush(privateModeStatusProbeBytes)]
  )
  #expect(events.contains(.exitAltScreen))
  #expect(events.contains(.exitRawMode))
  #expect(!events.contains(.flush(bracketedPasteEnableBytes)))
}

@Test
func `initial application mode failure exits before application body`() async throws {
  let device = LifecycleFailureTerminalDevice(failures: [.applicationMode])
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  var bodyRan = false

  await #expect(throws: LifecycleFailureTerminalDevice.Failure.applicationMode) {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default,
      io: io,
      environment: [:]
    ) { _ in
      bodyRan = true
    }
  }

  let events = await device.events

  #expect(!bodyRan)
  expectNoDifference(
    Array(events.prefix(3)),
    [.enterRawMode, .enterAltScreen, .flush(bracketedPasteEnableBytes)]
  )
  #expect(events.contains(.exitAltScreen))
  #expect(events.contains(.exitRawMode))
}

@Test
func `body error remains primary when cursor restoration and exit fail`() async throws {
  let device = LifecycleFailureTerminalDevice(failures: [.cursorRestore, .exitRawMode])
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  await #expect(throws: TerminalSessionTestError.bodyFailed) {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default,
      io: io,
      environment: [:]
    ) { _ in
      throw TerminalSessionTestError.bodyFailed
    }
  }

  let events = await device.events

  #expect(events.contains(.flush(cursorVisibleBytes)))
  #expect(events.contains(.exitRawMode))
}

@Test
func `cursor restoration error remains primary after exit failure`() async throws {
  let device = LifecycleFailureTerminalDevice(failures: [.cursorRestore, .exitRawMode])
  let io = PlatformIO(terminalDevice: await device.terminalDevice)

  await #expect(throws: LifecycleFailureTerminalDevice.Failure.cursorRestore) {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default,
      io: io,
      environment: [:]
    ) { _ in }
  }

  let events = await device.events

  #expect(events.contains(.exitRawMode))
}

@Test
func `app terminal keeps Kitty off for passive Ghostty`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let observed = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [
      "TERM_PROGRAM": "Ghostty",
      "TERM_PROGRAM_VERSION": "1.3.2",
    ]
  ) { session in
    (session.capabilities, session.enabledProtocolModes)
  }

  expectNoDifference(
    observed.0,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .ghostty,
        source: .termProgram("Ghostty"),
        version: "1.3.2"
      ),
      isNested: false
    )
  )
  expectNoDifference(observed.1, applicationModes())
}

@Test
func `app terminal accepts dumb hints without kitty keyboard`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let result = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: ["TERM": "dumb"]
  ) { _ in
    "started"
  }

  let events = await device.events

  expectNoDifference(result, "started")
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `active app terminal probes without enabling Kitty keyboard`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .active,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let observed = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [
      "TERM_PROGRAM": "Ghostty",
      "TERM_PROGRAM_VERSION": "1.3.2",
    ]
  ) { session in
    (session.capabilities, session.enabledProtocolModes)
  }

  let events = await device.events

  expectNoDifference(
    observed.0,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .ghostty,
        source: .termProgram("Ghostty"),
        version: "1.3.2"
      ),
      isNested: false
    )
  )
  expectNoDifference(observed.1, applicationModes())
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: privateModeStatusProbes
      flush: kittyKeyboardProbe
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `app terminal resolves intent any-event mouse and enables tracking`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .disabled,
    mouseTracking: .anyEvent,
    keyboardProtocol: .legacyOnly
  )

  let enabledModes = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io
  ) { session in
    session.enabledProtocolModes
  }

  let events = await device.events

  expectNoDifference(
    enabledModes,
    applicationModes(including: [.mouseTracking(.anyEvent)])
  )
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: enableMouseTracking(anyEvent)
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: disableMouseTracking
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `app terminal enables button-event mouse when requested`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    modes: applicationModes(including: [.mouseTracking(.buttonEvents)])
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io
  ) { _ in }

  let events = await device.events
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: enableMouseTracking(buttonEvents)
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: disableMouseTracking
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `app terminal enables any-event mouse when requested`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    modes: applicationModes(including: [.mouseTracking(.anyEvent)])
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io
  ) { _ in }

  let events = await device.events
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: enableMouseTracking(anyEvent)
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: disableMouseTracking
      flush: enableFocusTracking(false)
      flush: enableBracketedPaste(false)
      exitAltScreen
      exitRawMode
      """
  )
}

@Test
func `app terminal normalizes mouse granularities to any-event`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    modes: applicationModes(
      including: [.mouseTracking(.buttonEvents), .mouseTracking(.anyEvent)]
    )
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io
  ) { _ in }

  let events = await device.events
  #expect(
    terminalSessionEventLog(events) == """
      enterRawMode
      enterAltScreen
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: enableMouseTracking(anyEvent)
      flush: cursorVisible(true)
      flush: deleteKittyGraphicsAll
      flush: disableMouseTracking
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
func `draw uses session no-color capability for rendered output`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .noColor)
  )

  try await session.draw { frame in
    frame.write(
      "R",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(foreground: .rgb(255, 0, 0))
    )
  }

  let bytes = await device.bytes

  let expected = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0mR\u{1B}[0m\u{1B}[?25l".utf8
  )
  #expect(bytes == expected)
}

@Test
func `session threads explicit baseline underline rendering to drawing`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    underlineRendering: .baseline
  )

  let underlineRendering = await session.underlineRendering
  expectNoDifference(underlineRendering, .baseline)

  try await session.draw { frame in
    frame.write(
      "D",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .double, underlineColor: .indexed(196))
    )
    frame.write(
      "C",
      at: TerminalPosition(column: 1, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
    frame.write(
      "O",
      at: TerminalPosition(column: 2, row: 0),
      style: Style(underlineStyle: .dotted, underlineColor: .indexed(196))
    )
    frame.write(
      "H",
      at: TerminalPosition(column: 3, row: 0),
      style: Style(underlineStyle: .dashed, underlineColor: .indexed(196))
    )
  }

  let bytes = await device.bytes
  let expected = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[4mDCOH\u{1B}[0m\u{1B}[?25l".utf8
  )

  #expect(bytes == expected)
}

@Test
func `session defaults to extended underline rendering and exact bytes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .indexed256)
  )

  let underlineRendering = await session.underlineRendering
  expectNoDifference(underlineRendering, .extended)

  try await session.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }

  let bytes = await device.bytes
  let expected = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[58:5:196m\u{1B}[4:3mC\u{1B}[0m\u{1B}[?25l".utf8
  )

  #expect(bytes == expected)
}

@Test
func `application terminal threads custom underline rendering to session`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let underlineRendering = UnderlineRenderingPolicy(style: .singleOnly, color: .emit)
  let configuration = TerminalApplicationConfiguration(
    underlineRendering: underlineRendering)

  let observed = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    environment: ["TERM_PROGRAM": "Apple_Terminal"]
  ) { session in
    session.underlineRendering
  }

  expectNoDifference(observed, underlineRendering)
}

@Test
func `runtime underline change repaints unchanged frame exactly`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .indexed256)
  )

  try await session.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }
  await session.setUnderlineRendering(.baseline)
  try await session.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }

  let policy = await session.underlineRendering
  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let extended = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[58:5:196m\u{1B}[4:3mC\u{1B}[0m\u{1B}[?25l".utf8
  )
  let baseline = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[4mC\u{1B}[0m\u{1B}[?25l".utf8
  )

  expectNoDifference(policy, .baseline)
  expectNoDifference(flushes, [extended, baseline])
}

@Test
func `runtime underline axes emit exact mixed bytes`() async throws {
  let styleDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let colorDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let styleSession = TerminalSession(
    io: PlatformIO(terminalDevice: await styleDevice.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .indexed256)
  )
  let colorSession = TerminalSession(
    io: PlatformIO(terminalDevice: await colorDevice.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .indexed256)
  )
  let styleOnly = UnderlineRenderingPolicy(style: .singleOnly, color: .emit)
  let colorOnly = UnderlineRenderingPolicy(style: .preserveVariants, color: .omit)

  await styleSession.setUnderlineRendering(styleOnly)
  await colorSession.setUnderlineRendering(colorOnly)
  try await styleSession.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }
  try await colorSession.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }

  let stylePolicy = await styleSession.underlineRendering
  let colorPolicy = await colorSession.underlineRendering
  let styleFlushes = await styleDevice.events.filter(\.isFlush).map(\.flushBytes)
  let colorFlushes = await colorDevice.events.filter(\.isFlush).map(\.flushBytes)
  let expectedStyleOnly = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[58:5:196m\u{1B}[4mC\u{1B}[0m\u{1B}[?25l".utf8
  )
  let expectedColorOnly = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[4:3mC\u{1B}[0m\u{1B}[?25l".utf8
  )

  expectNoDifference(stylePolicy, styleOnly)
  expectNoDifference(colorPolicy, colorOnly)
  expectNoDifference(styleFlushes, [expectedStyleOnly])
  expectNoDifference(colorFlushes, [expectedColorOnly])
}

@Test
func `equal runtime underline policy does not repaint`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .indexed256)
  )

  try await session.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }
  await session.setUnderlineRendering(.extended)
  try await session.draw { frame in
    frame.write(
      "C",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(underlineStyle: .curly, underlineColor: .indexed(196))
    )
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let initialFrame = Array(
    "\u{1B}[2J\u{1B}[1;1H\u{1B}[0m\u{1B}[58:5:196m\u{1B}[4:3mC\u{1B}[0m\u{1B}[?25l".utf8
  )
  let unchangedFrame = Array("\u{1B}[0m\u{1B}[?25l".utf8)

  expectNoDifference(flushes, [initialFrame, unchangedFrame])
}

@Test
func `NO_COLOR pins output without overwriting color evidence`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    colorCapability: .force(.truecolor)
  )

  let observed = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: ["COLORTERM": "truecolor", "NO_COLOR": "1"]
  ) { session in
    try await session.draw { frame in
      frame.write(
        "R",
        at: TerminalPosition(column: 0, row: 0),
        style: Style(foreground: .rgb(255, 0, 0))
      )
    }
    return (
      session.capabilities.color,
      session.effectiveColorCapability,
      session.hasNoColorEnvironment,
      session.hasDumbTerminal
    )
  }

  let bytes = await device.bytes
  let truecolorPrefix = Array("\u{1B}[38;2;".utf8)

  expectNoDifference(observed.0, .truecolor)
  expectNoDifference(observed.1, .noColor)
  expectNoDifference(observed.2, true)
  expectNoDifference(observed.3, false)
  #expect(containsBytes(truecolorPrefix, in: bytes) == false)
}

@Test
func `runtime color changes repaint unchanged frames but equal policies do not`()
  async throws
{
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .truecolor)
  )

  try await session.draw { frame in
    frame.write(
      "R",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(foreground: .rgb(255, 0, 0))
    )
  }
  await session.setColorCapability(.force(.ansi16))
  try await session.draw { frame in
    frame.write(
      "R",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(foreground: .rgb(255, 0, 0))
    )
  }
  await session.setColorCapability(.force(.ansi16))
  try await session.draw { frame in
    frame.write(
      "R",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(foreground: .rgb(255, 0, 0))
    )
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let effectiveColorCapability = await session.effectiveColorCapability
  let evidence = await session.capabilities.color

  expectNoDifference(effectiveColorCapability, .ansi16)
  expectNoDifference(evidence, .truecolor)
  #expect(containsBytes(Array("\u{1B}[2J".utf8), in: flushes[1]))
  #expect(containsBytes(Array("\u{1B}[38;2;".utf8), in: flushes[1]) == false)
  expectNoDifference(flushes[2], Array("\u{1B}[0m\u{1B}[?25l".utf8))
}

@Test
func `color policy pinned by NO_COLOR does not repaint unchanged frames`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled,
    capabilities: TerminalCapabilities(color: .truecolor),
    hasNoColorEnvironment: true
  )

  try await session.draw { frame in
    frame.write(
      "R",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(foreground: .rgb(255, 0, 0))
    )
  }
  await session.setColorCapability(.force(.ansi16))
  try await session.draw { frame in
    frame.write(
      "R",
      at: TerminalPosition(column: 0, row: 0),
      style: Style(foreground: .rgb(255, 0, 0))
    )
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let policy = await session.colorCapability
  let effectiveColorCapability = await session.effectiveColorCapability

  expectNoDifference(policy, .force(.ansi16))
  expectNoDifference(effectiveColorCapability, .noColor)
  expectNoDifference(flushes[1], Array("\u{1B}[0m\u{1B}[?25l".utf8))
}

@Test
func `runtime hyperlink rendering repaints unchanged cells and equal assignment does not`()
  async throws
{
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled
  )
  let hyperlink = try Hyperlink(uri: "https://example.com")

  try await session.draw { frame in
    frame.write(
      "L", at: TerminalPosition(column: 0, row: 0), style: Style(hyperlink: hyperlink))
  }
  await session.setHyperlinkRendering(.disabled)
  try await session.draw { frame in
    frame.write(
      "L", at: TerminalPosition(column: 0, row: 0), style: Style(hyperlink: hyperlink))
  }
  await session.setHyperlinkRendering(.disabled)
  try await session.draw { frame in
    frame.write(
      "L", at: TerminalPosition(column: 0, row: 0), style: Style(hyperlink: hyperlink))
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let disabledHyperlinks = await session.hyperlinkRendering
  let osc8Open = Array("\u{1B}]8;;https://example.com\u{1B}\\".utf8)

  expectNoDifference(disabledHyperlinks, .disabled)
  #expect(containsBytes(Array("\u{1B}[2J".utf8), in: flushes[1]))
  #expect(containsBytes(osc8Open, in: flushes[1]) == false)
  expectNoDifference(flushes[2], Array("\u{1B}[0m\u{1B}[?25l".utf8))
}

@Test
func `draw commits runtime policies after delayed size resolution`() async throws {
  let device = DelayedSizeTerminalDevice()
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    capabilities: TerminalCapabilities(color: .truecolor)
  )
  let hyperlink = try Hyperlink(uri: "https://example.com")
  let drawing = Task {
    try await session.draw { frame in
      frame.write(
        "R",
        at: TerminalPosition(column: 0, row: 0),
        style: Style(foreground: .rgb(255, 0, 0), hyperlink: hyperlink)
      )
    }
  }

  await device.waitForSizeRequest()
  await session.setColorCapability(.force(.ansi16))
  await session.setHyperlinkRendering(.disabled)
  await session.setSynchronizedOutput(.disabled)
  await device.resolveSize(TerminalSize(columns: 1, rows: 1))
  try await drawing.value

  let bytes = await device.bytes

  #expect(containsBytes(Array("\u{1B}[38;2;".utf8), in: bytes) == false)
  #expect(
    containsBytes(
      Array("\u{1B}]8;;https://example.com\u{1B}\\".utf8),
      in: bytes
    ) == false
  )
  #expect(bytes.starts(with: Array("\u{1B}[?2026h".utf8)) == false)
}

@Test
func `failed frame replays hyperlink close and synchronized exit first`() async throws {
  let device = PartialFailureTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice))
  let hyperlink = try Hyperlink(uri: "https://example.com")

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await session.draw { frame in
      frame.write(
        "L", at: TerminalPosition(column: 0, row: 0), style: Style(hyperlink: hyperlink))
    }
  }
  await session.setSynchronizedOutput(.disabled)
  try await session.draw { frame in
    frame.write("Y", at: TerminalPosition(column: 0, row: 0))
  }

  let bytes = await device.bytes
  let hyperlinkClose = Array("\u{1B}]8;;\u{1B}\\".utf8)
  let syncExit = Array("\u{1B}[?2026l".utf8)
  let yIndex = try #require(bytes.firstIndex(of: 89))
  let hyperlinkCloseRange = try #require(firstByteRange(hyperlinkClose, in: bytes))
  let syncExitRange = try #require(firstByteRange(syncExit, in: bytes))

  #expect(hyperlinkCloseRange.lowerBound < yIndex)
  #expect(syncExitRange.lowerBound < yIndex)
}

@Test
func `every partial hyperlink frame offset replays close and synchronized exit first`()
  async throws
{
  let hyperlink = try Hyperlink(uri: "https://example.com")
  let referenceDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let referenceSession = TerminalSession(
    io: PlatformIO(terminalDevice: await referenceDevice.terminalDevice)
  )
  try await referenceSession.draw { frame in
    frame.write(
      "L", at: TerminalPosition(column: 0, row: 0), style: Style(hyperlink: hyperlink))
  }
  let expectedFirstFrame = try #require(
    await referenceDevice.events.first(where: \.isFlush)?.flushBytes
  )
  let hyperlinkClose = Array("\u{1B}]8;;\u{1B}\\".utf8)
  let syncExit = Array("\u{1B}[?2026l".utf8)

  for failureOffset in expectedFirstFrame.indices {
    let device = OffsetFailureTerminalDevice(
      failureOffset: failureOffset,
      size: TerminalSize(columns: 1, rows: 1)
    )
    let session = TerminalSession(
      io: PlatformIO(terminalDevice: await device.terminalDevice))

    await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
      try await session.draw { frame in
        frame.write(
          "L",
          at: TerminalPosition(column: 0, row: 0),
          style: Style(hyperlink: hyperlink)
        )
      }
    }
    await session.setSynchronizedOutput(.disabled)
    try await session.draw { frame in
      frame.write("Y", at: TerminalPosition(column: 0, row: 0))
    }

    let bytes = await device.bytes
    let yIndex = try #require(bytes.firstIndex(of: 89))
    let hyperlinkCloseRange = try #require(firstByteRange(hyperlinkClose, in: bytes))
    let syncExitRange = try #require(firstByteRange(syncExit, in: bytes))
    #expect(bytes.starts(with: expectedFirstFrame))
    #expect(hyperlinkCloseRange.lowerBound < yIndex)
    #expect(syncExitRange.lowerBound < yIndex)
  }
}

@Test
func `next event returns first parsed input event`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x61])
  let session = await makeSession(device)

  let event = try await session.nextEvent()

  #expect(event == .key(Key(code: .character("a"))))
}

@Test
func `next event can be called repeatedly on one input stream`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: [0x61, 0x62])
  let session = await makeSession(device)

  let first = try await session.nextEvent()
  let second = try await session.nextEvent()

  #expect(first == .key(Key(code: .character("a"))))
  #expect(second == .key(Key(code: .character("b"))))
}

@Test
func `events stream exposes parsed input events`() async throws {
  let device = InMemoryTerminalDevice(inputBytes: Array("\u{1B}[A".utf8))
  let session = await makeSession(device)
  var iterator = session.events.makeAsyncIterator()

  let event = await iterator.next()

  #expect(event == .key(Key(code: .up)))
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

  #expect(event == .resize(size))
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

  #expect(event == .key(Key(code: .character("a"))))
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
func `input event buffer coalesces buffered moves to the latest position`() async throws {
  let buffer = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
  let first = mouseInputEvent(.move, column: 1, row: 1)
  let second = mouseInputEvent(.move, column: 2, row: 1)
  let latest = mouseInputEvent(.move, column: 3, row: 1)

  await buffer.yield(first)
  await buffer.yield(second)
  await buffer.yield(latest)
  await buffer.finish()

  let event = try await buffer.next()
  let end = try await buffer.next()

  expectNoDifference(event, latest)
  expectNoDifference(end, nil)
}

@Test
func `event buffer keeps press between buffered moves`() async throws {
  let buffer = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
  let firstMove = mouseInputEvent(.move, column: 1, row: 1)
  let press = mouseInputEvent(.press(.left), column: 2, row: 1)
  let secondMove = mouseInputEvent(.move, column: 3, row: 1)

  await buffer.yield(firstMove)
  await buffer.yield(press)
  await buffer.yield(secondMove)

  let first = try await buffer.next()
  let second = try await buffer.next()
  let third = try await buffer.next()

  expectNoDifference(first, firstMove)
  expectNoDifference(second, press)
  expectNoDifference(third, secondMove)
}

@Test
func `event buffer coalesces same-button drags only`() async throws {
  let buffer = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
  let firstLeft = mouseInputEvent(.drag(.left), column: 1, row: 1)
  let latestLeft = mouseInputEvent(.drag(.left), column: 2, row: 1)
  let right = mouseInputEvent(.drag(.right), column: 3, row: 1)

  await buffer.yield(firstLeft)
  await buffer.yield(latestLeft)
  await buffer.yield(right)

  let first = try await buffer.next()
  let second = try await buffer.next()

  expectNoDifference(first, latestLeft)
  expectNoDifference(second, right)
}

@Test
func `input event buffer preserves moves whose modifiers differ`() async throws {
  let buffer = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
  let unmodified = mouseInputEvent(.move, column: 1, row: 1)
  let shifted = mouseInputEvent(.move, column: 2, row: 1, modifiers: .shift)

  await buffer.yield(unmodified)
  await buffer.yield(shifted)

  let first = try await buffer.next()
  let second = try await buffer.next()

  expectNoDifference(first, unmodified)
  expectNoDifference(second, shifted)
}

@Test
func `event buffer delivers waiting consumers every mouse move`() async throws {
  let buffer = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
  let firstMove = mouseInputEvent(.move, column: 1, row: 1)
  let secondMove = mouseInputEvent(.move, column: 2, row: 1)

  let firstPending = Task { try await buffer.next() }
  while await buffer.waiterCount == 0 {
    await Task.yield()
  }
  await buffer.yield(firstMove)
  let first = try await firstPending.value

  let secondPending = Task { try await buffer.next() }
  while await buffer.waiterCount == 0 {
    await Task.yield()
  }
  await buffer.yield(secondMove)
  let second = try await secondPending.value

  expectNoDifference(first, firstMove)
  expectNoDifference(second, secondMove)
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
func `draw owns complete synchronized output wrapper around renderer and cursor bytes`()
  async throws
{
  let enabledDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let enabledSession = await makeSession(enabledDevice, synchronizedOutput: .enabled)
  let disabledDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let disabledSession = await makeSession(disabledDevice, synchronizedOutput: .disabled)

  try await enabledSession.draw { frame in
    frame.setCursorPosition(TerminalPosition(column: 0, row: 0))
  }
  try await disabledSession.draw { _ in }

  let enabledBytes = await enabledDevice.bytes
  let disabledBytes = await disabledDevice.bytes
  let syncEnter = Array("\u{1B}[?2026h".utf8)
  let syncExit = Array("\u{1B}[?2026l".utf8)
  let expectedEnabled = Array(
    ("\u{1B}[?2026h\u{1B}[2J\u{1B}[1;1H\u{1B}[0m "
      + "\u{1B}[0m\u{1B}[?25h\u{1B}[1;1H\u{1B}[?2026l").utf8
  )

  expectNoDifference(enabledBytes, expectedEnabled)
  #expect(disabledBytes.starts(with: syncEnter) == false)
  #expect(containsBytes(syncExit, in: disabledBytes) == false)
}

@Test
func `runtime synchronized output changes frame boundaries without repainting cells`()
  async throws
{
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let session = await makeSession(device, synchronizedOutput: .disabled)

  try await session.draw { frame in
    frame.write("S", at: TerminalPosition(column: 0, row: 0))
  }
  await session.setSynchronizedOutput(.enabled)
  try await session.draw { frame in
    frame.write("S", at: TerminalPosition(column: 0, row: 0))
  }
  await session.setSynchronizedOutput(.enabled)
  try await session.draw { frame in
    frame.write("S", at: TerminalPosition(column: 0, row: 0))
  }

  let flushes = await device.events.filter(\.isFlush).map(\.flushBytes)
  let policy = await session.synchronizedOutput
  let syncEnter = Array("\u{1B}[?2026h".utf8)
  let syncExit = Array("\u{1B}[?2026l".utf8)
  let unchangedFrame = syncEnter + Array("\u{1B}[0m\u{1B}[?25l".utf8) + syncExit

  expectNoDifference(policy, .enabled)
  expectNoDifference(flushes[1], unchangedFrame)
  expectNoDifference(flushes[2], unchangedFrame)
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

private func applicationModes(
  including additionalModes: Set<ModeLifecycle.Mode> = []
) -> Set<ModeLifecycle.Mode> {
  Set([.rawMode, .altScreen, .bracketedPaste, .focusEvents]).union(additionalModes)
}

private func mouseInputEvent(
  _ kind: MouseEventKind,
  column: Int,
  row: Int,
  modifiers: Modifiers = []
) -> InputEvent {
  .mouse(
    MouseEvent(
      kind: kind,
      position: TerminalPosition(column: column, row: row),
      modifiers: modifiers
    )
  )
}

private func makeSession(
  _ device: InMemoryTerminalDevice,
  synchronizedOutput: SynchronizedOutputPolicy = .enabled,
  capabilities: TerminalCapabilities = .conservativeDefault,
  clipboardWriting: ClipboardWriteMode = .disabled
) async -> TerminalSession {
  TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: synchronizedOutput,
    capabilities: capabilities,
    clipboardWriting: clipboardWriting,
    probeImageID: KittyImageID(rawValue: 17)
  )
}

private func makeSession(_ device: KeyboardProbeResponseTerminalDevice) async
  -> TerminalSession
{
  TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    probeImageID: KittyImageID(rawValue: 17)
  )
}

private let clipboardNestedTerminalCases = [
  ClipboardNestedTerminalCase(
    name: "tmux",
    environment: [
      "TERM": "tmux-256color",
      "TMUX": "/private/tmp/tmux-501/default,123,0",
    ],
    identity: TerminalIdentity(kind: .tmux, source: .term("tmux-256color"))
  ),
  ClipboardNestedTerminalCase(
    name: "screen",
    environment: [
      "STY": "1234.pts-0.host",
      "TERM": "screen-256color",
    ],
    identity: TerminalIdentity(kind: .screen, source: .term("screen-256color"))
  ),
]

private let clipboardNestedCapabilityCases = [
  ClipboardNestedCapabilityCase(
    name: "nested flag",
    capabilities: TerminalCapabilities(
      identity: TerminalIdentity(kind: .unknown, source: .none),
      isNested: true
    )
  ),
  ClipboardNestedCapabilityCase(
    name: "screen identity",
    capabilities: TerminalCapabilities(
      identity: TerminalIdentity(kind: .screen, source: .term("screen-256color")),
      isNested: false
    )
  ),
  ClipboardNestedCapabilityCase(
    name: "tmux identity",
    capabilities: TerminalCapabilities(
      identity: TerminalIdentity(kind: .tmux, source: .term("tmux-256color")),
      isNested: false
    )
  ),
]

private struct ClipboardNestedCapabilityCase: CustomStringConvertible, Sendable {
  let name: String
  let capabilities: TerminalCapabilities

  var description: String {
    name
  }
}

private struct ClipboardNestedTerminalCase: CustomStringConvertible, Sendable {
  let name: String
  let environment: [String: String]
  let identity: TerminalIdentity

  var description: String {
    name
  }
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
  if bytes == mouseEnableBytes(.buttonEvents) {
    return "enableMouseTracking(buttonEvents)"
  }
  if bytes == mouseEnableBytes(.anyEvent) {
    return "enableMouseTracking(anyEvent)"
  }
  if bytes == mouseDisableBytes {
    return "disableMouseTracking"
  }
  if bytes == kittyKeyboardProbeBytes {
    return "kittyKeyboardProbe"
  }
  if bytes == privateModeStatusProbeBytes {
    return "privateModeStatusProbes"
  }
  if containsBytes(Array(",a=q,".utf8), in: bytes)
    && bytes.suffix(3) == [0x1B, 0x5B, 0x63]
  {
    return "kittyGraphicsQueryProbe"
  }
  if bytes == kittyKeyboardPushBytes {
    return "pushKittyKeyboard"
  }
  if bytes == kittyKeyboardPopBytes {
    return "popKittyKeyboard"
  }
  if bytes == kittyGraphicsDeleteAllBytes {
    return "deleteKittyGraphicsAll"
  }

  return String(describing: bytes)
}

private let mouseDisableBytes =
  Array("\u{1B}[?1003l\u{1B}[?1002l\u{1B}[?1006l".utf8)
private let bracketedPasteEnableBytes = Array("\u{1B}[?2004h".utf8)
private let bracketedPasteDisableBytes = Array("\u{1B}[?2004l".utf8)
private let focusEnableBytes = Array("\u{1B}[?1004h".utf8)
private let focusDisableBytes = Array("\u{1B}[?1004l".utf8)
private let cursorVisibleBytes = Array("\u{1B}[?25h".utf8)
private let cursorColor = CursorColor(red: 0x12, green: 0xAB, blue: 0xF0)
private let cursorShapeSteadyBlockBytes =
  ControlSequence.setCursorShape(.steadyBlock).bytes
private let cursorShapeResetBytes = ControlSequence.setCursorShape(.defaultUserShape).bytes
private let cursorColorSetBytes = ControlSequence.setCursorColor(cursorColor).bytes
private let cursorColorResetBytes = ControlSequence.resetCursorColor.bytes
private let cursorStyleOverrideBytes =
  ControlSequence.setCursorShape(.steadyBar).bytes + cursorColorSetBytes
private let cursorStyleResetBytes = cursorShapeResetBytes + cursorColorResetBytes
private let kittyKeyboardProbeBytes = Array("\u{1B}[?u\u{1B}[c".utf8)
private let kittyKeyboardPushBytes = Array("\u{1B}[>7u".utf8)
private let kittyKeyboardPopBytes = Array("\u{1B}[<u".utf8)
private let kittyGraphicsDeleteAllBytes = Array("\u{1B}_Ga=d,d=A\u{1B}\\".utf8)
private let kittyGraphicsDeletePlacementBytes =
  Array("\u{1B}_Ga=d,d=i,i=7,p=9\u{1B}\\".utf8)
private let kittyGraphicsTransmitBytes =
  Array("\u{1B}_Ga=t,i=7,f=100,t=d,q=1,m=0;SGk=\u{1B}\\".utf8)
private let kittyGraphicsQueryProbeBytes =
  Array("\u{1B}_Gi=17,s=1,v=1,a=q,t=d,f=24;AAAA\u{1B}\\\u{1B}[c".utf8)
private let privateModeProbeModes = [2_004, 1_004, 1_002, 1_003, 1_006, 2_026]
private let privateModeStatusProbeBytes = privateModeProbeModes.flatMap { mode in
  Array("\u{1B}[?\(mode)$p".utf8)
}
private let serializedActiveProbeEvents: [InMemoryTerminalDeviceEvent] = [
  .flush(privateModeStatusProbeBytes),
  .flush(kittyKeyboardProbeBytes),
  .flush(kittyGraphicsQueryProbeBytes),
]

private func mouseEnableBytes(_ granularity: MouseTracking) -> [UInt8] {
  switch granularity {
  case .anyEvent:
    Array("\u{1B}[?1003h\u{1B}[?1006h".utf8)
  case .buttonEvents:
    Array("\u{1B}[?1002h\u{1B}[?1006h".utf8)
  }
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

private func firstByteRange(_ needle: [UInt8], in haystack: [UInt8]) -> Range<Int>? {
  guard needle.isEmpty == false, haystack.count >= needle.count else {
    return nil
  }

  return haystack.indices.lazy.compactMap { index in
    let endIndex = index + needle.count
    guard endIndex <= haystack.endIndex, Array(haystack[index..<endIndex]) == needle else {
      return nil
    }
    return index..<endIndex
  }.first
}

private actor KeyboardProbeResponseTerminalDevice {
  private let inputContinuation: AsyncStream<[UInt8]>.Continuation
  private let inputStream: AsyncStream<[UInt8]>
  private var recordedEvents: [InMemoryTerminalDeviceEvent] = []
  private let keyboardSupported: Bool
  private let storedSize: TerminalSize

  var events: [InMemoryTerminalDeviceEvent] {
    recordedEvents
  }

  var terminalDevice: TerminalDevice {
    let inputStream = inputStream
    return TerminalDevice(
      bytes: { inputStream },
      size: { self.storedSize },
      write: { try await self.write($0) }
    )
  }
  init(size: TerminalSize, keyboardSupported: Bool = false) {
    let stream = AsyncStream<[UInt8]>.makeStream()
    self.inputContinuation = stream.continuation
    self.inputStream = stream.stream
    self.keyboardSupported = keyboardSupported
    self.storedSize = size
  }

  private func write(_ byteSlice: ArraySlice<UInt8>) throws -> Int {
    let bytes = Array(byteSlice)
    recordedEvents.append(.flush(bytes))
    if bytes == privateModeStatusProbeBytes {
      var response = Array("x".utf8)
      for mode in privateModeProbeModes {
        response.append(contentsOf: "\u{1B}[?\(mode);0$y".utf8)
      }
      inputContinuation.yield(response)
    } else if bytes == kittyKeyboardProbeBytes {
      let response =
        keyboardSupported ? "\u{1B}[?7u\u{1B}[?1;2c" : "\u{1B}[?1;2c"
      inputContinuation.yield(Array(response.utf8))
    } else if containsBytes(Array(",a=q,".utf8), in: bytes) {
      inputContinuation.yield(Array("\u{1B}[?1;2c".utf8))
    }
    return bytes.count
  }
}

private actor DelayedSizeTerminalDevice {
  private var recordedBytes: [UInt8] = []
  private var sizeContinuation: CheckedContinuation<TerminalSize, Never>?
  private var sizeRequestWaiters: [CheckedContinuation<Void, Never>] = []
  private var sizeRequested = false

  var bytes: [UInt8] {
    recordedBytes
  }

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      size: { await self.size() },
      write: { await self.write($0) }
    )
  }

  func waitForSizeRequest() async {
    guard !sizeRequested else {
      return
    }

    await withCheckedContinuation { continuation in
      sizeRequestWaiters.append(continuation)
    }
  }

  func resolveSize(_ size: TerminalSize) {
    sizeContinuation?.resume(returning: size)
    sizeContinuation = nil
  }

  private func size() async -> TerminalSize {
    sizeRequested = true
    let waiters = sizeRequestWaiters
    sizeRequestWaiters.removeAll()
    for waiter in waiters {
      waiter.resume()
    }

    return await withCheckedContinuation { continuation in
      sizeContinuation = continuation
    }
  }

  private func write(_ byteSlice: ArraySlice<UInt8>) -> Int {
    let bytes = Array(byteSlice)
    recordedBytes.append(contentsOf: bytes)
    return bytes.count
  }
}

private actor PartialFailureTerminalDevice {
  private var attempts = 0
  private var recordedBytes: [UInt8] = []
  private let storedSize: TerminalSize

  var bytes: [UInt8] {
    recordedBytes
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

  private func write(_ byteSlice: ArraySlice<UInt8>) throws -> Int {
    defer { attempts += 1 }
    switch attempts {
    case 0:
      let firstByte = byteSlice.prefix(1)
      recordedBytes.append(contentsOf: firstByte)
      return firstByte.count
    case 1:
      throw PlatformIOError.writeFailed(errno: .ioError)
    default:
      recordedBytes.append(contentsOf: byteSlice)
      return byteSlice.count
    }
  }
}

private actor OffsetFailureTerminalDevice {
  private var didFail = false
  private var recordedBytes: [UInt8] = []
  private var remainingBytesBeforeFailure: Int
  private let storedSize: TerminalSize

  var bytes: [UInt8] {
    recordedBytes
  }

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      size: { self.storedSize },
      write: { try await self.write($0) }
    )
  }

  init(failureOffset: Int, size: TerminalSize) {
    self.remainingBytesBeforeFailure = failureOffset
    self.storedSize = size
  }

  private func write(_ byteSlice: ArraySlice<UInt8>) throws -> Int {
    if didFail {
      recordedBytes.append(contentsOf: byteSlice)
      return byteSlice.count
    }
    guard remainingBytesBeforeFailure > 0 else {
      didFail = true
      throw PlatformIOError.writeFailed(errno: .ioError)
    }

    let writeCount = min(remainingBytesBeforeFailure, byteSlice.count)
    recordedBytes.append(contentsOf: byteSlice.prefix(writeCount))
    remainingBytesBeforeFailure -= writeCount
    return writeCount
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

private actor LifecycleFailureTerminalDevice {
  enum Event: Equatable, Sendable {
    case enterAltScreen
    case enterRawMode
    case exitAltScreen
    case exitRawMode
    case flush([UInt8])
  }

  enum Failure: Error, Equatable, Hashable, Sendable {
    case applicationMode
    case cursorRestore
    case exitRawMode
    case probe
  }

  private var remainingFailures: Set<Failure>
  private var recordedEvents: [Event] = []

  var events: [Event] {
    recordedEvents
  }

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      enterAltScreen: { await self.enterAltScreen() },
      enterRawMode: { await self.enterRawMode() },
      exitAltScreen: { await self.exitAltScreen() },
      exitRawMode: { try await self.exitRawMode() },
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  init(failures: Set<Failure>) {
    self.remainingFailures = failures
  }

  private func enterAltScreen() {
    recordedEvents.append(.enterAltScreen)
  }

  private func enterRawMode() {
    recordedEvents.append(.enterRawMode)
  }

  private func exitAltScreen() {
    recordedEvents.append(.exitAltScreen)
  }

  private func exitRawMode() throws {
    recordedEvents.append(.exitRawMode)
    if consume(.exitRawMode) {
      throw Failure.exitRawMode
    }
  }

  private func write(_ byteSlice: ArraySlice<UInt8>) throws -> Int {
    let bytes = Array(byteSlice)
    recordedEvents.append(.flush(bytes))

    if bytes == privateModeStatusProbeBytes, consume(.probe) {
      throw Failure.probe
    }
    if bytes == bracketedPasteEnableBytes, consume(.applicationMode) {
      throw Failure.applicationMode
    }
    if bytes == cursorVisibleBytes, consume(.cursorRestore) {
      throw Failure.cursorRestore
    }

    return bytes.count
  }

  private func consume(_ failure: Failure) -> Bool {
    remainingFailures.remove(failure) != nil
  }
}

private actor RuntimeModeTerminalDevice {
  private var bytesToFailPartwayThrough: [UInt8] = []
  private var bytesToSuspend: [UInt8] = []
  private var failsNextWrite = false
  private var isWriteSuspended = false
  private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
  private var writeContinuation: CheckedContinuation<Void, Never>?

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      enterAltScreen: {},
      enterRawMode: {},
      exitAltScreen: {},
      exitRawMode: {},
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  func failPartwayThroughNextWrite(matching bytes: [UInt8]) {
    bytesToFailPartwayThrough = bytes
  }

  func suspendNextWrite(matching bytes: [UInt8]) {
    bytesToSuspend = bytes
  }

  func waitForSuspension() async {
    guard !isWriteSuspended else {
      return
    }
    await withCheckedContinuation { continuation in
      suspensionWaiters.append(continuation)
    }
  }

  func resumeSuspendedWrite() {
    writeContinuation?.resume()
    writeContinuation = nil
    isWriteSuspended = false
  }

  private func write(_ byteSlice: ArraySlice<UInt8>) async throws -> Int {
    if failsNextWrite {
      failsNextWrite = false
      throw PlatformIOError.writeFailed(errno: .ioError)
    }

    let bytes = Array(byteSlice)
    if !bytesToFailPartwayThrough.isEmpty,
      bytes == bytesToFailPartwayThrough,
      bytes.count > 1
    {
      bytesToFailPartwayThrough.removeAll()
      failsNextWrite = true
      return 1
    }

    if !bytesToSuspend.isEmpty, bytes == bytesToSuspend {
      bytesToSuspend.removeAll()
      await withCheckedContinuation { continuation in
        writeContinuation = continuation
        isWriteSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        for waiter in waiters {
          waiter.resume()
        }
      }
    }
    return byteSlice.count
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
