import TesseraTerminalCore
import TesseraTerminalInput

/// Owned platform terminal I/O.
package actor PlatformIO {
  nonisolated private let cleanupRegistry: CleanupRegistryClient
  private let terminalDevice: TerminalDevice
  private var outputBuffer: [UInt8] = []
  /// Bumped by each discard, so a drain suspended across the discard stops instead of
  /// trimming bytes appended after it.
  private var discardGeneration: UInt64 = 0
  /// Flushes waiting for the drain in flight, resumed one at a time in arrival order.
  private var drainWaiters: [CheckedContinuation<Void, Never>] = []
  private var isDraining = false

  /// The number of flushes waiting for the drain in flight; a test seam.
  package var queuedFlushCount: Int {
    drainWaiters.count
  }

  /// Reads raw byte chunks from terminal input.
  ///
  /// Empty chunks are input-idle notifications used internally for ESC timeout handling.
  package nonisolated let bytes: AsyncStream<[UInt8]>

  /// Streams semantic terminal input events.
  ///
  /// Input is never dropped: the stream buffers without bound. Resize events come from the
  /// same device subscription as `sizeChanges` and, like it, keep only the newest size
  /// that has not yet been turned into an event.
  package nonisolated let events: AsyncStream<InputEvent>

  /// Streams terminal-size changes.
  ///
  /// Only the newest unread size is kept: sizes that arrive before a read replace the
  /// buffered one, since only the latest size matters.
  package nonisolated let sizeChanges: AsyncStream<TerminalSize>

  /// Creates platform I/O from the live terminal device.
  package init() {
    self.init(terminalDevice: .live, cleanupRegistry: .live)
  }

  /// Creates platform I/O from owned platform handles.
  package init(handles: consuming PlatformHandles) throws {
    self.init(terminalDevice: .live(handles: handles), cleanupRegistry: .live)
  }

  /// Creates platform I/O from an owned package-internal terminal device seam.
  package init(terminalDevice: TerminalDevice) {
    self.init(terminalDevice: terminalDevice, cleanupRegistry: .disabled)
  }

  /// Creates platform I/O with an injected emergency-cleanup registry.
  package init(
    terminalDevice: TerminalDevice,
    cleanupRegistry: CleanupRegistryClient
  ) {
    self.cleanupRegistry = cleanupRegistry
    self.terminalDevice = terminalDevice
    self.bytes = terminalDevice.bytes()
    let sizeChanges = SizeChangeFanOut.streams(from: terminalDevice.sizeChanges())
    self.sizeChanges = sizeChanges.sizeChanges
    self.events = Self.events(
      from: self.bytes,
      sizeChanges: sizeChanges.events,
      inputStreamsShareLifetime: terminalDevice.inputStreamsShareLifetime
    )
  }

  private static func events(
    from bytes: AsyncStream<[UInt8]>,
    sizeChanges: AsyncStream<TerminalSize>,
    inputStreamsShareLifetime: Bool
  ) -> AsyncStream<InputEvent> {
    AsyncStream { continuation in
      let task = Task {
        let resizeTask = Task {
          for await size in sizeChanges {
            continuation.yield(.resize(size))
          }
        }
        defer { resizeTask.cancel() }

        var parser = InputParser()
        for await chunk in bytes {
          if chunk.isEmpty {
            for event in parser.flushPendingEscape() {
              continuation.yield(event)
            }
          } else {
            for event in parser.feed(contentsOf: chunk) {
              continuation.yield(event)
            }
          }
        }
        for event in parser.flush() {
          continuation.yield(event)
        }
        if inputStreamsShareLifetime, Task.isCancelled == false {
          await resizeTask.value
        }
        continuation.finish()
      }

      continuation.onTermination = { _ in
        task.cancel()
      }
    }
  }

  /// Buffers bytes for terminal output.
  package func write(_ bytes: [UInt8]) {
    outputBuffer.append(contentsOf: bytes)
  }

  /// Buffers bytes for terminal output.
  package func write(_ bytes: ArraySlice<UInt8>) {
    outputBuffer.append(contentsOf: bytes)
  }

  /// Discards buffered output bytes that belong to a failed terminal-mode transition.
  ///
  /// A drain in flight stops after its current write; bytes the terminal has already
  /// accepted cannot be recalled.
  package func discardBufferedOutput() {
    outputBuffer.removeAll(keepingCapacity: true)
    discardGeneration &+= 1
  }

  /// Flushes buffered output bytes to the terminal device.
  ///
  /// One drain runs at a time: a flush that arrives while another is writing waits for it,
  /// then drains whatever is left. A drain also sends bytes appended while it is suspended,
  /// after its remainder, so each byte is written once and in order. On a write failure the
  /// unwritten bytes stay at the front of the buffer for the next flush. Only
  /// `PlatformIOError.writeInterrupted` is retried; any other error is thrown.
  package func flush() async throws {
    if isDraining {
      // `finishDrain` hands ownership over before resuming this waiter.
      await withCheckedContinuation { drainWaiters.append($0) }
    } else {
      isDraining = true
    }
    defer { finishDrain() }

    let generation = discardGeneration
    var offset = 0

    do {
      while generation == discardGeneration, offset < outputBuffer.count {
        let written: Int
        do {
          written = try await terminalDevice.write(outputBuffer[offset...])
        } catch PlatformIOError.writeInterrupted {
          continue
        }

        guard written > 0 else {
          throw PlatformIOError.writeFailed(errno: .init(rawValue: 0))
        }

        offset += written
      }

      if generation == discardGeneration {
        outputBuffer.removeAll(keepingCapacity: true)
      }
    } catch {
      if generation == discardGeneration, offset > 0 {
        outputBuffer.removeFirst(offset)
      }
      throw error
    }
  }

  private func finishDrain() {
    if drainWaiters.isEmpty {
      isDraining = false
    } else {
      drainWaiters.removeFirst().resume()
    }
  }

  /// Installs emergency cleanup state for the current terminal modes.
  package nonisolated func installCleanupHandlers() {
    cleanupRegistry.installHandlers()
  }

  /// Installs emergency cleanup state for the current terminal modes.
  package func installCleanup(teardownBytes: [UInt8]) async {
    await terminalDevice.cleanupState.install(
      teardownBytes: teardownBytes,
      in: cleanupRegistry
    )
  }

  /// Clears emergency cleanup state for this terminal session.
  package func clearCleanup() async {
    await cleanupRegistry.clear()
  }

  /// Reads the terminal's per-cell pixel size, or `nil` when unknown.
  package func cellPixelSize() async -> CellPixelSize? {
    await terminalDevice.cellPixelSize()
  }

  /// Reads the terminal size from the output terminal.
  package func size() async throws -> TerminalSize {
    try await terminalDevice.size()
  }

  /// Enters the terminal's alternate screen buffer.
  package func enableAltScreen() async throws {
    try await terminalDevice.enterAltScreen()
  }

  /// Enables raw input mode.
  package func enableRawMode() async throws {
    try await terminalDevice.enterRawMode()
  }

  /// Leaves the terminal's alternate screen buffer.
  package func disableAltScreen() async throws {
    try await terminalDevice.exitAltScreen()
  }

  /// Restores the terminal input mode captured before entering raw mode.
  package func disableRawMode() async throws {
    try await terminalDevice.exitRawMode()
  }
}

