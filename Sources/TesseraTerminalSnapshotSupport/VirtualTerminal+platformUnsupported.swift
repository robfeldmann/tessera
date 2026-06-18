import IssueReporting
import TesseraTerminalCore

extension VirtualTerminal {
  /// Whether virtual terminal support is unavailable on this platform.
  public static var isPlatformUnsupported: Bool {
    #if os(Windows)
      true
    #else
      false
    #endif
  }

  /// Creates a Ghostty-backed terminal or an unsupported terminal on unsupported platforms.
  public static func ghosttyOrPlatformUnsupported(cols: Int, rows: Int) -> Self {
    #if os(Windows)
      platformUnsupported
    #else
      ghostty(cols: cols, rows: rows)
    #endif
  }

  /// A virtual terminal that fails loudly on platforms without Ghostty support.
  public static var platformUnsupported: Self {
    let reason = "libghostty-vt is unavailable on this platform"
    return Self(
      feed: unimplemented("VirtualTerminal.feed: \(reason)"),
      text: unimplemented(
        "VirtualTerminal.text: \(reason)",
        placeholder: ""
      ),
      cell: unimplemented(
        "VirtualTerminal.cell: \(reason)",
        placeholder: .blank
      ),
      cursor: unimplemented(
        "VirtualTerminal.cursor: \(reason)",
        placeholder: TerminalPosition(column: 0, row: 0)
      ),
      snapshot: unimplemented(
        "VirtualTerminal.snapshot: \(reason)",
        placeholder: ScreenSnapshot.empty
      )
    )
  }
}
