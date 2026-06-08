/// A terminal color in one of ANSI's supported color spaces.
public enum Color: Equatable, Sendable {
  /// The terminal's default foreground or background color.
  case `default`

  /// One of the named 16 ANSI colors.
  case ansi(ANSIColor)

  /// A 256-color palette index.
  case indexed(UInt8)

  /// A 24-bit truecolor value.
  case rgb(UInt8, UInt8, UInt8)
}
