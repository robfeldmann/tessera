/// A named 16-color ANSI palette entry.
public enum ANSIColor: CaseIterable, Equatable, Sendable {
  case black
  case blue
  case brightBlack
  case brightBlue
  case brightCyan
  case brightGreen
  case brightMagenta
  case brightRed
  case brightWhite
  case brightYellow
  case cyan
  case green
  case magenta
  case red
  case white
  case yellow

  /// The conventional xterm palette index for this named ANSI color.
  var ansiPaletteIndex: Int {
    switch self {
    case .black:
      0
    case .blue:
      4
    case .brightBlack:
      8
    case .brightBlue:
      12
    case .brightCyan:
      14
    case .brightGreen:
      10
    case .brightMagenta:
      13
    case .brightRed:
      9
    case .brightWhite:
      15
    case .brightYellow:
      11
    case .cyan:
      6
    case .green:
      2
    case .magenta:
      5
    case .red:
      1
    case .white:
      7
    case .yellow:
      3
    }
  }

  /// The ECMA-48 SGR foreground parameter for this 16-color ANSI palette entry.
  var foregroundSGRParameter: Int {
    switch self {
    case .black:
      30
    case .blue:
      34
    case .brightBlack:
      90
    case .brightBlue:
      94
    case .brightCyan:
      96
    case .brightGreen:
      92
    case .brightMagenta:
      95
    case .brightRed:
      91
    case .brightWhite:
      97
    case .brightYellow:
      93
    case .cyan:
      36
    case .green:
      32
    case .magenta:
      35
    case .red:
      31
    case .white:
      37
    case .yellow:
      33
    }
  }

  /// The ECMA-48 SGR background parameter for this 16-color ANSI palette entry.
  var backgroundSGRParameter: Int {
    switch self {
    case .black:
      40
    case .blue:
      44
    case .brightBlack:
      100
    case .brightBlue:
      104
    case .brightCyan:
      106
    case .brightGreen:
      102
    case .brightMagenta:
      105
    case .brightRed:
      101
    case .brightWhite:
      107
    case .brightYellow:
      103
    case .cyan:
      46
    case .green:
      42
    case .magenta:
      45
    case .red:
      41
    case .white:
      47
    case .yellow:
      43
    }
  }
}
