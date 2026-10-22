#if os(Windows)

  import Foundation
  import TesseraTerminalCore

  /// Shared Windows console input owner that fans out bytes and resize events.
  ///
  /// Windows byte input and `WINDOW_BUFFER_SIZE_EVENT` records share one console input
  /// queue. This loop is intentionally single-owner: it drains queued console records with
  /// `ReadConsoleInputW`, translates key records into UTF-8 bytes, and fans resize records
  /// out separately. That prevents a resize-only record from blocking byte input while
  /// waiting for a later keypress, and prevents independent byte/resize loops from
  /// stealing records from each other.
  package actor WindowsInputLoop {
    /// One console event produced by the reader thread, in console queue order.
    private enum Event: Sendable {
      case bytes([UInt8])
      case size(TerminalSize)
    }

    /// A registered continuation and the run generation it belongs to.
    private struct Registration<Element: Sendable> {
      let generation: Int
      let continuation: AsyncStream<Element>.Continuation
    }

    private let inputHandle: UInt
    private let peekRecordLimit: UInt32
    private let pollTimeoutMilliseconds: UInt32
    private let system: WindowsConsoleSystem
    private let requiresByteAndSizeConsumers: Bool

    private var byteRegistrations: [Int: Registration<[UInt8]>] = [:]
    private var nextContinuationID = 0
    private var sizeRegistrations: [Int: Registration<TerminalSize>] = [:]
    /// Advances each time a run is cancelled, so late registrants belong to the next run
    /// and a finished run never touches them.
    private var generation = 0
    private var readerThread: Thread?

    /// The number of live byte and size streams, for tests that order registration.
    package var registeredStreamCount: Int {
      byteRegistrations.count + sizeRegistrations.count
    }

    package init(
      inputHandle: UInt,
      system: WindowsConsoleSystem = .current,
      pollTimeoutMilliseconds: UInt32 = 25,
      requiresByteAndSizeConsumers: Bool = false,
      peekRecordLimit: UInt32 = 32
    ) {
      self.inputHandle = inputHandle
      self.system = system
      self.pollTimeoutMilliseconds = pollTimeoutMilliseconds
      self.requiresByteAndSizeConsumers = requiresByteAndSizeConsumers
      self.peekRecordLimit = peekRecordLimit
    }

    /// Blocks on the console input handle until the thread is cancelled, the wait fails, or
    /// a console call throws, yielding each event into `events`.
    ///
    /// Runs on a dedicated thread so the 25 ms waits never occupy a cooperative-pool
    /// thread. Always finishes `events` on return.
    private static func run(
      inputHandle: UInt,
      system: WindowsConsoleSystem,
      pollTimeoutMilliseconds: UInt32,
      peekRecordLimit: UInt32,
      events: AsyncStream<Event>.Continuation
    ) {
      defer { events.finish() }
      while !Thread.current.isCancelled {
        let waitResult = system.waitForSingleObject(inputHandle, pollTimeoutMilliseconds)
        if waitResult == WindowsWaitStatus.timeout {
          events.yield(.bytes([]))
          continue
        }
        guard waitResult == WindowsWaitStatus.object else {
          return
        }

        let records: [WindowsInputRecord]
        do {
          records = try system.peekConsoleInput(inputHandle, peekRecordLimit)
        } catch {
          return
        }
        guard records.isEmpty == false else {
          continue
        }

        let drainedRecords: [WindowsInputRecord]
        do {
          drainedRecords = try system.readConsoleInput(
            inputHandle,
            UInt32(records.count)
          )
        } catch {
          return
        }

        for record in drainedRecords {
          switch record {
          case .key(let bytes) where bytes.isEmpty == false:
            events.yield(.bytes(bytes))

          case .resize(let size):
            events.yield(.size(size))

          case .key, .other:
            break
          }
        }
      }
    }

    package nonisolated func bytes() -> AsyncStream<[UInt8]> {
      AsyncStream { continuation in
        let registration = Task { await self.registerByteContinuation(continuation) }
        continuation.onTermination = { _ in
          registration.cancel()
          Task {
            let id = await registration.value
            await self.unregisterByteContinuation(id)
          }
        }
      }
    }

    package nonisolated func sizeChanges() -> AsyncStream<TerminalSize> {
      AsyncStream { continuation in
        let registration = Task { await self.registerSizeContinuation(continuation) }
        continuation.onTermination = { _ in
          registration.cancel()
          Task {
            let id = await registration.value
            await self.unregisterSizeContinuation(id)
          }
        }
      }
    }

    private func registerByteContinuation(
      _ continuation: AsyncStream<[UInt8]>.Continuation
    ) -> Int {
      let id = nextContinuationID
      nextContinuationID += 1
      byteRegistrations[id] = Registration(
        generation: generation, continuation: continuation)
      startIfNeeded()
      return id
    }

    private func registerSizeContinuation(
      _ continuation: AsyncStream<TerminalSize>.Continuation
    ) -> Int {
      let id = nextContinuationID
      nextContinuationID += 1
      sizeRegistrations[id] = Registration(
        generation: generation, continuation: continuation)
      startIfNeeded()
      return id
    }

    private func unregisterByteContinuation(_ id: Int) {
      byteRegistrations[id] = nil
      cancelIfUnused()
    }

    private func unregisterSizeContinuation(_ id: Int) {
      sizeRegistrations[id] = nil
      cancelIfUnused()
    }

    private func startIfNeeded() {
      guard readerThread == nil else {
        return
      }
      if requiresByteAndSizeConsumers,
        byteRegistrations.isEmpty || sizeRegistrations.isEmpty
      {
        return
      }

      let inputHandle = inputHandle
      let peekRecordLimit = peekRecordLimit
      let pollTimeoutMilliseconds = pollTimeoutMilliseconds
      let system = system
      let runGeneration = generation
      let (events, continuation) = AsyncStream<Event>.makeStream()
      let thread = Thread {
        Self.run(
          inputHandle: inputHandle,
          system: system,
          pollTimeoutMilliseconds: pollTimeoutMilliseconds,
          peekRecordLimit: peekRecordLimit,
          events: continuation
        )
      }
      thread.name = "tessera.windows-input"
      readerThread = thread
      Task { [self] in
        for await event in events {
          dispatch(event, generation: runGeneration)
        }
        finishAll(generation: runGeneration)
      }
      thread.start()
    }

    /// Stops the reader once nobody listens. Clearing the thread and advancing the
    /// generation lets a later registrant start a fresh run that the old run cannot finish.
    private func cancelIfUnused() {
      guard byteRegistrations.isEmpty, sizeRegistrations.isEmpty else {
        return
      }
      readerThread?.cancel()
      readerThread = nil
      generation += 1
    }

    private func dispatch(_ event: Event, generation runGeneration: Int) {
      switch event {
      case .bytes(let bytes):
        for registration in byteRegistrations.values
        where registration.generation == runGeneration {
          registration.continuation.yield(bytes)
        }

      case .size(let size):
        for registration in sizeRegistrations.values
        where registration.generation == runGeneration {
          registration.continuation.yield(size)
        }
      }
    }

    /// Finishes the continuations that belong to `runGeneration`; newer generations keep
    /// their streams and their own run.
    private func finishAll(generation runGeneration: Int) {
      let byteRegistrations = self.byteRegistrations.filter {
        $0.value.generation == runGeneration
      }
      let sizeRegistrations = self.sizeRegistrations.filter {
        $0.value.generation == runGeneration
      }
      for id in byteRegistrations.keys {
        self.byteRegistrations[id] = nil
      }
      for id in sizeRegistrations.keys {
        self.sizeRegistrations[id] = nil
      }
      if runGeneration == generation {
        readerThread = nil
        generation += 1
      }

      for registration in byteRegistrations.values {
        registration.continuation.finish()
      }
      for registration in sizeRegistrations.values {
        registration.continuation.finish()
      }
    }
  }

#endif
