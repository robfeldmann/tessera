import TesseraCore
import TesseraTerminalBuffer
import TesseraTerminalCore

/// The six single-cell glyphs used to draw a border ring.
public struct BorderGlyphs: Equatable, Sendable {
  public let topLeft: String
  public let topRight: String
  public let bottomLeft: String
  public let bottomRight: String
  public let horizontal: String
  public let vertical: String

  /// Creates a custom border glyph set.
  ///
  /// Every supplied glyph must be exactly one printable extended grapheme cluster with a
  /// terminal display width of one cell.
  public init(
    topLeft: String,
    topRight: String,
    bottomLeft: String,
    bottomRight: String,
    horizontal: String,
    vertical: String
  ) {
    self.topLeft = _validatedBorderGlyph(topLeft, named: "topLeft")
    self.topRight = _validatedBorderGlyph(topRight, named: "topRight")
    self.bottomLeft = _validatedBorderGlyph(bottomLeft, named: "bottomLeft")
    self.bottomRight = _validatedBorderGlyph(bottomRight, named: "bottomRight")
    self.horizontal = _validatedBorderGlyph(horizontal, named: "horizontal")
    self.vertical = _validatedBorderGlyph(vertical, named: "vertical")
  }
}

/// The glyph family rendered by the `border(_:_:)` modifier.
public enum BorderStyle: Equatable, Sendable {
  /// ASCII-safe rules.
  case ascii
  /// Caller-supplied single-cell glyphs.
  case custom(BorderGlyphs)
  /// Double-line rules.
  case double
  /// Heavy rules.
  case heavy
  /// Light rules with rounded corners.
  case rounded
  /// Light square corners and rules.
  case single
}

/// A one-cell rule oriented across its enclosing stack's cross axis.
public struct Divider: LeafView {
  public typealias Body = Never

  private let dividerStyle: DividerStyle?

  /// Creates a divider whose orientation follows the nearest linear stack.
  ///
  /// Pass a style to override the inherited `dividerStyle` environment value.
  public init(style: DividerStyle? = nil) {
    dividerStyle = style
  }

  public func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    switch environment._stackAxis {
    case .horizontal:
      TerminalSize(columns: 1, rows: max(proposal.height ?? 1, 0))
    case .vertical, nil:
      TerminalSize(columns: max(proposal.width ?? 1, 0), rows: 1)
    }
  }

  public func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    let style = environment.defaultStyle
    let glyphs = (dividerStyle ?? environment.dividerStyle).glyphs

    switch environment._stackAxis {
    case .horizontal:
      for row in 0..<max(region.bounds.size.rows, 0) {
        region.write(
          glyphs.vertical,
          at: TerminalPosition(column: 0, row: row),
          style: style
        )
      }
    case .vertical, nil:
      for column in 0..<max(region.bounds.size.columns, 0) {
        region.write(
          glyphs.horizontal,
          at: TerminalPosition(column: column, row: 0),
          style: style
        )
      }
    }
  }
}

/// The named glyph family rendered by ``Divider``.
public enum DividerStyle: Equatable, Sendable {
  /// ASCII-safe rules.
  case ascii
  /// Dashed rules.
  case dashed
  /// Double rules.
  case double
  /// Heavy rules.
  case heavy
  /// Light rules.
  case light
}

private enum _DividerStyleKey: EnvironmentKey {
  static let defaultValue = DividerStyle.light
}

extension EnvironmentValues {
  /// The inherited glyph family used by ``Divider``.
  public var dividerStyle: DividerStyle {
    get { self[_DividerStyleKey.self] }
    set { self[_DividerStyleKey.self] = newValue }
  }
}

extension View {
  /// Sets the divider glyph family for descendants.
  public func dividerStyle(_ style: DividerStyle) -> some View {
    environment(\.dividerStyle, style)
  }

  /// Draws a one-cell border ring around this view.
  ///
  /// The child is clipped to the ring's interior. The ring is painted after the child, so
  /// child output cannot overwrite the chrome.
  public func border(
    _ style: BorderStyle = .single,
    _ lineStyle: Style = Style()
  ) -> some View {
    _BorderLayout {
      self
      _BorderChrome(glyphs: style.glyphs, lineStyle: lineStyle)
    }
  }

