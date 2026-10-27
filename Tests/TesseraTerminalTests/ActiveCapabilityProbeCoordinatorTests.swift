import CustomDump
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminal

@Test
func `probe coordinator runs graphics after unsupported keyboard evidence`() async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let imageID = KittyImageID(rawValue: 41)
  let modes = [2_004, 1_004, 1_002, 1_003, 1_006, 2_026]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: imageID,
    colorScope: .all,
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
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      } else if bytes == kittyKeyboardProbeBytes {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      } else if bytes == colorProbeBytes {
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
      colorProbeBytes,
    ])
  expectNoDifference(evidence.kittyKeyboard, .unsupported)
  expectNoDifference(evidence.kittyGraphics, .supported)
  let expectedModes: [Int: PrivateModeState] = Dictionary(
    uniqueKeysWithValues: modes.map { ($0, .reset) }
  )
  expectNoDifference(evidence.privateModes, expectedModes)
}

@Test
func `DA1 alone ends the DECRQM round without waiting for the timeout`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let imageID = KittyImageID(rawValue: 7)
  let modes = [2_004, 1_004]
  let (sleepStarted, sleepStartedSignal) = AsyncStream<Void>.makeStream()
  let sleepCalls = SleepCallCounter()

  // The terminal ignores every DECRQM request and answers only DA1. The injected sleep
  // never elapses, so only the DA1 sentinel can end the round.
  let replies = Task {
    for await _ in sleepStarted {
      await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      return
    }
  }
  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: imageID,
    colorScope: .all,
    timeout: .seconds(60),
    sleep: { _ in
      await sleepCalls.record()
      sleepStartedSignal.yield()
      try await suspendUntilCancelled()
    },
    emit: { bytes in
      await recorder.append(bytes)
      if bytes != privateModeProbeBytes(modes) {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    }
  )
  await replies.value

  let emissions = await recorder.values
  expectNoDifference(
    emissions,
    [
      privateModeProbeBytes(modes),
      kittyKeyboardProbeBytes,
      kittyGraphicsProbeBytes(imageID),
      colorProbeBytes,
    ])
  let sleepCallCount = await sleepCalls.count
  expectNoDifference(sleepCallCount, 1)
  expectNoDifference(evidence.privateModes, [:])
}

@Test
func `DA1 ends the DECRQM round with only the replies received so far`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let modes = [2_004, 1_004]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .seconds(60),
    sleep: { _ in
      Issue.record("DA1 should have ended every round before its timeout")
    },
    emit: { bytes in
      if bytes == privateModeProbeBytes(modes) {
        await coordinator.observe(
          .privateModeStatus(PrivateModeStatus(mode: 2_004, state: .set))
        )
      }
      await coordinator.observe(.primaryDeviceAttributes([1, 2]))
    }
  )

  expectNoDifference(evidence.privateModes, [2_004: .set])
}

@Test
func `DECRQM timeout retires the later rounds and resolves unknown evidence`()
  async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let modes = [2_004, 1_004]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .milliseconds(250),
    sleep: { _ in },
    emit: { bytes in
      await recorder.append(bytes)
    }
  )

  // The late DA1 of the timed-out round must not reach a round that never started.
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))

  let emissions = await recorder.values
  expectNoDifference(emissions, [privateModeProbeBytes(modes), colorProbeBytes])
  expectNoDifference(evidence, ActiveCapabilityProbeEvidence())
  let cachedEvidence = await coordinator.cachedEvidence()
  expectNoDifference(cachedEvidence, evidence)
}

