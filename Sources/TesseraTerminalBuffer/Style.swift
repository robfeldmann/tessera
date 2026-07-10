import TesseraTerminalANSI

/// Display attributes for a terminal cell.
///
/// Phase 2 Slice 4 keeps style limited to SGR attributes already represented by
/// `TesseraTerminalANSI.ControlSequence`, so the damage renderer can replay a complete
/// style at the start of any changed run.
public struct Style: Equatable, Sendable {
  /// The text foreground color.
  public var foreground: Color
  /// The text background color.
  public var background: Color
  /// The non-underline ECMA-48 text attributes.
  public var attributes: TextAttributes

  /// The semantic underline style, independent of `attributes`.
  public var underlineStyle: UnderlineStyle
  /// The underline color; `.default` resets it to the terminal default.
  public var underlineColor: Color

  /// The optional OSC 8 hyperlink associated with the cell text.
  public var hyperlink: Hyperlink?

  /// Creates a cell style with independently configurable text and underline styling.
  public init(
    foreground: Color = .default,
    background: Color = .default,
    attributes: TextAttributes = [],
    underlineStyle: UnderlineStyle = .none,
    underlineColor: Color = .default,
    hyperlink: Hyperlink? = nil
  ) {
    self.foreground = foreground
    self.background = background
    self.attributes = attributes
    self.underlineStyle = underlineStyle
    self.underlineColor = underlineColor
    self.hyperlink = hyperlink
  }
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
