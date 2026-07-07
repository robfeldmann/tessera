import TesseraTerminalANSI

/// Display attributes for a terminal cell.
///
/// Phase 2 Slice 4 keeps style limited to SGR attributes already represented by
/// `TesseraTerminalANSI.ControlSequence`, so the damage renderer can replay a complete
/// style at the start of any changed run.
public struct Style: Equatable, Sendable {
  public var foreground: Color
  public var background: Color
  public var attributes: TextAttributes

  public var hyperlink: Hyperlink?

  public init(
    foreground: Color = .default,
    background: Color = .default,
    attributes: TextAttributes = [],
    hyperlink: Hyperlink? = nil
  ) {
    self.foreground = foreground
    self.background = background
    self.attributes = attributes
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
  public static let underline = Self(rawValue: 1 << 5)

  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }
}
