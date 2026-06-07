/// A visible terminal cell reconstructed by the virtual terminal.
public struct RenderedCell: Sendable, Equatable {
  public static let blank = Self(
    character: " ",
    foreground: .default,
    background: .default,
    bold: false,
    italic: false,
    underline: false,
    reverse: false
  )

  public let character: Character
  public let foreground: RenderedColor
  public let background: RenderedColor
  public let bold: Bool
  public let italic: Bool
  public let underline: Bool
  public let reverse: Bool

  public init(
    character: Character,
    foreground: RenderedColor,
    background: RenderedColor,
    bold: Bool,
    italic: Bool,
    underline: Bool,
    reverse: Bool
  ) {
    self.character = character
    self.foreground = foreground
    self.background = background
    self.bold = bold
    self.italic = italic
    self.underline = underline
    self.reverse = reverse
  }
}
