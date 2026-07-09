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
func `query kitty graphics support writes query and DA1`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  try await session.queryKittyGraphicsSupport(id: KittyImageID(rawValue: 17))

  let events = await device.events

  expectNoDifference(events, [.flush(kittyGraphicsQueryProbeBytes)])
}

@Test
func `query Kitty keyboard support writes query and DA1`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  try await session.queryKittyKeyboardSupport()

  let events = await device.events

  expectNoDifference(events, [.flush(kittyKeyboardProbeBytes)])
}

@Test
func `query private modes writes phase 3 DECRQM requests`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  try await session.queryPrivateModeStatuses()

  let events = await device.events

  expectNoDifference(events, [.flush(privateModeStatusProbeBytes)])
}

@Test
func `query active capabilities writes keyboard and DEC mode probes`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let session = await makeSession(device)

  try await session.queryActiveCapabilities()

  let events = await device.events

  expectNoDifference(events, [.flush(activeCapabilityProbeBytes)])
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
      bracketedPaste: .probing,
      focusEvents: .probing,
      mouseTracking: .probing,
      kittyGraphics: .unknown,
      kittyKeyboard: .probing,
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .probing,
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
      flush: enableBracketedPaste(true)
      flush: enableFocusTracking(true)
      flush: activeCapabilityProbes
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
func `app NO_COLOR overrides forced truecolor draw output`() async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 1, rows: 1))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    colorCapability: .force(.truecolor)
  )

  let observed = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: ["NO_COLOR": "1"]
  ) { session in
    try await session.draw { frame in
      frame.write(
        "R",
        at: TerminalPosition(column: 0, row: 0),
        style: Style(foreground: .rgb(255, 0, 0))
      )
    }
    return session.capabilities.color
  }

  let bytes = await device.bytes
  let truecolorPrefix = Array("\u{1B}[38;2;".utf8)

  expectNoDifference(observed, .noColor)
  #expect(containsBytes(truecolorPrefix, in: bytes) == false)
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
  if bytes == activeCapabilityProbeBytes {
    return "activeCapabilityProbes"
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
private let privateModeProbeModes = [2_004, 1_004, 1_000, 1_002, 1_003, 1_006, 2_026]
private let privateModeStatusProbeBytes = privateModeProbeModes.flatMap { mode in
  Array("\u{1B}[?\(mode)$p".utf8)
}
private let activeCapabilityProbeBytes =
  kittyKeyboardProbeBytes + privateModeStatusProbeBytes

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
