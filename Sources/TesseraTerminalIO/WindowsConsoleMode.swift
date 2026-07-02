/// Windows console mode operations surfaced in platform I/O errors.
public enum WindowsConsoleModeOperation: CustomStringConvertible, Equatable, Sendable {
  case getInputMode
  case getOutputMode
  case setInputMode
  case setOutputMode

  public var description: String {
    switch self {
    case .getInputMode:
      return "read input console mode"

    case .getOutputMode:
      return "read output console mode"

    case .setInputMode:
      return "set input console mode"

    case .setOutputMode:
      return "set output console mode"
    }
  }
}

#if os(Windows)

  /// Named Windows console-mode flags and mode transformations used by Tessera.
  package struct WindowsConsoleModeFlags: OptionSet, Sendable {
    package static let echoInput = Self(rawValue: UInt32(ENABLE_ECHO_INPUT))
    package static let lineInput = Self(rawValue: UInt32(ENABLE_LINE_INPUT))
    package static let processedInput = Self(rawValue: UInt32(ENABLE_PROCESSED_INPUT))
    package static let windowInput = Self(rawValue: UInt32(ENABLE_WINDOW_INPUT))
    package static let virtualTerminalInput = Self(
      rawValue: UInt32(ENABLE_VIRTUAL_TERMINAL_INPUT)
    )

    package static let processedOutput = Self(rawValue: UInt32(ENABLE_PROCESSED_OUTPUT))
    package static let virtualTerminalProcessing = Self(
      rawValue: UInt32(ENABLE_VIRTUAL_TERMINAL_PROCESSING)
    )
    package static let disableNewlineAutoReturn = Self(
      rawValue: UInt32(DISABLE_NEWLINE_AUTO_RETURN)
    )

    package static let disabledRawInputFlags: Self = [
      .echoInput,
      .lineInput,
      .processedInput,
    ]
    package static let enabledRawInputFlags: Self = [
      .virtualTerminalInput,
      .windowInput,
    ]
    package static let enabledVirtualTerminalOutputFlags: Self = [
      .disableNewlineAutoReturn,
      .processedOutput,
      .virtualTerminalProcessing,
    ]

    package let rawValue: UInt32

    package init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    package static func rawInputMode(from mode: UInt32) -> UInt32 {
      Self(rawValue: mode)
        .subtracting(disabledRawInputFlags)
        .union(enabledRawInputFlags)
        .rawValue
    }

    package static func virtualTerminalOutputMode(from mode: UInt32) -> UInt32 {
      Self(rawValue: mode)
        .union(enabledVirtualTerminalOutputFlags)
        .rawValue
    }
  }

  /// Owns saved Windows console modes for raw input and VT output lifecycle.
  package actor WindowsConsoleMode {
    package struct SavedModes: Equatable, Sendable {
      package let input: UInt32
      package let output: UInt32

      package init(input: UInt32, output: UInt32) {
        self.input = input
        self.output = output
      }
    }

    private let inputHandle: UInt
    private let outputHandle: UInt
    private let system: WindowsConsoleSystem
    private var savedModeState: SavedModes?

    package init(
      inputHandle: UInt,
      outputHandle: UInt,
      system: WindowsConsoleSystem = .current
    ) {
      self.inputHandle = inputHandle
      self.outputHandle = outputHandle
      self.system = system
    }

    package func enterRawMode() throws {
      guard savedModeState == nil else {
        return
      }

      let originalInputMode = try consoleMode(
        for: inputHandle,
        operation: .getInputMode
      )
      let originalOutputMode = try consoleMode(
        for: outputHandle,
        operation: .getOutputMode
      )
      let rawInputMode = WindowsConsoleModeFlags.rawInputMode(from: originalInputMode)
      let virtualTerminalOutputMode = WindowsConsoleModeFlags.virtualTerminalOutputMode(
        from: originalOutputMode
      )

      try setConsoleMode(
        rawInputMode,
        for: inputHandle,
        operation: .setInputMode
      )
      do {
        try setConsoleMode(
          virtualTerminalOutputMode,
          for: outputHandle,
          operation: .setOutputMode
        )
      } catch {
        _ = system.setConsoleMode(inputHandle, originalInputMode)
        throw error
      }

      savedModeState = SavedModes(input: originalInputMode, output: originalOutputMode)
    }

    package func exitRawMode() throws {
      guard let savedModeState else {
        return
      }

      var firstError: (any Error)?

      do {
        try setConsoleMode(
          savedModeState.input,
          for: inputHandle,
          operation: .setInputMode
        )
      } catch {
        firstError = error
      }

      do {
        try setConsoleMode(
          savedModeState.output,
          for: outputHandle,
          operation: .setOutputMode
        )
      } catch {
        if firstError == nil {
          firstError = error
        }
      }

      guard let firstError else {
        self.savedModeState = nil
        return
      }

      throw firstError
    }

    package func savedModes() -> SavedModes? {
      savedModeState
    }

    private func consoleMode(
      for handle: UInt,
      operation: WindowsConsoleModeOperation
    ) throws -> UInt32 {
      guard let mode = system.getConsoleMode(handle) else {
        throw PlatformIOError.unsupportedTerminalEnvironment
      }
      return mode
    }

    private func setConsoleMode(
      _ mode: UInt32,
      for handle: UInt,
      operation: WindowsConsoleModeOperation
    ) throws {
      guard system.setConsoleMode(handle, mode) else {
        throw PlatformIOError.consoleModeFailed(
          operation: operation,
          errorCode: system.lastErrorCode()
        )
      }
    }
  }

#endif
