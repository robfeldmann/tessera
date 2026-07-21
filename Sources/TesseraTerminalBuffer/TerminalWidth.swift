import DisplayWidth

private let displayWidth = DisplayWidth()

package func terminalCellWidth(of grapheme: String) -> Int {
  if isHalfwidthKatakanaSoundMark(grapheme) {
    // Terminals render these marks as spacing halfwidth characters even when width tables
    // vary.
    return 1
  }

  return min(displayWidth(grapheme), 2)
}

package func isControlGrapheme(_ grapheme: String) -> Bool {
  grapheme.unicodeScalars.contains { scalar in
    scalar == "\t" || scalar.value < 0x20 || (0x80...0x9F).contains(scalar.value)
  }
}

package func isPrintableStoredGrapheme(_ grapheme: String) -> Bool {
  !isControlGrapheme(grapheme) && terminalCellWidth(of: grapheme) > 0
}

package func isSupportedStoredGrapheme(_ grapheme: String) -> Bool {
  isPrintableStoredGrapheme(grapheme) && terminalCellWidth(of: grapheme) <= 2
}

private func isHalfwidthKatakanaSoundMark(_ grapheme: String) -> Bool {
  grapheme.unicodeScalars.count == 1
    && (grapheme.unicodeScalars.first == "\u{FF9E}"
      || grapheme.unicodeScalars.first == "\u{FF9F}")
}
