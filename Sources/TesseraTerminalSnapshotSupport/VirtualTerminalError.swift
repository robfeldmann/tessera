#if !os(Windows)
  import CGhosttyVT
#endif

enum VirtualTerminalError: Error {
  #if !os(Windows)
    case ghostty(operation: String, result: GhosttyResult)
  #endif
  case invalidSize(cols: Int, rows: Int)
}