  /// Paints a layer over this view without allowing that layer to affect its measurement.
  public func overlay<Layer: View>(
    alignment: Alignment = .topLeading,
    @ViewBuilder _ layer: () -> Layer
  ) -> some View {
    _OverlayLayout(alignment: alignment) {
      self
      layer()
    }
  }

  /// Paints a view-builder layer behind this view without allowing it to affect measurement.
  public func background<BackgroundLayer: View>(
    alignment: Alignment = .topLeading,
    @ViewBuilder background: () -> BackgroundLayer
  ) -> some View {
    Background(alignment: alignment, background: background) {
      self
    }
  }
}

/// A bordered group with one content-padding cell and an optional title in its top chrome.
public struct Box<Content: View>: View, _FocusAppearanceRendering,
  _FocusAppearanceResponder
{
  private let title: String?
  private let borderStyle: BorderStyle
  private let content: Content

  @ViewBuilder
  public var body: some View {
    if let title {
      content
        .padding(1)
        .border(borderStyle)
        .overlay {
          _BoxTitleLayout {
            Text(title).truncation(.tail)
            _BoxTitleSpacing()
          }
        }
    } else {
      content.padding(1).border(borderStyle)
    }
  }

  public init(
    title: String? = nil,
    border: BorderStyle = .rounded,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    borderStyle = border
    self.content = content()
  }

  package func _renderFocusAppearance(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  ) {
    let columns = max(region.bounds.size.columns, 0)
    let rows = max(region.bounds.size.rows, 0)
    guard columns > 0, rows > 0 else {
      return
    }

    let style = Style(foreground: environment.semanticStyles.focus.background).bold()
    let titleColumns: Range<Int>?
    if let title, columns >= 7 {
      var state: Void = ()
      let titleWidth = min(
        Text(title).sizeThatFits(
          .unspecified,
          state: &state,
          environment: environment
        ).columns,
        max(columns - 6, 0)
      )
      titleColumns = 2..<(2 + titleWidth + 2)
    } else {
      titleColumns = nil
    }

    for column in 0..<columns {
      if !(titleColumns?.contains(column) ?? false) {
        region._mergeStyle(style, at: TerminalPosition(column: column, row: 0))
      }
      if rows > 1 {
        region._mergeStyle(
          style,
          at: TerminalPosition(column: column, row: rows - 1)
        )
      }
    }
    if rows > 2 {
      for row in 1..<(rows - 1) {
        region._mergeStyle(style, at: TerminalPosition(column: 0, row: row))
        if columns > 1 {
          region._mergeStyle(
            style,
            at: TerminalPosition(column: columns - 1, row: row)
          )
        }
      }
    }
  }

}

/// A primary-size-owned view with a background layer that paints first.
public struct Background<Primary: View, BackgroundLayer: View>: View {
  private let alignment: Alignment
  private let backgroundLayer: BackgroundLayer
  private let primary: Primary

  public var body: some View {
    _BackgroundLayout(alignment: alignment) {
      backgroundLayer
      primary
    }
  }

  public init(
    alignment: Alignment = .topLeading,
    @ViewBuilder background: () -> BackgroundLayer,
    @ViewBuilder content: () -> Primary
  ) {
    self.alignment = alignment
    backgroundLayer = background()
    primary = content()
  }

}

private struct _BorderLayout: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    let childSize =
      subviews.first?.sizeThatFits(_borderInteriorProposal(for: proposal))
      ?? TerminalSize(columns: 0, rows: 0)
    return TerminalSize(
      columns: _borderExtent(child: childSize.columns, proposal: proposal.width),
      rows: _borderExtent(child: childSize.rows, proposal: proposal.height)
    )
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    guard let content = subviews.first else {
      return
    }

    let interior = _borderInterior(of: bounds)
    content.place(
      at: interior.origin,
      proposal: ProposedSize(width: interior.size.columns, height: interior.size.rows),
      clip: interior
    )

    guard subviews.count > 1 else {
      return
    }

    subviews[1].place(
      at: bounds.origin,
      proposal: ProposedSize(
        width: max(bounds.size.columns, 0), height: max(bounds.size.rows, 0)),
      clip: bounds
    )
  }
}

private struct _BorderChrome: LeafView {
  typealias Body = Never

