import TesseraCore
import TesseraLayout
import TesseraTerminalCore

/// A titled group that preserves the identity and input contracts of its content.
///
/// Section is a real two-child layout rather than a VStack alias: the header and content
/// are measured independently, then placed as one grouped region. It owns no data,
/// selection, or focus state.
public struct Section<Header: View, Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let header: Header
  private let content: Content
  private let spacing: Int

  /// Creates a section with an arbitrary header and grouped content.
  public init(
    spacing: Int = 0,
    header: () -> Header,
    @ViewBuilder content: () -> Content
  ) {
    precondition(spacing >= 0, "Section spacing must be nonnegative.")
    self.header = header()
    self.content = content()
    self.spacing = spacing
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: header,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
    visit(
      _ViewChild(
        slot: .index(1),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    guard subviews.count == 2 else {
      return TerminalSize(columns: 0, rows: 0)
    }
    let headerSize = subviews[0].measure(proposal)
    let contentSize = subviews[1].measure(proposal)
    return TerminalSize(
      columns: max(headerSize.columns, contentSize.columns),
      rows: _sectionAdd(headerSize.rows, _sectionAdd(spacing, contentSize.rows))
    )
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    guard subviews.count == 2 else {
      return
    }
    let headerSize = subviews[0].measure(proposal)
    let headerOrigin = bounds.origin
    let children = Subviews(subviews)
    children[0].place(
      at: headerOrigin,
      proposal: ProposedSize(width: bounds.size.columns, height: headerSize.rows),
      clip: bounds
    )
    let contentOrigin = TerminalPosition(
      column: bounds.origin.column,
      row: _sectionAdd(bounds.origin.row, _sectionAdd(headerSize.rows, spacing))
    )
    children[1].place(
      at: contentOrigin,
      proposal: ProposedSize(
        width: bounds.size.columns,
        height: max(bounds.size.rows - headerSize.rows - spacing, 0)
      ),
      clip: bounds
    )
  }
}

extension Section where Header == Text {
  /// Creates a section with a text title.
  public init(
    _ title: String,
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  ) {
    self.init(spacing: spacing, header: { Text(title) }, content: content)
  }
}

private func _sectionAdd(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.addingReportingOverflow(rhs)
  return result.overflow ? (rhs >= 0 ? Int.max : Int.min) : result.partialValue
}
