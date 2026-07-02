#if canImport(CGhosttyVT)
  import CGhosttyVT
#endif

enum VirtualTerminalError: Error {
  #if canImport(CGhosttyVT)
    case ghostty(operation: String, result: GhosttyResult)
  #endif
  case invalidSize(cols: Int, rows: Int)
}
