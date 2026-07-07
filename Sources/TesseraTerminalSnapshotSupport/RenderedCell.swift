/// A visible terminal cell reconstructed by the virtual terminal.
public struct RenderedCell: Sendable, Equatable {
  public static let blank = Self(
    character: " ",
    foreground: .default,
    background: .default,
    bold: false,
    dim: false,
    italic: false,
    reverse: false,
    strikethrough: false,
    underline: false,
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
  public let underline: Bool
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
    underline: Bool,
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
    self.underline = underline
    self.hyperlinkURI = hyperlinkURI
  }
}
