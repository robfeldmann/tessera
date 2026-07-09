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
    case .rgb(let red, let green, let blue):
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
    case .rgb(let red, let green, let blue):
      [48, 2, Int(red), Int(green), Int(blue)]
    }
  }
}

extension Color {
  /// The representable form of this color under `capability`, still a `Color`.
  /// `.default` is preserved under every capability.
  package func resolved(for capability: ColorCapability) -> Color {
    switch capability {
    case .truecolor:
      return self
    case .indexed256:
      return resolvedForIndexed256()
    case .ansi16, .unknown:
      return resolvedForANSI16()
    case .noColor:
      return .default
    }
  }

  private func resolvedForIndexed256() -> Color {
    switch self {
    case .default, .ansi, .indexed:
      return self
    case .rgb(let red, let green, let blue):
      return .indexed(nearestXterm256Index(red: red, green: green, blue: blue))
    }
  }

  private func resolvedForANSI16() -> Color {
    switch self {
    case .ansi, .default:
      return self
    case .indexed(let index):
      return .ansi(ansiColor(forXterm256Index: index))
    case .rgb(let red, let green, let blue):
      return .ansi(nearestANSIColor(red: red, green: green, blue: blue))
    }
  }
}

private func nearestXterm256Index(red: UInt8, green: UInt8, blue: UInt8) -> UInt8 {
  var bestIndex = UInt8(16)
  var bestDistance = Int.max

  for index in UInt8(16)...UInt8.max {
    let candidate = rgbForXterm256Index(index)
    let distance = squaredDistance(
      red,
      green,
      blue,
      candidate.red,
      candidate.green,
      candidate.blue
    )
    if distance < bestDistance {
      bestDistance = distance
      bestIndex = index
    }
  }

  return bestIndex
}

private func ansiColor(forXterm256Index index: UInt8) -> ANSIColor {
  if index < 16 {
    return ansiColorByXtermSystemIndex[Int(index)]
  }

  let rgb = rgbForXterm256Index(index)
  return nearestANSIColor(red: rgb.red, green: rgb.green, blue: rgb.blue)
}

private func nearestANSIColor(red: UInt8, green: UInt8, blue: UInt8) -> ANSIColor {
  var best = ansi16Palette[0]
  var bestDistance = Int.max

  for candidate in ansi16Palette {
    let distance = squaredDistance(
      red,
      green,
      blue,
      candidate.red,
      candidate.green,
      candidate.blue
    )
    if distance < bestDistance {
      bestDistance = distance
      best = candidate
    }
  }

  return best.color
}

private func rgbForXterm256Index(
  _ index: UInt8
) -> (red: UInt8, green: UInt8, blue: UInt8) {
  if index >= 232 {
    let value = UInt8(8 + 10 * (Int(index) - 232))
    return (value, value, value)
  }

  if index >= 16 {
    let cubeIndex = Int(index) - 16
    let red = xtermColorCubeComponent(cubeIndex / 36)
    let green = xtermColorCubeComponent((cubeIndex / 6) % 6)
    let blue = xtermColorCubeComponent(cubeIndex % 6)
    return (red, green, blue)
  }

  let color = ansi16Palette[Int(index)]
  return (color.red, color.green, color.blue)
}

private func xtermColorCubeComponent(_ index: Int) -> UInt8 {
  switch index {
  case 0:
    return 0
  case 1:
    return 95
  case 2:
    return 135
  case 3:
    return 175
  case 4:
    return 215
  default:
    return 255
  }
}

private func squaredDistance(
  _ leftRed: UInt8,
  _ leftGreen: UInt8,
  _ leftBlue: UInt8,
  _ rightRed: UInt8,
  _ rightGreen: UInt8,
  _ rightBlue: UInt8
) -> Int {
  let red = Int(leftRed) - Int(rightRed)
  let green = Int(leftGreen) - Int(rightGreen)
  let blue = Int(leftBlue) - Int(rightBlue)
  return red * red + green * green + blue * blue
}

private let ansiColorByXtermSystemIndex: [ANSIColor] = [
  .black,
  .red,
  .green,
  .yellow,
  .blue,
  .magenta,
  .cyan,
  .white,
  .brightBlack,
  .brightRed,
  .brightGreen,
  .brightYellow,
  .brightBlue,
  .brightMagenta,
  .brightCyan,
  .brightWhite,
]

private let ansi16Palette: [(color: ANSIColor, red: UInt8, green: UInt8, blue: UInt8)] = [
  (.black, 0x00, 0x00, 0x00),
  (.red, 0xCD, 0x00, 0x00),
  (.green, 0x00, 0xCD, 0x00),
  (.yellow, 0xCD, 0xCD, 0x00),
  (.blue, 0x00, 0x00, 0xEE),
  (.magenta, 0xCD, 0x00, 0xCD),
  (.cyan, 0x00, 0xCD, 0xCD),
  (.white, 0xE5, 0xE5, 0xE5),
  (.brightBlack, 0x7F, 0x7F, 0x7F),
  (.brightRed, 0xFF, 0x00, 0x00),
  (.brightGreen, 0x00, 0xFF, 0x00),
  (.brightYellow, 0xFF, 0xFF, 0x00),
  (.brightBlue, 0x5C, 0x5C, 0xFF),
  (.brightMagenta, 0xFF, 0x00, 0xFF),
  (.brightCyan, 0x00, 0xFF, 0xFF),
  (.brightWhite, 0xFF, 0xFF, 0xFF),
]
