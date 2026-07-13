import CustomDump
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminal

@Test
func `probe coordinator runs graphics after unsupported keyboard evidence`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let imageID = KittyImageID(rawValue: 41)
  let modes = [2_004, 1_004, 1_002, 1_003, 1_006, 2_026]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: imageID,
    timeout: .seconds(1),
    sleep: { _ in
      Issue.record("completed probe round unexpectedly reached its timeout")
    },
    emit: { bytes in
      await recorder.append(bytes)
      if bytes == privateModeProbeBytes(modes) {
        for mode in modes {
          await coordinator.observe(
            .privateModeStatus(PrivateModeStatus(mode: mode, state: .reset))
          )
        }
      } else if bytes == kittyKeyboardProbeBytes {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      } else {
        await coordinator.observe(
          .kittyGraphicsResponse(
            KittyGraphicsResponse(id: KittyImageID(rawValue: 99), message: "OK")
          )
        )
        await coordinator.observe(
          .kittyGraphicsResponse(KittyGraphicsResponse(id: imageID, message: "OK"))
        )
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    }
  )

  let emissions = await recorder.values
  expectNoDifference(
    emissions,
    [
      privateModeProbeBytes(modes),
      kittyKeyboardProbeBytes,
      kittyGraphicsProbeBytes(imageID),
    ])
  expectNoDifference(evidence.kittyKeyboard, .unsupported)
  expectNoDifference(evidence.kittyGraphics, .supported)
  let expectedModes: [Int: PrivateModeState] = Dictionary(
    uniqueKeysWithValues: modes.map { ($0, .reset) }
  )
  expectNoDifference(evidence.privateModes, expectedModes)
}

@Test
func `keyboard timeout skips graphics probe and resolves partial evidence`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let imageID = KittyImageID(rawValue: 7)
  let modes = [2_004, 1_004]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: imageID,
    timeout: .milliseconds(250),
    sleep: { _ in },
    emit: { bytes in
      await recorder.append(bytes)
    }
  )

  let emissions = await recorder.values
  expectNoDifference(
    emissions,
    [
      privateModeProbeBytes(modes),
      kittyKeyboardProbeBytes,
    ])
  #expect(!emissions.contains(kittyGraphicsProbeBytes(imageID)))
  expectNoDifference(evidence, ActiveCapabilityProbeEvidence())
}

@Test
func `late DA1 after keyboard timeout is ignored`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let imageID = KittyImageID(rawValue: 7)
  let modes = [2_004]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: imageID,
    timeout: .milliseconds(250),
    sleep: { _ in },
    emit: { bytes in
      await recorder.append(bytes)
      if bytes == privateModeProbeBytes(modes) {
        await coordinator.observe(
          .privateModeStatus(PrivateModeStatus(mode: modes[0], state: .reset))
        )
      }
    }
  )

  await coordinator.observe(.primaryDeviceAttributes([1, 2]))

  let cachedEvidence = await coordinator.cachedEvidence()
  let emissions = await recorder.values
  expectNoDifference(cachedEvidence, evidence)
  expectNoDifference(evidence.kittyKeyboard, .unknown)
  expectNoDifference(evidence.kittyGraphics, .unknown)
  #expect(!emissions.contains(kittyGraphicsProbeBytes(imageID)))
}

@Test
func `input closure resumes a probe and rejects an overlapping generation`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let firstProbe = Task {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      timeout: .seconds(60),
      sleep: { duration in
        try await ContinuousClock().sleep(for: duration)
      },
      emit: { bytes in
        await recorder.append(bytes)
      }
    )
  }

  await recorder.waitForCount(1)
  await #expect(throws: ActiveCapabilityProbeCoordinatorError.inProgress) {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 8),
      timeout: .zero,
      sleep: { _ in },
      emit: { _ in }
    )
  }

  await coordinator.finishInput()
  let evidence = try await firstProbe.value

  expectNoDifference(evidence, ActiveCapabilityProbeEvidence())
  let emissionCount = await recorder.count
  expectNoDifference(emissionCount, 2)
}

