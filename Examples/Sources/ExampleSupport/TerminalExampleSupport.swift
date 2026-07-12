import Foundation

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#elseif os(Windows)
  import WinSDK
#endif

/// Shared helpers for Tessera example executables.
public enum TerminalExampleSupport {
  /// Returns whether standard input/output provide the terminal features live demos need.
  public static func isRunningInInteractiveTerminal() -> Bool {
    #if os(macOS) || os(Linux)
      return isRunningInPOSIXTerminal()
    #elseif os(Windows)
      return isRunningInWindowsConsole()
    #else
      return false
    #endif
  }

  /// Prints guidance for examples that require a real interactive terminal.
  public static func printTerminalRequiredMessage(
    applicationName: String,
    features: [String],
    runCommand: String,
    attachSchemeName: String
  ) {
    let featureList = features.joined(separator: ", ")
    writeLine(
      """
      \(applicationName) needs to run in a real terminal because it uses \(featureList).

      Run it from your preferred terminal with:

        \(runCommand)

      To debug with Xcode breakpoints, select the `\(attachSchemeName)` scheme in Xcode,
      run it so Xcode waits for the executable to launch, then run the command above from
      your terminal.
      """
    )
  }

  /// Writes one line to standard output.
  public static func writeLine(_ line: String) {
    FileHandle.standardOutput.write(Data("\(line)\n".utf8))
  }

  #if os(macOS) || os(Linux)
    private static func isRunningInPOSIXTerminal() -> Bool {
      guard isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1 else {
        return false
      }

      var windowSize = winsize()
      guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &windowSize) == 0 else {
        return false
      }

      return windowSize.ws_col > 0 && windowSize.ws_row > 0
    }
  #endif

  #if os(Windows)
    private static func isRunningInWindowsConsole() -> Bool {
      guard
        let standardInput = standardWindowsHandle(STD_INPUT_HANDLE),
        let standardOutput = standardWindowsHandle(STD_OUTPUT_HANDLE)
      else {
        return false
      }

      guard isConsole(standardInput), isConsole(standardOutput) else {
        return false
      }

      var info = CONSOLE_SCREEN_BUFFER_INFO()
      guard GetConsoleScreenBufferInfo(standardOutput, &info) else {
        return false
      }

      let columns = Int(info.srWindow.Right - info.srWindow.Left + 1)
      let rows = Int(info.srWindow.Bottom - info.srWindow.Top + 1)
      return columns > 0 && rows > 0
    }

    private static func standardWindowsHandle(_ standardHandle: DWORD) -> HANDLE? {
      let handle = GetStdHandle(standardHandle)
      let rawHandle = unsafeBitCast(handle, to: UInt.self)
      guard rawHandle != 0, rawHandle != UInt.max else {
        return nil
      }
      return handle
    }

    private static func isConsole(_ handle: HANDLE) -> Bool {
      var mode: DWORD = 0
      return GetConsoleMode(handle, &mode)
    }
  #endif
}
