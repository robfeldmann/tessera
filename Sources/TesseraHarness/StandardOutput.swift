import Foundation

#if os(Windows)
  import WinSDK
#endif

/// The one platform question the command line asks: is standard output a terminal.
enum StandardOutput {
  /// Whether standard output is attached to a terminal or console.
  static var isTerminal: Bool {
    #if os(Windows)
      var mode: DWORD = 0
      return GetConsoleMode(GetStdHandle(STD_OUTPUT_HANDLE), &mode)
    #else
      return isatty(STDOUT_FILENO) != 0
    #endif
  }
}
