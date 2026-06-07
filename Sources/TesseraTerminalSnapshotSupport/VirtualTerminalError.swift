enum VirtualTerminalError: Error {
  case ghosttyBackendUnavailable(cols: Int, rows: Int)
}
