#if os(Windows)

  import CustomDump
  import Foundation
  import Testing

  @testable import TesseraTerminalIO

  struct WindowsConsoleModeTests {
    @Test
    func `flag helpers apply Tessera raw input and VT output modes`() {
      let unrelatedFlag: UInt32 = 0x8000_0000
      let originalInputMode =
        WindowsConsoleModeFlags.disabledRawInputFlags.rawValue | unrelatedFlag
      let rawInputMode = WindowsConsoleModeFlags.rawInputMode(from: originalInputMode)

      #expect(contains(rawInputMode, .echoInput) == false)
      #expect(contains(rawInputMode, .lineInput) == false)
      #expect(contains(rawInputMode, .processedInput) == false)
      #expect(contains(rawInputMode, .virtualTerminalInput))
      #expect(contains(rawInputMode, .windowInput))
      #expect(rawInputMode & unrelatedFlag == unrelatedFlag)

      let originalOutputMode = unrelatedFlag
      let virtualTerminalOutputMode = WindowsConsoleModeFlags.virtualTerminalOutputMode(
        from: originalOutputMode
      )

      #expect(contains(virtualTerminalOutputMode, .disableNewlineAutoReturn))
      #expect(contains(virtualTerminalOutputMode, .processedOutput))
      #expect(contains(virtualTerminalOutputMode, .virtualTerminalProcessing))
      #expect(virtualTerminalOutputMode & unrelatedFlag == unrelatedFlag)
    }

    @Test
    func `enter raw mode saves modes and is idempotent`() async throws {
      let state = ConsoleState()
      let mode = WindowsConsoleMode(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        system: state.system
      )

      try await mode.enterRawMode()
      try await mode.enterRawMode()

      let savedModes = try #require(await mode.savedModes())
      #expect(savedModes.input == originalInputMode)
      #expect(savedModes.output == originalOutputMode)
      expectNoDifference(
        state.setCalls,
        [
          .init(handle: inputHandle, mode: expectedRawInputMode),
          .init(handle: outputHandle, mode: expectedVTOutputMode),
        ]
      )
    }

    @Test
    func `exit raw mode restores saved modes and is idempotent`() async throws {
      let state = ConsoleState()
      let mode = WindowsConsoleMode(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        system: state.system
      )

      try await mode.enterRawMode()
      try await mode.exitRawMode()
      try await mode.exitRawMode()

      #expect(await mode.savedModes() == nil)
      #expect(state.modes[inputHandle] == originalInputMode)
      #expect(state.modes[outputHandle] == originalOutputMode)
      expectNoDifference(
        state.setCalls,
        [
          .init(handle: inputHandle, mode: expectedRawInputMode),
          .init(handle: outputHandle, mode: expectedVTOutputMode),
          .init(handle: inputHandle, mode: originalInputMode),
          .init(handle: outputHandle, mode: originalOutputMode),
        ]
      )
    }

    @Test
    func `get console mode failure reports unsupported terminal environment`() async {
      let state = ConsoleState()
      state.failingGetHandles = [inputHandle]
      let mode = WindowsConsoleMode(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        system: state.system
      )

      await #expect(throws: PlatformIOError.unsupportedTerminalEnvironment) {
        try await mode.enterRawMode()
      }
      expectNoDifference(state.setCalls, [])
    }

    @Test
    func `set output mode failure rolls back input mode and propagates error`() async {
      let state = ConsoleState()
      state.failingSetCalls = [
        .init(handle: outputHandle, mode: expectedVTOutputMode): 50
      ]
      let mode = WindowsConsoleMode(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        system: state.system
      )

      await #expect(
        throws: PlatformIOError.consoleModeFailed(operation: .setOutputMode, errorCode: 50)
      ) {
        try await mode.enterRawMode()
      }

      #expect(await mode.savedModes() == nil)
      #expect(state.modes[inputHandle] == originalInputMode)
      expectNoDifference(
        state.setCalls,
        [
          .init(handle: inputHandle, mode: expectedRawInputMode),
          .init(handle: outputHandle, mode: expectedVTOutputMode),
          .init(handle: inputHandle, mode: originalInputMode),
        ]
      )
    }

    @Test
    func `exit raw mode attempts both restores and propagates first error`() async throws {
      let state = ConsoleState()
      let mode = WindowsConsoleMode(
        inputHandle: inputHandle,
        outputHandle: outputHandle,
        system: state.system
      )
      try await mode.enterRawMode()
      state.failingSetCalls = [
        .init(handle: inputHandle, mode: originalInputMode): 5,
        .init(handle: outputHandle, mode: originalOutputMode): 6,
      ]

      await #expect(
        throws: PlatformIOError.consoleModeFailed(operation: .setInputMode, errorCode: 5)
      ) {
        try await mode.exitRawMode()
      }

      let savedModes = try #require(await mode.savedModes())
      #expect(savedModes.input == originalInputMode)
      #expect(savedModes.output == originalOutputMode)
      expectNoDifference(
        Array(state.setCalls.suffix(2)),
        [
          .init(handle: inputHandle, mode: originalInputMode),
          .init(handle: outputHandle, mode: originalOutputMode),
        ]
      )
    }

    @Test
    func `PlatformIO raw mode API drives Windows console mode lifecycle`() async throws {
      let state = ConsoleState()
      let io = PlatformIO(
        terminalDevice: .windowsConsoleMode(
          inputHandle: inputHandle,
          outputHandle: outputHandle,
          system: state.system
        )
      )

      try await io.enableRawMode()
      try await io.disableRawMode()

      expectNoDifference(
        state.setCalls,
        [
          .init(handle: inputHandle, mode: expectedRawInputMode),
          .init(handle: outputHandle, mode: expectedVTOutputMode),
          .init(handle: inputHandle, mode: originalInputMode),
          .init(handle: outputHandle, mode: originalOutputMode),
        ]
      )
    }

    @Test
    func `unsupported terminal error explains the console requirement`() {
      let message = PlatformIOError.unsupportedTerminalEnvironment.localizedDescription

      #expect(message.contains("Tessera requires a console terminal"))
      #expect(message.contains("PowerShell ISE"))
      #expect(message.contains("redirected input/output"))
    }
  }

  private let inputHandle: UInt = 0x11
  private let outputHandle: UInt = 0x22
  private let originalInputMode: UInt32 =
    WindowsConsoleModeFlags.disabledRawInputFlags.rawValue | 0x4000
  private let originalOutputMode: UInt32 = 0x8000
  private let expectedRawInputMode =
    WindowsConsoleModeFlags.rawInputMode(from: originalInputMode)
  private let expectedVTOutputMode =
    WindowsConsoleModeFlags.virtualTerminalOutputMode(from: originalOutputMode)

  private func contains(_ mode: UInt32, _ flag: WindowsConsoleModeFlags) -> Bool {
    mode & flag.rawValue == flag.rawValue
  }

  private final class ConsoleState: @unchecked Sendable {
    struct SetCall: Equatable, Hashable, Sendable {
      let handle: UInt
      let mode: UInt32
    }

    var failingGetHandles: Set<UInt> = []
    var failingSetCalls: [SetCall: UInt32] = [:]
    private(set) var modes: [UInt: UInt32] = [
      inputHandle: originalInputMode,
      outputHandle: originalOutputMode,
    ]
    private(set) var setCalls: [SetCall] = []
    private var lastErrorCode: UInt32 = 0

    var system: WindowsConsoleSystem {
      .stub(
        getConsoleMode: { handle in self.getConsoleMode(handle) },
        setConsoleMode: { handle, mode in self.setConsoleMode(handle, mode) },
        lastErrorCode: { self.lastErrorCode }
      )
    }

    private func getConsoleMode(_ handle: UInt) -> UInt32? {
      if failingGetHandles.contains(handle) {
        lastErrorCode = 6
        return nil
      }
      return modes[handle]
    }

    private func setConsoleMode(_ handle: UInt, _ mode: UInt32) -> Bool {
      let call = SetCall(handle: handle, mode: mode)
      setCalls.append(call)
      guard let errorCode = failingSetCalls[call] else {
        modes[handle] = mode
        return true
      }

      lastErrorCode = errorCode
      return false
    }
  }

#endif
