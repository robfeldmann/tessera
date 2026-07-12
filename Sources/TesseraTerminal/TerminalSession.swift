import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalRendering

func shouldCoalesceInputEvents(
  _ buffered: InputEvent,
  _ incoming: InputEvent
) -> Bool {
  guard case .mouse(let bufferedMouse) = buffered,
    case .mouse(let incomingMouse) = incoming,
    bufferedMouse.modifiers == incomingMouse.modifiers
  else {
    return false
  }

  switch (bufferedMouse.kind, incomingMouse.kind) {
  case (.move, .move):
    return true
  case (.drag(let bufferedButton), .drag(let incomingButton)):
    return bufferedButton == incomingButton
  case (.press, _),
    (.release, _),
    (.scroll, _),
    (.move, _),
    (.drag, _):
    return false
  }
}

/// Outcome of requesting the session's single active-probe generation.
public enum ActiveCapabilityProbeResult: Equatable, Sendable {
  /// A probe generation already completed, so no bytes were emitted.
  case alreadyResolved

  /// Another caller is currently running the session's probe generation.
  case inProgress

  /// This call completed the session's probe generation.
  case resolved
}

/// Requested policy and lifecycle belief for terminal protocol modes.
public struct TerminalProtocolModeReport: Equatable, Sendable {
  /// Modes the application currently requests.
  public var requested: Set<ModeLifecycle.Mode>

  /// Modes the lifecycle currently believes are active.
  public var effective: Set<ModeLifecycle.Mode>

  /// Modes that may have reached the terminal before an I/O failure.
  public var possiblyActive: Set<ModeLifecycle.Mode>

  /// Creates a protocol-mode report.
  public init(
    requested: Set<ModeLifecycle.Mode>,
    effective: Set<ModeLifecycle.Mode>,
    possiblyActive: Set<ModeLifecycle.Mode>
  ) {
    self.requested = requested
    self.effective = effective
    self.possiblyActive = possiblyActive
  }
}

private actor TerminalSessionInputObserver {
  private weak var session: TerminalSession?
  private var waiters: [CheckedContinuation<TerminalSession?, Never>] = []

  func install(_ session: TerminalSession) {
    self.session = session
    let waiters = self.waiters
    self.waiters.removeAll()
    for waiter in waiters {
      waiter.resume(returning: session)
    }
  }

  func observe(_ event: InputEvent) async {
    guard let session = await installedSession() else {
      return
    }
    await session.observeInput(event)
  }

  private func installedSession() async -> TerminalSession? {
    if let session {
      return session
    }
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }
}

