import TesseraTerminal
import TesseraTerminalSnapshotSupport

/// Renders a `ScreenSnapshot` as a self-contained SVG document.
///
/// Every cell lives at a fixed grid position in hundredths of a user unit. Text runs carry
/// one explicit `x` per glyph, so glyph advance widths from the font never shift a
/// character off its cell. Background, underline, and strikethrough are rectangles, so
/// they do not depend on font metrics either. Only glyph shapes come from the font.
public struct SVGRenderer: Sendable {
  /// Advance of one cell: 0.6 em at 16 px, the advance of most monospace faces.
  static let cellWidth = 960

  /// Height of one row: 20 user units.
  static let cellHeight = 2000

  /// Baseline offset from the top of a row.
  static let baseline = 1500

  static let fontFamily = "Menlo, 'SF Mono', 'DejaVu Sans Mono', 'Liberation Mono', monospace"
  static let fontSize = 16

  public var palette: SVGPalette
  public var showsCursor: Bool

  public init(palette: SVGPalette, showsCursor: Bool = false) {
    self.palette = palette
    self.showsCursor = showsCursor
  }

  /// Returns the SVG document for `screen`. Equal inputs produce equal bytes.
  public func render(_ screen: ScreenSnapshot) -> String {
    let columns = screen.cells.first?.count ?? 0
    let rows = screen.cells.count

    var backgrounds = ""
    var decorations = ""
    var glyphs = ""
    for (row, line) in screen.cells.enumerated() {
      let slots = slots(in: line)
      appendBackgrounds(of: slots, row: row, into: &backgrounds)
      appendDecorations(of: slots, row: row, into: &decorations)
      appendGlyphs(of: slots, row: row, into: &glyphs)
    }

    var svg = documentStart(columns: columns, rows: rows)
    svg += "<rect width=\"\(formatHundredths(columns * Self.cellWidth))\""
    svg += " height=\"\(formatHundredths(rows * Self.cellHeight))\""
    svg += " fill=\"\(palette.background.hex)\"/>\n"
    svg += group(backgrounds)
    svg += group(decorations)
    svg += group(glyphs)
    if showsCursor {
      svg += cursorRect(screen.cursor, rows: rows, columns: columns)
    }
    svg += "</svg>\n"
    return svg
  }

  // MARK: - Slots

  /// One visible cell, or a wide cell and the spacer it covers.
  private struct Slot {
    let column: Int
    let span: Int
    let cell: RenderedCell
    let glyphStyle: GlyphStyle
    /// The fill behind the cell, or `nil` when the page background shows through.
    let paper: SVGColor?
  }

  private struct GlyphStyle: Equatable {
    let fill: SVGColor
    let bold: Bool
    let italic: Bool
  }

  /// Consecutive slots that share a key, measured in columns.
  private struct Run<Key> {
    let column: Int
    let columns: Int
    let key: Key
  }

  private func slots(in line: [RenderedCell]) -> [Slot] {
    var result: [Slot] = []
    var column = 0
    while column < line.count {
      let span = occupiesTwoCells(line, column: column) ? 2 : 1
      result.append(slot(for: line[column], column: column, span: span))
      column += span
    }
    return result
  }

  /// A wide grapheme owns the blank cell after it. Ghostty stores that spacer as a space.
  /// Requiring the blank means a misclassified narrow grapheme cannot swallow a real
  /// neighbour; it only shifts the rest of the row by one cell.
  private func occupiesTwoCells(_ line: [RenderedCell], column: Int) -> Bool {
    guard CellWidth.isWide(line[column].character), column + 1 < line.count else {
      return false
    }
    return line[column + 1].character == " "
  }

  private func slot(for cell: RenderedCell, column: Int, span: Int) -> Slot {
    let ink: SVGColor
    let paper: SVGColor?
    if cell.reverse {
      ink = resolve(cell.background, default: palette.background)
      paper = resolve(cell.foreground, default: palette.foreground)
    } else {
      ink = resolve(cell.foreground, default: palette.foreground)
      paper = cell.background == .default
        ? nil
        : resolve(cell.background, default: palette.background)
    }
    let fill = cell.dim ? ink.midpoint(with: paper ?? palette.background) : ink
    return Slot(
      column: column,
      span: span,
      cell: cell,
      glyphStyle: GlyphStyle(fill: fill, bold: cell.bold, italic: cell.italic),
      paper: paper
    )
  }

