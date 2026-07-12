import SnapshotTesting
import TesseraTerminalANSI
import TesseraTerminalBuffer

extension Snapshotting where Value == Buffer, Format == String {
  /// Snapshots every buffer cell's content, diff policy, and non-default style.
  public static var bufferState: Snapshotting {
    Snapshotting<String, String>.lines.pullback { buffer in
      (0..<buffer.size.rows)
        .map { row in
          (0..<buffer.size.columns)
            .map { column in
              bufferStateToken(for: buffer[row, column])
            }
            .joined(separator: " ")
        }
        .joined(separator: "\n")
    }
  }
}

private func bufferStateToken(for cell: Cell) -> String {
  bufferContentToken(for: cell)
    + bufferPolicySuffix(for: cell.diffPolicy)
    + bufferStyleSuffix(for: cell.style)
}

private func bufferContentToken(for cell: Cell) -> String {
  switch cell.content {
  case .blank:
    "·"
  case .continuation:
    "◌"
  case .grapheme(let grapheme):
    grapheme
  case .raw:
    "R\(cell.width)"
  }
}

private func bufferPolicySuffix(for diffPolicy: CellDiffPolicy) -> String {
  switch diffPolicy {
  case .alwaysRepaint:
    "!"
  case .normal:
    ""
  case .opaque:
    "?"
  }
}

private func bufferStyleSuffix(for style: Style) -> String {
  guard style != Style() else {
    return ""
  }

  var components: [String] = []
  if style.foreground != .default {
    components.append("fg=\(bufferColorDescription(style.foreground))")
  }
  if style.background != .default {
    components.append("bg=\(bufferColorDescription(style.background))")
  }
  components.append(contentsOf: bufferAttributeDescriptions(style.attributes))
  if style.underlineStyle != .none {
    components.append("underline=\(bufferUnderlineStyleDescription(style.underlineStyle))")
  }
  if style.underlineColor != .default {
    components.append("underlineColor=\(bufferColorDescription(style.underlineColor))")
  }
  if let hyperlink = style.hyperlink {
    if let id = hyperlink.id {
      components.append("link=\(id):\(hyperlink.uri)")
    } else {
      components.append("link=\(hyperlink.uri)")
    }
  }

  return "{\(components.joined(separator: ","))}"
}

private func bufferAttributeDescriptions(_ attributes: TextAttributes) -> [String] {
  var descriptions: [String] = []
  if attributes.contains(.bold) {
    descriptions.append("bold")
  }
  if attributes.contains(.dim) {
    descriptions.append("dim")
  }
  if attributes.contains(.italic) {
    descriptions.append("italic")
  }
  if attributes.contains(.reverse) {
    descriptions.append("reverse")
  }
  if attributes.contains(.strikethrough) {
    descriptions.append("strikethrough")
  }
  return descriptions
}

private func bufferUnderlineStyleDescription(_ style: UnderlineStyle) -> String {
  switch style {
  case .none:
    "none"
  case .single:
    "single"
  case .double:
    "double"
  case .curly:
    "curly"
  case .dotted:
    "dotted"
  case .dashed:
    "dashed"
  }
}

private func bufferColorDescription(_ color: Color) -> String {
  String(describing: color)
    .replacingOccurrences(of: ", ", with: ",")
}
