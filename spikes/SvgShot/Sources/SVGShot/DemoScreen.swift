import TesseraTerminalSnapshotSupport

/// A scripted 80×24 screen that exercises every color path and attribute the renderer
/// maps: the ANSI 16, the 256-color ramp and cube, truecolor, every SGR attribute, wide
/// graphemes, combining marks, emoji presentation, and box drawing.
public enum DemoScreen {
  public static let columns = 80
  public static let rows = 24

  /// The demo as a screen parsed by Ghostty.
  public static func snapshot() -> ScreenSnapshot {
    let terminal = VirtualTerminal.ghostty(cols: columns, rows: rows)
    terminal.feed(script)
    return terminal.snapshot()
  }

  /// The demo's byte stream: one line per row, CR LF separated, no trailing newline.
  public static let script: String = makeRows().joined(separator: "\r\n")

  private static func sgr(_ parameters: String) -> String {
    "\u{1B}[\(parameters)m"
  }

  private static let reset = sgr("0")

  /// Pads plain text with spaces to `width` cells, counting wide graphemes as two.
  private static func pad(_ text: String, to width: Int) -> String {
    let used = text.reduce(0) { $0 + (CellWidth.isWide($1) ? 2 : 1) }
    return text + String(repeating: " ", count: max(0, width - used))
  }

  /// A bordered line `width` cells wide; `edges` are the left and right glyphs.
  private static func framed(_ inner: String, width: Int, edges: (String, String)) -> String {
    edges.0 + pad(" " + inner, to: width - 2) + edges.1
  }

  private static func rule(_ count: Int, _ glyph: String) -> String {
    String(repeating: glyph, count: count)
  }

  private static func makeRows() -> [String] {
    var rows: [String] = []

    rows.append(sgr("1;96") + "SvgShot demo · 80×24" + reset)
    rows.append("")

    rows.append(
      "ANSI bg  "
        + (0..<16).map { index in
          sgr(index < 8 ? "\(40 + index)" : "\(100 + index - 8)") + "   " + reset
        }.joined()
    )
    rows.append(
      "ANSI fg  "
        + (0..<16).map { index in
          sgr(index < 8 ? "\(30 + index)" : "\(90 + index - 8)") + "Aa " + reset
        }.joined()
    )
    rows.append(
      "gray 256 "
        + (232..<256).map { sgr("48;5;\($0)") + "  " + reset }.joined()
    )
    rows.append(
      "cube 256 "
        + (16..<48).map { sgr("48;5;\($0)") + "  " + reset }.joined()
    )
    rows.append(
      "rgb      "
        + (0..<35).map { step in
          let red = step * 255 / 34
          return sgr("48;2;\(red);128;\(255 - red)") + "  " + reset
        }.joined()
    )
    rows.append("")

    rows.append(
      "plain "
        + sgr("1") + "bold" + reset + " "
        + sgr("2") + "dim" + reset + " "
        + sgr("3") + "italic" + reset + " "
        + sgr("4") + "underline" + reset + " "
        + sgr("4:2") + "double" + reset + " "
        + sgr("4:3") + "curly" + reset + " "
        + sgr("9") + "strike" + reset + " "
        + sgr("7") + "reverse" + reset
    )
    rows.append(
      sgr("1;3;38;2;255;121;198") + "bold italic rgb" + reset + " "
        + sgr("4;58:5:208") + "ul-color" + reset + " "
        + sgr("31;42") + "red/green" + reset + " "
        + sgr("7;33") + "rev-yellow" + reset + " "
        + sgr("2;31") + "dim-red" + reset
    )
    rows.append("")

    let boxes: [[String]] = [
      singleBox(),
      doubleBox(),
      roundedBox(),
    ]
    for line in 0..<boxes[0].count {
      rows.append(boxes[0][line] + "  " + boxes[1][line] + "  " + boxes[2][line])
    }
    rows.append("")

    rows.append("wide    漢字テスト 한국어 中文 ｶﾅ")
    rows.append("emoji   🙂 🚀 ✅ ⚡ ❤️ ★ ✓ ✗ → ←")
    rows.append("combine e\u{301} a\u{308} o\u{302} n\u{303} (NFD)")
    rows.append("align   |漢|a|字|b|   |ab|漢字|cd|")
    rows.append(
      "rainbow "
        + "SvgShot".enumerated().map { index, letter in
          sgr("1;38;2;\(255 - index * 35);\(index * 40);\(120 + index * 15)")
            + String(letter) + reset
        }.joined()
    )
    rows.append("")
    rows.append("$ ")
    return rows
  }

  private static func singleBox() -> [String] {
    let width = 24
    return [
      "┌" + rule(width - 2, "─") + "┐",
      framed("single ascii", width: width, edges: ("│", "│")),
      framed("漢字 wide cells", width: width, edges: ("│", "│")),
      framed("░▒▓█ shades", width: width, edges: ("│", "│")),
      "└" + rule(width - 2, "─") + "┘",
    ]
  }

  private static func doubleBox() -> [String] {
    let width = 24
    return [
      "╔" + rule(width - 2, "═") + "╗",
      framed("double lines", width: width, edges: ("║", "║")),
      framed("▀▄▌▐ halves", width: width, edges: ("║", "║")),
      framed("├┼┤ junctions", width: width, edges: ("║", "║")),
      "╚" + rule(width - 2, "═") + "╝",
    ]
  }

  private static func roundedBox() -> [String] {
    let width = 26
    let red = sgr("31")
    return [
      "╭" + rule(width - 2, "─") + "╮",
      red + framed("rounded red", width: width, edges: ("│", "│")) + reset,
      framed("heavy ┏━┓┗━┛", width: width, edges: ("┃", "┃")),
      framed("╞═╡ ╟─╢", width: width, edges: ("│", "│")),
      "╰" + rule(width - 2, "─") + "╯",
    ]
  }
}