  // MARK: - Colors

  private func resolve(_ color: RenderedColor, default fallback: SVGColor) -> SVGColor {
    switch color {
    case .default:
      fallback
    case .indexed(let index):
      indexedColor(index)
    case .rgb(let red, let green, let blue):
      SVGColor(red: red, green: green, blue: blue)
    }
  }

  private func indexedColor(_ index: UInt8) -> SVGColor {
    if index < 16 {
      return palette.ansi[Int(index)]
    }
    if index < 232 {
      let levels: [UInt8] = [0, 95, 135, 175, 215, 255]
      let offset = Int(index) - 16
      return SVGColor(
        red: levels[offset / 36],
        green: levels[(offset / 6) % 6],
        blue: levels[offset % 6]
      )
    }
    let level = UInt8(8 + 10 * (Int(index) - 232))
    return SVGColor(red: level, green: level, blue: level)
  }

  // MARK: - Layers

  private func appendBackgrounds(of slots: [Slot], row: Int, into output: inout String) {
    for run in runs(in: slots, key: { $0.paper }) {
      output += rect(
        x: run.column * Self.cellWidth,
        y: row * Self.cellHeight,
        width: run.columns * Self.cellWidth,
        height: Self.cellHeight,
        fill: run.key
      )
    }
  }

  /// Strikethrough and underline rectangles, one pass per line offset so that equal
  /// adjacent cells merge into one rectangle.
  private func appendDecorations(of slots: [Slot], row: Int, into output: inout String) {
    let lineHeight = 100
    for offset in [900, 1600, 1700, 1800] {
      let lineRuns = runs(in: slots) { slot in
        decorationLines(for: slot).first { $0.offset == offset }?.color
      }
      for run in lineRuns {
        output += rect(
          x: run.column * Self.cellWidth,
          y: row * Self.cellHeight + offset,
          width: run.columns * Self.cellWidth,
          height: lineHeight,
          fill: run.key
        )
      }
    }
  }

  private func decorationLines(for slot: Slot) -> [(offset: Int, color: SVGColor)] {
    var lines: [(offset: Int, color: SVGColor)] = []
    if slot.cell.strikethrough {
      lines.append((offset: 900, color: slot.glyphStyle.fill))
    }
    let underlineColor =
      slot.cell.underlineColor == .default
      ? slot.glyphStyle.fill
      : resolve(slot.cell.underlineColor, default: palette.foreground)
    switch slot.cell.underlineStyle {
    case .none:
      break
    case .double:
      lines.append((offset: 1600, color: underlineColor))
      lines.append((offset: 1800, color: underlineColor))
    case .curly, .dashed, .dotted, .single:
      // Curly, dashed, and dotted are drawn as single lines; see README.
      lines.append((offset: 1700, color: underlineColor))
    }
    return lines
  }

  private func appendGlyphs(of slots: [Slot], row: Int, into output: inout String) {
    let baselineY = row * Self.cellHeight + Self.baseline
    var index = 0
    while index < slots.count {
      let slot = slots[index]
      guard slot.span == 1, Self.isSimple(displayCharacter(slot.cell)) else {
        if !isBlank(slot) {
          output += standaloneGlyph(slot, y: baselineY)
        }
        index += 1
        continue
      }

      var end = index + 1
      while end < slots.count,
        slots[end].span == 1,
        Self.isSimple(displayCharacter(slots[end].cell)),
        slots[end].glyphStyle == slot.glyphStyle
      {
        end += 1
      }
      var first = index
      var last = end - 1
      while first <= last, isBlank(slots[first]) {
        first += 1
      }
      while last >= first, isBlank(slots[last]) {
        last -= 1
      }
      if first <= last {
        output += glyphRun(slots[first...last], style: slot.glyphStyle, y: baselineY)
      }
      index = end
    }
  }

  private func standaloneGlyph(_ slot: Slot, y: Int) -> String {
    let text = Self.escaped(String(displayCharacter(slot.cell)))
    return "<text x=\"\(formatHundredths(slot.column * Self.cellWidth))\""
      + " y=\"\(formatHundredths(y))\""
      + " textLength=\"\(formatHundredths(slot.span * Self.cellWidth))\""
      + " lengthAdjust=\"spacingAndGlyphs\""
      + styleAttributes(slot.glyphStyle)
      + ">\(text)</text>\n"
  }

