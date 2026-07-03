#if os(Windows)

  import CustomDump
  import TesseraTerminalCore
  import TesseraTerminalInput
  import Testing

  @testable import TesseraTerminalIO

  @Suite(.serialized)
  struct WindowsInputLoopTests {
    @Test
    func `windows input loop reads queued key bytes`() async {
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [[.key]],
        readFileResults: [.success([0x61, 0x62])]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let chunk = await iterator.next()

      expectNoDifference(chunk, [0x61, 0x62])
      expectNoDifference(state.readFileCallCount, 1)
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
        peekResults: [[.resize(size)]],
        readConsoleResults: [[.resize(size)]]
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
        peekResults: [[.other, .resize(size)]],
        readConsoleResults: [[.other, .resize(size)]]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let end = await iterator.next()

      expectNoDifference(end, nil)
      expectNoDifference(state.readConsoleCounts, [2])
      expectNoDifference(state.readFileCallCount, 0)
    }

    @Test
    func `windows input loop drains resize before key bytes`() async {
      let size = TerminalSize(columns: 90, rows: 24)
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [[.resize(size), .key]],
        readConsoleResults: [[.resize(size)]],
        readFileResults: [.success([0x1B])]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var byteIterator = loop.bytes().makeAsyncIterator()
      var sizeIterator = loop.sizeChanges().makeAsyncIterator()

      let resize = await sizeIterator.next()
      let bytes = await byteIterator.next()

      expectNoDifference(resize, size)
      expectNoDifference(bytes, [0x1B])
      expectNoDifference(state.readConsoleCounts, [1])
      expectNoDifference(state.readFileCallCount, 1)
    }

    @Test
    func `windows input loop finishes when peek fails`() async {
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [nil]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let end = await iterator.next()

      expectNoDifference(end, nil)
    }

    @Test
    func `windows input loop finishes when read file fails`() async {
      let state = WindowsInputState(
        waitResults: [WindowsWaitStatus.object],
        peekResults: [[.key]],
        readFileResults: [.failure(995)]
      )
      let loop = WindowsInputLoop(inputHandle: 0x10, system: state.system)
      var iterator = loop.bytes().makeAsyncIterator()

      let end = await iterator.next()

      expectNoDifference(end, nil)
      expectNoDifference(state.lastErrorCode, 995)
    }

    @Test
    func `platform io events includes windows resize notifications`() async {
      let size = TerminalSize(columns: 80, rows: 25)
      let state = WindowsInputState(
        waitResults: [
          WindowsWaitStatus.object,
          WindowsWaitStatus.timeout,
          WindowsWaitStatus.failed,
        ],
        peekResults: [[.resize(size)]],
        readConsoleResults: [[.resize(size)]]
      )

      let io = await WindowsConsoleSystem.$override.withValue(state.system) {
        PlatformIO(
          terminalDevice: .live(
            handles: PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)
          )
        )
      }
      var iterator = io.events.makeAsyncIterator()

      let event = await iterator.next()

      expectNoDifference(event, .resize(size))
    }
  }

  private final class WindowsInputState: @unchecked Sendable {
    enum ReadFileResult: Sendable {
      case failure(UInt32)
      case success([UInt8])
    }

    private var peekResults: [[WindowsInputRecord]?]
    private var readFileResults: [ReadFileResult]
    private var readConsoleResults: [[WindowsInputRecord]?]
    private var waitResults: [UInt32]
    private(set) var lastErrorCode: UInt32 = 0
    private(set) var readConsoleCounts: [UInt32] = []
    private(set) var readFileCallCount = 0

    var system: WindowsConsoleSystem {
      .stub(
        waitForSingleObject: { _, _ in self.wait() },
        peekConsoleInput: { _, _ in self.peek() },
        readConsoleInput: { _, count in self.readConsoleInput(count: count) },
        readFile: { _, buffer, count in self.readFile(buffer: buffer, count: count) },
        lastErrorCode: { self.lastErrorCode }
      )
    }

    init(
      waitResults: [UInt32],
      peekResults: [[WindowsInputRecord]?] = [],
      readConsoleResults: [[WindowsInputRecord]?] = [],
      readFileResults: [ReadFileResult] = []
    ) {
      self.waitResults = waitResults
      self.peekResults = peekResults
      self.readConsoleResults = readConsoleResults
      self.readFileResults = readFileResults
    }

    private func wait() -> UInt32 {
      guard waitResults.isEmpty == false else {
        return WindowsWaitStatus.failed
      }
      return waitResults.removeFirst()
    }

    private func peek() -> [WindowsInputRecord]? {
      guard peekResults.isEmpty == false else {
        return []
      }
      return peekResults.removeFirst()
    }

    private func readConsoleInput(count: UInt32) -> [WindowsInputRecord]? {
      readConsoleCounts.append(count)
      guard readConsoleResults.isEmpty == false else {
        return []
      }
      return readConsoleResults.removeFirst()
    }

    private func readFile(buffer: UnsafeMutableRawPointer?, count: UInt32) -> Int? {
      readFileCallCount += 1
      guard readFileResults.isEmpty == false else {
        return 0
      }

      switch readFileResults.removeFirst() {
      case .success(let bytes):
        if let buffer {
          let destination = buffer.assumingMemoryBound(to: UInt8.self)
          for (offset, byte) in bytes.prefix(Int(count)).enumerated() {
            destination[offset] = byte
          }
        }
        return min(bytes.count, Int(count))

      case .failure(let errorCode):
        lastErrorCode = errorCode
        return nil
      }
    }
  }

#endif
