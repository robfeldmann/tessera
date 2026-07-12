/// Selects how underline colors are rendered.
public enum UnderlineColorRendering: Equatable, Sendable {
  /// Emits underline colors using SGR 58.
  case emit

  /// Omits underline colors.
  case omit
}

/// Selects how underline styles are rendered.
public enum UnderlineStyleRendering: Equatable, Sendable {
  /// Emits each underline style variant.
  case preserveVariants

  /// Collapses every non-none underline style to a single underline.
  case singleOnly
}

/// Controls how underline style and color are rendered.
public struct UnderlineRenderingPolicy: Equatable, Sendable {
  /// A baseline policy that renders single underlines without underline colors.
  public static let baseline = Self(style: .singleOnly, color: .omit)

  /// The full policy that preserves underline styles and emits underline colors.
  public static let extended = Self(style: .preserveVariants, color: .emit)

  /// The rendering behavior for underline colors.
  public var color: UnderlineColorRendering

  /// The rendering behavior for underline styles.
  public var style: UnderlineStyleRendering

  /// Creates an underline rendering policy.
  public init(
    style: UnderlineStyleRendering,
    color: UnderlineColorRendering
  ) {
    self.style = style
    self.color = color
  }
}