  /// One `<text>` whose glyph positions are listed per cell.
  private func glyphRun(_ slots: ArraySlice<Slot>, style: GlyphStyle, y: Int) -> String {
    let positions = slots
      .map { formatHundredths($0.column * Self.cellWidth) }
      .joined(separator: " ")
    let text = slots
      .map { Self.escaped(String(displayCharacter($0.cell))) }
      .joined()
    return "<text x=\"\(positions)\" y=\"\(formatHundredths(y))\""
      + styleAttributes(style)
      + ">\(text)</text>\n"
  }

  private func cursorRect(_ position: TerminalPosition, rows: Int, columns: Int) -> String {
    guard position.row < rows, position.column < columns else {
      return ""
    }
    let barHeight = 200
    return rect(
      x: position.column * Self.cellWidth,
      y: position.row * Self.cellHeight + Self.cellHeight - barHeight,
      width: Self.cellWidth,
      height: barHeight,
      fill: palette.cursor
    )
  }

  // MARK: - Runs and text helpers

  private func runs<Key: Equatable>(
    in slots: [Slot],
    key: (Slot) -> Key?
  ) -> [Run<Key>] {
    var result: [Run<Key>] = []
    var index = 0
    while index < slots.count {
      guard let value = key(slots[index]) else {
        index += 1
        continue
      }
      let start = index
      index += 1
      while index < slots.count, key(slots[index]) == value {
        index += 1
      }
      let last = slots[index - 1]
      let end = last.column + last.span
      result.append(
        Run(column: slots[start].column, columns: end - slots[start].column, key: value)
      )
    }
    return result
  }

  private func isBlank(_ slot: Slot) -> Bool {
    displayCharacter(slot.cell) == " "
  }

  /// Control characters have no glyph in a cell; render them as spaces.
  private func displayCharacter(_ cell: RenderedCell) -> Character {
    guard let scalar = cell.character.unicodeScalars.first, scalar.value >= 0x20,
      scalar.value != 0x7F
    else {
      return " "
    }
    return cell.character
  }

  /// Single-scalar, BMP characters can be positioned with one `x` value each.
  /// SVG counts characters in UTF-16 code units, so astral scalars take their own element.
  private static func isSimple(_ character: Character) -> Bool {
    let scalars = character.unicodeScalars
    return scalars.count == 1 && (scalars.first?.value ?? 0) <= 0xFFFF
  }

  private func styleAttributes(_ style: GlyphStyle) -> String {
    var attributes = " fill=\"\(style.fill.hex)\""
    if style.bold {
      attributes += " font-weight=\"bold\""
    }
    if style.italic {
      attributes += " font-style=\"italic\""
    }
    return attributes
  }

  private func rect(x: Int, y: Int, width: Int, height: Int, fill: SVGColor) -> String {
    "<rect x=\"\(formatHundredths(x))\" y=\"\(formatHundredths(y))\""
      + " width=\"\(formatHundredths(width))\" height=\"\(formatHundredths(height))\""
      + " fill=\"\(fill.hex)\"/>\n"
  }

  private func group(_ content: String) -> String {
    content.isEmpty ? "" : "<g>\n\(content)</g>\n"
  }

  private func documentStart(columns: Int, rows: Int) -> String {
    let width = formatHundredths(columns * Self.cellWidth)
    let height = formatHundredths(rows * Self.cellHeight)
    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      + "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"\(height)\""
      + " viewBox=\"0 0 \(width) \(height)\""
      + " font-family=\"\(Self.fontFamily)\" font-size=\"\(Self.fontSize)\""
      + " xml:space=\"preserve\">\n"
  }

  /// Escapes the five XML metacharacters for element content.
  static func escaped(_ text: String) -> String {
    var result = ""
    for scalar in text.unicodeScalars {
      switch scalar {
      case "&": result += "&amp;"
      case "<": result += "&lt;"
      case ">": result += "&gt;"
      case "\"": result += "&quot;"
      case "'": result += "&apos;"
      default: result.unicodeScalars.append(scalar)
      }
    }
    return result
  }
}
