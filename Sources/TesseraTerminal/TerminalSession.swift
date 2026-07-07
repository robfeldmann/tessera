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
  private let inputEvents: AsyncEventBuffer<InputEvent>
  private let inputPump: Task<Void, Never>
  private let io: PlatformIO
  private var lastDrawnBuffer: Buffer?
  private var renderer = Renderer()

  /// Capability hints resolved for this session.
  nonisolated public let capabilities: TerminalCapabilities

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

  /// The terminal's per-cell pixel size, or `nil` when unknown.
  public var cellPixelSize: CellPixelSize? {
    get async { await io.cellPixelSize() }
  }
  package init(
    io: PlatformIO,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled,
    capabilities: TerminalCapabilities = .conservativeDefault,
    enabledProtocolModes: Set<ModeLifecycle.Mode> = [],
    hyperlinkRendering: HyperlinkRenderingMode = .enabled
  ) {
    let inputEvents = AsyncEventBuffer<InputEvent>(coalescing: shouldCoalesceInputEvents)
    let eventStream = AsyncStream<InputEvent>.makeStream()
    self.capabilities = capabilities
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
    self.hyperlinkRendering = hyperlinkRendering
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
      hyperlinkRendering: resolution.hyperlinkRendering
    )
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
