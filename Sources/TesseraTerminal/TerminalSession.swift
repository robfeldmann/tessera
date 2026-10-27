import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalRendering

func randomProbeImageID() -> KittyImageID {
  KittyImageID(rawValue: UInt32.random(in: 1...UInt32.max))
}

func continuousClockSleep(_ duration: Duration) async throws {
  try await ContinuousClock().sleep(for: duration)
}

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

/// Errors thrown by a ``TerminalSession``.
public enum TerminalSessionError: Error, Equatable, Sendable {
  /// The session has left its scoped teardown, so it no longer writes to the terminal.
  case closed
}

/// The frame a ``TerminalSession`` last flushed to the terminal.
///
/// A harness seam: it carries what the terminal shows, so a mirror can read it without
/// replaying output bytes.
package struct DrawnFrame: Equatable, Sendable {
  /// The cells the frame painted.
  package let buffer: Buffer

  /// The cursor position the frame requested, or `nil` when the cursor was hidden.
  package let cursor: TerminalPosition?

  /// The count of frames the session has flushed, starting at 1.
  package let sequence: Int
}

/// A scoped live-terminal capability for Tessera applications.
///
/// The session is closed when its `withApplicationTerminal` scope ends. After that, draw,
/// image, clipboard, and runtime mode calls throw ``TerminalSessionError/closed`` before
/// writing to the terminal.
public actor TerminalSession {
  private enum ApplicationModeMutation {
    case cursorStyle(CursorStyle?)
    case focusEvents(Bool)
    case keyboardProtocol(KeyboardProtocolMode, kittyStatus: CapabilityStatus?)
    case mouseTracking(MouseTrackingMode)
  }

  /// The rendering policy fixed for one frame.
  private struct FramePolicy: Sendable {
    var size: TerminalSize
    var colorCapability: ColorCapability
    var hyperlinkRendering: HyperlinkRenderingMode
    var synchronizedOutput: SynchronizedOutputPolicy
    var underlineRendering: UnderlineRenderingPolicy
  }

  nonisolated private static let privateModeProbeModes = [
    2_004, 1_004, 1_002, 1_003, 1_006, 2_026,
  ]

  private let activeProbeTimeout: Duration
  /// Serializes `draw` from the size query through the flush, so each frame diffs against
  /// the frame the terminal last received. It is separate from `modeTransitionGate`, so a
  /// long mode transition does not stall drawing, and a draw does not stall mode changes.
  private let drawGate = ModeLifecycleTransitionGate()
  /// The single queue behind ``events`` and ``nextEvent()``. It is unbounded, so input is
  /// never dropped while it waits for a reader.
  private let inputEvents: AsyncEventBuffer<InputEvent>
  private var inputPump: Task<Void, Never>?
  private let io: PlatformIO
  private var isClosed = false
  private var lastDrawnBuffer: Buffer?
  private let modeLifecycle: ModeLifecycle?
  private let modeTransitionGate = ModeLifecycleTransitionGate()

  /// The number of input reads waiting for an event; a test seam for ordering tests on a
  /// pending read.
  package var pendingEventReadCount: Int {
    get async {
      await inputEvents.waiterCount
    }
  }

  /// The number of draws queued behind the one in flight; a test seam for ordering tests
  /// on the queued state.
  package var queuedDrawCount: Int {
    get async {
      await drawGate.waiterCount
    }
  }

  /// The number of mode setters queued behind the one in flight on this session's gate;
  /// a test seam for ordering tests on the queued state.
  package var queuedModeSetterCount: Int {
    get async {
      await modeTransitionGate.waiterCount
    }
  }

  /// The frame the terminal last received; a test and harness seam.
  ///
  /// A draw sets it once its flush succeeds, so a failed flush leaves the previous frame.
  /// ``invalidateRenderer()`` does not clear it: the terminal still shows that frame.
  package private(set) var lastDrawn: DrawnFrame?

  /// The total bytes of the frames the terminal has received; a test and harness seam.
  ///
  /// A draw adds its encoded byte count once its flush succeeds, as it sets ``lastDrawn``, so
  /// the difference between two reads is what the draws between them wrote. It counts frames
  /// only: mode changes, probes, and cursor-restore writes are not frames.
  package private(set) var bytesDrawn = 0

  /// Receives the encoded bytes of each draw just before they are written, in write order;
  /// a test and harness seam.
  package var outputTap: (@Sendable ([UInt8]) -> Void)?

  /// The terminal's current size; a test and harness seam.
  package var size: TerminalSize {
    get async throws {
      try await io.size()
    }
  }

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
  ///
  /// `events` and ``nextEvent()`` read one shared, unbounded input queue: each event is
  /// delivered once, to whichever reader takes it first, and no event is dropped while it
  /// waits. Consecutive buffered pointer moves, and drags with the same button, coalesce to
  /// the latest position. Cancelling a pending read ends this stream; queued events stay
  /// available to ``nextEvent()``.
  nonisolated public let events: AsyncStream<InputEvent>

  /// OSC 8 hyperlink rendering policy applied to future drawn frames.
  public private(set) var hyperlinkRendering: HyperlinkRenderingMode

  /// Terminal-size notifications for the live session.
  ///
  /// While no reader is waiting, the stream keeps only the newest size and drops older
  /// ones, since only the latest size matters.
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

  /// The colors the session's color rounds ask for: only the background under `NO_COLOR`.
  private var colorQueryScope: ColorQueryScope {
    hasNoColorEnvironment ? .backgroundOnly : .all
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
    activeProbeTimeout: Duration = .seconds(1),
    probeImageID: KittyImageID = randomProbeImageID(),
    probeSleep: @escaping ActiveCapabilityProbeCoordinator.Sleep = continuousClockSleep,
    modeLifecycle: ModeLifecycle? = nil
  ) {
    let inputEvents = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
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
    self.events = AsyncStream { [inputEvents] in
      try? await inputEvents.next()
    }
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
    self.probeCoordinator = ActiveCapabilityProbeCoordinator()
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
  }

  nonisolated private static func fixedOwnershipModes(
    in modes: Set<ModeLifecycle.Mode>
  ) -> Set<ModeLifecycle.Mode> {
    modes.filter { mode in
      switch mode {
      case .rawMode, .altScreen, .colorSchemeNotifications:
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
      case .rawMode, .altScreen, .colorSchemeNotifications:
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
      case .altScreen, .bracketedPaste, .colorSchemeNotifications, .cursorStyle,
        .focusEvents, .kittyKeyboard, .rawMode:
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
    probeImageID: KittyImageID = randomProbeImageID(),
    probeSleep: @escaping ActiveCapabilityProbeCoordinator.Sleep = continuousClockSleep,
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
        probeImageID: probeImageID,
        probeSleep: probeSleep,
        modeLifecycle: lifecycle
      )
      session = constructedSession
      await constructedSession.startInputPump()

      if resolution.runsActiveProbes {
        _ = try await constructedSession.queryActiveCapabilities()
      }
      try await constructedSession.applyInitialApplicationModes()

      let result = try await body(constructedSession)
      await constructedSession.close()
      cursorRestoreAttempted = true
      try await runUncancellableTeardown {
        try await constructedSession.restoreCursorVisibility()
      }
      lifecycleExitAttempted = true
      try await runUncancellableTeardown {
        try await lifecycle.exit()
      }
      return result
    } catch {
      await session?.close()
      if !cursorRestoreAttempted, let session {
        cursorRestoreAttempted = true
        try? await runUncancellableTeardown {
          try await session.restoreCursorVisibility()
        }
      }
      if !lifecycleExitAttempted {
        lifecycleExitAttempted = true
        try? await runUncancellableTeardown {
          try await lifecycle.exit()
        }
      }
      throw error
    }
  }

  /// Runs a teardown step in an unstructured task, which does not inherit the caller's
  /// cancellation, so a cancelled scope still restores the terminal. `value` rethrows the
  /// step's error.
  private static func runUncancellableTeardown(
    _ operation: @escaping @Sendable () async throws -> Void
  ) async throws {
    try await Task {
      try await operation()
    }.value
  }

  /// Starts forwarding parsed input into the session's input queue.
  ///
  /// `withApplicationTerminal` calls this once the session is constructed. The pump holds
  /// the session weakly, so a released session stops it at the next event. Later calls do
  /// nothing.
  package func startInputPump() {
    guard inputPump == nil else {
      return
    }
    inputPump = Task { [weak self, io, inputEvents, probeCoordinator] in
      for await event in io.events {
        guard let self else {
          break
        }
        await self.observeInput(event)
        await inputEvents.yield(event)
      }
      await probeCoordinator.finishInput()
      await inputEvents.finish()
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
    try checkOpen()
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
    try checkOpen()
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
    try checkOpen()
    guard modeLifecycle != nil else {
      return
    }
    try await reconcileApplicationModes(.mouseTracking(mouseTracking))
  }

  /// Enables or disables terminal focus-event reporting at runtime.
  public func setFocusEvents(_ enabled: Bool) async throws {
    try checkOpen()
    guard modeLifecycle != nil else {
      return
    }
    try await reconcileApplicationModes(.focusEvents(enabled))
  }

  /// Changes the requested keyboard protocol at runtime.
  ///
  /// Conditional Kitty enablement consumes only the cached result of the session's
  /// active-probe generation. It never starts another probe or trusts passive capability
  /// metadata. A probe that timed out stays resolved; a cancelled probe, or one whose
  /// bytes failed to send, returns to idle, and a later active-probe query retries it.
  public func setKeyboardProtocol(_ keyboardProtocol: KeyboardProtocolMode) async throws {
    try checkOpen()
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
  ///
  /// The body runs in the caller's isolation, so a graph that lives with its host (the
  /// main actor, another actor, or this session) renders where it lives; the session
  /// serializes draws and commits the finished buffer. Concurrent draws run one at a
  /// time, so each frame diffs against the frame the terminal last received.
  nonisolated(nonsending) public func draw<R>(
    _ body: (borrowing Frame) throws -> R
  ) async throws -> R {
    guard await acquireDrawGate() else {
      throw CancellationError()
    }
    do {
      let result = try await drawHoldingGate(body)
      await releaseDrawGate()
      return result
    } catch {
      await releaseDrawGate()
      throw error
    }
  }

  private func acquireDrawGate() async -> Bool {
    await drawGate.acquire()
  }

  private func releaseDrawGate() async {
    await drawGate.release()
  }

  /// Reads the size and fixes the policy for the frame about to be rendered.
  ///
  /// This is the rendering policy commit point. It follows the size suspension and
  /// precedes the synchronous frame body and encoding, so no setter can affect a frame
  /// once its bytes begin to be constructed.
  private func beginFrame() async throws -> FramePolicy {
    try checkOpen()
    let size = try await io.size()
    return FramePolicy(
      size: size,
      colorCapability: effectiveColorCapability,
      hyperlinkRendering: hyperlinkRendering,
      synchronizedOutput: synchronizedOutput,
      underlineRendering: underlineRendering
    )
  }

  nonisolated(nonsending) private func drawHoldingGate<R>(
    _ body: (borrowing Frame) throws -> R
  ) async throws -> R {
    let policy = try await beginFrame()

    // The frame is a borrowed, non-escapable view onto heap-owned buffer storage. The
    // storage outlives the synchronous body call, and the body runs without suspension in
    // the caller's isolation, so the frame cannot escape the transaction or be observed by
    // other work.
    let storage = UnsafeMutablePointer<Buffer>.allocate(capacity: 1)
    storage.initialize(to: Buffer(size: policy.size))
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
    try await commitFrame(storage.pointee, cursor: cursorStorage.pointee, policy: policy)
    return result
  }

  /// Encodes the rendered buffer against the last drawn one and flushes the bytes.
  ///
  /// The body ran in the caller's isolation, so the scope that owns this session can have
  /// closed since `beginFrame`; the check keeps a frame from reaching a terminal that has
  /// already left its application modes.
  private func commitFrame(
    _ buffer: Buffer,
    cursor: TerminalPosition?,
    policy: FramePolicy
  ) async throws {
    try checkOpen()
    var bytes: [UInt8] = []
    if policy.synchronizedOutput == .enabled {
      ControlSequence.enterSynchronizedOutput.encode(into: &bytes)
    }
    renderer.encodeFrame(
      previous: lastDrawnBuffer,
      current: buffer,
      wrapInSynchronizedOutput: false,
      colorCapability: policy.colorCapability,
      underlineRendering: policy.underlineRendering,
      renderHyperlinks: policy.hyperlinkRendering == .enabled,
      into: &bytes
    )
    appendCursorState(cursor, into: &bytes)
    if policy.synchronizedOutput == .enabled {
      ControlSequence.exitSynchronizedOutput.encode(into: &bytes)
    }
    outputTap?(bytes)
    await io.write(bytes)
    do {
      try await io.flush()
      lastDrawnBuffer = buffer
      bytesDrawn += bytes.count
      lastDrawn = DrawnFrame(
        buffer: buffer,
        cursor: cursor,
        sequence: (lastDrawn?.sequence ?? 0) + 1
      )
    } catch {
      // A failed flush may have written a prefix of the frame, so the next successful draw
      // must erase and repaint conservatively.
      renderer.invalidate()
      throw error
    }
  }

  /// Runs or reuses this session's single serialized active-probe generation.
  ///
  /// The rounds are DECRQM, Kitty keyboard plus DA1, Kitty Graphics plus DA1, then the
  /// color round: OSC 10, 11, and 4 queries plus DA1, which fills ``capabilities``'s
  /// ``TerminalCapabilities/colorReport``. The color round asks only for the background
  /// when the environment sets `NO_COLOR`. Every parsed event, including probe replies,
  /// remains available through the input queue.
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
    try checkOpen()
    await io.write(ControlSequence.kittyGraphics(.transmit(transmission)).bytes)
    try await io.flush()
  }

  /// Deletes Kitty Graphics Protocol images or placements immediately.
  public func deleteImages(_ delete: KittyGraphicsDelete) async throws {
    try checkOpen()
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
      try checkOpen()
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
        || !possiblyActiveApplicationModes.isEmpty
      {
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
        colorScope: colorQueryScope,
        timeout: activeProbeTimeout,
        sleep: probeSleep,
        emit: emitProbeBytes
      )
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

  /// Writes one probe round to the terminal, unless the session has closed.
  private func emitProbeBytes(_ bytes: [UInt8]) async throws {
    try checkOpen()
    await io.write(bytes)
    try await io.flush()
  }

  /// Asks the terminal for its colors again after the process resumes from a suspend.
  ///
  /// The session's suspend path calls this once the terminal is back. It does nothing
  /// unless active detection ran the session's probe generation, because `.passive` and
  /// `.disabled` detection send no color queries. Replies fill ``capabilities``'s
  /// ``TerminalCapabilities/colorReport`` as they arrive.
  package func resumeAfterSuspend() async throws {
    try await rerunColorRound()
  }

  private func rerunColorRound() async throws {
    try await probeCoordinator.rerunColorRound(
      scope: colorQueryScope,
      timeout: activeProbeTimeout,
      sleep: probeSleep,
      emit: emitProbeBytes
    )
  }

  /// Re-runs the color round for a color-scheme notification without blocking the input
  /// pump, which must keep delivering the round's replies. A failed re-run leaves the
  /// reported colors as they were; the next notification asks again.
  private func scheduleColorRound() {
    Task { [weak self] in
      try? await self?.rerunColorRound()
    }
  }

  private func observeInput(_ event: InputEvent) async {
    await probeCoordinator.observe(event)
    switch event {
    case .colorReport(let reply):
      capabilities.colorReport.record(reply)
    case .colorSchemeChanged:
      scheduleColorRound()
    case .privateModeStatus(let status):
      capabilities.recordPrivateModeStatus(status)
    case .kittyGraphicsResponse:
      capabilities.kittyGraphics = .supported
    case .kittyKeyboardEnhancementFlags:
      capabilities.kittyKeyboard = .supported
    case .focusGained, .focusLost, .key, .mouse, .paste, .primaryDeviceAttributes,
      .resize,
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

  /// Marks the session closed once its scope ends; later writing calls throw and a color
  /// round in flight ends.
  private func close() async {
    isClosed = true
    await probeCoordinator.close()
  }

  private func checkOpen() throws {
    if isClosed {
      throw TerminalSessionError.closed
    }
  }

  /// Reads the next parsed input event from the queue shared with ``events``.
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
