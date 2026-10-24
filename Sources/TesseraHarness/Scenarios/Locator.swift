/// `key=value` node selector: `type=Text id=root/index(1) text="Submit" nth=2`.
///
/// A selector addresses nodes by meaning and is re-resolved against a fresh ``Projection`` at
/// every statement. Every key filters; `nth` then picks one match by zero-based position in tree
/// order. Without `nth` the selector must match exactly one node, and a selector that matches
/// nothing is an error, never an empty result.
package struct Locator: Equatable, Sendable {
  struct Failure: Error {
    var message: String
  }

  enum Resolution {
    case node(Projection.Node)
    case none
    case ambiguous([Projection.Node])
  }

  static let accepted = "type, layout, id, text, nth"

  package var type: String?
  package var layout: String?
  package var id: String?
  package var text: String?
  package var nth: Int?

  var description: String {
    var terms: [String] = []
    if let type { terms.append("type=\(type)") }
    if let layout { terms.append("layout=\(layout)") }
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
      // An empty `text=` would match every leaf that shows anything, and an empty `type=`,
      // `layout=`, or `id=` nothing at all; either is a mistake in the scenario, not a query.
      if value.isEmpty, ["type", "layout", "id", "text"].contains(key) {
        throw Failure(message: "locator key `\(key)` needs a value that is not empty")
      }
      switch key {
      case "type": locator.type = value
      case "layout": locator.layout = value
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

  /// The identity path component that names a node by what the app wrote: `explicit(X)` for a
  /// `.id(X)` modifier and `id(X)` for a `ForEach` key. `nil` for a positional component such as
  /// `index(2)`.
  static func userID(ofPath path: String) -> String? {
    guard let last = path.split(separator: "/", omittingEmptySubsequences: true).last
    else {
      return nil
    }
    for prefix in ["explicit(", "id("] where last.hasPrefix(prefix) && last.hasSuffix(")")
    {
      return String(last.dropFirst(prefix.count).dropLast())
    }
    return nil
  }

  /// Re-resolves against a fresh projection.
  ///
  /// - `type` is the short type name (`Text`, `_LayoutContainer`), `layout` the short name of a
  ///   `_LayoutContainer`'s algorithm (`_FrameLayout`, `_PaddingLayout`).
  /// - `id` is a node's full identity path, or the id the app gave it: the `X` of `.id(X)` or of
  ///   a `ForEach` key.
  /// - `text` is a substring of the text the node's own cells show, so a container has none and
  ///   text that another node paints over does not match: `text="atus"` finds `status` under
  ///   `OK`, whose own cells show only `atus`, and `text="OKatus"` finds nothing.
  func resolve(in projection: Projection) -> Resolution {
    let matches = projection.nodes.filter { node in
      if let type, node.type != type {
        return false
      }
      if let layout, node.layout != layout {
        return false
      }
      if let id, node.path != id, Self.userID(ofPath: node.path) != id {
        return false
      }
      if let text, node.text?.contains(text) != true {
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
