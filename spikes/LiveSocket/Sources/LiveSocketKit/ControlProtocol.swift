import Foundation
import Tessera

/// A failure the control protocol reports to the client as `{"ok":false,"error":...}`.
public struct ControlError: Error, Equatable, Sendable {
  public let message: String

  public init(_ message: String) {
    self.message = message
  }
}

/// One decoded control request.
public enum ControlOperation: Equatable, Sendable {
  /// Injects a key through the same step path as terminal input.
  case key(Key, name: String)

  /// Exits the app and removes the socket.
  case quit

  /// Returns the current screen.
  case text

  /// Returns the diagnostics projection.
  case tree
}

/// NDJSON request decoding and reply envelopes (investigation 037 §5).
public enum ControlProtocol {
  public static let operationNames = ["key", "quit", "text", "tree"]

  /// Decodes one request line.
  public static func decode(_ line: String) -> Result<ControlOperation, ControlError> {
    let document: JSONValue
    do {
      document = try JSONValue.parse(line)
    } catch {
      return .failure(ControlError("request is not valid JSON"))
    }
    guard case .object = document else {
      return .failure(ControlError("request must be a JSON object with an \"op\" member"))
    }
    guard let name = document["op"]?.stringValue else {
      return .failure(ControlError("missing \"op\" (ops: \(operationNames.joined(separator: ", ")))"))
    }

    switch name {
    case "text":
      return .success(.text)
    case "tree":
      return .success(.tree)
    case "quit":
      return .success(.quit)
    case "key":
      guard let keyName = document["key"]?.stringValue else {
        return .failure(ControlError("op \"key\" needs a \"key\" string such as \"Tab\""))
      }
      return KeyNames.parse(keyName).map { .key($0, name: keyName) }
    default:
      return .failure(
        ControlError(
          "unknown op \"\(name)\" (ops: \(operationNames.joined(separator: ", ")))"
        )
      )
    }
  }

  /// Formats a success reply line.
  public static func success(_ members: [String: JSONValue] = [:]) -> String {
    var members = members
    members["ok"] = .bool(true)
    return JSONValue.object(members).line
  }

  /// Formats a failure reply line.
  public static func failure(_ message: String) -> String {
    JSONValue.object(["error": .string(message), "ok": .bool(false)]).line
  }
}

/// Playwright-style key names, mapped to the values `InputParser` produces for real input.
public enum KeyNames {
  private static let named: [(String, KeyCode)] = [
    ("ArrowDown", .down),
    ("ArrowLeft", .left),
    ("ArrowRight", .right),
    ("ArrowUp", .up),
    ("Backspace", .backspace),
    ("Delete", .delete),
    ("End", .end),
    ("Enter", .enter),
    ("Escape", .escape),
    ("Home", .home),
    ("Insert", .insert),
    ("PageDown", .pageDown),
    ("PageUp", .pageUp),
    ("Space", .character(" ")),
    ("Tab", .tab),
  ]

  private static let modifiers: [(String, Modifiers)] = [
    ("alt", .alt),
    ("cmd", .meta),
    ("command", .meta),
    ("control", .control),
    ("ctrl", .control),
    ("meta", .meta),
    ("option", .alt),
    ("shift", .shift),
    ("super", .super),
  ]

  /// Every accepted key name, for error messages.
  public static var accepted: String {
    let names = named.map(\.0) + ["F1-F12", "a single character"]
    return names.joined(separator: ", ")
      + "; prefix with Shift+, Ctrl+, Alt+, Meta+ or Super+"
  }

  /// Parses `Ctrl+C`, `Shift+Tab`, `ArrowLeft`, `F5`, `q`, `+`.
  public static func parse(_ text: String) -> Result<Key, ControlError> {
    var remainder = Substring(text)
    var active: Modifiers = []
    while let plus = remainder.firstIndex(of: "+"), plus != remainder.startIndex,
      remainder.index(after: plus) != remainder.endIndex
    {
      let prefix = remainder[..<plus].lowercased()
      guard let match = modifiers.first(where: { $0.0 == prefix }) else {
        break
      }
      active.insert(match.1)
      remainder = remainder[remainder.index(after: plus)...]
    }

    let name = String(remainder)
    if let match = named.first(where: { $0.0.lowercased() == name.lowercased() }) {
      return .success(Key(code: match.1, modifiers: active))
    }
    if name.count > 1, name.first == "F" || name.first == "f", let number = Int(name.dropFirst()),
      (1...12).contains(number)
    {
      return .success(Key(code: .function(number), modifiers: active))
    }
    if name.count == 1, let character = name.first {
      return .success(Key(code: .character(character), modifiers: active))
    }
    return .failure(ControlError("unknown key \"\(text)\" (names: \(accepted))"))
  }
}

extension KeyNames {
  /// The canonical name for `key`, such as `Shift+Tab` or `ArrowLeft`.
  public static func describe(_ key: Key) -> String {
    var parts: [String] = []
    for (name, modifier) in [("Shift", Modifiers.shift), ("Ctrl", .control), ("Alt", .alt),
      ("Meta", .meta), ("Super", .super)] where key.modifiers.contains(modifier)
    {
      parts.append(name)
    }
    switch key.code {
    case .character(let character):
      parts.append(character == " " ? "Space" : String(character))
    case .function(let number):
      parts.append("F\(number)")
    default:
      parts.append(named.first { $0.1 == key.code }?.0 ?? "\(key.code)")
    }
    return parts.joined(separator: "+")
  }
}
