#if canImport(CGhosttyVT)
  import CGhosttyVT
#endif

/// A virtual-terminal operation failed before its observation checkpoint completed.
public enum VirtualTerminalError: Error {
  #if canImport(CGhosttyVT)
    /// The backing emulator rejected an operation; the original result is preserved.
    case ghostty(operation: String, result: GhosttyResult)
  #endif
  /// Dimensions must each be in 1...65535; invalid resize leaves terminal state intact.
  case invalidSize(cols: Int, rows: Int)
}
