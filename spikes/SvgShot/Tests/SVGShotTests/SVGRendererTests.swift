import Testing
import TesseraTerminal
import TesseraTerminalSnapshotSupport

@testable import SVGShot

struct SVGRendererTests {
  @Test
  func `renders identical bytes for repeated renders of one screen`() {
    let screen = DemoScreen.snapshot()
    let first = SVGRenderer(palette: .light).render(screen)
    let second = SVGRenderer(palette: .light).render(DemoScreen.snapshot())
    #expect(first == second)
  }

  @Test
  func `differs between light and dark only in palette values`() {
    let light = SVGRenderer(palette: .light).render(DemoScreen.snapshot())
    let dark = SVGRenderer(palette: .dark).render(DemoScreen.snapshot())
    #expect(light != dark)
    #expect(replacingHexColors(in: light) == replacingHexColors(in: dark))
  }

  @Test
  func `keeps the 80 by 24 demo under 100 kilobytes`() {
    let svg = SVGRenderer(palette: .light).render(DemoScreen.snapshot())
    #expect(svg.utf8.count < 100_000)
  }

  @Test
  func `places a wide grapheme across two cells and skips its spacer`() {
    let screen = screen(
      [
        [cell("漢"), cell(" "), cell("a")]
      ]
    )
    let svg = SVGRenderer(palette: .light).render(screen)
    #expect(svg.contains("textLength=\"19.2\""))
    #expect(svg.contains("x=\"19.2\" y=\"15\""))
    #expect(!svg.contains("x=\"9.6\""))
  }

  @Test
  func `keeps a narrow neighbour when a grapheme is not followed by a blank`() {
    let screen = screen(
      [
        [cell("❤️"), cell("|"), cell("★")]
      ]
    )
    let svg = SVGRenderer(palette: .light).render(screen)
    #expect(svg.contains("x=\"9.6 19.2\" y=\"15\" fill=\"#1f2328\">|★</text>"))
  }

  @Test
  func `merges adjacent cells with the same background into one rectangle`() {
    let red = RenderedColor.indexed(1)
    let screen = screen(
      [
        [cell(" ", background: red), cell(" ", background: red), cell(" ", background: red)]
      ]
    )
    let svg = SVGRenderer(palette: .light).render(screen)
    #expect(svg.contains("<rect x=\"0\" y=\"0\" width=\"28.8\" height=\"20\" fill=\"#cf222e\"/>"))
  }

  @Test
  func `escapes XML metacharacters in glyph content`() {
    let screen = screen([[cell("<"), cell("&"), cell(">")]])
    let svg = SVGRenderer(palette: .light).render(screen)
    #expect(svg.contains(">&lt;&amp;&gt;</text>"))
  }

  @Test
  func `formats hundredths of a unit without trailing zeros or exponents`() {
    #expect(formatHundredths(0) == "0")
    #expect(formatHundredths(5) == "0.05")
    #expect(formatHundredths(960) == "9.6")
    #expect(formatHundredths(1500) == "15")
    #expect(formatHundredths(1920) == "19.2")
    #expect(formatHundredths(-250) == "-2.5")
  }

  @Test
  func `draws reverse video with the foreground as the cell background`() {
    let screen = screen(
      [
        [cell("x", foreground: .indexed(4), reverse: true)]
      ]
    )
    let svg = SVGRenderer(palette: .dark).render(screen)
    #expect(svg.contains("fill=\"#58a6ff\"/>"))
  }

  @Test
  func `draws the cursor as a bar at its cell`() {
    let screen = ScreenSnapshot(
      cells: [[cell("a"), cell(" ")]],
      cursor: TerminalPosition(column: 1, row: 0)
    )
    let svg = SVGRenderer(palette: .light, showsCursor: true).render(screen)
    #expect(svg.contains("<rect x=\"9.6\" y=\"18\" width=\"9.6\" height=\"2\" fill=\"#0969da\"/>"))
  }
}

private func cell(
  _ character: Character,
  foreground: RenderedColor = .default,
  background: RenderedColor = .default,
  reverse: Bool = false
) -> RenderedCell {
  RenderedCell(
    character: character,
    foreground: foreground,
    background: background,
    bold: false,
    dim: false,
    italic: false,
    reverse: reverse,
    strikethrough: false
  )
}

private func screen(_ rows: [[RenderedCell]]) -> ScreenSnapshot {
  ScreenSnapshot(cells: rows, cursor: TerminalPosition(column: 0, row: 0))
}

/// Replaces every `#rrggbb` value with a placeholder so two palettes can be compared.
private func replacingHexColors(in svg: String) -> String {
  var result = ""
  var remaining = Substring(svg)
  while let hash = remaining.firstIndex(of: "#") {
    result += remaining[..<hash]
    let digitsStart = remaining.index(after: hash)
    let digitsEnd = remaining.index(digitsStart, offsetBy: 6, limitedBy: remaining.endIndex)
      ?? remaining.endIndex
    result += "#?"
    remaining = remaining[digitsEnd...]
  }
  result += remaining
  return result
}