@Test
func `keyboard timeout skips graphics probe and resolves partial evidence`() async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let imageID = KittyImageID(rawValue: 7)
  let modes = [2_004, 1_004]

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: imageID,
    colorScope: .all,
    timeout: .milliseconds(250),
    sleep: { _ in },
    emit: { bytes in
      await recorder.append(bytes)
      if bytes == privateModeProbeBytes(modes) {
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
      colorProbeBytes,
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
    colorScope: .all,
    timeout: .milliseconds(250),
    sleep: { _ in },
    emit: { bytes in
      await recorder.append(bytes)
      if bytes == privateModeProbeBytes(modes) {
        await coordinator.observe(
          .privateModeStatus(PrivateModeStatus(mode: modes[0], state: .reset))
        )
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
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
func `input closure resumes a probe and rejects an overlapping generation`() async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let firstProbe = Task {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        try await suspendUntilCancelled()
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
      colorScope: .all,
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
func `failed emit returns the probe generation to idle so a later reconcile retries`()
  async throws
{
  struct EmitFailure: Error, Equatable {}
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()

  await #expect(throws: EmitFailure()) {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(1),
      sleep: { _ in },
      emit: { bytes in
        await recorder.append(bytes)
        throw EmitFailure()
      }
    )
  }
  let cachedAfterFailure = await coordinator.cachedEvidence()
  let inProgressAfterFailure = await coordinator.isInProgress()
  #expect(cachedAfterFailure == nil)
  #expect(!inProgressAfterFailure)

  let evidence = try await coordinator.reconcile(
    privateModes: [2_004],
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
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
      privateModeProbeBytes([2_004]),
      privateModeProbeBytes([2_004]),
      colorProbeBytes,
    ])
  expectNoDifference(evidence, ActiveCapabilityProbeEvidence())
  let cachedAfterRetry = await coordinator.cachedEvidence()
  expectNoDifference(cachedAfterRetry, evidence)
}

@Test
func `cancelled probe discards partial evidence and a later reconcile retries`()
  async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let modes = [2_004]

  let cancelledProbe = Task {
    try await coordinator.reconcile(
      privateModes: modes,
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        try await suspendUntilCancelled()
      },
      emit: { bytes in
        await recorder.append(bytes)
        if bytes == privateModeProbeBytes(modes) {
          await coordinator.observe(
            .privateModeStatus(PrivateModeStatus(mode: modes[0], state: .set))
          )
          await coordinator.observe(.primaryDeviceAttributes([1, 2]))
        }
      }
    )
  }

  await recorder.waitForCount(2)
  cancelledProbe.cancel()
  await #expect(throws: CancellationError.self) {
    try await cancelledProbe.value
  }
  let cachedAfterCancel = await coordinator.cachedEvidence()
  let inProgressAfterCancel = await coordinator.isInProgress()
  #expect(cachedAfterCancel == nil)
  #expect(!inProgressAfterCancel)

  let evidence = try await coordinator.reconcile(
    privateModes: modes,
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
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
      privateModeProbeBytes(modes),
      colorProbeBytes,
    ])
  expectNoDifference(evidence, ActiveCapabilityProbeEvidence())
}

@Test
func `a cancelled generation's DA1 does not end the retry's DECRQM round`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let (sleepStarted, sleepStartedSignal) = AsyncStream<Void>.makeStream()
  let cancelledProbe = Task {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        sleepStartedSignal.yield()
        try await suspendUntilCancelled()
      },
      emit: { _ in }
    )
  }
  for await _ in sleepStarted {
    break
  }
  cancelledProbe.cancel()
  await #expect(throws: CancellationError.self) {
    try await cancelledProbe.value
  }

  try await expectRetryAttributesEverySentinel(
    coordinator,
    abandonedReplies: [
      .privateModeStatus(PrivateModeStatus(mode: 2_004, state: .set)),
      .primaryDeviceAttributes([1, 2]),
    ]
  )
}

@Test
func `a failed emit's DA1 does not end the retry's DECRQM round`() async throws {
  struct EmitFailure: Error, Equatable {}
  let coordinator = ActiveCapabilityProbeCoordinator()
  await #expect(throws: EmitFailure()) {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        Issue.record("a failed emit should not reach a timeout")
      },
      emit: { _ in throw EmitFailure() }
    )
  }

  try await expectRetryAttributesEverySentinel(
    coordinator,
    abandonedReplies: [
      .privateModeStatus(PrivateModeStatus(mode: 2_004, state: .set)),
      .primaryDeviceAttributes([1, 2]),
    ]
  )
}

