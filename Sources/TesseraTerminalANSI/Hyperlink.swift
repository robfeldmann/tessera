/// Semantic OSC 8 hyperlink metadata.
public struct Hyperlink: Equatable, Hashable, Sendable {
  public enum ValidationError: Error, Equatable, Sendable {
    case emptyURI
    case unsafeURI
    case emptyID
    case unsafeID
  }

  public let uri: String
  public let id: String?

  public init(uri: String, id: String? = nil) throws {
    guard uri.isEmpty == false else {
      throw ValidationError.emptyURI
    }
    guard uri.isOSCHyperlinkSafeURI else {
      throw ValidationError.unsafeURI
    }
    if let id {
      guard id.isEmpty == false else {
        throw ValidationError.emptyID
      }
      guard id.isOSCHyperlinkSafeID else {
        throw ValidationError.unsafeID
      }
    }
    self.uri = uri
    self.id = id
  }
}

extension String {
  fileprivate var isOSCHyperlinkSafeURI: Bool {
    var previousWasEscape = false
    for scalar in unicodeScalars {
      let value = scalar.value
      if value < 0x20 || value == 0x7F {
        return false
      }
      if previousWasEscape, scalar == "\\" {
        return false
      }
      previousWasEscape = value == UInt32(ANSIByteEncoding.escape)
    }
    return true
  }

  fileprivate var isOSCHyperlinkSafeID: Bool {
    unicodeScalars.allSatisfy { scalar in
      let value = scalar.value
      return value >= 0x20 && value != 0x7F && scalar != ";"
    }
  }
}
