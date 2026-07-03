#if os(Windows)

  import TesseraTerminalCore

  /// Shared Windows console input owner that fans out bytes and resize events.
  ///
  /// Windows byte input and `WINDOW_BUFFER_SIZE_EVENT` records share one console input
  /// queue. This loop is intentionally single-owner: it peeks the queue, drains only
  /// non-character records with `ReadConsoleInputW`, and calls `ReadFile` only after a
  /// queued key record proves byte input is available. That prevents a resize-only record
  /// from blocking `ReadFile` while waiting for a later keypress, and prevents independent
  /// byte/resize loops from stealing records from each other.
  package actor WindowsInputLoop {
    private let inputHandle: UInt
    private let peekRecordLimit: UInt32
    private let pollTimeoutMilliseconds: UInt32
    private let system: WindowsConsoleSystem

    private var byteContinuations: [Int: AsyncStream<[UInt8]>.Continuation] = [:]
    private var nextContinuationID = 0
    private var sizeContinuations: [Int: AsyncStream<TerminalSize>.Continuation] = [:]
    private var task: Task<Void, Never>?

    package init(
      inputHandle: UInt,
      system: WindowsConsoleSystem = .current,
      pollTimeoutMilliseconds: UInt32 = 25,
      peekRecordLimit: UInt32 = 32
    ) {
      self.inputHandle = inputHandle
      self.system = system
      self.pollTimeoutMilliseconds = pollTimeoutMilliseconds
      self.peekRecordLimit = peekRecordLimit
    }

    private static func run(
      inputHandle: UInt,
      system: WindowsConsoleSystem,
      pollTimeoutMilliseconds: UInt32,
      peekRecordLimit: UInt32,
      loop: WindowsInputLoop
    ) async {
      var buffer = [UInt8](repeating: 0, count: 256)

      while !Task.isCancelled {
        let waitResult = system.waitForSingleObject(inputHandle, pollTimeoutMilliseconds)
        if waitResult == WindowsWaitStatus.timeout {
          await loop.yieldBytes([])
          continue
        }
        guard waitResult == WindowsWaitStatus.object else {
          await loop.finishAll()
          return
        }

        guard let records = system.peekConsoleInput(inputHandle, peekRecordLimit) else {
          await loop.finishAll()
          return
        }
        guard records.isEmpty == false else {
          continue
        }

        let firstKeyIndex = records.firstIndex { $0.isKey }
        let drainCount = firstKeyIndex ?? records.count
        if drainCount > 0 {
          guard
            let drainedRecords = system.readConsoleInput(
              inputHandle,
              UInt32(drainCount)
            )
          else {
            await loop.finishAll()
            return
          }
          for record in drainedRecords {
            if case .resize(let size) = record {
              await loop.yieldSize(size)
            }
          }
        }

        guard firstKeyIndex != nil else {
          continue
        }

        let readCount = buffer.withUnsafeMutableBufferPointer { pointer in
          system.readFile(inputHandle, pointer.baseAddress, UInt32(pointer.count))
        }
        guard let readCount else {
          await loop.finishAll()
          return
        }
        guard readCount > 0 else {
          await loop.finishAll()
          return
        }

        await loop.yieldBytes(Array(buffer.prefix(readCount)))
      }

      await loop.finishAll()
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
      byteContinuations[id] = continuation
      startIfNeeded()
      return id
    }

    private func registerSizeContinuation(
      _ continuation: AsyncStream<TerminalSize>.Continuation
    ) -> Int {
      let id = nextContinuationID
      nextContinuationID += 1
      sizeContinuations[id] = continuation
      startIfNeeded()
      return id
    }

    private func unregisterByteContinuation(_ id: Int) {
      byteContinuations[id] = nil
      cancelIfUnused()
    }

    private func unregisterSizeContinuation(_ id: Int) {
      sizeContinuations[id] = nil
      cancelIfUnused()
    }

    private func startIfNeeded() {
      guard task == nil else {
        return
      }

      let inputHandle = inputHandle
      let peekRecordLimit = peekRecordLimit
      let pollTimeoutMilliseconds = pollTimeoutMilliseconds
      let system = system
      task = Task.detached { [self] in
        await Self.run(
          inputHandle: inputHandle,
          system: system,
          pollTimeoutMilliseconds: pollTimeoutMilliseconds,
          peekRecordLimit: peekRecordLimit,
          loop: self
        )
      }
    }

    private func cancelIfUnused() {
      guard byteContinuations.isEmpty, sizeContinuations.isEmpty else {
        return
      }
      task?.cancel()
    }

    private func yieldBytes(_ bytes: [UInt8]) {
      for continuation in byteContinuations.values {
        continuation.yield(bytes)
      }
    }

    private func yieldSize(_ size: TerminalSize) {
      for continuation in sizeContinuations.values {
        continuation.yield(size)
      }
    }

    private func finishAll() {
      let byteContinuations = Array(self.byteContinuations.values)
      let sizeContinuations = Array(self.sizeContinuations.values)
      self.byteContinuations.removeAll()
      self.sizeContinuations.removeAll()
      task = nil

      for continuation in byteContinuations {
        continuation.finish()
      }
      for continuation in sizeContinuations {
        continuation.finish()
      }
    }
  }

#endif
