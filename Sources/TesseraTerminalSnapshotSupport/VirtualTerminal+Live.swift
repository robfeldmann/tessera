import Dependencies

extension VirtualTerminal: DependencyKey {
  public static var liveValue: Self { Self.ghostty }
}

extension VirtualTerminal {
  /// The Ghostty-backed virtual terminal implementation.
  public static var ghostty: Self {
    Self { cols, rows in
      throw VirtualTerminalError.ghosttyBackendUnavailable(cols: cols, rows: rows)
    }
  }
}
