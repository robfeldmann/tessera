/// An 8-bit-per-channel RGB color reported by a terminal.
public struct TerminalRGBColor: Equatable, Hashable, Sendable {
  /// The red channel, 0 through 255.
  public var red: UInt8

  /// The green channel, 0 through 255.
  public var green: UInt8

  /// The blue channel, 0 through 255.
  public var blue: UInt8

  /// Creates a color from 8-bit channels.
  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

/// A color the terminal can report about itself.
public enum TerminalColorRole: Equatable, Hashable, Sendable {
  /// The terminal's default background color, reported by OSC 11.
  case background

  /// The terminal's default foreground color, reported by OSC 10.
  case foreground

  /// One of the 16 ANSI palette slots, 0 through 15, reported by OSC 4.
  case slot(Int)
}

/// One terminal color reply, parsed from an OSC 10, OSC 11, or OSC 4 response.
public struct TerminalColorReply: Equatable, Sendable {
  /// The color the terminal described.
  public var role: TerminalColorRole

  /// The reported value, scaled to 8 bits per channel.
  public var color: TerminalRGBColor

  /// Creates a color reply.
  public init(role: TerminalColorRole, color: TerminalRGBColor) {
    self.role = role
    self.color = color
  }
}

/// The color scheme a terminal announced in a color-scheme notification.
public enum TerminalColorScheme: Equatable, Sendable {
  /// The terminal switched to a dark color scheme (`CSI ? 997 ; 1 n`).
  case dark

  /// The terminal switched to a light color scheme (`CSI ? 997 ; 2 n`).
  case light
}
