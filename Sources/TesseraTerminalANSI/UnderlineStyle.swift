/// A semantic ECMA-48 underline style.
///
/// `.none` explicitly disables underline with SGR 24. The remaining cases select the
/// corresponding SGR 4 style; unsupported terminals may approximate or ignore variants.
public enum UnderlineStyle: Equatable, Sendable {
  /// Render a curly underline, also known as an undercurl.
  case curly

  /// Render a dashed underline.
  case dashed

  /// Render a dotted underline.
  case dotted

  /// Render a double underline.
  case double

  /// Disable underline.
  case none

  /// Render a single straight underline.
  case single
}
