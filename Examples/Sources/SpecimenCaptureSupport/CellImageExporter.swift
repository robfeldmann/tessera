import TesseraTerminalSnapshotSupport

/// Exports the observed terminal cells in a screen snapshot as a deliberately bounded SVG.
package enum CellImageExporter {
  /// Errors are explicit rather than silently changing an observed cell into a different image.
  package enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case dimensionsOverflow
    case hyperlinkUnsupported
    case raggedRows(expected: Int, row: Int, actual: Int)
    case underlineColorWithoutUnderline
    case underlineStyleUnsupported
    case unsupportedCharacter(Character)

    package var description: String {
      switch self {
      case .dimensionsOverflow:
        return "the snapshot dimensions overflow the fixed SVG geometry"
      case .hyperlinkUnsupported:
        return "hyperlinks are not represented by this exporter"
      case let .raggedRows(expected, row, actual):
        return "row \(row) has \(actual) cells; expected \(expected)"
      case .underlineColorWithoutUnderline:
        return "an underline color cannot be represented without an underline"
      case .underlineStyleUnsupported:
        return "underline style is not supported; only single underline is supported"
      case let .unsupportedCharacter(character):
        return "character \(String(character)) is outside the printable ASCII exporter scope"
      }
    }
  }

  /// Constants are part of the image format and must change with the exporter version.
  package enum Constants {
    package static let version = "1"
    package static let cellWidth = 10
    package static let cellHeight = 20
    package static let fontFamily = "monospace"
    package static let fontSize = 16
    package static let baselineOffset = 15
    package static let defaultForeground = "#D0D0D0"
    package static let defaultBackground = "#101010"
    package static let dimOpacity = 0.6
  }

  private enum ColorRole {
    case background
    case foreground
  }
  /// A versioned projection of the actual cells in `screen`.
  ///
  /// The cursor outline, when present, is only a diagnostic coordinate marker. It does not
  /// claim to reproduce the terminal's cursor visibility, shape, or blink state.
  package static func svg(_ screen: ScreenSnapshot) throws -> String {
    let rowCount = screen.cells.count
    let columnCount = screen.cells.first?.count ?? 0

    for (row, cells) in screen.cells.enumerated() where cells.count != columnCount {
      throw Error.raggedRows(expected: columnCount, row: row, actual: cells.count)
    }

    guard columnCount <= Int.max / Constants.cellWidth,
          rowCount <= Int.max / Constants.cellHeight
    else {
      throw Error.dimensionsOverflow
    }

    // Validate all style and text data before emitting any output. This keeps failure atomic.
    for cells in screen.cells {
      for cell in cells {
        try validate(cell)
      }
    }

    let width = columnCount * Constants.cellWidth
    let height = rowCount * Constants.cellHeight
    var output = ""
    output.reserveCapacity(max(256, rowCount * max(columnCount, 1) * 160))
    output += "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\""
    output += " width=\"\(width)\" height=\"\(height)\" viewBox=\"0 0 \(width) \(height)\""
    output += " data-exporter-version=\"\(Constants.version)\""
    output += " data-cell-width=\"\(Constants.cellWidth)\" data-cell-height=\"\(Constants.cellHeight)\""
    output += " xml:space=\"preserve\" shape-rendering=\"crispEdges\">"
    output += "<desc>Observed terminal cells. The cursor outline is a diagnostic coordinate marker, not observed cursor visibility or shape.</desc>"

    for (row, cells) in screen.cells.enumerated() {
      for (column, cell) in cells.enumerated() {
        let x = column * Constants.cellWidth
        let y = row * Constants.cellHeight
        let foreground = color(cell.foreground, role: .foreground)
        let background = color(cell.background, role: .background)
        let effectiveForeground = cell.reverse ? background : foreground
        let effectiveBackground = cell.reverse ? foreground : background

        output += "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(Constants.cellWidth)\" height=\"\(Constants.cellHeight)\" fill=\"\(effectiveBackground)\"/>"

        var attributes = " x=\"\(x + Constants.cellWidth / 2)\" y=\"\(y + Constants.baselineOffset)\""
        attributes += " fill=\"\(effectiveForeground)\" font-family=\"\(Constants.fontFamily)\""
        attributes += " font-size=\"\(Constants.fontSize)\" text-anchor=\"middle\" dominant-baseline=\"alphabetic\""
        if cell.bold { attributes += " font-weight=\"700\"" }
        if cell.italic { attributes += " font-style=\"italic\"" }
        if cell.dim { attributes += " opacity=\"\(Constants.dimOpacity)\"" }

        var decorations: [String] = []
        if cell.underlineStyle == .single { decorations.append("underline") }
        if cell.strikethrough { decorations.append("line-through") }
        if !decorations.isEmpty {
          attributes += " text-decoration=\"\(decorations.joined(separator: " "))\""
          let decorationColor = cell.underlineStyle == .single
            ? underlineColor(cell.underlineColor, fallback: effectiveForeground)
            : effectiveForeground
          attributes += " text-decoration-color=\"\(decorationColor)\""
        }

        output += "<text\(attributes)>\(escapeXML(String(cell.character)))</text>"
      }
    }

    let cursor = screen.cursor
    if cursor.column >= 0, cursor.column < columnCount,
       cursor.row >= 0, cursor.row < rowCount {
      let x = cursor.column * Constants.cellWidth
      let y = cursor.row * Constants.cellHeight
      output += "<rect class=\"cursor-marker\" data-diagnostic=\"coordinate-only\" x=\"\(x)\" y=\"\(y)\" width=\"\(Constants.cellWidth)\" height=\"\(Constants.cellHeight)\" fill=\"none\" stroke=\"#FF00FF\" stroke-width=\"1\"/>"
    }

    output += "</svg>"
    return output
  }


  private static func validate(_ cell: RenderedCell) throws {
    let scalars = cell.character.unicodeScalars
    guard scalars.count == 1,
          let scalar = scalars.first,
          scalar.value >= 0x20,
          scalar.value <= 0x7E
    else {
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
      return role == .foreground ? Constants.defaultForeground : Constants.defaultBackground
    case let .rgb(red, green, blue):
      return rgb(red, green, blue)
    case let .indexed(index):
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
