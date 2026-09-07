import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore

/// The complete presentation roles supplied to system components.
public struct SemanticStyles: Equatable, Sendable {
  /// The ordinary inherited presentation.
  public var primary: Style {
    didSet { primary = primary._resolved }
  }
  /// The supporting presentation used for inactive facts and labels.
  public var secondary: Style {
    didSet { secondary = secondary._resolved }
  }
  /// The emphasized presentation used for focus and selection.
  public var accent: Style {
    didSet { accent = accent._resolved }
  }
  /// The presentation used by disabled controls.
  public var disabled: Style {
    didSet { disabled = disabled._resolved }
  }
  /// The emphasized presentation used for destructive actions and warnings.
  public var destructive: Style {
    didSet { destructive = destructive._resolved }
  }

  /// Creates Tessera's default semantic presentation roles.
  public init() {
    self.init(
      primary: Style(),
      secondary: Style().dim(),
      accent: Style(foreground: .indexed(14)).bold(),
      disabled: Style().dim(),
      destructive: Style(foreground: .indexed(9)).bold().underline()
    )
  }

  /// Creates semantic roles from application-provided styles.
  ///
  /// Each role is resolved to a complete terminal style so controls can consume it directly.
  public init(
    primary: Style,
    secondary: Style,
    accent: Style,
    disabled: Style,
    destructive: Style
  ) {
    self.primary = primary._resolved
    self.secondary = secondary._resolved
    self.accent = accent._resolved
    self.disabled = disabled._resolved
    self.destructive = destructive._resolved
  }
}

private enum _SemanticStylesKey: EnvironmentKey {
  static let defaultValue = SemanticStyles()
}

extension EnvironmentValues {
  /// The complete semantic presentation roles inherited by this subtree.
  public var semanticStyles: SemanticStyles {
    get { self[_SemanticStylesKey.self] }
    set { self[_SemanticStylesKey.self] = newValue }
  }
}

extension View {
  /// Overrides the inherited foreground color for this view's descendants.
  public func foreground(_ color: Color) -> some View {
    _StyleModifier(
      content: self, overlay: Style(foreground: color), paintsBackground: false)
  }

  /// Paints and inherits a background color for this view's descendants.
  public func background(_ color: Color) -> some View {
    _StyleModifier(
      content: self, overlay: Style(background: color), paintsBackground: true)
  }

  /// Explicitly enables or disables bold for this view's descendants.
  public func bold(_ on: Bool = true) -> some View {
    _StyleModifier(content: self, overlay: Style().bold(on), paintsBackground: false)
  }

  /// Explicitly enables or disables italic for this view's descendants.
  public func italic(_ on: Bool = true) -> some View {
    _StyleModifier(content: self, overlay: Style().italic(on), paintsBackground: false)
  }

  /// Explicitly enables or disables underlining for this view's descendants.
  public func underline(_ on: Bool = true) -> some View {
    _StyleModifier(content: self, overlay: Style().underline(on), paintsBackground: false)
  }

  /// Merges explicit attributes from `style` into the inherited descendant style.
  public func style(_ style: Style) -> some View {
    _StyleModifier(content: self, overlay: style, paintsBackground: false)
  }
}

package struct _StyleModifier<Content: View>: View, _LayoutView {
  package typealias Body = Never

  private let content: Content
  private let overlay: Style
  private let paintsBackground: Bool
  private let environmentOverrideName: String

  private var contentIndex: Int {
    paintsBackground ? 1 : 0
  }

  package init(content: Content, overlay: Style, paintsBackground: Bool) {
    self.content = content
    self.overlay = overlay
    self.paintsBackground = paintsBackground
    environmentOverrideName = String(reflecting: \EnvironmentValues.defaultStyle)
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var resolvedEnvironment = environment
    resolvedEnvironment.defaultStyle = environment.defaultStyle._merging(overlay)

    var resolvedOverrides = environmentOverrides
    resolvedOverrides.append(environmentOverrideName)

    if paintsBackground {
      visit(
        _ViewChild(
          slot: .index(0),
          view: _StyleBackground(style: resolvedEnvironment.defaultStyle),
          environment: resolvedEnvironment,
          environmentOverrides: resolvedOverrides
        )
      )
    }

    visit(
      _ViewChild(
        slot: .index(contentIndex),
        view: content,
        environment: resolvedEnvironment,
        environmentOverrides: resolvedOverrides
      )
    )
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    subviews[contentIndex].measure(proposal)
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    let contentSize = subviews[contentIndex].measure(proposal)

    if paintsBackground {
      subviews[0].place(
        bounds.origin,
        ProposedSize(width: contentSize.columns, height: contentSize.rows)
      )
    }

    subviews[contentIndex].place(bounds.origin, proposal)
  }
}

private struct _StyleBackground: LeafView {
  typealias Body = Never

  let style: Style

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: proposal.width ?? 0, rows: proposal.height ?? 0)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    guard !region.bounds.isEmpty else {
      return
    }

    region.fill(Cell(style: style), in: region.bounds)
  }
}
