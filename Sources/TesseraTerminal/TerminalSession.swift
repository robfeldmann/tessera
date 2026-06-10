import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalRendering

/// A scoped live-terminal capability for Tessera applications.
public actor TerminalSession {
  private let inputEvents: InputEventBuffer
  private let inputPump: Task<Void, Never>
  private let io: PlatformIO

  /// Terminal-size notifications for the live session.
  nonisolated public let sizeChanges: AsyncStream<TerminalSize>

  package init(io: PlatformIO) {
    let inputEvents = InputEventBuffer()
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

    let session = TerminalSession(io: io)
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
    let frame = Frame(size: size)
    let result = try body(frame)
    await io.write(Renderer.render(frame.buffer))
    try await io.flush()
    return result
  }

  /// Reads the next parsed input event.
  public func nextEvent() async throws -> InputEvent {
    guard let event = await inputEvents.next() else {
      throw PlatformIOError.inputClosed
    }

    return event
  }

  deinit {
    inputPump.cancel()
  }
}

private actor InputEventBuffer {
  private var events: [InputEvent] = []
  private var finished = false
  private var waiters: [CheckedContinuation<InputEvent?, Never>] = []

  func finish() {
    finished = true
    let waiters = waiters
    self.waiters = []

    for waiter in waiters {
      waiter.resume(returning: nil)
    }
  }

  func next() async -> InputEvent? {
    if !events.isEmpty {
      return events.removeFirst()
    }

    if finished {
      return nil
    }

    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  func yield(_ event: InputEvent) {
    if !waiters.isEmpty {
      let waiter = waiters.removeFirst()
      waiter.resume(returning: event)
    } else {
      events.append(event)
    }
  }
}