  let glyphs: BorderGlyphs
  let lineStyle: Style

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(
      columns: max(proposal.width ?? 0, 0),
      rows: max(proposal.height ?? 0, 0)
    )
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    _drawBorder(
      glyphs,
      in: &region,
      style: environment.defaultStyle._merging(lineStyle)
    )
  }
}

private struct _OverlayLayout: Layout {
  let alignment: Alignment

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    guard let primary = subviews.first else {
      return TerminalSize(columns: 0, rows: 0)
    }
    return primary.sizeThatFits(proposal)
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    guard subviews.count >= 2 else {
      return
    }

    let layerProposal = ProposedSize(
      width: max(bounds.size.columns, 0),
      height: max(bounds.size.rows, 0)
    )
    let layerSize = subviews[1].sizeThatFits(layerProposal)

    subviews[0].place(at: bounds.origin, proposal: layerProposal, clip: bounds)
    subviews[1].place(
      at: _alignedOrigin(
        for: layerSize,
        in: bounds,
        alignment: alignment
      ),
      proposal: layerProposal,
      clip: bounds
    )
  }
}

private struct _BackgroundLayout: Layout {
  let alignment: Alignment

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    guard subviews.count >= 2 else {
      return TerminalSize(columns: 0, rows: 0)
    }
    return subviews[1].sizeThatFits(proposal)
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    guard subviews.count >= 2 else {
      return
    }

    let layerProposal = ProposedSize(
      width: max(bounds.size.columns, 0),
      height: max(bounds.size.rows, 0)
    )
    let backgroundSize = subviews[0].sizeThatFits(layerProposal)
    let primarySize = subviews[1].sizeThatFits(layerProposal)

    subviews[0].place(
      at: _alignedOrigin(
        for: backgroundSize,
        in: bounds,
        alignment: alignment
      ),
      proposal: layerProposal,
      clip: bounds
    )
    subviews[1].place(
      at: _alignedOrigin(
        for: primarySize,
        in: bounds,
        alignment: alignment
      ),
      proposal: layerProposal,
      clip: bounds
    )
  }
}

private struct _BoxTitleLayout: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    TerminalSize(
      columns: max(proposal.width ?? 0, 0),
      rows: max(proposal.height ?? 0, 0)
    )
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    guard subviews.count >= 2,
      bounds.size.rows > 0,
      bounds.size.columns >= 7
    else {
      return
    }

    let titleProposal = ProposedSize(width: bounds.size.columns - 6, height: 1)
    let titleSize = subviews[0].sizeThatFits(titleProposal)
    guard titleSize.columns > 0 else {
      return
    }

    let titleOrigin = TerminalPosition(
      column: bounds.origin.column + 3,
      row: bounds.origin.row
    )
    subviews[0].place(at: titleOrigin, proposal: titleProposal, clip: bounds)
    subviews[1].place(
      at: TerminalPosition(
        column: bounds.origin.column + 2,
        row: bounds.origin.row
      ),
      proposal: ProposedSize(width: titleSize.columns + 2, height: 1),
      clip: bounds
    )
  }
}

private struct _BoxTitleSpacing: LeafView {
  typealias Body = Never

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(
      columns: max(proposal.width ?? 0, 0),
      rows: max(proposal.height ?? 0, 0)
    )
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    guard region.bounds.size.columns >= 2, region.bounds.size.rows > 0 else {
      return
    }

    region.write(
      " ", at: TerminalPosition(column: 0, row: 0), style: environment.defaultStyle)
    region.write(
      " ",
      at: TerminalPosition(column: region.bounds.size.columns - 1, row: 0),
      style: environment.defaultStyle
    )
  }
}

private func _validatedBorderGlyph(_ glyph: String, named name: String) -> String {
  precondition(glyph.count == 1, "BorderGlyphs.\(name) must contain one grapheme cluster.")
  guard let character = glyph.first else {
    preconditionFailure("BorderGlyphs.\(name) must not be empty.")
  }
  precondition(
    !glyph.unicodeScalars.contains { scalar in
      scalar == "\t" || scalar.value < 0x20 || (0x80...0x9F).contains(scalar.value)
    },
    "BorderGlyphs.\(name) must be printable."
  )
  precondition(
    Cell(character: character).width == 1,
    "BorderGlyphs.\(name) must occupy exactly one terminal cell."
  )
  return glyph
}

