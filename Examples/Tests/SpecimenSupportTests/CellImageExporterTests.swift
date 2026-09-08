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
    #expect(image.contains("fill=\"#FF0000\""))
    #expect(image.contains("fill=\"#123456\""))
    #expect(image.contains("font-weight=\"700\""))
    #expect(image.contains("font-style=\"italic\""))
    #expect(image.contains("opacity=\"0.6\""))
    #expect(image.contains("text-decoration=\"underline line-through\""))
    #expect(image.contains("&amp;</text>"))
    #expect(image.contains("&lt;</text>"))
    #expect(
      image.contains(
        "class=\"cursor-marker\" data-diagnostic=\"coordinate-only\" x=\"10\""))
  }

  @Test
  func exportsUnicodeGraphemesAndKeepsContinuationStyles() throws {
    let screen = ScreenSnapshot(
      cells: [
        [
          cell("╭"),
          cell("界", background: .rgb(0x12, 0x34, 0x56)),
          cell(" ", background: .rgb(0x65, 0x43, 0x21)),
          cell("é"),
        ]
      ],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    let image = try CellImageExporter.svg(screen)

    #expect(image.contains("╭</text>"))
    #expect(image.contains("界</text>"))
    #expect(image.contains("é</text>"))
    #expect(image.contains("fill=\"#123456\""))
    #expect(image.contains("fill=\"#654321\""))
    #expect(image.contains("clipPath"))
    #expect(image.contains("x=\"20\" y=\"15\""))
    #expect(!image.contains("x=\"25\" y=\"15\""))
  }

  @Test
  func rejectsXMLInvalidControlsWithTypedError() {
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
