import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalRendering

/// A scoped live-terminal capability for Tessera applications.
public actor TerminalSession {
  private let inputEvents: AsyncEventBuffer<InputEvent>
  private let inputPump: Task<Void, Never>
  private let io: PlatformIO
  private let synchronizedOutput: SynchronizedOutputPolicy
  private var lastDrawnBuffer: Buffer?
  private var renderer = Renderer()

  /// Terminal-size notifications for the live session.
  nonisolated public let sizeChanges: AsyncStream<TerminalSize>

  package init(
    io: PlatformIO,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled
  ) {
    let inputEvents = AsyncEventBuffer<InputEvent>()
    self.inputEvents = inputEvents
    self.inputPump = Task {
      for await byte in io.bytes {
        if let event = InputParser.parse(byte) {
          await inputEvents.yield(event)
        }
      }
      await inputEvents.finish()
    }
    self.io = io
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
    _ body: (isolated TerminalSession) async throws -> sending R
  ) async throws -> sending R {
    let lifecycle = ModeLifecycle(io: io)
    try await lifecycle.enter(configuration.modes)

    let session = TerminalSession(
      io: io,
      synchronizedOutput: configuration.synchronizedOutput
    )
    do {
      let result = try await body(session)
      try await lifecycle.exit()
      return result
    } catch {
      do {
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
    let result = try body(Frame(buffer: storage))
    let buffer = storage.pointee
    var bytes: [UInt8] = []
    renderer.encodeFrame(
      previous: lastDrawnBuffer,
      current: buffer,
      wrapInSynchronizedOutput: synchronizedOutput == .enabled,
      into: &bytes
    )
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
