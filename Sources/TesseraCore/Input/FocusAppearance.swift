import TesseraTerminalBuffer
import TesseraTerminalCore

/// The declarative policy used to resolve a view's primary focus appearance.
public enum FocusAppearance: Equatable, Sendable {
  /// Uses the component's built-in focus appearance policy.
  case automatic
  /// Suppresses the primary focus appearance when resolution reaches this view.
  case none
  /// Offers a one-cell ring as the primary focus appearance.
  case ring
}

/// The result of asking one runtime node to host a focused descendant's appearance.
public enum FocusAppearanceDisposition: Equatable, Sendable {
  /// Continues resolution at the node's parent.
  case deferred
  /// Selects this node as the sole primary appearance host.
  case handled
  /// Stops resolution without selecting a primary appearance host.
  case suppressed
}

/// Immutable geometry supplied while resolving a focused node's appearance host.
public struct FocusAppearanceContext {
  /// The live identity whose appearance is being resolved.
  public let focusedID: FocusID
  /// The focused runtime node's resolved bounds.
  public let focusedBounds: Rect
  /// The candidate host runtime node's resolved bounds.
  public let hostBounds: Rect

  /// Creates immutable focus and candidate-host geometry for one resolution step.
  public init(
    focusedID: FocusID,
    focusedBounds: Rect,
    hostBounds: Rect
  ) {
    self.focusedID = focusedID
    self.focusedBounds = focusedBounds
    self.hostBounds = hostBounds
  }
}

package protocol _FocusAppearanceResponder {
  func _resolveFocusAppearance(
    in context: FocusAppearanceContext
  ) -> FocusAppearanceDisposition
}

extension _FocusAppearanceResponder {
  package func _resolveFocusAppearance(
    in context: FocusAppearanceContext
  ) -> FocusAppearanceDisposition {
    .handled
  }
}

package protocol _FocusAppearanceFallbackRendering {
  func _renderFocusAppearanceFallback(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  )
}

package protocol _FocusAppearanceRendering {
  func _renderFocusAppearance(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  )
}

private enum _FocusAppearanceStyleKey: EnvironmentKey {
  static let defaultValue =
    Style(foreground: .indexed(0), background: .indexed(3))
    .bold()
    ._resolved
}

extension EnvironmentValues {
  package var _focusAppearanceStyle: Style {
    get { self[_FocusAppearanceStyleKey.self] }
    set { self[_FocusAppearanceStyleKey.self] = newValue._resolved }
  }
}

private struct _FocusAppearanceModifier<Content: View>: View, _FocusAppearanceRendering,
  _FocusAppearanceResponder, _StructuralView
{
  typealias Body = Never

  let content: Content
  let appearance: FocusAppearance

  func _resolveFocusAppearance(
    in context: FocusAppearanceContext
  ) -> FocusAppearanceDisposition {
    switch appearance {
    case .automatic:
      .deferred
    case .ring:
      .handled
    case .none:
      .suppressed
    }
  }

  func _renderFocusAppearance(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  ) {
    guard appearance == .ring else {
      return
    }
    _renderFocusRing(
      in: &region,
      style: environment._focusAppearanceStyle
    )
  }

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}

extension View {
  /// Sets the primary focus appearance policy for this view.
  public func focusAppearance(_ appearance: FocusAppearance) -> some View {
    _FocusAppearanceModifier(content: self, appearance: appearance)
  }
}

package func _renderFocusRing(
  in region: inout RenderRegion,
  style: Style
) {
  let columns = max(region.bounds.size.columns, 0)
  let rows = max(region.bounds.size.rows, 0)
  guard columns > 0, rows > 0 else {
    return
  }

  if columns == 1, rows == 1 {
    region.write("╭", at: TerminalPosition(column: 0, row: 0), style: style)
    return
  }

  if rows == 1 {
    region.write("╭", at: TerminalPosition(column: 0, row: 0), style: style)
    for column in 1..<max(columns - 1, 1) {
      region.write("─", at: TerminalPosition(column: column, row: 0), style: style)
    }
    if columns > 1 {
      region.write("╮", at: TerminalPosition(column: columns - 1, row: 0), style: style)
    }
    return
  }

  if columns == 1 {
    region.write("╭", at: TerminalPosition(column: 0, row: 0), style: style)
    for row in 1..<max(rows - 1, 1) {
      region.write("│", at: TerminalPosition(column: 0, row: row), style: style)
    }
    region.write("╰", at: TerminalPosition(column: 0, row: rows - 1), style: style)
    return
  }

  region.write("╭", at: TerminalPosition(column: 0, row: 0), style: style)
  region.write("╮", at: TerminalPosition(column: columns - 1, row: 0), style: style)
  region.write("╰", at: TerminalPosition(column: 0, row: rows - 1), style: style)
  region.write("╯", at: TerminalPosition(column: columns - 1, row: rows - 1), style: style)

  for column in 1..<(columns - 1) {
    region.write("─", at: TerminalPosition(column: column, row: 0), style: style)
    region.write("─", at: TerminalPosition(column: column, row: rows - 1), style: style)
  }
  for row in 1..<(rows - 1) {
    region.write("│", at: TerminalPosition(column: 0, row: row), style: style)
    region.write("│", at: TerminalPosition(column: columns - 1, row: row), style: style)
  }
}
