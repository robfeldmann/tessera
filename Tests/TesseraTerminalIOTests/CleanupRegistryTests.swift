import CustomDump
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  // Serialized because every test installs, clears, or fires the process-wide
  // `tessera_cleanup_*` C shim state through `CleanupRegistry` directly. No other suite
  // reaches that state: they inject `.disabled` or `TestCleanupRegistry`.
  @Suite(.serialized)
  struct CleanupRegistryTests {
    @Test
    func `cleanup registry writes installed teardown bytes`() throws {
      let pipe = try FileDescriptorPipe()
      defer {
        CleanupRegistry.clear()
        pipe.closeAll()
      }

      CleanupRegistry.install(
        inputFileDescriptor: -1,
        outputFileDescriptor: pipe.writeDescriptor,
        teardownBytes: [0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x6C],
        savedTermios: nil
      )

      CleanupRegistry.performEmergencyCleanupForTesting()
      pipe.closeWriteDescriptor()

      let bytes = try pipe.readAll()
      expectNoDifference(bytes, [0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x6C])
    }

    @Test
    func `cleanup registry stores saved termios when installed`() {
      var saved = termios()
      saved.c_lflag = tcflag_t(ICANON | ECHO)
      defer { CleanupRegistry.clear() }

      CleanupRegistry.install(
        inputFileDescriptor: -1,
        outputFileDescriptor: -1,
        teardownBytes: [],
        savedTermios: saved
      )

      #expect(CleanupRegistry.hasSavedTermiosForTesting())
    }

    @Test
    func `test terminal device cleanup client cannot clear live registry`() async {
      var saved = termios()
      saved.c_lflag = tcflag_t(ICANON | ECHO)
      defer { CleanupRegistry.clear() }
      CleanupRegistry.install(
        inputFileDescriptor: -1,
        outputFileDescriptor: -1,
        teardownBytes: [],
        savedTermios: saved
      )
      let io = PlatformIO(
        terminalDevice: TerminalDevice(
          size: { .init(columns: 1, rows: 1) },
          write: { _ in 0 }
        )
      )

      await io.clearCleanup()

      #expect(CleanupRegistry.hasSavedTermiosForTesting())
    }

    @Test
    func `cleanup registry clear removes installed teardown bytes`() throws {
      let pipe = try FileDescriptorPipe()
      defer {
        CleanupRegistry.clear()
        pipe.closeAll()
      }

      CleanupRegistry.install(
        inputFileDescriptor: -1,
        outputFileDescriptor: pipe.writeDescriptor,
        teardownBytes: [0x1B],
        savedTermios: nil
      )
      CleanupRegistry.clear()
      CleanupRegistry.performEmergencyCleanupForTesting()
      pipe.closeWriteDescriptor()

      let bytes = try pipe.readAll()
      expectNoDifference(bytes, [])
    }

    @Test
    func
      `cleanup registry performs only the latest state after repeated installs and clears`()
      throws
    {
      let pipe = try FileDescriptorPipe()
      defer {
        CleanupRegistry.clear()
        pipe.closeAll()
      }

      // More replacements than the C shim's retired-state ring holds, so evictions run.
      for index in 0..<40 {
        CleanupRegistry.install(
          inputFileDescriptor: -1,
          outputFileDescriptor: pipe.writeDescriptor,
          teardownBytes: [UInt8(index)],
          savedTermios: nil
        )
        if index.isMultiple(of: 7) {
          CleanupRegistry.clear()
        }
      }

      CleanupRegistry.performEmergencyCleanupForTesting()
      pipe.closeWriteDescriptor()

      expectNoDifference(try pipe.readAll(), [39])
    }

    @Test
    func `querying installed handlers is side-effect free`() {
      // Regression: the query previously used `atomic_flag_test_and_set`, so merely
      // asking whether handlers were installed marked them installed and flipped a
      // subsequent read to true. Reset to a known-clear flag, then prove a query keeps
      // it clear.
      CleanupRegistry.resetHandlersForTesting()

      #expect(!CleanupRegistry.hasInstalledHandlersForTesting())
      #expect(!CleanupRegistry.hasInstalledHandlersForTesting())
    }
  }

  // Created, used, and closed inside one test body; never shared or captured by a
  // `@Sendable` closure.
  private final class FileDescriptorPipe {
    private var descriptors: [CInt] = [-1, -1]

    var writeDescriptor: CInt {
      descriptors[1]
    }

    init() throws {
      guard pipe(&descriptors) == 0 else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
    }

    func closeAll() {
      if descriptors[0] >= 0 {
        close(descriptors[0])
        descriptors[0] = -1
      }
      closeWriteDescriptor()
    }

    func closeWriteDescriptor() {
      if descriptors[1] >= 0 {
        close(descriptors[1])
        descriptors[1] = -1
      }
    }

    func readAll() throws -> [UInt8] {
      var bytes: [UInt8] = []
      var buffer = [UInt8](repeating: 0, count: 32)

      while true {
        let capacity = buffer.count
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
          systemRead(descriptors[0], pointer.baseAddress, capacity)
        }

        if count > 0 {
          bytes.append(contentsOf: buffer.prefix(count))
        } else if count == 0 {
          return bytes
        } else if errno == EINTR {
          continue
        } else {
          throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
        }
      }
    }
  }

  private func systemRead(
    _ fileDescriptor: CInt,
    _ buffer: UnsafeMutablePointer<UInt8>?,
    _ count: Int
  ) -> Int {
    read(fileDescriptor, buffer, count)
  }
