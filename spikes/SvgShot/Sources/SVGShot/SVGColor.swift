/// An opaque 24-bit color written to SVG as lowercase `#rrggbb`.
public struct SVGColor: Equatable, Sendable {
  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8

  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  /// Creates a color from a packed `0xRRGGBB` literal.
  public init(_ rgb: UInt32) {
    self.init(
      red: UInt8(truncatingIfNeeded: rgb >> 16),
      green: UInt8(truncatingIfNeeded: rgb >> 8),
      blue: UInt8(truncatingIfNeeded: rgb)
    )
  }

  /// The SVG paint value for this color.
  public var hex: String {
    "#" + [red, green, blue].map(Self.hexDigits).joined()
  }

  /// The midpoint between this color and `other`, computed in integer channels.
  func midpoint(with other: SVGColor) -> SVGColor {
    SVGColor(
      red: UInt8((Int(red) + Int(other.red)) / 2),
      green: UInt8((Int(green) + Int(other.green)) / 2),
      blue: UInt8((Int(blue) + Int(other.blue)) / 2)
    )
  }

  private static func hexDigits(_ value: UInt8) -> String {
    let digits = Array("0123456789abcdef")
    return String([digits[Int(value >> 4)], digits[Int(value & 0x0F)]])
  }
}
