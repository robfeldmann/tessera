import Foundation

/// An OSC 52 clipboard selection target (`Pc`).
public enum ClipboardTarget: Equatable, Hashable, Sendable {
  case clipboard
  case cutBuffer(UInt8)
  case primary
  case secondary
  case select
}

extension ClipboardTarget {
  /// The single OSC 52 `Pc` character for this target.
  var pcCharacter: String {
    switch self {
    case .clipboard:
      "c"
    case .cutBuffer(let buffer):
      String(buffer)
    case .primary:
      "p"
    case .secondary:
      "q"
    case .select:
      "s"
    }
  }
}

/// An ordered, validated OSC 52 selection. Order is observable.
public struct ClipboardSelection: Equatable, Hashable, Sendable {
  public static let clipboard = Self(unchecked: [.clipboard])
  public static let clipboardAndPrimary = Self(unchecked: [.clipboard, .primary])
  public static let primary = Self(unchecked: [.primary])

  public let targets: [ClipboardTarget]

  /// Fails for empty lists, duplicate targets, or cutBuffer values greater than 7.
  public init?(_ targets: [ClipboardTarget]) {
    guard targets.isEmpty == false else {
      return nil
    }
    guard Set(targets).count == targets.count else {
      return nil
    }
    guard targets.allSatisfy(\.isValidClipboardTarget) else {
      return nil
    }
    self.init(unchecked: targets)
  }

  private init(unchecked targets: [ClipboardTarget]) {
    self.targets = targets
  }
}

/// A safe OSC 52 clipboard write. The encoder owns base64 so payload data can never
/// escape the OSC body unencoded.
public struct ClipboardWrite: Equatable, Sendable {
  public let selection: ClipboardSelection
  public let bytes: [UInt8]

  public init(selection: ClipboardSelection = .clipboard, bytes: [UInt8]) {
    self.selection = selection
    self.bytes = bytes
  }

  public init(selection: ClipboardSelection = .clipboard, text: String) {
    self.init(selection: selection, bytes: Array(text.utf8))
  }
}

extension ClipboardWrite {
  /// The OSC body `52;<Pc>;<RFC4648-base64>` (no introducer/terminator).
  var oscBody: String {
    let pc = selection.targets.map(\.pcCharacter).joined()
    let base64 = Data(bytes).base64EncodedString()
    return "52;\(pc);\(base64)"
  }
}

extension ClipboardTarget {
  fileprivate var isValidClipboardTarget: Bool {
    switch self {
    case .clipboard, .primary, .secondary, .select:
      true
    case .cutBuffer(let buffer):
      buffer <= 7
    }
  }
}