/// Forwards one device size-change subscription to two newest-only streams, so each
/// `PlatformIO` registers a single resize source.
///
/// The subscription is cancelled once both streams have terminated, and both streams
/// finish when the subscription does.
private actor SizeChangeFanOut {
  private let forwarding: Task<Void, Never>
  private var openStreamCount = 2

  private init(
    source: AsyncStream<TerminalSize>,
    first: AsyncStream<TerminalSize>.Continuation,
    second: AsyncStream<TerminalSize>.Continuation
  ) {
    forwarding = Task {
      for await size in source {
        first.yield(size)
        second.yield(size)
      }
      first.finish()
      second.finish()
    }
  }

  /// Subscribes to `source` and returns the public size stream and the stream that feeds
  /// resize events.
  static func streams(
    from source: AsyncStream<TerminalSize>
  ) -> (sizeChanges: AsyncStream<TerminalSize>, events: AsyncStream<TerminalSize>) {
    let sizeChanges = AsyncStream.makeStream(
      of: TerminalSize.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    let events = AsyncStream.makeStream(
      of: TerminalSize.self,
      bufferingPolicy: .bufferingNewest(1)
    )
    let fanOut = SizeChangeFanOut(
      source: source,
      first: sizeChanges.continuation,
      second: events.continuation
    )
    for continuation in [sizeChanges.continuation, events.continuation] {
      continuation.onTermination = { _ in
        Task { await fanOut.streamTerminated() }
      }
    }
    return (sizeChanges.stream, events.stream)
  }

  private func streamTerminated() {
    openStreamCount -= 1
    if openStreamCount == 0 {
      forwarding.cancel()
    }
  }
}
