import Foundation

/// A minimal JSON document model so protocol replies stay `Sendable` and key-sorted.
public enum JSONValue: Equatable, Sendable {
  case array([JSONValue])
  case bool(Bool)
  case double(Double)
  case int(Int)
  case null
  case object([String: JSONValue])
  case string(String)

  /// The object member named `key`, when this value is an object.
  public subscript(key: String) -> JSONValue? {
    guard case .object(let members) = self else {
      return nil
    }
    return members[key]
  }

  /// The string payload, when this value is a string.
  public var stringValue: String? {
    guard case .string(let value) = self else {
      return nil
    }
    return value
  }

  /// Decodes one JSON document.
  public static func parse(_ text: String) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
  }

  /// Encodes as a single line of key-sorted JSON.
  public var line: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(self) else {
      return #"{"error":"reply could not be encoded","ok":false}"#
    }
    return String(decoding: data, as: UTF8.self)
  }
}

extension JSONValue: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else if let value = try? container.decode(Double.self) {
      self = .double(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else {
      self = .object(try container.decode([String: JSONValue].self))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .array(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .double(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .object(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    }
  }
}
