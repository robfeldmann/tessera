import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import Testing

@testable import SpecimenCaptureSupport

@Suite
struct CellImageExporterTests {
  @Test
  func `exports actual cells with geometry, colors, and styles`() throws {
    let screen = ScreenSnapshot(
      cells: [
        [
          cell(
            "&",
            foreground: .rgb(0x12, 0x34, 0x56),
            background: .indexed(196),
            bold: true,
            dim: true,
            italic: true,
            reverse: true,
            strikethrough: true,
            underline: true
          ),
          cell("<"),
        ]
      ],
      cursor: TerminalPosition(column: 1, row: 0)
    )

    let image = try CellImageExporter.svg(screen)

    #expect(image.contains("width=\"20\" height=\"20\" viewBox=\"0 0 20 20\""))
    #expect(image.contains("data-font-family=\"monospace\""))
    #expect(image.contains("data-default-foreground=\"#D0D0D0\""))
    #expect(image.contains("data-default-background=\"#101010\""))
    #expect(image.contains("data-default-palette=\"tessera-dark-default\""))
    #expect(image.contains("data-diagnostic-cursor=\"false\""))
    #expect(image.contains("fill=\"#FF0000\""))
    #expect(image.contains("fill=\"#123456\""))
    #expect(image.contains("font-weight=\"700\""))
    #expect(image.contains("font-style=\"italic\""))
    #expect(image.contains("opacity=\"0.6\""))
    #expect(image.contains("text-decoration=\"underline line-through\""))
    #expect(image.contains("&amp;</text>"))
    #expect(image.contains("&lt;</text>"))
    #expect(!image.contains("cursor-marker"))

    let diagnostic = try CellImageExporter.svg(
      screen, options: CellImageExporter.Options(diagnosticCursor: true))
    #expect(diagnostic.contains("data-diagnostic-cursor=\"true\""))
    #expect(
      diagnostic.contains(
        "class=\"cursor-marker\" data-diagnostic=\"coordinate-only\" x=\"10\""))
  }

  @Test
  func `wide graphemes paint after every background and before following text`() throws {
    let screen = ScreenSnapshot(
      cells: [[
        cell("界", foreground: .rgb(0xF0, 0xF0, 0xF0), background: .rgb(0x10, 0x10, 0x10)),
        cell(" ", background: .rgb(0x20, 0x30, 0x40)),
        cell("A", foreground: .rgb(0x50, 0x60, 0x70), background: .rgb(0x40, 0x50, 0x60)),
      ]],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    let image = try CellImageExporter.svg(screen)
    let continuationBackground = offset(
      of: "<rect x=\"10\" y=\"0\" width=\"10\" height=\"20\" fill=\"#203040\"/>",
      in: image)
    let wideGlyph = offset(of: "界</text>", in: image)
    let followingGlyph = offset(of: "A</text>", in: image)
    #expect(continuationBackground >= 0)
    #expect(wideGlyph >= 0)
    #expect(followingGlyph >= 0)
    #expect(continuationBackground < wideGlyph)
    #expect(wideGlyph < followingGlyph)
    #expect(image.contains("id=\"glyph-clip-0-0\"><rect x=\"0\" y=\"0\" width=\"20\""))
    #expect(image.contains("clip-path=\"url(#glyph-clip-0-0)\""))
    #expect(image.contains("x=\"25\" y=\"15\""))
  }

  @Test
  func `combining and box drawing glyphs remain in the glyph layer`() throws {
    let screen = ScreenSnapshot(
      cells: [[cell("╭"), cell("é")]],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    let image = try CellImageExporter.svg(screen)
    let glyphLayer = offset(of: "<g data-layer=\"glyphs\">", in: image)
    let box = offset(of: "╭</text>", in: image)
    let combining = offset(of: "é</text>", in: image)
    #expect(glyphLayer >= 0)
    #expect(box > glyphLayer)
    #expect(combining > box)
    #expect(image.contains("x=\"15\" y=\"15\""))
  }

  @Test
  func `wide grapheme at viewport edge is clipped to its observed cells`() throws {
    let image = try CellImageExporter.svg(
      ScreenSnapshot(cells: [[cell("界")]], cursor: TerminalPosition(column: 0, row: 0)))

    #expect(image.contains("width=\"10\" height=\"20\" viewBox=\"0 0 10 20\""))
    #expect(image.contains("id=\"glyph-clip-0-0\"><rect x=\"0\" y=\"0\" width=\"10\""))
    #expect(image.contains("<text x=\"10\" y=\"15\""))
    #expect(image.contains("clipPath id=\"viewport-clip\""))
  }

  @Test
  func `reverse video swaps foreground and background in their paint layers`() throws {
    let image = try CellImageExporter.svg(
      ScreenSnapshot(
        cells: [[cell(
          "R", foreground: .rgb(0x12, 0x34, 0x56), background: .rgb(0xAB, 0xCD, 0xEF), reverse: true
        )]],
        cursor: TerminalPosition(column: 0, row: 0)))

    #expect(image.contains("<rect x=\"0\" y=\"0\" width=\"10\" height=\"20\" fill=\"#123456\"/>"))
    #expect(image.contains("<text x=\"5\" y=\"15\" fill=\"#ABCDEF\""))
  }

  @Test
  func `empty and zero width snapshots produce explicit zero area SVG`() throws {
    let empty = try CellImageExporter.svg(.empty)
    #expect(empty.contains("width=\"0\" height=\"0\" viewBox=\"0 0 0 0\""))
    #expect(!empty.contains("<text"))

    let zeroWidth = try CellImageExporter.svg(
      ScreenSnapshot(cells: [[], []], cursor: TerminalPosition(column: 0, row: 0)))
    #expect(zeroWidth.contains("width=\"0\" height=\"40\" viewBox=\"0 0 0 40\""))
    #expect(!zeroWidth.contains("<text"))
  }

  @Test
  func `rejects XML-invalid controls with a typed error`() {
    let control = Character(String(UnicodeScalar(0x07)!))
    let screen = ScreenSnapshot(
      cells: [[cell(control)]],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    #expect(throws: CellImageExporter.Error.xmlInvalidControl(control)) {
      try CellImageExporter.svg(screen)
    }
  }

  @Test
  func `rejects ragged snapshots`() {
    let screen = ScreenSnapshot(
      cells: [[cell("a")], [cell("b"), cell("c")]],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    #expect(throws: CellImageExporter.Error.raggedRows(expected: 1, row: 1, actual: 2)) {
      try CellImageExporter.svg(screen)
    }
  }

  @Test
  func `rejects excessive dimensions and grapheme allocations`() {
    let rows = Array(repeating: [cell("a")], count: 4_097)
    #expect(throws: CellImageExporter.Error.dimensionsExceeded) {
      try CellImageExporter.svg(
        ScreenSnapshot(cells: rows, cursor: TerminalPosition(column: 0, row: 0)))
    }

    let combiningMark = String(UnicodeScalar(0x301)!)
    let combining = Character("a" + String(repeating: combiningMark, count: 2_048))
    #expect(throws: CellImageExporter.Error.graphemeTooLarge) {
      try CellImageExporter.svg(
        ScreenSnapshot(cells: [[cell(combining)]], cursor: TerminalPosition(column: 0, row: 0)))
    }
  }

  private func offset(of needle: String, in haystack: String) -> Int {
    guard let range = haystack.range(of: needle) else { return -1 }
    return haystack.distance(from: haystack.startIndex, to: range.lowerBound)
  }

  private func cell(
    _ character: Character,
    foreground: RenderedColor = .default,
    background: RenderedColor = .default,
    bold: Bool = false,
    dim: Bool = false,
    italic: Bool = false,
    reverse: Bool = false,
    strikethrough: Bool = false,
    underline: Bool = false,
    underlineColor: RenderedColor = .default,
    hyperlinkURI: String? = nil
  ) -> RenderedCell {
    RenderedCell(
      character: character,
      foreground: foreground,
      background: background,
      bold: bold,
      dim: dim,
      italic: italic,
      reverse: reverse,
      strikethrough: strikethrough,
      underlineStyle: underline ? .single : .none,
      underlineColor: underlineColor,
      hyperlinkURI: hyperlinkURI
    )
  }
}
