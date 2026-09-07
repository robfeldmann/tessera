import TesseraTerminalANSI

private struct ExplicitAttributes: Equatable, OptionSet, Sendable {
  static let foreground = Self(rawValue: 1 << 0)
  static let background = Self(rawValue: 1 << 1)
  static let bold = Self(rawValue: 1 << 2)
  static let dim = Self(rawValue: 1 << 3)
  static let italic = Self(rawValue: 1 << 4)
  static let reverse = Self(rawValue: 1 << 5)
  static let strikethrough = Self(rawValue: 1 << 6)
  static let underlineStyle = Self(rawValue: 1 << 7)
  static let underlineColor = Self(rawValue: 1 << 8)
  static let hyperlink = Self(rawValue: 1 << 9)
  static let textAttributes: Self = [.bold, .dim, .italic, .reverse, .strikethrough]
  static let all = Self(rawValue: (1 << 10) - 1)

  let rawValue: UInt16
}

/// Display attributes for a terminal cell.
///
/// Style is limited to SGR attributes already represented by
/// `TesseraTerminalANSI.ControlSequence`, allowing the damage renderer to replay a complete
/// style at the start of any changed run.
public struct Style: Equatable, Sendable {
  private static var terminalDefaults: Self {
    var result = Self()
    result.explicitAttributes = .all
    return result
  }

  /// The text foreground color.
  public var foreground: Color {
    didSet { explicitAttributes.insert(.foreground) }
  }
  /// The text background color.
  public var background: Color {
    didSet { explicitAttributes.insert(.background) }
  }
  /// The non-underline ECMA-48 text attributes.
  public var attributes: TextAttributes {
    didSet { explicitAttributes.formUnion(.textAttributes) }
  }

  /// The semantic underline style, independent of `attributes`.
  public var underlineStyle: UnderlineStyle {
    didSet { explicitAttributes.insert(.underlineStyle) }
  }
  /// The underline color; `.default` resets it to the terminal default.
  public var underlineColor: Color {
    didSet { explicitAttributes.insert(.underlineColor) }
  }

  /// The optional OSC 8 hyperlink associated with the cell text.
  public var hyperlink: Hyperlink? {
    didSet { explicitAttributes.insert(.hyperlink) }
  }

  private var explicitAttributes: ExplicitAttributes

  package var _resolved: Self {
    Self.terminalDefaults._merging(self)
  }

  package var _rendered: Self {
    var result = self
    result.explicitAttributes = []
    return result
  }

  /// Creates a style whose supplied arguments override inherited attributes.
  ///
  /// Omitted arguments remain inheritable. Passing a non-`nil` default value explicitly,
  /// including an empty attribute set, records an explicit reset. Use ``link(_:)`` with
  /// `nil` to clear an inherited hyperlink; a `nil` initializer argument remains inheritable.
  public init(
    foreground: Color? = nil,
    background: Color? = nil,
    attributes: TextAttributes? = nil,
    underlineStyle: UnderlineStyle? = nil,
    underlineColor: Color? = nil,
    hyperlink: Hyperlink? = nil
  ) {
    self.foreground = foreground ?? .default
    self.background = background ?? .default
    self.attributes = attributes ?? []
    self.underlineStyle = underlineStyle ?? .none
    self.underlineColor = underlineColor ?? .default
    self.hyperlink = hyperlink

    var explicit: ExplicitAttributes = []
    if foreground != nil {
      explicit.insert(.foreground)
    }
    if background != nil {
      explicit.insert(.background)
    }
    if attributes != nil {
      explicit.formUnion(.textAttributes)
    }
    if underlineStyle != nil {
      explicit.insert(.underlineStyle)
    }
    if underlineColor != nil {
      explicit.insert(.underlineColor)
    }
    if hyperlink != nil {
      explicit.insert(.hyperlink)
    }
    explicitAttributes = explicit
  }

  /// Returns a copy with an explicit foreground override.
  public func foreground(_ color: Color) -> Self {
    setting(\.foreground, to: color)
  }

  /// Returns a copy with an explicit background override.
  public func background(_ color: Color) -> Self {
    setting(\.background, to: color)
  }

