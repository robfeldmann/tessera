import SnapshotTesting
import TesseraTerminalSnapshotSupport

/// Whitespace policy for terminal text snapshots.
public enum TerminalSnapshotTrim: Sendable {
  /// Preserve every cell in every row.
  case none

  /// Trim trailing blank cells from each row.
  case trailing
}

extension Snapshotting where Value == ScreenSnapshot, Format == String {
  /// Snapshots cursor position and per-cell debug metadata.
  public static var terminalDebugDump: Snapshotting {
    Snapshotting<String, String>.lines.pullback { snapshot in
      debugDump(snapshot)
    }
  }

  /// Snapshots the terminal's character grid.
  public static func terminalText(
    trim: TerminalSnapshotTrim = .trailing
  ) -> Snapshotting {
    Snapshotting<String, String>.lines.pullback { snapshot in
      textGrid(snapshot, trim: trim)
    }
  }

  /// Snapshots characters plus an aligned style grid.
  public static func terminalStyledGrid(
    trim: TerminalSnapshotTrim = .trailing
  ) -> Snapshotting {
    Snapshotting<String, String>.lines.pullback { snapshot in
      """
      ── chars ──
      \(textGrid(snapshot, trim: trim))
      ── style ──
      \(styleGrid(snapshot, trim: trim))
      """
    }
  }

  /// Snapshots characters plus an aligned hyperlink grid when metadata is available.
  public static func terminalLinksGrid(
    trim: TerminalSnapshotTrim = .trailing
  ) -> Snapshotting {
    Snapshotting<String, String>.lines.pullback { snapshot in
      """
      ── chars ──
      \(textGrid(snapshot, trim: trim))
      ── links ──
      \(linkGrid(snapshot, trim: trim))
      \(linkLegend(snapshot))
      """
    }
  }
}

private func textGrid(_ snapshot: ScreenSnapshot, trim: TerminalSnapshotTrim) -> String {
  snapshot.cells
    .map { row in String(characters(in: row, trim: trim)) }
    .joined(separator: "\n")
}

private func styleGrid(_ snapshot: ScreenSnapshot, trim: TerminalSnapshotTrim) -> String {
  snapshot.cells
    .map { row in String(styleGlyphs(in: row, trim: trim)) }
    .joined(separator: "\n")
}

private func linkGrid(_ snapshot: ScreenSnapshot, trim: TerminalSnapshotTrim) -> String {
  let legend = linkLegendEntries(snapshot)
  return snapshot.cells
    .map { row in
      String(
        trimmed(row, trim: trim).map { cell in
          guard let hyperlinkURI = cell.hyperlinkURI else {
            return "."
          }
          return legend[hyperlinkURI] ?? "?"
        }
      )
    }
    .joined(separator: "\n")
}

private func linkLegend(_ snapshot: ScreenSnapshot) -> String {
  let entries = linkLegendEntries(snapshot)
  guard entries.isEmpty == false else {
    return "No hyperlink metadata exposed by backing terminal."
  }

  let lines = entries
    .sorted { $0.value < $1.value }
    .map { "\($0.value) = \($0.key)" }
  return lines.joined(separator: "\n")
}

private func linkLegendEntries(_ snapshot: ScreenSnapshot) -> [String: Character] {
  let glyphs = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
  var entries: [String: Character] = [:]
  var nextGlyphIndex = 0
  for row in snapshot.cells {
    for cell in row {
      guard let hyperlinkURI = cell.hyperlinkURI, entries[hyperlinkURI] == nil else {
        continue
      }
      entries[hyperlinkURI] = nextGlyphIndex < glyphs.count ? glyphs[nextGlyphIndex] : "?"
      nextGlyphIndex += 1
    }
  }
  return entries
}

private func debugDump(_ snapshot: ScreenSnapshot) -> String {
  var lines = [
    "cursor: row \(snapshot.cursor.row), column \(snapshot.cursor.column)",
    "rows: \(snapshot.cells.count)",
  ]

  for rowIndex in snapshot.cells.indices {
    let row = snapshot.cells[rowIndex]
    lines.append("row \(rowIndex): \(debugText(row))")
    for columnIndex in row.indices {
      let cell = row[columnIndex]
      guard cell != .blank else { continue }
      lines.append(
        "  [\(rowIndex),\(columnIndex)] \(cell.character) \(attributesDescription(cell))"
      )
    }
  }

  return lines.joined(separator: "\n")
}

private func debugText(_ row: [RenderedCell]) -> String {
  String(characters(in: row, trim: .none).map { $0 == " " ? "·" : $0 })
}

private func characters(
  in row: [RenderedCell],
  trim: TerminalSnapshotTrim
) -> [Character] {
  trimmed(row, trim: trim).map(\.character)
}

private func styleGlyphs(
  in row: [RenderedCell],
  trim: TerminalSnapshotTrim
) -> [Character] {
  trimmed(row, trim: trim).map(styleGlyph)
}

private func trimmed(
  _ row: [RenderedCell],
  trim: TerminalSnapshotTrim
) -> ArraySlice<RenderedCell> {
  switch trim {
  case .none:
    row[...]
  case .trailing:
    if let lastNonBlankIndex = row.lastIndex(where: { $0 != .blank }) {
      row[...lastNonBlankIndex]
    } else {
      []
    }
  }
}

private func styleGlyph(_ cell: RenderedCell) -> Character {
  guard cell != .blank else {
    return "."
  }
  if cell.reverse {
    return "R"
  }
  if cell.foreground != .default || cell.background != .default {
    return "C"
  }
  if cell.bold {
    return "B"
  }
  if cell.dim {
    return "D"
  }
  if cell.italic {
    return "I"
  }
  if cell.strikethrough {
    return "S"
  }
  if cell.underline {
    return "U"
  }
  return "T"
}

private func attributesDescription(_ cell: RenderedCell) -> String {
  var attributes: [String] = []

  if cell.foreground != .default {
    attributes.append("fg=\(colorDescription(cell.foreground))")
  }
  if cell.background != .default {
    attributes.append("bg=\(colorDescription(cell.background))")
  }
  if cell.bold {
    attributes.append("bold")
  }
  if cell.dim {
    attributes.append("dim")
  }
  if cell.italic {
    attributes.append("italic")
  }
  if cell.underline {
    attributes.append("underline")
  }
  if cell.reverse {
    attributes.append("reverse")
  }
  if cell.strikethrough {
    attributes.append("strikethrough")
  }

  if let hyperlinkURI = cell.hyperlinkURI {
    attributes.append("link=\(hyperlinkURI)")
  }
  return attributes.isEmpty ? "default" : attributes.joined(separator: ",")
}

private func colorDescription(_ color: RenderedColor) -> String {
  if color == .default {
    return "default"
  }
  return String(describing: color)
    .replacingOccurrences(of: ", ", with: ",")
}
