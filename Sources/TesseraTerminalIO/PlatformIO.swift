import TesseraTerminalCore
import TesseraTerminalInput

/// Owned platform terminal I/O.
package actor PlatformIO {
  nonisolated private let cleanupRegistry: CleanupRegistryClient
  private let terminalDevice: TerminalDevice
  private var outputBuffer: [UInt8] = []

  /// Reads raw byte chunks from terminal input.
  ///
  /// Empty chunks are input-idle notifications used internally for ESC timeout handling.
  package nonisolated let bytes: AsyncStream<[UInt8]>

  /// Streams semantic terminal input events.
  package nonisolated let events: AsyncStream<InputEvent>

  /// Streams terminal-size changes.
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
    self.sizeChanges = terminalDevice.sizeChanges()
    self.events = Self.events(
      from: self.bytes,
      sizeChanges: self.sizeChanges,
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
  package func discardBufferedOutput() {
    outputBuffer.removeAll(keepingCapacity: true)
  }

  /// Flushes buffered output bytes to the terminal device.
  package func flush() async throws {
    var offset = 0

    do {
      while offset < outputBuffer.count {
        let written: Int
        do {
          written = try await terminalDevice.write(outputBuffer[offset...])
        } catch PlatformIOError.writeInterrupted {
          continue
        } catch PlatformIOError.writeWouldBlock {
          await Task.yield()
          continue
        }

        guard written > 0 else {
          throw PlatformIOError.writeFailed(errno: .init(rawValue: 0))
        }

        offset += written
      }

      outputBuffer.removeAll(keepingCapacity: true)
    } catch {
      if offset > 0 {
        outputBuffer.removeFirst(offset)
      }
      throw error
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
