/// Fixed colors for one SVG theme.
///
/// The 16 ANSI entries are the only palette values that differ between themes for
/// indexed colors. Indices 16–255 use the xterm cube and grayscale ramp in every theme.
public struct SVGPalette: Equatable, Sendable {
  public let background: SVGColor
  public let foreground: SVGColor
  public let cursor: SVGColor

  /// The xterm 16 colors in index order: black, red, green, yellow, blue, magenta,
  /// cyan, white, then their bright variants.
  public let ansi: [SVGColor]

  public init(
    background: SVGColor,
    foreground: SVGColor,
    cursor: SVGColor,
    ansi: [SVGColor]
  ) {
    precondition(ansi.count == 16, "An SVG palette needs exactly 16 ANSI colors.")
    self.background = background
    self.foreground = foreground
    self.cursor = cursor
    self.ansi = ansi
  }

  /// Light theme with a near-white page and dark text.
  public static let light = SVGPalette(
    background: SVGColor(0xFBFBFA),
    foreground: SVGColor(0x1F2328),
    cursor: SVGColor(0x0969DA),
    ansi: [
      SVGColor(0x24292F), SVGColor(0xCF222E), SVGColor(0x116329), SVGColor(0x4D2D00),
      SVGColor(0x0969DA), SVGColor(0x8250DF), SVGColor(0x1B7C83), SVGColor(0x6E7781),
      SVGColor(0x57606A), SVGColor(0xA40E26), SVGColor(0x1A7F37), SVGColor(0x633C01),
      SVGColor(0x218BFF), SVGColor(0xA475F9), SVGColor(0x3192AA), SVGColor(0x8C959F),
    ]
  )

  /// Dark theme with a near-black page and light text.
  public static let dark = SVGPalette(
    background: SVGColor(0x0D1117),
    foreground: SVGColor(0xE6EDF3),
    cursor: SVGColor(0x58A6FF),
    ansi: [
      SVGColor(0x484F58), SVGColor(0xFF7B72), SVGColor(0x3FB950), SVGColor(0xD29922),
      SVGColor(0x58A6FF), SVGColor(0xBC8CFF), SVGColor(0x39C5CF), SVGColor(0xB1BAC4),
      SVGColor(0x6E7681), SVGColor(0xFFA198), SVGColor(0x56D364), SVGColor(0xE3B341),
      SVGColor(0x79C0FF), SVGColor(0xD2A8FF), SVGColor(0x56D4DD), SVGColor(0xF0F6FC),
    ]
  )
}
