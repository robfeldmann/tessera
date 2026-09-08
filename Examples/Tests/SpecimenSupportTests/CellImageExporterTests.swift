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
  func `rejects non-printable characters with a typed error`() {
    let screen = ScreenSnapshot(
      cells: [[cell("é")]],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    #expect(throws: CellImageExporter.Error.unsupportedCharacter("é")) {
      try CellImageExporter.svg(screen)
    }
  }

  @Test
  func `rejects hyperlinks instead of dropping them`() {
    let screen = ScreenSnapshot(
      cells: [[cell("x", hyperlinkURI: "https://example.invalid")]],
      cursor: TerminalPosition(column: 0, row: 0)
    )

    #expect(throws: CellImageExporter.Error.hyperlinkUnsupported) {
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
