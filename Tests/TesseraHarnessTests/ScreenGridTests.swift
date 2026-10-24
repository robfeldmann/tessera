import CustomDump
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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

    expectNoDifference(screen.textRows, ["東京a"])
    expectNoDifference(
      screen.rows[0].map(\.isContinuation), [false, true, false, true, false, false])
  }

  @Test
  func `content right after a wide grapheme is never taken for its continuation`() {
    let screen = grid([[cell("東"), cell("x"), .blank]])

    expectNoDifference(screen.textRows, ["東x"])
    expectNoDifference(screen.rows[0].map(\.isContinuation), [false, false, false])
  }

  @Test
  func `a row's text loses its trailing spaces and a blank row is empty`() {
    let screen = grid([plain("ab", width: 5), plain("", width: 5)])

    expectNoDifference(screen.textRows, ["ab", ""])
    #expect(screen.columns == 5)
  }

  // MARK: Styled grid

  @Test
  func `a screen with no styled cell has an empty style section and a default legend`()
    throws
  {
    let screen = grid([plain("Hi", width: 4), plain("", width: 4)])

    assertInlineSnapshot(of: try screen.styledGridText(), as: .lines) {
      """
      ── chars ──
      Hi
      ── style ──
      ── legend ──
      .  default

      """
    }
  }

  @Test
  func
    `style letters are handed out in reading order and rows lose trailing default cells`()
    throws
  {
    let bold = cell("A", bold: true)
    let accent = cell("B", foreground: .rgb(0, 128, 255), bold: true)
    let screen = grid([
      [cell("x"), bold, bold, cell("y"), .blank],
      [accent, cell("z"), accent, .blank, .blank],
      plain("", width: 5),
    ])

    assertInlineSnapshot(of: try screen.styledGridText(), as: .lines) {
      """
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

      """
    }
  }

  @Test
  func `a continuation cell is styled like the wide grapheme it continues`() throws {
    let wide = cell("東", background: .indexed(4), italic: true)
    let screen = grid([[wide, cell(" "), cell("a")]])

    assertInlineSnapshot(of: try screen.styledGridText(), as: .lines) {
      """
      ── chars ──
      東a
      ── style ──
      AA
      ── legend ──
      .  default
      A  bg=indexed(4) italic

      """
    }
    expectNoDifference(
      screen.styleRuns,
      [ScreenGrid.StyleRun(row: 0, column: 0, columns: 2, style: "bg=indexed(4) italic")]
    )
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

    expectNoDifference(
      screen.styleRuns,
      [
        ScreenGrid.StyleRun(row: 0, column: 0, columns: 2, style: "bold"),
        ScreenGrid.StyleRun(row: 0, column: 3, columns: 1, style: "bold"),
        ScreenGrid.StyleRun(row: 1, column: 0, columns: 1, style: "bold"),
      ]
    )
  }

  // MARK: Grid rows

  /// The chars rows and the style rows of a grid's text.
  private func sections(of text: String) -> (
    chars: [String], style: [String], legend: [String]
  ) {
    var chars: [String] = []
    var style: [String] = []
    var legend: [String] = []
    var section = ""
    for line in text.split(separator: "\n", omittingEmptySubsequences: false).dropLast() {
      if line.hasPrefix("── ") {
        section = String(line)
        continue
      }
      switch section {
      case "── chars ──": chars.append(String(line))
      case "── style ──": style.append(String(line))
      default: legend.append(String(line))
      }
    }
    return (chars, style, legend)
  }

  @Test
  func `a styled blank row below the text keeps its place in the chars section`() throws {
    let fill = cell(" ", background: .indexed(4))
    let screen = grid([
      plain("Hi", width: 4), [fill, fill, fill, fill], [fill, fill, fill, fill],
    ])

    expectNoDifference(screen.textRows, ["Hi", "", ""])
    assertInlineSnapshot(of: try screen.styledGridText(), as: .lines) {
      """
      ── chars ──
      Hi


      ── style ──

      AAAA
      AAAA
      ── legend ──
      .  default
      A  bg=indexed(4)

      """
    }
  }

  @Test
  func `the text golden still ends at the last row with text`() throws {
    let fill = cell(" ", background: .indexed(4))
    let screen = grid([plain("Hi", width: 4), [fill, fill, fill, fill]])

    #expect(GoldenStore.text(of: screen.textRows) == "Hi\n")
    expectNoDifference(try sections(of: screen.styledGridText()).chars, ["Hi", ""])
  }

  @Test
  func `a grid never has more style rows than chars rows`() throws {
    let bold = cell("a", bold: true)
    let fill = cell(" ", background: .indexed(1))
    let screens: [ScreenGrid] = [
      grid([]),
      grid([plain("", width: 3)]),
      grid([plain("text", width: 4), plain("", width: 4)]),
      grid([[bold], plain("", width: 1), plain("", width: 1)]),
      grid([plain("", width: 2), [fill, fill], plain("x", width: 2), [fill, fill]]),
      grid([[fill, fill], [fill, fill], plain("", width: 2), plain("", width: 2)]),
    ]
    for screen in screens {
      let found = try sections(of: screen.styledGridText())
      #expect(found.style.count <= found.chars.count, "\(screen.textRows)")
      #expect(found.style.last?.isEmpty != true, "\(screen.textRows)")
      #expect(found.chars.last?.isEmpty != true || found.style.count == found.chars.count)
    }
  }

  @Test
  func `a grid names up to 62 styles, one letter each`() throws {
    let cells = (0..<62).map { cell("x", foreground: .rgb(UInt8($0), 0, 0)) }
    let found = try sections(of: grid([cells]).styledGridText())

    #expect(found.legend.count == 63)
    #expect(Set(found.legend.compactMap(\.first)).count == 63)
    #expect(found.legend.last == "9  fg=#3d0000")
    #expect(found.style == [String(found.legend.dropFirst().compactMap(\.first))])
  }

  @Test
  func `a screen with 63 styles is refused, not written with a repeated letter`() {
    let cells = (0..<63).map { cell("x", foreground: .rgb(UInt8($0), 0, 0)) }
    let screen = grid([cells])

    #expect(throws: ScreenGrid.GridError(styles: 63)) {
      try screen.styledGridText()
    }
    #expect(ScreenGrid.GridError(styles: 63).description.contains("63 distinct styles"))
  }

  @Test
  func `a shot of a screen with too many styles fails as a harness error in both modes`()
  {
    let cells = (0..<63).map { cell("x", foreground: .rgb(UInt8($0), 0, 0)) }
    let screen = grid([cells])

    var messages: [String] = []
    for record in [false, true] {
      let store = GoldenStore(scenarioPath: "/nonexistent/many.scn", record: record)
      guard case .failed(let message) = store.check(shot: "wide", screen: screen) else {
        Issue.record("record \(record): the shot did not fail as a harness error")
        continue
      }
      messages.append(message)
    }

    assertInlineSnapshot(of: messages, as: .customDump) {
      """
      [
        [0]: "shot `wide` cannot be compared with a grid golden: the screen has 63 distinct styles, and a grid golden names at most 62 with one letter each; take the shot where fewer styles show, or compare the screen with `expect text` instead",
        [1]: "shot `wide` cannot be compared with a grid golden: the screen has 63 distinct styles, and a grid golden names at most 62 with one letter each; take the shot where fewer styles show, or compare the screen with `expect text` instead"
      ]
      """
    }
  }
}
