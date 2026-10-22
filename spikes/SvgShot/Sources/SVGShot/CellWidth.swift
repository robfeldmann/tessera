/// Estimates whether a grapheme occupies two terminal cells.
///
/// `ScreenSnapshot` does not carry width, so the renderer infers it. The ranges cover
/// East Asian Wide and Fullwidth blocks and `Emoji_Presentation`; they are an
/// approximation, not a Unicode width table. A `U+FE0F` selector does not widen: the
/// Ghostty build used here stores `❤️` (U+2764 U+FE0F) in one cell.
enum CellWidth {
  static func isWide(_ character: Character) -> Bool {
    let scalars = character.unicodeScalars
    guard let first = scalars.first else {
      return false
    }
    if first.properties.isEmojiPresentation {
      return true
    }
    return wideRanges.contains { $0.contains(first.value) }
  }

  private static let wideRanges: [ClosedRange<UInt32>] = [
    0x1100...0x115F,
    0x2E80...0x303E,
    0x3041...0x33FF,
    0x3400...0x4DBF,
    0x4E00...0x9FFF,
    0xA000...0xA4CF,
    0xAC00...0xD7A3,
    0xF900...0xFAFF,
    0xFE10...0xFE19,
    0xFE30...0xFE6F,
    0xFF00...0xFF60,
    0xFFE0...0xFFE6,
    0x1F300...0x1F64F,
    0x1F900...0x1F9FF,
    0x20000...0x3FFFD,
  ]
}
