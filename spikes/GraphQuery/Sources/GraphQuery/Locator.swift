import Foundation

/// A conjunction of clauses selecting nodes of a projection.
///
/// Grammar (clauses are whitespace separated and all must hold):
///
/// ```text
/// type=Text            module-free type name, `Module.Type`, the full reflected name, or
///                      a `_LayoutContainer`'s layout name (`type=_FrameLayout`)
/// id=root/index(0)     exact identity path, or a user id: the node's last path
///                      component is `explicit(X)` or `id(X)` and the value is `X`
/// text="Hello"         the node's attributed screen text contains the substring
/// text-exact="Hello"   the attributed text equals the value after trimming whitespace
/// nth=0                zero-based pick among the nodes selected by the other clauses
/// ```
///
/// `nth` applies last whatever its position, mirroring Playwright's `.nth()`.
public struct Locator: Equatable, Sendable {
  public enum Clause: Equatable, Sendable {
    case id(String)
    case text(String)
    case textExact(String)
    case type(String)

    public var description: String {
      switch self {
      case .id(let value): "id=\(Locator.quoted(value))"
      case .text(let value): "text=\(Locator.quoted(value))"
      case .textExact(let value): "text-exact=\(Locator.quoted(value))"
      case .type(let value): "type=\(Locator.quoted(value))"
      }
    }

    public func matches(_ node: Projection.Node) -> Bool {
      switch self {
      case .id(let value):
        return node.path == value || Locator.userID(of: node.path) == value
      case .text(let value):
        return node.text?.contains(value) ?? false
      case .textExact(let value):
        return node.text.map { $0.trimmingWhitespace() == value.trimmingWhitespace() } ?? false
      case .type(let value):
        let base = node.typeName.prefix { $0 != "<" }
        return node.type == value || base == value || node.typeName == value
          || node.layout == value
      }
    }
  }

  public static let acceptedKeys = ["id", "nth", "text", "text-exact", "type"]

  public var clauses: [Clause]
  public var nth: Int?

  public var description: String {
    (clauses.map(\.description) + (nth.map { ["nth=\($0)"] } ?? [])).joined(separator: " ")
  }

  public init(clauses: [Clause], nth: Int? = nil) {
    self.clauses = clauses
    self.nth = nth
  }

  /// Parses one string of whitespace-separated clauses, honouring double quotes.
  public init(parsing source: String) throws {
    try self.init(clauseTexts: try Self.tokenize(source))
  }

  /// Parses one clause per element, as received from a shell argv where each clause is
  /// already a single word, so unquoted values may contain spaces.
  public init(clauseTexts: [String]) throws {
    var clauses: [Clause] = []
    var nth: Int?
    for text in clauseTexts {
      guard let equals = text.firstIndex(of: "=") else {
        throw LocatorError.malformed(text)
      }
      let key = String(text[..<equals])
      let value = Self.unquoted(String(text[text.index(after: equals)...]))
      switch key {
      case "id": clauses.append(.id(value))
      case "text": clauses.append(.text(value))
      case "text-exact": clauses.append(.textExact(value))
      case "type": clauses.append(.type(value))
      case "nth":
        guard let index = Int(value), index >= 0 else {
          throw LocatorError.invalidNth(value)
        }
        nth = index
      default:
        throw LocatorError.unknownKey(key)
      }
    }
    guard !clauses.isEmpty || nth != nil else {
      throw LocatorError.empty
    }
    self.init(clauses: clauses, nth: nth)
  }

  /// Every node selected, in tree (pre-order, paint) order.
  public func resolve(in projection: Projection) -> Resolution {
    var remaining = projection.nodes
    var steps: [Resolution.Step] = []
    for clause in clauses {
      remaining = remaining.filter(clause.matches)
      steps.append(Resolution.Step(clause: clause.description, remaining: remaining.count))
    }
    if let nth {
      remaining = remaining.indices.contains(nth) ? [remaining[nth]] : []
      steps.append(Resolution.Step(clause: "nth=\(nth)", remaining: remaining.count))
    }
    return Resolution(nodes: remaining, steps: steps)
  }

  /// The user-supplied identity of a node: the payload of its last `explicit(…)` or
  /// `id(…)` path component, if any.
  static func userID(of path: String) -> String? {
    guard let last = path.split(separator: "/", omittingEmptySubsequences: false).last else {
      return nil
    }
    for prefix in ["explicit(", "id("] where last.hasPrefix(prefix) && last.hasSuffix(")") {
      return String(last.dropFirst(prefix.count).dropLast())
    }
    return nil
  }

  static func quoted(_ value: String) -> String {
    let needsQuotes = value.isEmpty || value.contains { $0 == " " || $0 == "\"" || $0 == "\n" }
    guard needsQuotes else {
      return value
    }
    let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escaped)\""
  }

  private static func unquoted(_ value: String) -> String {
    guard value.count >= 2, value.first == "\"", value.last == "\"" else {
      return value
    }
    var result = ""
    var escaping = false
    for character in value.dropFirst().dropLast() {
      if escaping {
        result.append(character == "n" ? "\n" : character)
        escaping = false
      } else if character == "\\" {
        escaping = true
      } else {
        result.append(character)
      }
    }
    return result
  }

  private static func tokenize(_ source: String) throws -> [String] {
    var tokens: [String] = []
    var current = ""
    var inQuotes = false
    var escaping = false
    for character in source {
      if escaping {
        current.append(character)
        escaping = false
      } else if inQuotes && character == "\\" {
        current.append(character)
        escaping = true
      } else if character == "\"" {
        inQuotes.toggle()
        current.append(character)
      } else if character == " " && !inQuotes {
        if !current.isEmpty { tokens.append(current) }
        current = ""
      } else {
        current.append(character)
      }
    }
    guard !inQuotes else {
      throw LocatorError.unterminatedQuote(source)
    }
    if !current.isEmpty { tokens.append(current) }
    return tokens
  }

  /// The nodes a locator selected and how each clause narrowed the candidates.
  public struct Resolution: Equatable, Sendable {
    public struct Step: Codable, Equatable, Sendable {
      public var clause: String
      public var remaining: Int
    }

    public var nodes: [Projection.Node]
    public var steps: [Step]
  }
}

public enum LocatorError: CustomStringConvertible, Equatable, Error {
  case empty
  case invalidNth(String)
  case malformed(String)
  case unknownKey(String)
  case unterminatedQuote(String)

  public var description: String {
    switch self {
    case .empty:
      "empty locator; accepted keys: \(Locator.acceptedKeys.joined(separator: ", "))"
    case .invalidNth(let value):
      "nth must be a nonnegative integer, got `\(value)`"
    case .malformed(let text):
      "expected key=value, got `\(text)`"
    case .unknownKey(let key):
      "unknown locator key `\(key)`; accepted keys: \(Locator.acceptedKeys.joined(separator: ", "))"
    case .unterminatedQuote(let text):
      "unterminated quote in `\(text)`"
    }
  }
}

extension String {
  func trimmingWhitespace() -> String {
    var scalars = Substring(self)
    while scalars.first?.isWhitespace == true { scalars.removeFirst() }
    while scalars.last?.isWhitespace == true { scalars.removeLast() }
    return String(scalars)
  }
}
