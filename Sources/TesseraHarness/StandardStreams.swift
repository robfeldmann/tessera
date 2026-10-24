import Foundation

#if os(Windows)
  import WinSDK
#endif

/// The one platform question the command line asks: is a standard stream a terminal.
enum StandardStreams {
  /// Whether standard input is attached to a terminal or console.
  static var inputIsTerminal: Bool {
    #if os(Windows)
      var mode: DWORD = 0
      return GetConsoleMode(GetStdHandle(STD_INPUT_HANDLE), &mode)
    #else
      return isatty(STDIN_FILENO) != 0
    #endif
  }

  /// Whether standard output is attached to a terminal or console.
  static var outputIsTerminal: Bool {
    #if os(Windows)
      var mode: DWORD = 0
      return GetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), &mode)
    #else
      return isatty(STDOUT_FILENO) != 0
    #endif
  }
}
