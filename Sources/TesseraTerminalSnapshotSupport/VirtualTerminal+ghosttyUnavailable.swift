import IssueReporting
import TesseraTerminalCore

extension VirtualTerminal {
  /// Whether Ghostty-backed virtual terminal support is absent from this build.
  ///
  /// True only when the `CGhosttyVT` module is compiled out — on Windows without the
  /// `TESSERA_GHOSTTY_WINDOWS=1` opt-in (see `Package.swift`).
  public static var isGhosttyUnavailable: Bool {
    #if canImport(CGhosttyVT)
      false
    #else
      true
    #endif
  }

  /// A virtual terminal that fails loudly in builds without Ghostty support.
  public static var ghosttyUnavailable: Self {
    let reason = "libghostty-vt is not available in this build"
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
      kittyImages: unimplemented(
        "VirtualTerminal.kittyImages: \(reason)",
        placeholder: []
      ),
      kittyPlacements: unimplemented(
        "VirtualTerminal.kittyPlacements: \(reason)",
        placeholder: []
      ),
      snapshot: unimplemented(
        "VirtualTerminal.snapshot: \(reason)",
        placeholder: ScreenSnapshot.empty
      )
    )
  }

  /// Creates a Ghostty-backed terminal, or a loudly-failing one when Ghostty is
  /// compiled out of this build.
  public static func ghosttyOrUnavailable(cols: Int, rows: Int) -> Self {
    #if canImport(CGhosttyVT)
      ghostty(cols: cols, rows: rows)
    #else
      ghosttyUnavailable
    #endif
  }
}