#elseif os(Windows)
  // Serialized because every test installs, clears, or fires the process-wide
  // `tessera_cleanup_*` C shim state (`tessera_cleanup_install_windows`, `_clear`).
  @Suite(.serialized)
  struct CleanupRegistryTests {
    @Test
    func `cleanup registry stores saved windows modes when installed`() {
      defer { CleanupRegistry.clear() }

      CleanupRegistry.install(
        inputHandle: 0,
        outputHandle: 0,
        teardownBytes: [],
        savedInputMode: 0x0001,
        savedOutputMode: 0x0004
      )

      #expect(CleanupRegistry.hasSavedWindowsModesForTesting())
    }

    @Test
    func `cleanup registry clear removes saved windows modes`() {
      defer { CleanupRegistry.clear() }

      CleanupRegistry.install(
        inputHandle: 0,
        outputHandle: 0,
        teardownBytes: [0x1B],
        savedInputMode: 0x0001,
        savedOutputMode: 0x0004
      )
      CleanupRegistry.clear()

      #expect(!CleanupRegistry.hasSavedWindowsModesForTesting())
    }

    @Test
    func `cleanup registry emergency cleanup is safe with windows state`() {
      defer { CleanupRegistry.clear() }

      CleanupRegistry.install(
        inputHandle: 0,
        outputHandle: 0,
        teardownBytes: [0x1B],
        savedInputMode: 0x0001,
        savedOutputMode: 0x0004
      )

      CleanupRegistry.performEmergencyCleanupForTesting()
      #expect(CleanupRegistry.hasSavedWindowsModesForTesting())
    }

    @Test
    func `cleanup registry installs windows handlers and backstop`() {
      CleanupRegistry.installHandlers()

      #expect(CleanupRegistry.hasInstalledHandlersForTesting())
    }

    @Test
    func `platform io installs cleanup from windows console modes`() async {
      let cleanupState = PlatformCleanupState(
        inputHandle: 1,
        outputHandle: 2
      ) { .init(input: 0x0001, output: 0x0004) }
      let io = PlatformIO(
        terminalDevice: TerminalDevice(
          cleanupState: cleanupState,
          size: { .init(columns: 1, rows: 1) },
          write: { _ in 0 }
        ),
        cleanupRegistry: .live
      )
      defer { CleanupRegistry.clear() }

      await io.installCleanup(teardownBytes: [0x1B])

      #expect(CleanupRegistry.hasSavedWindowsModesForTesting())
    }
  }
#endif

actor TestCleanupRegistry {
  private var registration: PlatformCleanupRegistration?

  nonisolated var client: CleanupRegistryClient {
    CleanupRegistryClient(
      installHandlers: {},
      install: { registration in
        await self.install(registration)
      },
      clear: {
        await self.clear()
      }
    )
  }

  var hasRegistration: Bool {
    registration != nil
  }

  var teardownBytes: [UInt8] {
    registration?.teardownBytes ?? []
  }

  private func clear() {
    registration = nil
  }

  private func install(_ registration: PlatformCleanupRegistration) {
    self.registration = registration
  }
}
