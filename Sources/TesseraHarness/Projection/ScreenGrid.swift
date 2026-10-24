import TesseraTerminal
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport

/// The screen a terminal shows, one cell per column.
///
/// The virtual terminal reports a wide grapheme in its first cell and a blank in the next, and
/// carries no flag that says which blank belongs to the grapheme. The grid marks that second
/// cell as a continuation from the width table the library draws with, so the text of a row
/// reads `東京` and not `東 京 `, and a column still maps to one cell. Once the terminal
/// reports its own wide flag this derivation goes away.
package struct ScreenGrid: Equatable, Sendable {
  /// One terminal cell and whether it only continues the wide grapheme before it.
  struct GridCell: Equatable, Sendable {
    var cell: RenderedCell
    var isContinuation: Bool
  }

  /// One run of cells that share a non-default style, in one row.
  struct StyleRun: Equatable, Sendable {
    var row: Int
    var column: Int
    var columns: Int
    var style: String
  }

  /// A screen that cannot be written as a grid.
  package struct GridError: Error, Equatable, CustomStringConvertible {
    /// How many distinct styles the screen has.
    var styles: Int

    package var description: String {
      "the screen has \(styles) distinct styles, and a grid golden names at most "
        + "\(ScreenGrid.alphabet.count) with one letter each; take the shot where fewer "
        + "styles show, or compare the screen with `expect text` instead"
    }
  }

  /// The style letters, in the order a grid hands them out.
  private static let alphabet = Array(
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")

  /// The cells, row by row.
  var rows: [[GridCell]]

  /// Where the cursor is, in cells.
  var cursor: TerminalPosition

  /// The width of the widest row.
  var columns: Int {
    rows.map(\.count).max() ?? 0
  }

  /// The visible text of every row: continuation cells elided and trailing spaces removed.
  package var textRows: [String] {
    rows.indices.map(text(ofRow:))
  }

  /// The runs of non-default style in reading order, as the projection lists them.
  var styleRuns: [StyleRun] {
    var runs: [StyleRun] = []
    for (row, cells) in rows.enumerated() {
      var current: StyleRun?
      for (column, style) in Self.columnStyles(of: cells).enumerated() {
        if let run = current, run.style == style, !style.isEmpty {
          current?.columns = run.columns + 1
          continue
        }
        if let run = current {
          runs.append(run)
        }
        current =
          style.isEmpty
          ? nil : StyleRun(row: row, column: column, columns: 1, style: style)
      }
      if let current {
        runs.append(current)
      }
    }
    return runs
  }

  package init(_ snapshot: ScreenSnapshot) {
    rows = snapshot.cells.map(Self.cells(of:))
    cursor = snapshot.cursor
  }

  /// The cell's style as the legend spells it, or an empty string for the default style.
  ///
  /// Colours come first, then the attributes in the catalog's order. Hyperlinks are not part
  /// of the grid.
  static func style(of cell: RenderedCell) -> String {
    var tokens: [String] = []
    if cell.foreground != .default {
      tokens.append("fg=\(colorName(cell.foreground))")
    }
    if cell.background != .default {
      tokens.append("bg=\(colorName(cell.background))")
    }
    if cell.bold {
      tokens.append("bold")
    }
    if cell.dim {
      tokens.append("dim")
    }
    if cell.italic {
      tokens.append("italic")
    }
    switch cell.underlineStyle {
    case .none: break
    case .single: tokens.append("underline")
    case .double: tokens.append("underline=double")
    case .curly: tokens.append("underline=curly")
    case .dotted: tokens.append("underline=dotted")
    case .dashed: tokens.append("underline=dashed")
    }
    if cell.underlineStyle != .none, cell.underlineColor != .default {
      tokens.append("underline-color=\(colorName(cell.underlineColor))")
    }
    if cell.reverse {
      tokens.append("reverse")
    }
    if cell.strikethrough {
      tokens.append("strikethrough")
    }
    return tokens.joined(separator: " ")
  }

  private static func cells(of row: [RenderedCell]) -> [GridCell] {
    var result: [GridCell] = []
    result.reserveCapacity(row.count)
    var follows = false
    for cell in row {
      // Only a blank cell right after a wide grapheme is its continuation. The library's
      // width table and the terminal's can disagree about a cluster, and then the cell after
      // it holds real content that must not be dropped.
      let isContinuation = follows && cell.character == " "
      result.append(GridCell(cell: cell, isContinuation: isContinuation))
      follows = !isContinuation && Cell(character: cell.character).width == 2
    }
    return result
  }

  /// The style of every column of a row; a continuation cell takes the style of the wide
  /// grapheme it continues, so a style letter sits under every cell the grapheme covers.
  private static func columnStyles(of cells: [GridCell]) -> [String] {
    var styles: [String] = []
    styles.reserveCapacity(cells.count)
    for gridCell in cells {
      if gridCell.isContinuation, let previous = styles.last {
        styles.append(previous)
      } else {
        styles.append(style(of: gridCell.cell))
      }
    }
    return styles
  }

  private static func colorName(_ color: RenderedColor) -> String {
    switch color {
    case .default:
      "default"
    case .indexed(let index):
      "indexed(\(index))"
    case .rgb(let red, let green, let blue):
      "#" + [red, green, blue].map(hex).joined()
    }
  }

  private static func hex(_ byte: UInt8) -> String {
    let digits = String(byte, radix: 16)
    return digits.count == 1 ? "0" + digits : digits
  }

  /// The grid as `NAME.grid.txt` holds it: the characters, an aligned row of style letters
  /// for every character row, and the legend that names each letter.
  ///
  /// This is the catalog's styled-grid dialect (`docs/design.md`, "Styled grids"): three
  /// sections in this order, one style letter per cell, `.` for the default style. The rows
  /// follow one rule, so the dialect's "no more style rows than chars rows" always holds: a
  /// character row loses its trailing spaces, the chars section ends at the last row that has
  /// text or a style (a blank row with a background keeps its place as an empty line, and
  /// `NAME.txt` still ends at the last row with text), and the style section ends at the last
  /// row that has a style, each style row losing its trailing default cells. A screen with no
  /// styled cell has no style rows at all. The dialect names a colour only by role, so a
  /// colour that no role owns is spelled `#rrggbb` or `indexed(N)`, which
  /// `docs/architecture/developer-tooling.md` ("Shots and goldens") fixes.
  ///
  /// - Throws: ``GridError`` when the screen has more distinct styles than the 62 letters
  ///   name, since a letter that stands for two styles would make the golden ambiguous.
  package func styledGridText() throws(GridError) -> String {
    let styled = rows.map(Self.columnStyles(of:))
    let distinct = Set(styled.joined().filter { !$0.isEmpty })
    guard distinct.count <= Self.alphabet.count else {
      throw GridError(styles: distinct.count)
    }

    var letters: [String: Character] = [:]
    var order: [String] = []
    var styleRows: [String] = []
    for styles in styled {
      var line = ""
      for style in styles {
        if style.isEmpty {
          line.append(".")
          continue
        }
        let letter = letters[style] ?? Self.alphabet[order.count]
        if letters[style] == nil {
          letters[style] = letter
          order.append(style)
        }
        line.append(letter)
      }
      while line.last == "." {
        line.removeLast()
      }
      styleRows.append(line)
    }

    let text = textRows
    let styledRows = styleRows.lastIndex { !$0.isEmpty }.map { $0 + 1 } ?? 0
    let shownRows = max(text.dropTrailingEmptyRows().count, styledRows)
    var lines = ["── chars ──"] + text.prefix(shownRows)
    lines.append("── style ──")
    lines += styleRows.prefix(styledRows)
    lines.append("── legend ──")
    lines.append(".  default")
    for (index, style) in order.enumerated() {
      lines.append("\(Self.alphabet[index])  \(style)")
    }
    return lines.joined(separator: "\n") + "\n"
  }

  /// The text of one row, without its trailing spaces.
  func text(ofRow row: Int) -> String {
    guard rows.indices.contains(row) else {
      return ""
    }
    var text = String(rows[row].filter { !$0.isContinuation }.map(\.cell.character))
    while text.last == " " {
      text.removeLast()
    }
    return text
  }
}