@Test
func `semantic DECRQM events update live evidence without changing effective modes`()
  async throws
{
  let bytes = Array("\u{1B}[?2004;1$y".utf8)
  let device = InMemoryTerminalDevice(inputBytes: bytes)
  let session = await makeProbeSession(device)

  let event = try await session.nextEvent()
  let capabilities = await session.capabilities
  let enabledModes = await session.enabledProtocolModes
  expectNoDifference(
    event,
    .privateModeStatus(PrivateModeStatus(mode: 2_004, state: .set))
  )
  expectNoDifference(capabilities.bracketedPaste, .supported)
  expectNoDifference(enabledModes, [])
}

@Test
func `failed runtime apply publishes possible state without committing request`()
  async throws
{
  let device = PartialCursorTerminalDevice()
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let lifecycle = ModeLifecycle(io: io)
  let session = TerminalSession(
    io: io,
    cursorStyling: .enabled(default: nil),
    keyboardProtocol: .legacyOnly,
    modeLifecycle: lifecycle
  )
  let style = CursorStyle(shape: .steadyBar)

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await session.setCursorStyle(style)
  }

  let report = await session.protocolModeReport
  expectNoDifference(report.requested, [])
  expectNoDifference(report.effective, [])
  #expect(report.possiblyActive.contains(.cursorStyle(style)))
  try await lifecycle.exit()
}

@Test
func `active reconciliation preserves events and enables Kitty`() async throws {
  let device = ResponsiveProbeTerminalDevice(keyboardSupported: true)
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .seconds(1),
    capabilityDetection: .active,
    keyboardProtocol: .kittyIfAvailable
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    expectNoDifference(session.capabilities.kittyKeyboard, .supported)
    expectNoDifference(session.capabilities.kittyGraphics, .unsupported)
    expectNoDifference(session.capabilities.bracketedPaste, .supported)
    expectNoDifference(session.capabilities.focusEvents, .supported)
    expectNoDifference(session.capabilities.mouseTracking, .supported)
    expectNoDifference(session.capabilities.synchronizedOutput, .supported)
    #expect(session.enabledProtocolModes.contains(.kittyKeyboard))
    #expect(session.protocolModeReport.requested.contains(.kittyKeyboard))

    var iterator = session.events.makeAsyncIterator()
    let nextEvent = try await session.nextEvent()
    let streamedEvent = await iterator.next()
    expectNoDifference(nextEvent, .key(Key(code: .character("x"))))
    expectNoDifference(streamedEvent, .key(Key(code: .character("x"))))
  }

  let flushes = await device.flushes
  #expect(flushes.contains(kittyKeyboardPushBytes))
  #expect(flushes.contains(kittyKeyboardPopBytes))
}

@Test
func `DA1 before keyboard response leaves conditional Kitty disabled`() async throws {
  let device = ResponsiveProbeTerminalDevice(keyboardSupported: false)
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .seconds(1),
    capabilityDetection: .active,
    keyboardProtocol: .kittyIfAvailable
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    expectNoDifference(session.capabilities.kittyKeyboard, .unsupported)
    #expect(!session.enabledProtocolModes.contains(.kittyKeyboard))
    #expect(!session.protocolModeReport.requested.contains(.kittyKeyboard))
    expectNoDifference(session.keyboardProtocol, .kittyIfAvailable)
  }

  let flushes = await device.flushes
  #expect(!flushes.contains(kittyKeyboardPushBytes))
  #expect(!flushes.contains(kittyKeyboardPopBytes))
}

@Test
func `required Kitty policy wins when active evidence remains unknown`() async throws {
  let device = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .zero,
    capabilityDetection: .active,
    keyboardProtocol: .kittyRequired
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    expectNoDifference(session.capabilities.kittyKeyboard, .unknown)
    #expect(session.enabledProtocolModes.contains(.kittyKeyboard))
    expectNoDifference(session.keyboardProtocol, .kittyRequired)
  }

  let flushes = await device.events.map(\.flushBytes)
  #expect(flushes.contains(kittyKeyboardPushBytes))
  #expect(flushes.contains(kittyKeyboardPopBytes))
}

