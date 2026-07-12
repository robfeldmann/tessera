import CustomDump
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  @Suite(.serialized)
  struct CleanupRegistryTests {
    @Test
    func `cleanup registry writes installed teardown bytes`() async throws {
      try await CleanupRegistryTestIsolation.withExclusiveAccess {
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
    }

    @Test
    func `cleanup registry stores saved termios when installed`() async throws {
      await CleanupRegistryTestIsolation.withExclusiveAccess {
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
    }

    @Test
    func `test terminal device cleanup client cannot clear live registry`() async {
      await CleanupRegistryTestIsolation.withExclusiveAccess {
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
    }

    @Test
    func `cleanup registry clear removes installed teardown bytes`() async throws {
      try await CleanupRegistryTestIsolation.withExclusiveAccess {
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
    }

    @Test
    func `querying installed handlers is side-effect free`() async {
      await CleanupRegistryTestIsolation.withExclusiveAccess {
        // Regression: the query previously used `atomic_flag_test_and_set`, so merely
        // asking whether handlers were installed marked them installed and flipped a
        // subsequent read to true. Reset to a known-clear flag, then prove a query keeps
        // it clear.
        CleanupRegistry.resetHandlersForTesting()

        #expect(!CleanupRegistry.hasInstalledHandlersForTesting())
        #expect(!CleanupRegistry.hasInstalledHandlersForTesting())
      }
    }
  }

  private final class FileDescriptorPipe: @unchecked Sendable {
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

enum CleanupRegistryTestIsolation {
  private static let lock = CleanupRegistryAsyncLock()

  static func withExclusiveAccess<T>(
    _ operation: () async throws -> T
  ) async rethrows -> T {
    await lock.acquire()
    do {
      let result = try await operation()
      await lock.release()
      return result
    } catch {
      await lock.release()
      throw error
    }
  }
}

private actor CleanupRegistryAsyncLock {
  private var isLocked = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func acquire() async {
    if !isLocked {
      isLocked = true
      return
    }

    await withCheckedContinuation { continuation in
      waiters.append(continuation)
    }
  }

  func release() {
    guard !waiters.isEmpty else {
      isLocked = false
      return
    }

    let nextWaiter = waiters.removeFirst()
    nextWaiter.resume()
  }
}
