#if os(Windows)

  import CustomDump
  import TesseraTerminalCore
  import TesseraTerminalInput
  import Testing

  @testable import TesseraTerminalIO

  @Suite(.serialized)
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
