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

  /// ECMA-48 SGR parameters for setting this value as the foreground color.
  ///
  /// The default foreground is SGR 39. Named 16-color ANSI values use SGR 30-37
  /// and 90-97. Indexed and truecolor values use the extended SGR color forms
  /// `38;5;n` and `38;2;r;g;b`.
  var foregroundSGRParameters: [Int] {
    switch self {
    case .ansi(let color):
      [color.foregroundSGRParameter]
    case .default:
      [39]
    case .indexed(let index):
      [38, 5, Int(index)]
    case let .rgb(red, green, blue):
      [38, 2, Int(red), Int(green), Int(blue)]
    }
  }

  /// ECMA-48 SGR parameters for setting this value as the background color.
  ///
  /// The default background is SGR 49. Named 16-color ANSI values use SGR 40-47
  /// and 100-107. Indexed and truecolor values use the extended SGR color forms
  /// `48;5;n` and `48;2;r;g;b`.
  var backgroundSGRParameters: [Int] {
    switch self {
    case .ansi(let color):
      [color.backgroundSGRParameter]
    case .default:
      [49]
    case .indexed(let index):
      [48, 5, Int(index)]
    case let .rgb(red, green, blue):
      [48, 2, Int(red), Int(green), Int(blue)]
    }
  }
}
