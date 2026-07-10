import TesseraTerminalANSI

/// A visible terminal cell reconstructed by the virtual terminal.
public struct RenderedCell: Equatable, Sendable {
  public static let blank = Self(
    character: " ",
    foreground: .default,
    background: .default,
    bold: false,
    dim: false,
    italic: false,
    reverse: false,
    strikethrough: false,
    underlineStyle: .none,
    underlineColor: .default,
    hyperlinkURI: nil
  )

  public let character: Character
  public let foreground: RenderedColor
  public let background: RenderedColor
  public let bold: Bool
  public let dim: Bool
  public let italic: Bool
  public let reverse: Bool
  public let strikethrough: Bool
  public let underlineStyle: UnderlineStyle
  public let underlineColor: RenderedColor
  public let hyperlinkURI: String?

  public init(
    character: Character,
    foreground: RenderedColor,
    background: RenderedColor,
    bold: Bool,
    dim: Bool,
    italic: Bool,
    reverse: Bool,
    strikethrough: Bool,
    underlineStyle: UnderlineStyle = .none,
    underlineColor: RenderedColor = .default,
    hyperlinkURI: String? = nil
  ) {
    self.character = character
    self.foreground = foreground
    self.background = background
    self.bold = bold
    self.dim = dim
    self.italic = italic
    self.reverse = reverse
    self.strikethrough = strikethrough
    self.underlineStyle = underlineStyle
    self.underlineColor = underlineColor
    self.hyperlinkURI = hyperlinkURI
  }
}
