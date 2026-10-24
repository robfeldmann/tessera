import TesseraTerminalANSI
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@testable import TesseraHarness

struct ScreenGridTests {
  private func cell(
    _ character: Character, foreground: RenderedColor = .default,
    background: RenderedColor = .default, bold: Bool = false, italic: Bool = false,
    underline: UnderlineStyle = .none
  ) -> RenderedCell {
    RenderedCell(
      character: character, foreground: foreground, background: background, bold: bold,
      dim: false, italic: italic, reverse: false, strikethrough: false,
      underlineStyle: underline)
  }

  private func grid(_ rows: [[RenderedCell]]) -> ScreenGrid {
    ScreenGrid(ScreenSnapshot(cells: rows, cursor: TerminalPosition(column: 0, row: 0)))
  }

  private func plain(_ text: String, width: Int? = nil) -> [RenderedCell] {
    var cells = text.map { cell($0) }
    while cells.count < (width ?? 0) {
      cells.append(.blank)
    }
    return cells
  }

  // MARK: Text

  @Test
  func `a blank after a wide grapheme is its continuation and leaves no character`() {
    let screen = grid([[cell("東"), .blank, cell("京"), .blank, cell("a"), .blank]])

    #expect(screen.textRows == ["東京a"])
    #expect(
      screen.rows[0].map(\.isContinuation) == [false, true, false, true, false, false])
  }

  @Test
  func `content right after a wide grapheme is never taken for its continuation`() {
    let screen = grid([[cell("東"), cell("x"), .blank]])

    #expect(screen.textRows == ["東x"])
    #expect(screen.rows[0].map(\.isContinuation) == [false, false, false])
  }

  @Test
  func `a row's text loses its trailing spaces and a blank row is empty`() {
    let screen = grid([plain("ab", width: 5), plain("", width: 5)])

    #expect(screen.textRows == ["ab", ""])
    #expect(screen.columns == 5)
  }

  // MARK: Styled grid

  @Test
  func `a screen with no styled cell has an empty style section and a default legend`() {
    let screen = grid([plain("Hi", width: 4), plain("", width: 4)])

    #expect(
      screen.styledGridText
        == """
        ── chars ──
        Hi
        ── style ──
        ── legend ──
        .  default

        """)
  }

  @Test
  func
    `style letters are handed out in reading order and rows lose trailing default cells`()
  {
    let bold = cell("A", bold: true)
    let accent = cell("B", foreground: .rgb(0, 128, 255), bold: true)
    let screen = grid([
      [cell("x"), bold, bold, cell("y"), .blank],
      [accent, cell("z"), accent, .blank, .blank],
      plain("", width: 5),
    ])

    #expect(
      screen.styledGridText
        == """
        ── chars ──
        xAAy
        BzB
        ── style ──
        .AA
        B.B
        ── legend ──
        .  default
        A  bold
        B  fg=#0080ff bold

        """)
  }

  @Test
  func `a continuation cell is styled like the wide grapheme it continues`() {
    let wide = cell("東", background: .indexed(4), italic: true)
    let screen = grid([[wide, cell(" "), cell("a")]])

    #expect(
      screen.styledGridText
        == """
        ── chars ──
        東a
        ── style ──
        AA
        ── legend ──
        .  default
        A  bg=indexed(4) italic

        """)
    #expect(
      screen.styleRuns == [
        ScreenGrid.StyleRun(row: 0, column: 0, columns: 2, style: "bg=indexed(4) italic")
      ])
  }

  @Test
  func `a style spells colours first and attributes in the catalog's order`() {
    let cell = cell(
      "x", foreground: .indexed(1), background: .rgb(1, 2, 255), bold: true, italic: true,
      underline: .curly)

    #expect(
      ScreenGrid.style(of: cell) == "fg=indexed(1) bg=#0102ff bold italic underline=curly"
    )
    #expect(ScreenGrid.style(of: .blank).isEmpty)
  }

  @Test
  func `style runs merge adjacent cells of one style within a row`() {
    let bold = cell("a", bold: true)
    let screen = grid([[bold, bold, cell("b"), bold], [bold, .blank]])

    #expect(
      screen.styleRuns == [
        ScreenGrid.StyleRun(row: 0, column: 0, columns: 2, style: "bold"),
        ScreenGrid.StyleRun(row: 0, column: 3, columns: 1, style: "bold"),
        ScreenGrid.StyleRun(row: 1, column: 0, columns: 1, style: "bold"),
      ])
  }
}