@Test
func `a cancelled color round's DA1 does not end the retry's DECRQM round`() async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let (sleepStarted, sleepStartedSignal) = AsyncStream<Void>.makeStream()
  // The terminal answers every round but the color round, which stays in flight.
  let cancelledProbe = Task {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        sleepStartedSignal.yield()
        try await suspendUntilCancelled()
      },
      emit: { bytes in
        if bytes != colorProbeBytes {
          await coordinator.observe(.primaryDeviceAttributes([1, 2]))
        }
      }
    )
  }
  for await _ in sleepStarted {
    break
  }
  cancelledProbe.cancel()
  await #expect(throws: CancellationError.self) {
    try await cancelledProbe.value
  }

  try await expectRetryAttributesEverySentinel(
    coordinator,
    abandonedReplies: [.primaryDeviceAttributes([1, 2])]
  )
}

@Test
func `a failed color write's DA1 does not end the retry's DECRQM round`() async throws {
  struct EmitFailure: Error, Equatable {}
  let coordinator = ActiveCapabilityProbeCoordinator()
  await #expect(throws: EmitFailure()) {
    try await coordinator.reconcile(
      privateModes: [2_004],
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        Issue.record("a failed color write should not reach a timeout")
      },
      emit: { bytes in
        guard bytes != colorProbeBytes else {
          throw EmitFailure()
        }
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    )
  }

  try await expectRetryAttributesEverySentinel(
    coordinator,
    abandonedReplies: [.primaryDeviceAttributes([1, 2])]
  )
}

@Test
func `a timed-out round's late DA1 does not end the color round`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let sleepCalls = SleepCallCounter()
  let (colorRoundWaiting, colorRoundWaitingSignal) = AsyncStream<Void>.makeStream()

  // The DECRQM round times out, so its DA1 is still in flight when the color round writes,
  // and a terminal that answers in order delivers it right behind that write. The color
  // round must keep waiting: it ends only at its own DA1, which this task delivers once
  // the round is waiting on its sleep. A round that took the stale DA1 would end at once
  // and never reach the sleep.
  let ownReply = Task {
    for await _ in colorRoundWaiting {
      await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      return
    }
  }
  let evidence = try await coordinator.reconcile(
    privateModes: [2_004],
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .seconds(60),
    sleep: { _ in
      let call = await sleepCalls.record()
      if call == 1 {
        return
      }
      colorRoundWaitingSignal.yield()
      try await suspendUntilCancelled()
    },
    emit: { bytes in
      if bytes == colorProbeBytes {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    }
  )
  colorRoundWaitingSignal.finish()
  await ownReply.value

  let sleepCallCount = await sleepCalls.count
  expectNoDifference(sleepCallCount, 2)
  expectNoDifference(evidence, ActiveCapabilityProbeEvidence())
}

@Test
func `a cancelled color re-run's DA1 does not end the next re-run`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  try await resolveGenerationWithNothingInFlight(coordinator)

  let (sleepStarted, sleepStartedSignal) = AsyncStream<Void>.makeStream()
  let cancelledRerun = Task {
    try await coordinator.rerunColorRound(
      scope: .all,
      timeout: .seconds(60),
      sleep: { _ in
        sleepStartedSignal.yield()
        try await suspendUntilCancelled()
      },
      emit: { _ in }
    )
  }
  for await _ in sleepStarted {
    break
  }
  cancelledRerun.cancel()
  try await cancelledRerun.value

  try await expectColorRerunOutlastsEarlierDA1(coordinator)
}

