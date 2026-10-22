import Foundation

/// A dynamically typed JSON value used for generic field-level diffs and reports.
public enum JSONValue: Codable, Equatable, Sendable {
  case array([JSONValue])
  case bool(Bool)
  case int(Int)
  case null
  case object([String: JSONValue])
  case string(String)

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
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
    case .int(let value): try container.encode(value)
    case .null: try container.encodeNil()
    case .object(let value): try container.encode(value)
    case .string(let value): try container.encode(value)
    }
  }

  /// The value of `key` when this is an object.
  public subscript(key: String) -> JSONValue? {
    guard case .object(let object) = self else {
      return nil
    }
    return object[key]
  }

  /// Converts any `Encodable` value to a `JSONValue` by a JSON round trip.
  public init(encoding value: some Encodable) throws {
    let data = try JSONEncoder().encode(value)
    self = try JSONDecoder().decode(JSONValue.self, from: data)
  }

  /// Serialises with sorted keys and no insignificant whitespace.
  public func compactString() -> String {
    String(decoding: (try? Self.encoder(pretty: false).encode(self)) ?? Data(), as: UTF8.self)
  }

  /// Serialises with sorted keys and two-space indentation.
  public func prettyString() -> String {
    String(decoding: (try? Self.encoder(pretty: true).encode(self)) ?? Data(), as: UTF8.self)
  }

  static func encoder(pretty: Bool) -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = pretty
      ? [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
      : [.sortedKeys, .withoutEscapingSlashes]
    return encoder
  }
}