private actor ProbeEmissionRecorder {
  private var countWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
  private(set) var values: [[UInt8]] = []

  var count: Int {
    values.count
  }

  func append(_ bytes: [UInt8]) {
    values.append(bytes)
    let ready = countWaiters.filter { values.count >= $0.0 }
    countWaiters.removeAll { values.count >= $0.0 }
    for (_, continuation) in ready {
      continuation.resume()
    }
  }

  func waitForCount(_ count: Int) async {
    guard values.count < count else {
      return
    }
    await withCheckedContinuation { continuation in
      countWaiters.append((count, continuation))
    }
  }
}

private actor ResponsiveProbeTerminalDevice {
  private let inputContinuation: AsyncStream<[UInt8]>.Continuation
  private let inputStream: AsyncStream<[UInt8]>
  private let keyboardSupported: Bool

  private(set) var flushes: [[UInt8]] = []

  var terminalDevice: TerminalDevice {
    let inputStream = inputStream
    return TerminalDevice(
      bytes: { inputStream },
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  init(keyboardSupported: Bool) {
    let stream = AsyncStream<[UInt8]>.makeStream()
    self.inputContinuation = stream.continuation
    self.inputStream = stream.stream
    self.keyboardSupported = keyboardSupported
  }

  private func write(_ byteSlice: ArraySlice<UInt8>) throws -> Int {
    let bytes = Array(byteSlice)
    flushes.append(bytes)

    if bytes == privateModeProbeBytes(activePrivateModeProbeModes) {
      var response = Array("x".utf8)
      for mode in activePrivateModeProbeModes {
        response.append(contentsOf: "\u{1B}[?\(mode);1$y".utf8)
      }
      inputContinuation.yield(response)
    } else if bytes == kittyKeyboardProbeBytes {
      if keyboardSupported {
        inputContinuation.yield(Array("\u{1B}[?7u\u{1B}[?1;2c".utf8))
      } else {
        inputContinuation.yield(Array("\u{1B}[?1;2c".utf8))
      }
    } else if bytes.containsSubsequence(Array(",a=q,".utf8)) {
      inputContinuation.yield(Array("\u{1B}[?1;2c".utf8))
    }

    return bytes.count
  }
}

private actor PartialCursorTerminalDevice {
  private var writeAttempt = 0

  var terminalDevice: TerminalDevice {
    TerminalDevice(
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  private func write(_ bytes: ArraySlice<UInt8>) throws -> Int {
    writeAttempt += 1
    if writeAttempt == 1 {
      return 1
    }
    if writeAttempt == 2 {
      throw PlatformIOError.writeFailed(errno: .ioError)
    }
    return bytes.count
  }
}

private func makeProbeSession(_ device: InMemoryTerminalDevice) async -> TerminalSession {
  TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    probeImageID: KittyImageID(rawValue: 17)
  )
}

private let activePrivateModeProbeModes = [2_004, 1_004, 1_002, 1_003, 1_006, 2_026]
private let kittyKeyboardProbeBytes = Array("\u{1B}[?u\u{1B}[c".utf8)
private let kittyKeyboardPushBytes = Array("\u{1B}[>7u".utf8)
private let kittyKeyboardPopBytes = Array("\u{1B}[<u".utf8)

private func privateModeProbeBytes(_ modes: [Int]) -> [UInt8] {
  modes.flatMap { Array("\u{1B}[?\($0)$p".utf8) }
}

private func kittyGraphicsProbeBytes(_ imageID: KittyImageID) -> [UInt8] {
  var bytes = ControlSequence.kittyGraphics(.query(id: imageID)).bytes
  bytes.append(contentsOf: [0x1B, 0x5B, 0x63])
  return bytes
}

extension [UInt8] {
  fileprivate func containsSubsequence(_ subsequence: [UInt8]) -> Bool {
    guard !subsequence.isEmpty, count >= subsequence.count else {
      return false
    }
    return indices.contains { index in
      let endIndex = index + subsequence.count
      guard endIndex <= self.endIndex else {
        return false
      }
      return Array(self[index..<endIndex]) == subsequence
    }
  }
}

extension InMemoryTerminalDeviceEvent {
  fileprivate var flushBytes: [UInt8] {
    if case .flush(let bytes) = self {
      return bytes
    }
    return []
  }
}
