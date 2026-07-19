import TesseraCore
import TesseraLayout
import TesseraTerminalCore

/// A viewport that presents a translated portion of its content.
public struct ScrollView<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let axes: Axis.Set
  private let offset: Binding<TerminalPosition>?
  private let content: Content

  public init(
    _ axes: Axis.Set = .vertical,
    offset: Binding<TerminalPosition>? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.axes = axes
    self.offset = offset
    self.content = content()
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    _visitLayoutChildren(
      content,
      in: environment,
      environmentOverrides: environmentOverrides,
      visit
    )
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    let childProposal = contentProposal(for: proposal)
    let contentSize = measuredContentSize(subviews, proposal: childProposal)
    return TerminalSize(
      columns: proposal.width ?? contentSize.columns,
      rows: proposal.height ?? contentSize.rows
    )
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    let childProposal = contentProposal(for: proposal)
    let contentSize = measuredContentSize(subviews, proposal: childProposal)
    let translation = effectiveOffset(contentSize: contentSize, viewportSize: bounds.size)
    let origin = TerminalPosition(
      column: translated(bounds.origin.column, by: translation.column),
      row: translated(bounds.origin.row, by: translation.row)
    )

    for subview in Subviews(subviews) {
      subview.place(at: origin, proposal: childProposal)
    }
  }

  private func contentProposal(for proposal: ProposedSize) -> ProposedSize {
    ProposedSize(
      width: axes.contains(.horizontal) ? nil : proposal.width,
      height: axes.contains(.vertical) ? nil : proposal.height
    )
  }

  private func measuredContentSize(
    _ subviews: _LayoutSubviewsProxy,
    proposal: ProposedSize
  ) -> TerminalSize {
    var columns = 0
    var rows = 0
    for subview in Subviews(subviews) {
      let size = subview.sizeThatFits(proposal)
      columns = max(columns, size.columns)
      rows = max(rows, size.rows)
    }
    return TerminalSize(columns: columns, rows: rows)
  }

  private func effectiveOffset(
    contentSize: TerminalSize,
    viewportSize: TerminalSize
  ) -> TerminalPosition {
    let requestedOffset = offset?.wrappedValue ?? TerminalPosition(column: 0, row: 0)
    return TerminalPosition(
      column: effectiveComponent(
        requestedOffset.column,
        enabled: axes.contains(.horizontal),
        content: contentSize.columns,
        viewport: viewportSize.columns
      ),
      row: effectiveComponent(
        requestedOffset.row,
        enabled: axes.contains(.vertical),
        content: contentSize.rows,
        viewport: viewportSize.rows
      )
    )
  }

  private func translated(_ origin: Int, by offset: Int) -> Int {
    let result = origin.subtractingReportingOverflow(offset)
    guard result.overflow else {
      return result.partialValue
    }

    return Int.min
  }

  private func effectiveComponent(
    _ requested: Int,
    enabled: Bool,
    content: Int,
    viewport: Int
  ) -> Int {
    guard enabled else {
      return 0
    }

    return min(max(requested, 0), max(content - viewport, 0))
  }
}