  /// Returns a copy with bold explicitly enabled or disabled.
  public func bold(_ on: Bool = true) -> Self {
    setting(.bold, explicit: .bold, to: on)
  }

  /// Returns a copy with dim explicitly enabled or disabled.
  public func dim(_ on: Bool = true) -> Self {
    setting(.dim, explicit: .dim, to: on)
  }

  /// Returns a copy with italic explicitly enabled or disabled.
  public func italic(_ on: Bool = true) -> Self {
    setting(.italic, explicit: .italic, to: on)
  }

  /// Returns a copy with reverse video explicitly enabled or disabled.
  public func reverse(_ on: Bool = true) -> Self {
    setting(.reverse, explicit: .reverse, to: on)
  }

  /// Returns a copy with strikethrough explicitly enabled or disabled.
  public func strikethrough(_ on: Bool = true) -> Self {
    setting(.strikethrough, explicit: .strikethrough, to: on)
  }

  /// Returns a copy with single underline explicitly enabled or disabled.
  public func underline(_ on: Bool = true) -> Self {
    setting(\.underlineStyle, to: on ? .single : .none)
  }

  /// Returns a copy with an explicit underline color.
  public func underlineColor(_ color: Color) -> Self {
    setting(\.underlineColor, to: color)
  }

  /// Returns a copy with an explicit hyperlink, or with hyperlinks explicitly cleared.
  public func link(_ hyperlink: Hyperlink?) -> Self {
    setting(\.hyperlink, to: hyperlink)
  }

  package func _merging(_ overlay: Self) -> Self {
    var result = self

    if overlay.explicitAttributes.contains(.foreground) {
      result.foreground = overlay.foreground
    }
    if overlay.explicitAttributes.contains(.background) {
      result.background = overlay.background
    }
    result.mergeTextAttribute(.bold, explicit: .bold, from: overlay)
    result.mergeTextAttribute(.dim, explicit: .dim, from: overlay)
    result.mergeTextAttribute(.italic, explicit: .italic, from: overlay)
    result.mergeTextAttribute(.reverse, explicit: .reverse, from: overlay)
    result.mergeTextAttribute(.strikethrough, explicit: .strikethrough, from: overlay)
    if overlay.explicitAttributes.contains(.underlineStyle) {
      result.underlineStyle = overlay.underlineStyle
    }
    if overlay.explicitAttributes.contains(.underlineColor) {
      result.underlineColor = overlay.underlineColor
    }
    if overlay.explicitAttributes.contains(.hyperlink) {
      result.hyperlink = overlay.hyperlink
    }

    result.explicitAttributes.formUnion(overlay.explicitAttributes)
    return result
  }

  private func setting<Value>(
    _ keyPath: WritableKeyPath<Self, Value>,
    to value: Value
  ) -> Self {
    var result = self
    result[keyPath: keyPath] = value
    return result
  }

  private func setting(
    _ attribute: TextAttributes,
    explicit: ExplicitAttributes,
    to on: Bool
  ) -> Self {
    var result = self
    let previousExplicit = result.explicitAttributes
    if on {
      result.attributes.insert(attribute)
    } else {
      result.attributes.remove(attribute)
    }
    result.explicitAttributes = previousExplicit.union(explicit)
    return result
  }

  private mutating func mergeTextAttribute(
    _ attribute: TextAttributes,
    explicit: ExplicitAttributes,
    from overlay: Self
  ) {
    guard overlay.explicitAttributes.contains(explicit) else {
      return
    }

    let previousExplicit = explicitAttributes
    if overlay.attributes.contains(attribute) {
      attributes.insert(attribute)
    } else {
      attributes.remove(attribute)
    }
    explicitAttributes = previousExplicit.union(explicit)
  }
}

extension Style {
  /// The color type used by foreground, background, and underline channels.
  public typealias ColorValue = Color
}

/// ECMA-48 SGR text attributes Tessera can currently encode.
public struct TextAttributes: Equatable, OptionSet, Sendable {
  public static let bold = Self(rawValue: 1 << 0)
  public static let dim = Self(rawValue: 1 << 1)
  public static let italic = Self(rawValue: 1 << 2)
  public static let reverse = Self(rawValue: 1 << 3)
  public static let strikethrough = Self(rawValue: 1 << 4)

  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}