@Test
func `a timed-out color round's late DA1 does not end the theme-change re-run`()
  async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  // Every round is answered but the color round, whose timeout elapses at once and leaves
  // its DA1 in flight.
  _ = try await coordinator.reconcile(
    privateModes: [],
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .seconds(60),
    sleep: { _ in },
    emit: { bytes in
      if !bytes.isEmpty, bytes != colorProbeBytes {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    }
  )

  try await expectColorRerunOutlastsEarlierDA1(coordinator)
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

    let nextEvent = try await session.nextEvent()
    expectNoDifference(nextEvent, .key(Key(code: .character("x"))))
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

@Test
func `colour query bytes are encoded exactly`() {
  expectNoDifference(
    ActiveCapabilityProbeCoordinator.colorQueryBytes(scope: .all),
    colorProbeBytes
  )
  expectNoDifference(
    ActiveCapabilityProbeCoordinator.colorQueryBytes(scope: .backgroundOnly),
    Array("\u{1B}]11;?\u{1B}\\\u{1B}[c".utf8)
  )
}

@Test(.timeLimit(.minutes(1)))
func `colour re-runs queue behind the round in flight and coalesce`() async throws {
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  _ = try await coordinator.reconcile(
    privateModes: [],
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .zero,
    sleep: { _ in },
    emit: { bytes in
      await recorder.append(bytes)
      if !bytes.isEmpty {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    }
  )
  let generationEmissions = await recorder.count

  func rerun() -> Task<Void, any Error> {
    Task {
      try await coordinator.rerunColorRound(
        scope: .all,
        timeout: .seconds(60),
        sleep: { _ in try await suspendUntilCancelled() },
        emit: { await recorder.append($0) }
      )
    }
  }

  let first = rerun()
  await recorder.waitForCount(generationEmissions + 1)
  let requests = [rerun(), rerun(), rerun()]
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  try await first.value
  await recorder.waitForCount(generationEmissions + 2)
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  for request in requests {
    try await request.value
  }

  let emissions = await recorder.values.suffix(2)
  expectNoDifference(Array(emissions), [colorProbeBytes, colorProbeBytes])
  let count = await recorder.count
  expectNoDifference(count, generationEmissions + 2)
}

@Test(.timeLimit(.minutes(1)))
func `colour re-run during the generation waits for the generation's own color round`()
  async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  let modes = [2_004]
  let generation = Task {
    try await coordinator.reconcile(
      privateModes: modes,
      kittyImageID: KittyImageID(rawValue: 7),
      colorScope: .all,
      timeout: .seconds(60),
      sleep: { _ in try await suspendUntilCancelled() },
      emit: { await recorder.append($0) }
    )
  }
  func rerun() -> Task<Void, any Error> {
    Task {
      try await coordinator.rerunColorRound(
        scope: .all,
        timeout: .seconds(60),
        sleep: { _ in try await suspendUntilCancelled() },
        emit: { await recorder.append($0) }
      )
    }
  }

  // Before the generation's color round has asked, its own query covers the request.
  await recorder.waitForCount(1)
  try await rerun().value
  let beforeColorRound = await recorder.count
  expectNoDifference(beforeColorRound, 1)

  await coordinator.observe(
    .privateModeStatus(PrivateModeStatus(mode: modes[0], state: .set))
  )
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  await recorder.waitForCount(2)
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  await recorder.waitForCount(3)
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  await recorder.waitForCount(4)
  let generationColorRoundEmissions = await recorder.values.suffix(1)
  expectNoDifference(Array(generationColorRoundEmissions), [colorProbeBytes])

  // Once it has asked, a later request waits for it, then asks again.
  let afterAsking = rerun()
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  _ = try await generation.value
  await recorder.waitForCount(5)
  await coordinator.observe(.primaryDeviceAttributes([1, 2]))
  try await afterAsking.value

  let emissions = await recorder.values.suffix(2)
  expectNoDifference(Array(emissions), [colorProbeBytes, colorProbeBytes])
  let count = await recorder.count
  expectNoDifference(count, 5)
}

@Test
func `colour re-run does nothing without a resolved generation or after close`()
  async throws
{
  let coordinator = ActiveCapabilityProbeCoordinator()
  let recorder = ProbeEmissionRecorder()
  func rerun() async throws {
    try await coordinator.rerunColorRound(
      scope: .all,
      timeout: .zero,
      sleep: { _ in },
      emit: { await recorder.append($0) }
    )
  }

  try await rerun()
  _ = try await coordinator.reconcile(
    privateModes: [],
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .zero,
    sleep: { _ in },
    emit: { await recorder.append($0) }
  )
  let afterGeneration = await recorder.count
  try await rerun()
  let afterRerun = await recorder.count
  await coordinator.close()
  try await rerun()
  let afterClose = await recorder.count

  expectNoDifference(afterRerun, afterGeneration + 1)
  expectNoDifference(afterClose, afterRerun)
}

/// Suspends until the surrounding task is cancelled, then throws `CancellationError`.
/// Stands in for a sleep that never elapses, so tests never wait on a clock.
private func suspendUntilCancelled() async throws {
  let (stream, continuation) = AsyncStream<Void>.makeStream()
  for await _ in stream {}
  continuation.finish()
  try Task.checkCancellation()
}

/// Replays the replies a terminal sends, in order, one batch per trigger.
private actor ReplyWire {
  private var batches: [[InputEvent]]

  init(_ batches: [[InputEvent]]) {
    self.batches = batches
  }

  func deliverNext(to coordinator: ActiveCapabilityProbeCoordinator) async {
    guard !batches.isEmpty else {
      return
    }
    for event in batches.removeFirst() {
      await coordinator.observe(event)
    }
  }
}

/// Runs a generation in which the terminal answers every round with its DA1, so no DA1 is
/// left in flight.
private func resolveGenerationWithNothingInFlight(
  _ coordinator: ActiveCapabilityProbeCoordinator
) async throws {
  _ = try await coordinator.reconcile(
    privateModes: [],
    kittyImageID: KittyImageID(rawValue: 7),
    colorScope: .all,
    timeout: .seconds(60),
    sleep: { _ in
      Issue.record("an answered round should not reach its timeout")
    },
    emit: { bytes in
      if !bytes.isEmpty {
        await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      }
    }
  )
}

/// Retries a generation whose first attempt already wrote a request and its DA1 that the
/// abandoned attempt will never read. The terminal answers in order, and each reply batch
/// arrives one step later than the write it answers, so the first batch belongs to the
/// abandoned attempt and carries its DA1. The retry must not take that DA1 for any of its
/// own sentinels: that would shift every later round by one and cache false `.unsupported`
/// evidence for a terminal that supports both Kitty protocols.
private func expectRetryAttributesEverySentinel(
  _ coordinator: ActiveCapabilityProbeCoordinator,
  abandonedReplies: [InputEvent]
) async throws {
  let imageID = KittyImageID(rawValue: 7)
  let da1 = InputEvent.primaryDeviceAttributes([1, 2])
  let status = InputEvent.privateModeStatus(PrivateModeStatus(mode: 2_004, state: .set))
  let wire = ReplyWire([
    abandonedReplies,
    [status, da1],  // the retry's DECRQM replies
    [.kittyKeyboardEnhancementFlags(7), da1],
    [.kittyGraphicsResponse(KittyGraphicsResponse(id: imageID, message: "OK")), da1],
    [da1],  // the retry's color round
  ])
  let (sleepStarted, sleepStartedSignal) = AsyncStream<Void>.makeStream()
  // A round that is still waiting for its sentinel is waiting on the sleep, which is
  // injected and never elapses, so the next reply batch arrives only through this task.
  let lateReplies = Task {
    for await _ in sleepStarted {
      await wire.deliverNext(to: coordinator)
    }
  }

  let evidence = try await coordinator.reconcile(
    privateModes: [2_004],
    kittyImageID: imageID,
    colorScope: .all,
    timeout: .seconds(60),
    sleep: { _ in
      sleepStartedSignal.yield()
      try await suspendUntilCancelled()
    },
    emit: { _ in
      await wire.deliverNext(to: coordinator)
    }
  )
  lateReplies.cancel()

  expectNoDifference(evidence.privateModes, [2_004: .set])
  expectNoDifference(evidence.kittyKeyboard, .supported)
  expectNoDifference(evidence.kittyGraphics, .supported)
}

/// Re-runs the color round while an earlier round's DA1 is still in flight. A terminal that
/// answers in order delivers that DA1 right behind the re-run's write. The re-run must keep
/// waiting for its own DA1, which this task delivers once the round is waiting on its sleep;
/// a re-run that took the earlier DA1 would end at once and never reach the sleep.
private func expectColorRerunOutlastsEarlierDA1(
  _ coordinator: ActiveCapabilityProbeCoordinator
) async throws {
  let sleepCalls = SleepCallCounter()
  let (rerunWaiting, rerunWaitingSignal) = AsyncStream<Void>.makeStream()
  let ownReply = Task {
    for await _ in rerunWaiting {
      await coordinator.observe(.primaryDeviceAttributes([1, 2]))
      return
    }
  }

  try await coordinator.rerunColorRound(
    scope: .all,
    timeout: .seconds(60),
    sleep: { _ in
      await sleepCalls.record()
      rerunWaitingSignal.yield()
      try await suspendUntilCancelled()
    },
    emit: { _ in
      await coordinator.observe(.primaryDeviceAttributes([1, 2]))
    }
  )
  rerunWaitingSignal.finish()
  await ownReply.value

  let sleepCallCount = await sleepCalls.count
  expectNoDifference(sleepCallCount, 1)
}

private actor SleepCallCounter {
  private(set) var count = 0

  /// Records one call and returns how many there have been, this one included.
  @discardableResult
  func record() -> Int {
    count += 1
    return count
  }
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
      response.append(contentsOf: "\u{1B}[?1;2c".utf8)
      inputContinuation.yield(response)
    } else if bytes == kittyKeyboardProbeBytes {
      if keyboardSupported {
        inputContinuation.yield(Array("\u{1B}[?7u\u{1B}[?1;2c".utf8))
      } else {
        inputContinuation.yield(Array("\u{1B}[?1;2c".utf8))
      }
    } else if bytes.containsSubsequence(Array(",a=q,".utf8)) {
      inputContinuation.yield(Array("\u{1B}[?1;2c".utf8))
    } else if bytes == colorProbeBytes {
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
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    probeImageID: KittyImageID(rawValue: 17)
  )
  await session.startInputPump()
  return session
}

private let activePrivateModeProbeModes = [2_004, 1_004, 1_002, 1_003, 1_006, 2_026]
private let kittyKeyboardProbeBytes = Array("\u{1B}[?u\u{1B}[c".utf8)

/// One color round, spelled out: `OSC 10 ; ? ST`, `OSC 11 ; ? ST`, `OSC 4 ; n ; ? ST` for
/// each slot 0 through 15, then the round's single DA1.
private let colorProbeBytes = Array(
  ("\u{1B}]10;?\u{1B}\\" + "\u{1B}]11;?\u{1B}\\"
    + (0...15).map { "\u{1B}]4;\($0);?\u{1B}\\" }.joined() + "\u{1B}[c").utf8
)
private let kittyKeyboardPushBytes = Array("\u{1B}[>7u".utf8)
private let kittyKeyboardPopBytes = Array("\u{1B}[<u".utf8)

private func privateModeProbeBytes(_ modes: [Int]) -> [UInt8] {
  modes.flatMap { Array("\u{1B}[?\($0)$p".utf8) } + Array("\u{1B}[c".utf8)
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
