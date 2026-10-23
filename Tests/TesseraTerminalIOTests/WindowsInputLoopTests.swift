#if os(Windows)

  import CustomDump
  import Foundation
  import TesseraTerminalCore
  import TesseraTerminalInput
  import Testing

  @testable import TesseraTerminalIO

  // Not serialized: the stubs ride the task-local `WindowsConsoleSystem.override`, the
  // handles are fake, and `PlatformIO(terminalDevice:)` injects `.disabled` cleanup, so no
  // test reaches the `tessera_cleanup_*` shim or a real console.
  @Suite
  struct WindowsInputLoopTests {
    @Test
    func `windows input loop yields bytes carried by queued key record`() async {
      let bytes = Array("é".utf8)
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [.success([.key(bytes)])],
        readConsoleResults: [.success([.key(bytes)])]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let chunk = await iterator.next()

      expectNoDifference(chunk, bytes)
      expectNoDifference(state.readConsoleCounts, [1])
      expectNoDifference(state.readFileCallCount, 0)
    }

    @Test
    func `windows input loop yields idle chunks on wait timeout`() async {
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.timeout, WindowsWaitStatus.failed]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let idle = await iterator.next()
      let end = await iterator.next()

      expectNoDifference(idle, [])
      expectNoDifference(end, nil)
    }

    @Test
    func `windows input loop translates resize records`() async {
      let size = TerminalSize(columns: 100, rows: 40)
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object, WindowsWaitStatus.failed],
        peekResults: [.success([.resize(size)])],
        readConsoleResults: [.success([.resize(size)])]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.sizeChanges().makeAsyncIterator()

      let event = await iterator.next()
      let end = await iterator.next()

      expectNoDifference(event, size)
      expectNoDifference(end, nil)
    }

    @Test
    func `windows input loop drains non key records without reading bytes`() async {
      let size = TerminalSize(columns: 120, rows: 30)
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object, WindowsWaitStatus.failed],
        peekResults: [.success([.other, .resize(size)])],
        readConsoleResults: [.success([.other, .resize(size)])]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let end = await iterator.next()

      expectNoDifference(end, nil)
      expectNoDifference(state.readConsoleCounts, [2])
      expectNoDifference(state.readFileCallCount, 0)
    }

    @Test
    func `windows input loop delivers resize before key bytes in same batch`() async {
      let size = TerminalSize(columns: 90, rows: 24)
      let bytes = Array("q".utf8)
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [.success([.resize(size), .key(bytes)])],
        readConsoleResults: [.success([.resize(size), .key(bytes)])]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      let byteStream = loop.bytes()
      let sizeStream = loop.sizeChanges()

      async let observedResize = firstSize(from: sizeStream)
      async let observedChunk = firstBytes(from: byteStream)

      let resize = await observedResize
      let chunk = await observedChunk

      expectNoDifference(resize, size)
      expectNoDifference(chunk, bytes)
      expectNoDifference(state.readConsoleCounts, [2])
      expectNoDifference(state.readFileCallCount, 0)
    }

    @Test
    func `windows input loop finishes when peek fails`() async {
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [
          .failure(.consoleOperationFailed(operation: .peekConsoleInput, errorCode: 123))
        ]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let end = await iterator.next()

      expectNoDifference(end, nil)
    }

    @Test
    func `windows input loop finishes when read console input fails`() async {
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [.success([.key([0x61])])],
        readConsoleResults: [
          .failure(.consoleOperationFailed(operation: .readConsoleInput, errorCode: 995))
        ]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let end = await iterator.next()

      expectNoDifference(end, nil)
      expectNoDifference(state.readFileCallCount, 0)
    }

    @Test
    func
      `windows input loop serves a stream registered after the previous run was cancelled`()
      async
    {
      let bytes = Array("a".utf8)
      let state = IdleInputState()
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)

      // The first consumer parks its run inside the next wait, then goes away, so the run is
      // cancelled while the new consumer has not registered yet. The consumer stays
      // registered until the wait has parked: releasing it earlier lets the cancellation
      // reach the run before its next wait, and the run would exit without parking.
      let first = Task {
        var iterator = loop.bytes().makeAsyncIterator()
        let chunk = await iterator.next()
        state.holdNextWait()
        let parked = await state.waitUntilHeld()
        return (chunk, parked)
      }
      let (idle, parked) = await first.value
      expectNoDifference(idle, [])
      #expect(parked)
      // The last consumer is unregistered, so the run has been cancelled.
      let unregistered = await loop.waitForRegisteredStreamCount(0)
      #expect(unregistered)

      // Register before the parked run resumes, so the old run exits while the new stream
      // is live.
      let stream = loop.bytes()
      let registered = await loop.waitForRegisteredStreamCount(1)
      #expect(registered)
      state.queueKey(bytes)
      async let pending = nextNonEmptyChunk(from: stream)
      state.releaseHeldWait()
      let received = await pending

      expectNoDifference(received, bytes)
    }

    @Test
    func `platform io drains windows resize before the shared input loop closes`() async {
      let size = TerminalSize(columns: 80, rows: 25)
      let state = WindowsInputState(
        waitResults: [
          WindowsWaitStatus.object,
          WindowsWaitStatus.failed,
        ],
        peekResults: [.success([.resize(size)])],
        readConsoleResults: [.success([.resize(size)])]
      )

      let io = WindowsConsoleSystem.$override.withValue(state.system) {
        PlatformIO(
          terminalDevice: .live(
            handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
          )
        )
      }
      var iterator = io.events.makeAsyncIterator()

      let event = await iterator.next()
      let end = await iterator.next()

      #expect(event == .resize(size))
      #expect(end == nil)
    }
  }

  private func firstBytes(from stream: AsyncStream<[UInt8]>) async -> [UInt8] {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next() ?? []
  }

  private func firstSize(from stream: AsyncStream<TerminalSize>) async -> TerminalSize? {
    var iterator = stream.makeAsyncIterator()
    return await iterator.next()
  }

  extension WindowsInputLoop {
    fileprivate func waitForRegisteredStreamCount(_ count: Int) async -> Bool {
      let deadline = ContinuousClock.now + .seconds(5)
      while ContinuousClock.now < deadline {
        if registeredStreamCount == count {
          return true
        }
        try? await Task.sleep(for: .milliseconds(5))
      }
      return false
    }
  }

  /// The first non-empty chunk, or an empty array if none arrives within five seconds.
  private func nextNonEmptyChunk(from stream: AsyncStream<[UInt8]>) async -> [UInt8] {
    await withTaskGroup(of: [UInt8].self) { group in
      group.addTask {
        for await chunk in stream where chunk.isEmpty == false {
          return chunk
        }
        return []
      }
      group.addTask {
        try? await Task.sleep(for: .seconds(5))
        return []
      }
      let result = await group.next() ?? []
      group.cancelAll()
      return result
    }
  }

  /// A console stub that reports timeouts until a key record is queued.
  ///
  /// Test-owned: the stubs run on the input loop's single reader thread one call at a
  /// time, and every field is read or written under `lock`, so the vouch is sound.
  private final class IdleInputState: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [UInt8] = []
    private let held = DispatchSemaphore(value: 0)
    private var holdRequested = false
    private var isHeld = false
    var system: WindowsConsoleSystem {
      .stub(
        waitForSingleObject: { _, _ in self.wait() },
        peekConsoleInput: { _, _ in self.peek() },
        readConsoleInput: { _, _ in self.drain() },
        readFile: { _, _, _ in nil }
      )
    }

    func queueKey(_ bytes: [UInt8]) {
      lock.withLock { pending = bytes }
    }

    /// Makes the next wait block until `releaseHeldWait()`, then report a timeout.
    func holdNextWait() {
      lock.withLock { holdRequested = true }
    }

    /// Returns `false` if no wait was parked within five seconds.
    func waitUntilHeld() async -> Bool {
      let deadline = ContinuousClock.now + .seconds(5)
      while ContinuousClock.now < deadline {
        if lock.withLock({ isHeld }) {
          return true
        }
        try? await Task.sleep(for: .milliseconds(5))
      }
      return false
    }

    func releaseHeldWait() {
      held.signal()
    }

    private func wait() -> UInt32 {
      if holdIfRequested() {
        return WindowsWaitStatus.timeout
      }
      let ready = lock.withLock { !pending.isEmpty }
      if ready {
        return WindowsWaitStatus.object
      }
      Thread.sleep(forTimeInterval: 0.005)
      // A request that arrives while this call sleeps parks it here, so the parked wait
      // is the one in flight when the consumer goes away.
      _ = holdIfRequested()
      return WindowsWaitStatus.timeout
    }

    /// Parks the caller until `releaseHeldWait()` when a hold was requested.
    private func holdIfRequested() -> Bool {
      let shouldHold = lock.withLock {
        let shouldHold = holdRequested
        if shouldHold {
          holdRequested = false
          isHeld = true
        }
        return shouldHold
      }
      if shouldHold {
        held.wait()
      }
      return shouldHold
    }

    private func peek() -> [WindowsInputRecord] {
      lock.withLock { pending.isEmpty ? [] : [.key(pending)] }
    }

    private func drain() -> [WindowsInputRecord] {
      lock.withLock {
        defer { pending = [] }
        return pending.isEmpty ? [] : [.key(pending)]
      }
    }
  }

  // Each test owns its instance: the input loop's single wait task calls the stubs one at
  // a time, and the test reads the counters only after the stream yields or finishes.
  private final class WindowsInputState: @unchecked Sendable {
    private var peekResults: [Result<[WindowsInputRecord], PlatformIOError>]
    private var readConsoleResults: [Result<[WindowsInputRecord], PlatformIOError>]
    private var waitResults: [UInt32]
    private(set) var readConsoleCounts: [UInt32] = []
    private(set) var readFileCallCount = 0
    var system: WindowsConsoleSystem {
      .stub(
        waitForSingleObject: { _, _ in self.wait() },
        peekConsoleInput: { _, _ in try self.peek() },
        readConsoleInput: { _, count in try self.readConsoleInput(count: count) },
        readFile: { _, buffer, count in self.readFile(buffer: buffer, count: count) }
      )
    }

    init(
      waitResults: [UInt32],
      peekResults: [Result<[WindowsInputRecord], PlatformIOError>] = [],
      readConsoleResults: [Result<[WindowsInputRecord], PlatformIOError>] = []
    ) {
      self.waitResults = waitResults
      self.peekResults = peekResults
      self.readConsoleResults = readConsoleResults
    }

    private func wait() -> UInt32 {
      guard waitResults.isEmpty == false else {
        return WindowsWaitStatus.failed
      }
      return waitResults.removeFirst()
    }

    private func peek() throws -> [WindowsInputRecord] {
      guard peekResults.isEmpty == false else {
        return []
      }
      return try peekResults.removeFirst().get()
    }

    private func readConsoleInput(count: UInt32) throws -> [WindowsInputRecord] {
      readConsoleCounts.append(count)
      guard readConsoleResults.isEmpty == false else {
        return []
      }
      return try readConsoleResults.removeFirst().get()
    }

    private func readFile(buffer: UnsafeMutableRawPointer?, count: UInt32) -> Int? {
      readFileCallCount += 1
      return nil
    }
  }

#endif
