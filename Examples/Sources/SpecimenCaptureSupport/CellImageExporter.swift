import TesseraTerminal
import TesseraTerminalSnapshotSupport

/// Exports the observed terminal cells in a deliberately bounded SVG.
/// It uses the canonical terminal cell width resolver and preserves each captured cell's
/// background, but its generic monospace text rasterization is not pixel-canonical.
/// SVG output is intended for readable review; exact styled-cell snapshots are the portable
/// oracle across fonts, platforms, and rasterizers.
package enum CellImageExporter {
  /// Errors are explicit rather than silently changing an observed cell into a different image.
  package enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case cellCountExceeded
    case dimensionsExceeded
    case dimensionsOverflow
    case graphemeTooLarge
    case hyperlinkUnsupported
    case outputTooLarge
    case raggedRows(expected: Int, row: Int, actual: Int)
    case underlineColorWithoutUnderline
    case underlineStyleUnsupported
    case unsupportedCharacter(Character)
    case xmlInvalidControl(Character)

    package var description: String {
      switch self {
      case .cellCountExceeded:
        return "the snapshot cell count exceeds the exporter's safe limit"
      case .dimensionsExceeded:
        return "the snapshot dimensions exceed the exporter's safe limits"
      case .dimensionsOverflow:
        return "the snapshot dimensions overflow the fixed SVG geometry"
      case .graphemeTooLarge:
        return "a grapheme exceeds the exporter's safe text limit"
      case .hyperlinkUnsupported:
        return "hyperlinks are not represented by this exporter"
      case .outputTooLarge:
        return "the SVG output exceeds the exporter's safe limit"
      case .raggedRows(let expected, let row, let actual):
        return "row \(row) has \(actual) cells; expected \(expected)"
      case .underlineColorWithoutUnderline:
        return "an underline color cannot be represented without an underline"
      case .underlineStyleUnsupported:
        return "underline style is not supported; only single underline is supported"
      case .xmlInvalidControl(let character):
        return
          "XML 1.0 does not permit character U+\(String(character.unicodeScalars.first?.value ?? 0, radix: 16).uppercased())"
      case .unsupportedCharacter(let character):
        return "character \(String(character)) is not a representable terminal grapheme"
      }
    }
  }

  /// Constants are part of the image format and must change with the exporter version.
  package enum Constants {
    package static let version = "3"
    package static let cellWidth = 10
    package static let cellHeight = 20
    package static let fontFamily = "monospace"
    package static let fontSize = 16
    package static let baselineOffset = 15
    package static let defaultForeground = "#D0D0D0"
    package static let defaultBackground = "#101010"
    package static let defaultPalette = "tessera-dark-default"
    package static let dimOpacity = 0.6
  }

  /// Controls optional diagnostic material. The default is an ordinary cell image: the
  /// terminal's cursor coordinate is not evidence of cursor visibility, shape, or blinking.
  package struct Options: Equatable, Sendable {
    package var diagnosticCursor: Bool

    package init(diagnosticCursor: Bool = false) {
      self.diagnosticCursor = diagnosticCursor
    }
  }

  private enum Limits {
    static let maximumRows = 4_096
    static let maximumColumns = 4_096
    static let maximumCells = 1_000_000
    static let maximumGraphemeBytes = 4_096
    static let maximumOutputBytes = 64 * 1_024 * 1_024
    static let estimatedCellOverhead = 512
  }

  private enum ColorRole {
    case background
    case foreground
  }

  /// A versioned projection of the actual cells in screen.
  ///
  /// Diagnostic overlays are opt-in and identify a coordinate only; they do not claim to
  /// reproduce the terminal's cursor visibility, shape, or blink state. Empty and zero-width
  /// snapshots produce a well-formed zero-area SVG.
  package static func svg(_ screen: ScreenSnapshot, options: Options = Options()) throws
    -> String
  {
    let rowCount = screen.cells.count
    let columnCount = screen.cells.first?.count ?? 0

    guard rowCount <= Limits.maximumRows, columnCount <= Limits.maximumColumns else {
      throw Error.dimensionsExceeded
    }

    for (row, cells) in screen.cells.enumerated() where cells.count != columnCount {
      throw Error.raggedRows(expected: columnCount, row: row, actual: cells.count)
    }

    let (cellCount, cellCountOverflow) = rowCount.multipliedReportingOverflow(
      by: columnCount)
    guard !cellCountOverflow else {
      throw Error.dimensionsOverflow
    }
    guard cellCount <= Limits.maximumCells else {
      throw Error.cellCountExceeded
    }

    let (width, widthOverflow) = columnCount.multipliedReportingOverflow(
      by: Constants.cellWidth)
    let (height, heightOverflow) = rowCount.multipliedReportingOverflow(
      by: Constants.cellHeight)
    guard !widthOverflow, !heightOverflow else {
      throw Error.dimensionsOverflow
    }

    // Validate all style and text data before emitting any output. This keeps failure atomic.
    // The estimate bounds reserveCapacity and is conservative for XML-escaped text.
    var estimatedOutputBytes = 256
    for cells in screen.cells {
      for cell in cells {
        try validate(cell)
        let characterBytes = cell.character.utf8.count
        guard characterBytes <= Limits.maximumGraphemeBytes else {
          throw Error.graphemeTooLarge
        }
        let (escapedBytes, escapedOverflow) = characterBytes.multipliedReportingOverflow(
          by: 6)
        let (cellEstimate, cellEstimateOverflow) =
          escapedBytes.addingReportingOverflow(Limits.estimatedCellOverhead)
        let (newEstimate, totalOverflow) = estimatedOutputBytes.addingReportingOverflow(
          cellEstimate)
        guard !escapedOverflow, !cellEstimateOverflow, !totalOverflow else {
          throw Error.outputTooLarge
        }
        estimatedOutputBytes = newEstimate
      }
    }
    guard estimatedOutputBytes <= Limits.maximumOutputBytes else {
      throw Error.outputTooLarge
    }

    var output = ""
    output.reserveCapacity(estimatedOutputBytes)
    output += "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\""
    output += " width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\""
    output += " data-exporter-version=\"\(escapeXML(Constants.version))\""
    output +=
      " data-cell-width=\"\(Constants.cellWidth)\" data-cell-height=\"\(Constants.cellHeight)\""
    output += " data-font-family=\"\(escapeXML(Constants.fontFamily))\""
    output += " data-default-foreground=\"\(escapeXML(Constants.defaultForeground))\""
    output += " data-default-background=\"\(escapeXML(Constants.defaultBackground))\""
    output += " data-default-palette=\"\(escapeXML(Constants.defaultPalette))\""
    let diagnosticCursorValue = options.diagnosticCursor ? "true" : "false"
    output += " data-diagnostic-cursor=\"\(diagnosticCursorValue)\""
    output += " xml:space=\"preserve\" shape-rendering=\"crispEdges\">"
    output +=
      "<desc>Observed terminal cells. Generic monospace SVG is a readable projection, not pixel-identical terminal output. The optional cursor outline is a diagnostic coordinate marker, not observed cursor visibility or shape.</desc>"

    // ScreenSnapshot currently carries visible RenderedCell values, not explicit continuation
    // flags. Keep the established Cell width resolver; Ghostty represents covered trailing cells
    // as spaces, so their captured backgrounds remain available while duplicate text is omitted.
    // Clip the viewport and every glyph's permitted span. The second clip prevents a wide
    // grapheme from painting into the following ordinary cell while preserving its captured
    // continuation-cell backgrounds underneath.
    var glyphClipDefinitions = ""
    glyphClipDefinitions.reserveCapacity(cellCount * 72)
    for (row, cells) in screen.cells.enumerated() {
      var continuationColumnsRemaining = 0
      for (column, cell) in cells.enumerated() {
        if continuationColumnsRemaining > 0 {
          continuationColumnsRemaining -= 1
          continue
        }
        let span = Cell(character: cell.character).width
        let visibleSpan = min(span, cells.count - column)
        if span > 1 {
          continuationColumnsRemaining = min(span - 1, cells.count - column - 1)
        }
        let x = column * Constants.cellWidth
        let y = row * Constants.cellHeight
        let clipWidth = visibleSpan * Constants.cellWidth
        glyphClipDefinitions +=
          "<clipPath id=\"glyph-clip-\(row)-\(column)\"><rect x=\"\(x)\" y=\"\(y)\" width=\"\(clipWidth)\" height=\"\(Constants.cellHeight)\"/></clipPath>"
      }
    }
    output +=
      "<defs><clipPath id=\"viewport-clip\"><rect x=\"0\" y=\"0\" width=\"\(width)\" height=\"\(height)\"/></clipPath>\(glyphClipDefinitions)</defs>"
    output += "<g clip-path=\"url(#viewport-clip)\">"

    // Paint in explicit layers so a continuation-cell background cannot cover a leading
    // wide grapheme that was emitted earlier.
    output += "<g data-layer=\"backgrounds\">"
    for (row, cells) in screen.cells.enumerated() {
      for (column, cell) in cells.enumerated() {
        let x = column * Constants.cellWidth
        let y = row * Constants.cellHeight
        let foreground = color(cell.foreground, role: .foreground)
        let background = color(cell.background, role: .background)
        let effectiveBackground = cell.reverse ? foreground : background
        output +=
          "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(Constants.cellWidth)\" height=\"\(Constants.cellHeight)\" fill=\"\(escapeXML(effectiveBackground))\"/>"
      }
    }
    output += "</g><g data-layer=\"glyphs\">"
    for (row, cells) in screen.cells.enumerated() {
      var continuationColumnsRemaining = 0
      for (column, cell) in cells.enumerated() {
        let x = column * Constants.cellWidth
        let y = row * Constants.cellHeight
        let foreground = color(cell.foreground, role: .foreground)
        let background = color(cell.background, role: .background)
        let effectiveForeground = cell.reverse ? background : foreground

        if continuationColumnsRemaining > 0 {
          continuationColumnsRemaining -= 1
          continue
        }

        let span = Cell(character: cell.character).width
        if span > 1 {
          continuationColumnsRemaining = min(span - 1, cells.count - column - 1)
        }

        var attributes =
          " x=\"\(x + span * Constants.cellWidth / 2)\" y=\"\(y + Constants.baselineOffset)\""
        attributes +=
          " fill=\"\(escapeXML(effectiveForeground))\" font-family=\"\(escapeXML(Constants.fontFamily))\""
        attributes += " clip-path=\"url(#glyph-clip-\(row)-\(column))\""
        attributes +=
          " font-size=\"\(Constants.fontSize)\" text-anchor=\"middle\" dominant-baseline=\"alphabetic\""
        if cell.bold { attributes += " font-weight=\"700\"" }
        if cell.italic { attributes += " font-style=\"italic\"" }
        if cell.dim { attributes += " opacity=\"\(Constants.dimOpacity)\"" }

        var decorations: [String] = []
        if cell.underlineStyle == .single { decorations.append("underline") }
        if cell.strikethrough { decorations.append("line-through") }
        if !decorations.isEmpty {
          attributes += " text-decoration=\"\(decorations.joined(separator: " "))\""
          let decorationColor =
            cell.underlineStyle == .single
            ? underlineColor(cell.underlineColor, fallback: effectiveForeground)
            : effectiveForeground
          attributes += " text-decoration-color=\"\(escapeXML(decorationColor))\""
        }

        output += "<text\(attributes)>\(escapeXML(String(cell.character)))</text>"
      }
    }
    output += "</g></g>"

    if options.diagnosticCursor {
      let cursor = screen.cursor
      if cursor.column >= 0, cursor.column < columnCount,
        cursor.row >= 0, cursor.row < rowCount
      {
        let x = cursor.column * Constants.cellWidth
        let y = cursor.row * Constants.cellHeight
        output +=
          "<g data-layer=\"diagnostic-overlays\" clip-path=\"url(#viewport-clip)\"><rect class=\"cursor-marker\" data-diagnostic=\"coordinate-only\" x=\"\(x)\" y=\"\(y)\" width=\"\(Constants.cellWidth)\" height=\"\(Constants.cellHeight)\" fill=\"none\" stroke=\"#FF00FF\" stroke-width=\"1\"/></g>"
      }
    }

    output += "</svg>"
    return output
  }

  private static func validate(_ cell: RenderedCell) throws {
    for scalar in cell.character.unicodeScalars {
      let value = scalar.value
      let valid =
        value == 0x9 || value == 0xA || value == 0xD
        || (0x20...0xD7FF).contains(value)
        || (0xE000...0xFFFD).contains(value)
        || (0x10000...0x10FFFF).contains(value)
      if !valid {
        throw Error.xmlInvalidControl(cell.character)
      }
    }

    guard Cell(character: cell.character).width > 0 else {
      throw Error.unsupportedCharacter(cell.character)
    }

    if cell.hyperlinkURI != nil {
      throw Error.hyperlinkUnsupported
    }

    switch cell.underlineStyle {
    case .none:
      if cell.underlineColor != .default {
        throw Error.underlineColorWithoutUnderline
      }
    case .single:
      break
    case .curly, .dashed, .dotted, .double:
      throw Error.underlineStyleUnsupported
    }
  }

  private static func underlineColor(_ value: RenderedColor, fallback: String) -> String {
    value == .default ? fallback : color(value, role: .foreground)
  }

  private static func color(_ color: RenderedColor, role: ColorRole) -> String {
    switch color {
    case .default:
      return role == .foreground
        ? Constants.defaultForeground : Constants.defaultBackground
    case .rgb(let red, let green, let blue):
      return rgb(red, green, blue)
    case .indexed(let index):
      return indexed(index)
    }
  }

  private static func rgb(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> String {
    "#\(hex(red))\(hex(green))\(hex(blue))"
  }

  private static func indexed(_ index: UInt8) -> String {
    if index <= 15 {
      let palette: [(UInt8, UInt8, UInt8)] = [
        (0x00, 0x00, 0x00), (0x80, 0x00, 0x00), (0x00, 0x80, 0x00), (0x80, 0x80, 0x00),
        (0x00, 0x00, 0x80), (0x80, 0x00, 0x80), (0x00, 0x80, 0x80), (0xC0, 0xC0, 0xC0),
        (0x80, 0x80, 0x80), (0xFF, 0x00, 0x00), (0x00, 0xFF, 0x00), (0xFF, 0xFF, 0x00),
        (0x00, 0x00, 0xFF), (0xFF, 0x00, 0xFF), (0x00, 0xFF, 0xFF), (0xFF, 0xFF, 0xFF),
      ]
      let paletteColor = palette[Int(index)]
      return rgb(paletteColor.0, paletteColor.1, paletteColor.2)
    }
    if index <= 231 {
      let value = Int(index) - 16
      let red = value / 36
      let green = (value / 6) % 6
      let blue = value % 6
      return rgb(cubeComponent(red), cubeComponent(green), cubeComponent(blue))
    }
    let component = UInt8(8 + (Int(index) - 232) * 10)
    return rgb(component, component, component)
  }

  private static func cubeComponent(_ component: Int) -> UInt8 {
    component == 0 ? 0 : UInt8(55 + component * 40)
  }

  private static func hex(_ value: UInt8) -> String {
    let digits = Array("0123456789ABCDEF")
    return String(digits[Int(value >> 4)]) + String(digits[Int(value & 0x0F)])
  }

  private static func escapeXML(_ value: String) -> String {
    var escaped = ""
    escaped.reserveCapacity(value.utf8.count)
    for scalar in value.unicodeScalars {
      switch scalar.value {
      case 0x26: escaped += "&amp;"
      case 0x3C: escaped += "&lt;"
      case 0x3E: escaped += "&gt;"
      case 0x22: escaped += "&quot;"
      case 0x27: escaped += "&apos;"
      default: escaped.unicodeScalars.append(scalar)
      }
    }
    return escaped
  }
}
