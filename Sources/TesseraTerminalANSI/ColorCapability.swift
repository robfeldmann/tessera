/// Advisory terminal color support.
public enum ColorCapability: Equatable, Sendable {
  /// ANSI 16-color support is the safest known color level.
  case ansi16

  /// ANSI indexed 256-color support is expected.
  case indexed256

  /// Color output is disabled by policy or by a terminal that should not receive color.
  case noColor

  /// 24-bit RGB color support is expected.
  case truecolor

  /// Tessera has no reliable local hint for color support.
  case unknown
}
