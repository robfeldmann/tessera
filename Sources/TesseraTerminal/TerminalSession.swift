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

/// A scoped live-terminal capability for Tessera applications.
public actor TerminalSession {
  nonisolated private static let kittyKeyboardProbeBytes: [UInt8] = [
    0x1B, 0x5B, 0x3F, 0x75, 0x1B, 0x5B, 0x63,
  ]

  nonisolated private static let privateModeProbeModes = [
    2_004, 1_004, 1_000, 1_002, 1_003, 1_006, 2_026,
  ]

  private let inputEvents: AsyncEventBuffer<InputEvent>
  private let inputPump: Task<Void, Never>
  private let io: PlatformIO
  private var lastDrawnBuffer: Buffer?
  private var renderer = Renderer()

  /// Capability hints resolved for this session.
  nonisolated public let capabilities: TerminalCapabilities

  /// OSC 52 clipboard write policy for this session.
  nonisolated public let clipboardWriting: ClipboardWriteMode

  /// Cursor shape and color styling policy for this session.
  nonisolated public let cursorStyling: CursorStylingPolicy

  /// Terminal modes enabled for this session.
  nonisolated public let enabledProtocolModes: Set<ModeLifecycle.Mode>

  /// The session's semantic terminal event stream.
  nonisolated public let events: AsyncStream<InputEvent>

  /// OSC 8 hyperlink rendering policy applied to drawn frames.
  nonisolated public let hyperlinkRendering: HyperlinkRenderingMode

  /// Terminal-size notifications for the live session.
  nonisolated public let sizeChanges: AsyncStream<TerminalSize>

  /// DEC synchronized output policy applied to drawn frames.
  nonisolated public let synchronizedOutput: SynchronizedOutputPolicy

  /// Underline rendering policy applied to drawn frames.
  public private(set) var underlineRendering: UnderlineRenderingPolicy

  private let modeLifecycle: ModeLifecycle?
  private var activeCursorStyle: CursorStyle?

  /// The currently effective cursor style, if Tessera owns an active style.
  ///
  /// This is actor-isolated because dynamic cursor style requests can mutate it during the
  /// session.
  public var effectiveCursorStyle: CursorStyle? {
    activeCursorStyle
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
    enabledProtocolModes: Set<ModeLifecycle.Mode> = [],
    hyperlinkRendering: HyperlinkRenderingMode = .enabled,
    underlineRendering: UnderlineRenderingPolicy = .extended,
    clipboardWriting: ClipboardWriteMode = .disabled,
    cursorStyling: CursorStylingPolicy = .disabled,
    cursorStyle: CursorStyle? = nil,
    modeLifecycle: ModeLifecycle? = nil
  ) {
    let inputEvents = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
    let eventStream = AsyncStream<InputEvent>.makeStream()
    self.capabilities = capabilities
    self.clipboardWriting = clipboardWriting
    self.cursorStyling = cursorStyling
    self.enabledProtocolModes = enabledProtocolModes
    self.events = eventStream.stream
    self.inputEvents = inputEvents
    self.inputPump = Task {
      for await event in io.events {
        eventStream.continuation.yield(event)
        await inputEvents.yield(event)
      }
      eventStream.continuation.finish()
      await inputEvents.finish()
    }
    self.io = io
    self.activeCursorStyle = cursorStyle
    self.hyperlinkRendering = hyperlinkRendering
    self.modeLifecycle = modeLifecycle
    self.underlineRendering = underlineRendering
    self.synchronizedOutput = synchronizedOutput
    self.sizeChanges = io.sizeChanges
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
    let lifecycle = ModeLifecycle(io: io)
    try await lifecycle.enter(resolution.modes)

    let session = TerminalSession(
      io: io,
      synchronizedOutput: resolution.synchronizedOutput,
      capabilities: resolution.capabilities,
      enabledProtocolModes: resolution.enabledProtocolModes,
      hyperlinkRendering: resolution.hyperlinkRendering,
      underlineRendering: resolution.underlineRendering,
      clipboardWriting: resolution.clipboardWriting,
      cursorStyling: resolution.cursorStyling,
      cursorStyle: resolution.cursorStyle,
      modeLifecycle: lifecycle
    )
    if resolution.runsActiveProbes {
      try await session.queryActiveCapabilities()
    }
    do {
      let result = try await body(session)
      try await session.restoreCursorVisibility()
      try await lifecycle.exit()
      return result
    } catch {
      do {
        try await session.restoreCursorVisibility()
        try await lifecycle.exit()
      } catch {
        // Preserve the application body's error. Cleanup failures are surfaced when the
        // body succeeds; when the body fails, emergency cleanup remains installed until
        // the best-effort exit attempt clears it.
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
    guard case .enabled = cursorStyling, let modeLifecycle else {
      return
    }

    var appModes = enabledProtocolModes.filter { mode in
      switch mode {
      case .rawMode, .altScreen, .cursorStyle:
        return false
      case .bracketedPaste, .focusEvents, .mouseTracking, .kittyKeyboard:
        return true
      }
    }

    if let style, style.shape != nil || style.color != nil {
      appModes.insert(.cursorStyle(style))
    }

    try await modeLifecycle.apply(applicationModes: appModes)
    activeCursorStyle = style
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

  /// Draws one frame and flushes it to terminal output.
  public func draw<R>(
    _ body: (borrowing Frame) throws -> sending R
  ) async throws -> sending R {
    let size = try await io.size()
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
    renderer.encodeFrame(
      previous: lastDrawnBuffer,
      current: buffer,
      wrapInSynchronizedOutput: synchronizedOutput == .enabled,
      colorCapability: capabilities.color,
      underlineRendering: underlineRendering,
      renderHyperlinks: hyperlinkRendering == .enabled,
      into: &bytes
    )
    appendCursorState(cursorStorage.pointee, into: &bytes)
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

  /// Sends a Kitty Graphics Protocol support query followed by DA1 as a sentinel.
  ///
  /// Terminals that support KGP should respond with `InputEvent.kittyGraphicsResponse`
  /// before the `InputEvent.primaryDeviceAttributes` DA1 response. If DA1 arrives first,
  /// the terminal did not answer the graphics query.
  public func queryKittyGraphicsSupport(
    id: KittyImageID = KittyImageID(rawValue: .max)
  ) async throws {
    var bytes = ControlSequence.kittyGraphics(.query(id: id)).bytes
    bytes.append(contentsOf: [0x1B, 0x5B, 0x63])
    await io.write(bytes)
    try await io.flush()
  }

  /// Sends the active capability probes that have protocol-native query mechanisms.
  public func queryActiveCapabilities() async throws {
    var bytes: [UInt8] = []
    bytes.append(contentsOf: Self.kittyKeyboardProbeBytes)
    for mode in Self.privateModeProbeModes {
      bytes.append(contentsOf: privateModeStatusRequestBytes(mode))
    }
    await io.write(bytes)
    try await io.flush()
  }

  /// Sends a Kitty keyboard support query followed by DA1 as a sentinel.
  ///
  /// Terminals that support progressive keyboard enhancement should respond with
  /// `InputEvent.kittyKeyboardEnhancementFlags` before the DA1 sentinel. If DA1
  /// arrives first, the terminal did not answer the keyboard query.
  public func queryKittyKeyboardSupport() async throws {
    await io.write(Self.kittyKeyboardProbeBytes)
    try await io.flush()
  }

  /// Sends DECRQM requests for the DEC private modes used by Phase 3 protocols.
  public func queryPrivateModeStatuses() async throws {
    try await queryPrivateModeStatuses(Self.privateModeProbeModes)
  }

  /// Sends DECRQM requests for selected DEC private modes.
  public func queryPrivateModeStatuses(_ modes: [Int]) async throws {
    var bytes: [UInt8] = []
    for mode in modes {
      bytes.append(contentsOf: privateModeStatusRequestBytes(mode))
    }
    await io.write(bytes)
    try await io.flush()
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
    inputPump.cancel()
  }
}
