import Darwin
import Foundation

/// Shared helpers for Tessera example executables.
public enum TerminalExampleSupport {
  /// Returns whether standard input/output provide the terminal features live demos need.
  public static func isRunningInInteractiveTerminal() -> Bool {
    guard isatty(STDIN_FILENO) == 1, isatty(STDOUT_FILENO) == 1 else {
      return false
    }

    var windowSize = winsize()
    guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &windowSize) == 0 else {
      return false
    }

    return windowSize.ws_col > 0 && windowSize.ws_row > 0
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
}