/// A scoped live-terminal capability for Tessera applications.
public actor TerminalSession {
  private enum ApplicationModeMutation {
    case cursorStyle(CursorStyle?)
    case focusEvents(Bool)
    case keyboardProtocol(KeyboardProtocolMode, kittyStatus: CapabilityStatus?)
    case mouseTracking(MouseTrackingMode)
  }

  nonisolated private static let privateModeProbeModes = [
    2_004, 1_004, 1_002, 1_003, 1_006, 2_026,
  ]

  private let activeProbeTimeout: Duration
  private let inputEvents: AsyncEventBuffer<InputEvent>
  private var inputPump: Task<Void, Never>?
  private let io: PlatformIO
  private var lastDrawnBuffer: Buffer?
  private let modeLifecycle: ModeLifecycle?
  private let modeTransitionGate = ModeLifecycleTransitionGate()
  private let probeCoordinator: ActiveCapabilityProbeCoordinator
  private let probeImageID: KittyImageID
  private let probeSleep: ActiveCapabilityProbeCoordinator.Sleep
  private var renderer = Renderer()
  private var requestedApplicationModes: Set<ModeLifecycle.Mode>

  /// Capability evidence observed for this session.
  public private(set) var capabilities: TerminalCapabilities

  /// Application-selected color policy for future drawn frames.
  public private(set) var colorCapability: ColorCapabilityOverride

  /// Color capability used by the renderer after applying the policy and user constraints.
  public private(set) var effectiveColorCapability: ColorCapability

  /// Whether the session environment explicitly contained `NO_COLOR`.
  public private(set) var hasNoColorEnvironment: Bool

  /// Whether the session environment identified a dumb-family `TERM`.
  public private(set) var hasDumbTerminal: Bool

  /// OSC 52 clipboard write policy for this session.
  nonisolated public let clipboardWriting: ClipboardWriteMode

  /// Cursor shape and color styling policy for this session.
  nonisolated public let cursorStyling: CursorStylingPolicy

  /// Terminal modes the lifecycle currently believes are active for this session.
  public private(set) var enabledProtocolModes: Set<ModeLifecycle.Mode>

  /// Whether focus-event reporting is currently requested by the application.
  public var focusEventsEnabled: Bool {
    requestedApplicationModes.contains(.focusEvents)
  }

  /// The session's semantic terminal event stream.
  nonisolated public let events: AsyncStream<InputEvent>

  /// OSC 8 hyperlink rendering policy applied to future drawn frames.
  public private(set) var hyperlinkRendering: HyperlinkRenderingMode

  /// Terminal-size notifications for the live session.
  nonisolated public let sizeChanges: AsyncStream<TerminalSize>

  /// DEC synchronized output policy applied to future drawn frames.
  public private(set) var synchronizedOutput: SynchronizedOutputPolicy
  /// Keyboard protocol policy requested by the application.
  public private(set) var keyboardProtocol: KeyboardProtocolMode

  /// Progressive-enhancement flags requested whenever Kitty keyboard mode is active.
  public let kittyKeyboardFlags: KittyKeyboardFlags

  /// Mouse-event volume currently requested by the application.
  public var mouseTracking: MouseTrackingMode {
    switch Self.mouseTracking(in: requestedApplicationModes) {
    case .anyEvent:
      .anyEvent
    case .buttonEvents:
      .buttonEvents
    case nil:
      .disabled
    }
  }

  /// Modes that may have reached the terminal before an I/O failure.
  public private(set) var possiblyActiveProtocolModes: Set<ModeLifecycle.Mode>

  /// Requested policy and effective/ambiguous lifecycle state.
  public var protocolModeReport: TerminalProtocolModeReport {
    TerminalProtocolModeReport(
      requested: requestedApplicationModes,
      effective: enabledProtocolModes,
      possiblyActive: possiblyActiveProtocolModes
    )
  }

  /// Underline rendering policy applied to drawn frames.
  public private(set) var underlineRendering: UnderlineRenderingPolicy

  /// The currently effective cursor style, if Tessera owns an active style.
  ///
  /// This is actor-isolated because dynamic cursor style requests can mutate it during the
  /// session.
  public var effectiveCursorStyle: CursorStyle? {
    Self.cursorStyle(in: enabledProtocolModes)
  }

  /// The terminal's per-cell pixel size, or `nil` when unknown.
  public var cellPixelSize: CellPixelSize? {
    get async { await io.cellPixelSize() }
  }

  private var isNestedClipboardTerminal: Bool {
    capabilities.isNested
      || capabilities.identity.kind == .tmux
      || capabilities.identity.kind == .screen
  }
  package init(
    io: PlatformIO,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled,
    capabilities: TerminalCapabilities = .conservativeDefault,
    colorCapability: ColorCapabilityOverride = .detect,
    hasDumbTerminal: Bool = false,
    hasNoColorEnvironment: Bool = false,
    enabledProtocolModes: Set<ModeLifecycle.Mode> = [],
    requestedProtocolModes: Set<ModeLifecycle.Mode> = [],
    hyperlinkRendering: HyperlinkRenderingMode = .enabled,
    underlineRendering: UnderlineRenderingPolicy = .extended,
    clipboardWriting: ClipboardWriteMode = .disabled,
    cursorStyling: CursorStylingPolicy = .disabled,
    cursorStyle: CursorStyle? = nil,
    keyboardProtocol: KeyboardProtocolMode = .legacyOnly,
    kittyKeyboardFlags: KittyKeyboardFlags = .tesseraDefault,
    activeProbeTimeout: Duration = .milliseconds(250),
    probeImageID: KittyImageID = KittyImageID(rawValue: UInt32.random(in: 1...UInt32.max)),
    probeSleep: @escaping ActiveCapabilityProbeCoordinator.Sleep = { duration in
      try await ContinuousClock().sleep(for: duration)
    },
    modeLifecycle: ModeLifecycle? = nil
  ) {
    let inputEvents = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
    let eventStream = AsyncStream<InputEvent>.makeStream()
    let inputObserver = TerminalSessionInputObserver()
    let probeCoordinator = ActiveCapabilityProbeCoordinator()
    self.activeProbeTimeout = activeProbeTimeout
    self.capabilities = capabilities
    self.clipboardWriting = clipboardWriting
    self.colorCapability = colorCapability
    self.cursorStyling = cursorStyling
    self.effectiveColorCapability = colorCapability.effectiveColorCapability(
      detected: capabilities.color,
      hasDumbTerminal: hasDumbTerminal,
      hasNoColorEnvironment: hasNoColorEnvironment
    )
    self.enabledProtocolModes = enabledProtocolModes
    self.events = eventStream.stream
    self.hasDumbTerminal = hasDumbTerminal
    self.hasNoColorEnvironment = hasNoColorEnvironment
    self.hyperlinkRendering = hyperlinkRendering
    self.inputEvents = inputEvents
    self.inputPump = nil
    self.io = io
    self.keyboardProtocol = keyboardProtocol
    self.kittyKeyboardFlags = kittyKeyboardFlags
    self.modeLifecycle = modeLifecycle
    self.possiblyActiveProtocolModes = []
    self.probeCoordinator = probeCoordinator
    self.probeImageID = probeImageID
    self.probeSleep = probeSleep
    var requestedModes =
      requestedProtocolModes.isEmpty ? enabledProtocolModes : requestedProtocolModes
    if let cursorStyle, cursorStyle.shape != nil || cursorStyle.color != nil {
      requestedModes.insert(.cursorStyle(cursorStyle))
    }
    self.requestedApplicationModes = Self.applicationModes(in: requestedModes)
    self.sizeChanges = io.sizeChanges
    self.synchronizedOutput = synchronizedOutput
    self.underlineRendering = underlineRendering
    self.inputPump = Task {
      for await event in io.events {
        await inputObserver.observe(event)
        eventStream.continuation.yield(event)
        await inputEvents.yield(event)
      }
      await probeCoordinator.finishInput()
      eventStream.continuation.finish()
      await inputEvents.finish()
    }
    Task { await inputObserver.install(self) }
  }

  nonisolated private static func fixedOwnershipModes(
    in modes: Set<ModeLifecycle.Mode>
  ) -> Set<ModeLifecycle.Mode> {
    modes.filter { mode in
      switch mode {
      case .rawMode, .altScreen:
        true
      case .bracketedPaste, .cursorStyle, .focusEvents, .kittyKeyboard, .mouseTracking:
        false
      }
    }
  }

  nonisolated private static func applicationModes(
    in modes: Set<ModeLifecycle.Mode>
  ) -> Set<ModeLifecycle.Mode> {
    modes.filter { mode in
      switch mode {
      case .rawMode, .altScreen:
        false
      case .bracketedPaste, .cursorStyle, .focusEvents, .kittyKeyboard, .mouseTracking:
        true
      }
    }
  }

  nonisolated private static func cursorStyle(
    in modes: Set<ModeLifecycle.Mode>
  ) -> CursorStyle? {
    for mode in modes {
      if case .cursorStyle(let style) = mode {
        return style
      }
    }
    return nil
  }

  nonisolated private static func mouseTracking(
    in modes: Set<ModeLifecycle.Mode>
  ) -> MouseTracking? {
    var buttonEventsRequested = false
    for mode in modes {
      switch mode {
      case .mouseTracking(.anyEvent):
        return .anyEvent
      case .mouseTracking(.buttonEvents):
        buttonEventsRequested = true
      case .altScreen, .bracketedPaste, .cursorStyle, .focusEvents, .kittyKeyboard,
        .rawMode:
        continue
      }
    }
    return buttonEventsRequested ? .buttonEvents : nil
  }

  /// Runs `body` inside a scoped application terminal session.
  public static func withApplicationTerminal<R>(
    configuration: TerminalApplicationConfiguration,
    _ body: (isolated TerminalSession) async throws -> sending R
  ) async throws -> sending R {
    let io = try PlatformIO(handles: PlatformHandles.standard())
    return try await withApplicationTerminal(configuration: configuration, io: io, body)
  }

  /// Runs `body` inside a scoped terminal session using package-supplied I/O.
  package static func withApplicationTerminal<R>(
    configuration: TerminalApplicationConfiguration,
    io: PlatformIO,
    environment: [String: String] = TerminalCapabilityDetector.currentEnvironment(),
    _ body: (isolated TerminalSession) async throws -> sending R
  ) async throws -> sending R {
    let resolution = configuration.resolve(environment: environment)
    let lifecycle = ModeLifecycle(
      io: io,
      kittyKeyboardFlags: resolution.kittyKeyboardFlags
    )
    let fixedModes = Self.fixedOwnershipModes(in: resolution.modes)
    let requestedApplicationModes = Self.applicationModes(in: resolution.modes)
    var session: TerminalSession?
    var cursorRestoreAttempted = false
    var lifecycleExitAttempted = false

    do {
      try await lifecycle.enter(fixedModes)

      let constructedSession = TerminalSession(
        io: io,
        synchronizedOutput: resolution.synchronizedOutput,
        capabilities: resolution.capabilities,
        colorCapability: resolution.colorCapability,
        hasDumbTerminal: resolution.hasDumbTerminal,
        hasNoColorEnvironment: resolution.hasNoColorEnvironment,
        enabledProtocolModes: fixedModes,
        requestedProtocolModes: requestedApplicationModes,
        hyperlinkRendering: resolution.hyperlinkRendering,
        underlineRendering: resolution.underlineRendering,
        clipboardWriting: resolution.clipboardWriting,
        cursorStyling: resolution.cursorStyling,
        cursorStyle: resolution.cursorStyle,
        keyboardProtocol: resolution.keyboardProtocol,
        kittyKeyboardFlags: resolution.kittyKeyboardFlags,
        activeProbeTimeout: resolution.activeProbeTimeout,
        modeLifecycle: lifecycle
      )
      session = constructedSession

      if resolution.runsActiveProbes {
        _ = try await constructedSession.queryActiveCapabilities()
      }
      try await constructedSession.applyInitialApplicationModes()

      let result = try await body(constructedSession)
      cursorRestoreAttempted = true
      try await constructedSession.restoreCursorVisibility()
      lifecycleExitAttempted = true
      try await lifecycle.exit()
      return result
    } catch {
      if !cursorRestoreAttempted, let session {
        cursorRestoreAttempted = true
        try? await session.restoreCursorVisibility()
      }
      if !lifecycleExitAttempted {
        lifecycleExitAttempted = true
        try? await lifecycle.exit()
      }
      throw error
    }
  }

  /// Writes text to a terminal clipboard selection using OSC 52.
  public func copyToClipboard(
    _ text: String,
    selection: ClipboardSelection = .clipboard,
    intent: ClipboardUserIntent
  ) async throws -> ClipboardWriteResult {
    try await clipboardWrite(
      ClipboardWrite(selection: selection, text: text),
      intent: intent
    )
  }

  /// Writes bytes to a terminal clipboard selection using OSC 52.
  public func copyToClipboard(
    _ bytes: [UInt8],
    selection: ClipboardSelection = .clipboard,
    intent: ClipboardUserIntent
  ) async throws -> ClipboardWriteResult {
    try await clipboardWrite(
      ClipboardWrite(selection: selection, bytes: bytes),
      intent: intent
    )
  }

  /// Applies session OSC 52 clipboard policy and emits an allowed clipboard write.
  package func clipboardWrite(
    _ write: ClipboardWrite,
    intent: ClipboardUserIntent?
  ) async throws -> ClipboardWriteResult {
    guard case .enabled(let policy) = clipboardWriting else {
      return .denied(.disabledByConfiguration)
    }

    guard intent != nil else {
      return .denied(.missingUserIntent)
    }

    if isNestedClipboardTerminal && !policy.allowsNestedTerminalPassthrough {
      return .denied(.nestedTerminalRequiresExplicitPassthrough(capabilities.identity))
    }

    if write.selection.targets.contains(where: { !policy.allowedTargets.contains($0) }) {
      return .denied(.selectionNotAllowed(write.selection))
    }

    if write.bytes.count > policy.maximumPayloadBytes {
      return .denied(
        .payloadTooLarge(
          actualBytes: write.bytes.count,
          maximumBytes: policy.maximumPayloadBytes
        )
      )
    }

    let bytes = ControlSequence.copyToClipboard(write).bytes
    await io.write(bytes)
    try await io.flush()
    return .sent(bytesWritten: bytes.count)
  }

  /// Changes this session's cursor style at runtime through the mode lifecycle.
  ///
  /// Applications call this public API after opting in to cursor styling. It is a no-op
  /// when cursor styling is disabled. Passing `nil`, or a style whose facets are all
  /// `nil`, tears down any Tessera-owned cursor style. All other application protocol
  /// modes are preserved.
  public func setCursorStyle(_ style: CursorStyle?) async throws {
    guard case .enabled = cursorStyling, modeLifecycle != nil else {
      return
    }

    let requestedStyle: CursorStyle? =
      if let style, style.shape != nil || style.color != nil {
        style
      } else {
        nil
      }
    try await reconcileApplicationModes(.cursorStyle(requestedStyle))
  }

  /// Changes mouse-event reporting at runtime through the mode lifecycle.
  public func setMouseTracking(_ mouseTracking: MouseTrackingMode) async throws {
    guard modeLifecycle != nil else {
      return
    }
    try await reconcileApplicationModes(.mouseTracking(mouseTracking))
  }

  /// Enables or disables terminal focus-event reporting at runtime.
  public func setFocusEvents(_ enabled: Bool) async throws {
    guard modeLifecycle != nil else {
      return
    }
    try await reconcileApplicationModes(.focusEvents(enabled))
  }

  /// Changes the requested keyboard protocol at runtime.
  ///
  /// Conditional Kitty enablement consumes only the permanently cached active-probe
  /// generation. It never starts another probe or trusts passive capability metadata.
  public func setKeyboardProtocol(_ keyboardProtocol: KeyboardProtocolMode) async throws {
    guard modeLifecycle != nil else {
      return
    }
    let kittyStatus = await probeCoordinator.cachedEvidence()?.kittyKeyboard
    try await reconcileApplicationModes(
      .keyboardProtocol(keyboardProtocol, kittyStatus: kittyStatus)
    )
  }

  /// Updates the underline rendering policy applied to future drawn frames.
  ///
  /// A changed policy invalidates cached terminal state so the next draw erases and
  /// repaints with the new policy. Passing the current policy has no effect.
  public func setUnderlineRendering(_ underlineRendering: UnderlineRenderingPolicy) {
    guard self.underlineRendering != underlineRendering else {
      return
    }

    self.underlineRendering = underlineRendering
    renderer.invalidate()
  }

  /// Updates the color degradation policy applied to future drawn frames.
  ///
  /// The detected color evidence and environment constraints remain unchanged. A changed
  /// effective color capability invalidates cached terminal state so the next draw
  /// repaints; a policy update pinned to the same effective depth does not.
  public func setColorCapability(_ colorCapability: ColorCapabilityOverride) {
    guard self.colorCapability != colorCapability else {
      return
    }

    self.colorCapability = colorCapability
    let effectiveColorCapability = colorCapability.effectiveColorCapability(
      detected: capabilities.color,
      hasDumbTerminal: hasDumbTerminal,
      hasNoColorEnvironment: hasNoColorEnvironment
    )
    guard self.effectiveColorCapability != effectiveColorCapability else {
      return
    }

    self.effectiveColorCapability = effectiveColorCapability
    renderer.invalidate()
  }

  /// Updates OSC 8 hyperlink rendering for future drawn frames.
  ///
  /// A changed policy invalidates cached terminal state so unchanged cells are repainted
  /// with their hyperlink metadata added or removed. Passing the current policy has no
  /// effect.
  public func setHyperlinkRendering(_ hyperlinkRendering: HyperlinkRenderingMode) {
    guard self.hyperlinkRendering != hyperlinkRendering else {
      return
    }

    self.hyperlinkRendering = hyperlinkRendering
    renderer.invalidate()
  }

  /// Updates DEC synchronized output framing for future drawn frames.
  ///
  /// This does not invalidate renderer cell state because it changes only transaction
  /// boundaries. Passing the current policy has no effect.
  public func setSynchronizedOutput(_ synchronizedOutput: SynchronizedOutputPolicy) {
    guard self.synchronizedOutput != synchronizedOutput else {
      return
    }

    self.synchronizedOutput = synchronizedOutput
  }

  /// Draws one frame and flushes it to terminal output.
  public func draw<R>(
    _ body: (borrowing Frame) throws -> sending R
  ) async throws -> sending R {
    let size = try await io.size()
    // This is the rendering policy commit point. It follows the size suspension and
    // precedes the synchronous frame body and encoding, so no setter can affect a frame
    // once its bytes begin to be constructed.
    let effectiveColorCapability = self.effectiveColorCapability
    let hyperlinkRendering = self.hyperlinkRendering
    let synchronizedOutput = self.synchronizedOutput
    let underlineRendering = self.underlineRendering

    // The frame is a borrowed, non-escapable view onto heap-owned buffer storage. The
    // storage outlives the synchronous body call, and the body runs without suspension, so
    // the frame cannot escape the transaction or be observed by other actor work.
    let storage = UnsafeMutablePointer<Buffer>.allocate(capacity: 1)
    storage.initialize(to: Buffer(size: size))
    defer {
      storage.deinitialize(count: 1)
      storage.deallocate()
    }
    let cursorStorage = UnsafeMutablePointer<TerminalPosition?>.allocate(capacity: 1)
    cursorStorage.initialize(to: nil)
    defer {
      cursorStorage.deinitialize(count: 1)
      cursorStorage.deallocate()
    }
    let result = try body(Frame(buffer: storage, cursorPosition: cursorStorage))
    let buffer = storage.pointee
    var bytes: [UInt8] = []
    if synchronizedOutput == .enabled {
      ControlSequence.enterSynchronizedOutput.encode(into: &bytes)
    }
    renderer.encodeFrame(
      previous: lastDrawnBuffer,
      current: buffer,
      wrapInSynchronizedOutput: false,
      colorCapability: effectiveColorCapability,
      underlineRendering: underlineRendering,
      renderHyperlinks: hyperlinkRendering == .enabled,
      into: &bytes
    )
    appendCursorState(cursorStorage.pointee, into: &bytes)
    if synchronizedOutput == .enabled {
      ControlSequence.exitSynchronizedOutput.encode(into: &bytes)
    }
    await io.write(bytes)
    do {
      try await io.flush()
      lastDrawnBuffer = buffer
      return result
    } catch {
      // A failed flush may have written a prefix of the frame, so docs/Spec.md Slice 4
      // requires the next successful draw to erase and repaint conservatively.
      renderer.invalidate()
      throw error
    }
  }

  /// Runs or reuses this session's single serialized active-probe generation.
  ///
  /// The rounds are DECRQM, Kitty keyboard plus DA1, then Kitty Graphics plus DA1. Every
  /// parsed event remains available through both public input APIs.
  @discardableResult
  public func queryActiveCapabilities() async throws -> ActiveCapabilityProbeResult {
    try await queryActiveCapabilities(kittyImageID: probeImageID)
  }

  /// Runs the session's active-probe generation with a caller-selected graphics query ID.
  ///
  /// The identifier is honored only when this call starts the generation.
  @discardableResult
  public func queryKittyGraphicsSupport(
    id: KittyImageID = KittyImageID(rawValue: .max)
  ) async throws -> ActiveCapabilityProbeResult {
    try await queryActiveCapabilities(kittyImageID: id)
  }

  /// Runs or reuses the session's active-probe generation.
  @discardableResult
  public func queryKittyKeyboardSupport() async throws -> ActiveCapabilityProbeResult {
    try await queryActiveCapabilities()
  }

  /// Runs or reuses the session's active-probe generation.
  @discardableResult
  public func queryPrivateModeStatuses() async throws -> ActiveCapabilityProbeResult {
    try await queryActiveCapabilities()
  }

  /// Transmits image data over the tty. Session-scoped, outside draw.
  public func transmitImage(_ transmission: KittyGraphicsTransmission) async throws {
    await io.write(ControlSequence.kittyGraphics(.transmit(transmission)).bytes)
    try await io.flush()
  }

  /// Deletes Kitty Graphics Protocol images or placements immediately.
  public func deleteImages(_ delete: KittyGraphicsDelete) async throws {
    await io.write(ControlSequence.kittyGraphics(.delete(delete)).bytes)
    try await io.flush()
  }

  /// Invalidates cached renderer assumptions so the next draw repaints conservatively.
  public func invalidateRenderer() {
    renderer.invalidate()
    lastDrawnBuffer = nil
  }

  nonisolated private func privateModeStatusRequestBytes(_ mode: Int) -> [UInt8] {
    Array("\u{1B}[?\(mode)$p".utf8)
  }

  private func reconcileApplicationModes(
    _ mutation: ApplicationModeMutation
  ) async throws {
    guard let modeLifecycle else {
      return
    }
    guard await modeTransitionGate.acquire() else {
      throw CancellationError()
    }

    do {
      var desiredModes = requestedApplicationModes
      switch mutation {
      case .cursorStyle(let style):
        desiredModes = desiredModes.filter {
          if case .cursorStyle = $0 {
            return false
          }
          return true
        }
        if let style {
          desiredModes.insert(.cursorStyle(style))
        }

      case .focusEvents(let enabled):
        if enabled {
          desiredModes.insert(.focusEvents)
        } else {
          desiredModes.remove(.focusEvents)
        }

      case .keyboardProtocol(let policy, let kittyStatus):
        switch policy {
        case .kittyIfAvailable where kittyStatus == .supported, .kittyRequired:
          desiredModes.insert(.kittyKeyboard)
        case .kittyIfAvailable, .legacyOnly:
          desiredModes.remove(.kittyKeyboard)
        }

      case .mouseTracking(let tracking):
        desiredModes = desiredModes.filter {
          if case .mouseTracking = $0 {
            return false
          }
          return true
        }
        switch tracking {
        case .anyEvent:
          desiredModes.insert(.mouseTracking(.anyEvent))
        case .buttonEvents:
          desiredModes.insert(.mouseTracking(.buttonEvents))
        case .disabled:
          break
        }
      }

      let invalidModes = Self.fixedOwnershipModes(in: desiredModes)
      guard invalidModes.isEmpty else {
        throw ModeLifecycleError.unsupportedModes(invalidModes)
      }

      let effectiveApplicationModes = Self.applicationModes(in: enabledProtocolModes)
      let possiblyActiveApplicationModes = Self.applicationModes(
        in: possiblyActiveProtocolModes
      )
      if desiredModes != requestedApplicationModes
        || effectiveApplicationModes != desiredModes
        || !possiblyActiveApplicationModes.isEmpty {
        try await modeLifecycle.apply(applicationModes: desiredModes)
        requestedApplicationModes = desiredModes
        await refreshLifecycleState()
      }
      if case .keyboardProtocol(let policy, _) = mutation {
        keyboardProtocol = policy
      }
      await modeTransitionGate.release()
    } catch {
      await refreshLifecycleState()
      await modeTransitionGate.release()
      throw error
    }
  }

  private func applyInitialApplicationModes() async throws {
    try await reconcileApplicationModes(
      .keyboardProtocol(keyboardProtocol, kittyStatus: capabilities.kittyKeyboard)
    )
  }

  private func queryActiveCapabilities(
    kittyImageID: KittyImageID
  ) async throws -> ActiveCapabilityProbeResult {
    if let evidence = await probeCoordinator.cachedEvidence() {
      capabilities.applyActiveProbeEvidence(evidence)
      return .alreadyResolved
    }
    if await probeCoordinator.isInProgress() {
      return .inProgress
    }

    do {
      let evidence = try await probeCoordinator.reconcile(
        privateModes: Self.privateModeProbeModes,
        kittyImageID: kittyImageID,
        timeout: activeProbeTimeout,
        sleep: probeSleep
      ) { [io] bytes in
        await io.write(bytes)
        try await io.flush()
      }
      capabilities.applyActiveProbeEvidence(evidence)
      return .resolved
    } catch ActiveCapabilityProbeCoordinatorError.alreadyResolved {
      if let evidence = await probeCoordinator.cachedEvidence() {
        capabilities.applyActiveProbeEvidence(evidence)
      }
      return .alreadyResolved
    } catch ActiveCapabilityProbeCoordinatorError.inProgress {
      return .inProgress
    }
  }

  fileprivate func observeInput(_ event: InputEvent) async {
    await probeCoordinator.observe(event)
    switch event {
    case .privateModeStatus(let status):
      capabilities.recordPrivateModeStatus(status)
    case .kittyGraphicsResponse:
      capabilities.kittyGraphics = .supported
    case .kittyKeyboardEnhancementFlags:
      capabilities.kittyKeyboard = .supported
    case .focusGained, .focusLost, .key, .mouse, .paste, .primaryDeviceAttributes, .resize,
      .unknown:
      break
    }
  }

  private func refreshLifecycleState() async {
    guard let modeLifecycle else {
      return
    }
    enabledProtocolModes = await modeLifecycle.activeModes
    possiblyActiveProtocolModes = await modeLifecycle.modesPossiblyActive
  }

  private func appendCursorState(
    _ position: TerminalPosition?,
    into bytes: inout [UInt8]
  ) {
    switch position {
    case .some(let position):
      ControlSequence.cursorVisible(true).encode(into: &bytes)
      ControlSequence.cursorPosition(position).encode(into: &bytes)

    case nil:
      ControlSequence.cursorVisible(false).encode(into: &bytes)
    }
  }

  private func restoreCursorVisibility() async throws {
    await io.write(ControlSequence.cursorVisible(true).bytes)
    try await io.flush()
  }

  /// Reads the next parsed input event.
  public func nextEvent() async throws -> InputEvent {
    guard let event = try await inputEvents.next() else {
      throw PlatformIOError.inputClosed
    }

    return event
  }

  deinit {
    inputPump?.cancel()
  }
}
