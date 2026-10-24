import TesseraCore
import TesseraTerminalCore

/// `key=value` node selector: `type=Text id=root/1/0 text="Submit" nth=2`.
///
/// Every field filters; `nth` then picks one match by zero-based preorder position.
/// Without `nth` the locator must match exactly one node.
package struct Locator: CustomStringConvertible, Equatable, Sendable {
  struct Failure: Error {
    var message: String
  }

  enum Resolution {
    case node(NodeDiagnostics)
    case none
    case ambiguous([NodeDiagnostics])
  }

  static let accepted = "type, id, text, nth"

  package var type: String?
  package var id: String?
  package var text: String?
  package var nth: Int?

  package var description: String {
    var terms: [String] = []
    if let type { terms.append("type=\(type)") }
    if let id { terms.append("id=\(id)") }
    if let text { terms.append("text=\"\(text)\"") }
    if let nth { terms.append("nth=\(nth)") }
    return terms.joined(separator: " ")
  }

  static func parse(_ tokens: [String]) throws -> Self {
    var locator = Self()
    for token in tokens {
      guard let equals = token.firstIndex(of: "=") else {
        throw Failure(
          message: "locator term `\(token)` is not key=value; accepted keys: \(accepted)")
      }
      let key = String(token[..<equals])
      let value = String(token[token.index(after: equals)...])
      switch key {
      case "type": locator.type = value
      case "id": locator.id = value
      case "text": locator.text = value
      case "nth":
        guard let nth = Int(value), nth >= 0 else {
          throw Failure(message: "nth must be a non-negative integer, got `\(value)`")
        }
        locator.nth = nth
      default:
        throw Failure(message: "unknown locator key `\(key)`; accepted: \(accepted)")
      }
    }
    return locator
  }

  /// `TesseraWidgets.ScrollView<Foo>` → `ScrollView`.
  static func baseTypeName(_ viewType: String) -> String {
    let withoutGenerics = viewType.prefix { $0 != "<" }
    return String(withoutGenerics.split(separator: ".").last ?? withoutGenerics)
  }

  /// Screen text inside `frame`, rows joined by newline.
  static func renderedText(in frame: Rect, rows: [String]) -> String {
    var lines: [String] = []
    for row in frame.rowRange where rows.indices.contains(row) {
      let characters = Array(rows[row])
      let lower = max(frame.origin.column, 0)
      let upper = min(frame.maxColumn, characters.count)
      lines.append(lower < upper ? String(characters[lower..<upper]) : "")
    }
    return lines.joined(separator: "\n")
  }

  /// Re-resolves against a fresh projection; `screenRows` are untrimmed screen rows.
  func resolve(in nodes: [NodeDiagnostics], screenRows: [String]) -> Resolution {
    let matches = nodes.filter { node in
      if let type, Self.baseTypeName(node.viewType) != type {
        return false
      }
      if let id, node.identity.description != id {
        return false
      }
      if let text, !Self.renderedText(in: node.frame, rows: screenRows).contains(text) {
        return false
      }
      return true
    }
    if let nth {
      return nth < matches.count ? .node(matches[nth]) : .none
    }
    switch matches.count {
    case 0: return .none
    case 1: return .node(matches[0])
    default: return .ambiguous(matches)
    }
  }
}
