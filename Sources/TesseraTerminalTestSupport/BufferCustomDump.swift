import CustomDump
import TesseraTerminalBuffer

extension Buffer: CustomDumpStringConvertible {
  /// Renders buffer rows directly for snapshots, using `·` for blank spaces.
  public var customDumpDescription: String {
    (0..<size.rows)
      .map { row in
        (0..<size.columns).map { column in
          switch self[row, column].content {
          case .blank:
            "·"
          case .continuation:
            "◌"
          case .grapheme(let grapheme):
            grapheme
          case .raw:
            "◆"
          }
        }
        .joined()
      }
      .joined(separator: "\n")
  }
}
