import CGhosttyVT

enum VirtualTerminalError: Error {
  case ghostty(operation: String, result: GhosttyResult)
  case invalidSize(cols: Int, rows: Int)
}
