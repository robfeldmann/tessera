/// A semantic DECSCUSR cursor shape.
///
/// In `CursorStyle`, `nil` shape means leave the cursor shape untouched.
/// `defaultUserShape` is an explicit DECSCUSR 0 request and is not the same as `nil`.
/// Cases are declared alphabetically; the ANSI encoder assigns the DECSCUSR value.
public enum CursorShape: Equatable, Hashable, Sendable {
  case blinkingBar
  case blinkingBlock
  case blinkingUnderline
  case defaultUserShape
  case steadyBar
  case steadyBlock
  case steadyUnderline
}

/// An RGB-only OSC 12 cursor color.
///
/// In `CursorStyle`, `nil` color means leave the cursor color untouched. Cursor color is
/// an explicit RGB request; it is never derived from SGR text color.
public struct CursorColor: Equatable, Hashable, Sendable {
  private static let hexDigits: [Character] = Array("0123456789ABCDEF")

  public var red: UInt8
  public var green: UInt8
  public var blue: UInt8

  /// The color serialized as an uppercase `#RRGGBB` string for OSC 12.
  var hexString: String {
    "#\(Self.hex(red))\(Self.hex(green))\(Self.hex(blue))"
  }

  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  private static func hex(_ byte: UInt8) -> String {
    "\(hexDigits[Int(byte >> 4)])\(hexDigits[Int(byte & 0x0F)])"
  }
}

/// A cursor style with independently optional shape and color facets.
///
/// `nil` shape or color means leave that facet untouched. `CursorShape.defaultUserShape`
/// is an explicit DECSCUSR 0 request and is not the same as `nil`.
public struct CursorStyle: Equatable, Hashable, Sendable {
  public var shape: CursorShape?
  public var color: CursorColor?

  public init(shape: CursorShape? = nil, color: CursorColor? = nil) {
    self.shape = shape
    self.color = color
  }
}