extension BorderStyle {
  fileprivate var glyphs: BorderGlyphs {
    switch self {
    case .single:
      BorderGlyphs(
        topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘", horizontal: "─",
        vertical: "│")
    case .rounded:
      BorderGlyphs(
        topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯", horizontal: "─",
        vertical: "│")
    case .double:
      BorderGlyphs(
        topLeft: "╔", topRight: "╗", bottomLeft: "╚", bottomRight: "╝", horizontal: "═",
        vertical: "║")
    case .heavy:
      BorderGlyphs(
        topLeft: "┏", topRight: "┓", bottomLeft: "┗", bottomRight: "┛", horizontal: "━",
        vertical: "┃")
    case .ascii:
      BorderGlyphs(
        topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+", horizontal: "-",
        vertical: "|")
    case .custom(let glyphs):
      glyphs
    }
  }
}

extension DividerStyle {
  fileprivate var glyphs: (horizontal: String, vertical: String) {
    switch self {
    case .light:
      (horizontal: "─", vertical: "│")
    case .heavy:
      (horizontal: "━", vertical: "┃")
    case .double:
      (horizontal: "═", vertical: "║")
    case .dashed:
      (horizontal: "╌", vertical: "╎")
    case .ascii:
      (horizontal: "-", vertical: "|")
    }
  }
}

private func _borderInteriorProposal(for proposal: ProposedSize) -> ProposedSize {
  ProposedSize(
    width: proposal.width.map { $0 > 2 ? $0 - 2 : 0 },
    height: proposal.height.map { $0 > 2 ? $0 - 2 : 0 }
  )
}

private func _borderExtent(child: Int, proposal: Int?) -> Int {
  let childWithInsets = child > Int.max - 2 ? Int.max : max(child, 0) + 2
  return min(childWithInsets, max(proposal ?? childWithInsets, 0))
}

private func _borderInterior(of bounds: Rect) -> Rect {
  Rect(
    origin: TerminalPosition(
      column: bounds.origin.column + min(max(bounds.size.columns, 0), 1),
      row: bounds.origin.row + min(max(bounds.size.rows, 0), 1)
    ),
    size: TerminalSize(
      columns: max(bounds.size.columns - 2, 0),
      rows: max(bounds.size.rows - 2, 0)
    )
  )
}

private func _drawBorder(
  _ glyphs: BorderGlyphs,
  in region: inout RenderRegion,
  style: Style
) {
  let columns = max(region.bounds.size.columns, 0)
  let rows = max(region.bounds.size.rows, 0)
  guard columns > 0, rows > 0 else {
    return
  }

  region.write(glyphs.topLeft, at: TerminalPosition(column: 0, row: 0), style: style)

  if columns > 1 {
    region.write(
      glyphs.topRight, at: TerminalPosition(column: columns - 1, row: 0), style: style)
  }
  if rows > 1 {
    region.write(
      glyphs.bottomLeft, at: TerminalPosition(column: 0, row: rows - 1), style: style)
  }
  if columns > 1, rows > 1 {
    region.write(
      glyphs.bottomRight,
      at: TerminalPosition(column: columns - 1, row: rows - 1),
      style: style
    )
  }

  for column in 1..<max(columns - 1, 1) {
    region.write(
      glyphs.horizontal, at: TerminalPosition(column: column, row: 0), style: style)
    if rows > 1 {
      region.write(
        glyphs.horizontal,
        at: TerminalPosition(column: column, row: rows - 1),
        style: style
      )
    }
  }

  for row in 1..<max(rows - 1, 1) {
    region.write(glyphs.vertical, at: TerminalPosition(column: 0, row: row), style: style)
    if columns > 1 {
      region.write(
        glyphs.vertical,
        at: TerminalPosition(column: columns - 1, row: row),
        style: style
      )
    }
  }
}

private func _alignedOrigin(
  for size: TerminalSize,
  in bounds: Rect,
  alignment: Alignment
) -> TerminalPosition {
  let horizontal = _alignmentOffset(
    slack: max(bounds.size.columns - size.columns, 0),
    alignment: alignment.horizontal
  )
  let vertical = _alignmentOffset(
    slack: max(bounds.size.rows - size.rows, 0),
    alignment: alignment.vertical
  )
  return TerminalPosition(
    column: bounds.origin.column + horizontal,
    row: bounds.origin.row + vertical
  )
}
