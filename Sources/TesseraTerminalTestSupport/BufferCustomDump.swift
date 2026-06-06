import CustomDump
import TesseraTerminalBuffer

extension Buffer: CustomDumpStringConvertible {
  /// Renders buffer rows directly for snapshots, using `·` for blank spaces.
  public var customDumpDescription: String {
    (0..<size.rows)
      .map { row in
        String(
          (0..<size.columns).map { column in
            self[row, column].character == " " ? "·" : self[row, column].character
          }
        )
      }
      .joined(separator: "\n")
  }
}
