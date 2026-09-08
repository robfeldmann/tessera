import TesseraCore
import TesseraTerminalCore

/// A row-major grid that resolves every column with Tessera's shared Flex allocator.
///
/// Grid does not support spanning: each child occupies one source-order cell. Column
/// constraints are resolved once per layout pass, row heights are the largest measured
/// child in each row, and painting remains in source order.
public struct Grid<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private struct Distribution {
    let columnWidths: [Int]
    let rowHeights: [Int]
    let size: TerminalSize
  }

  private let columns: [FlexConstraint]
  private let spacing: Int
  private let content: Content
  /// Creates a row-major grid with one cell per child and no spanning.
  ///
  /// An empty constraint list is treated as one unconstrained, fill column. Spacing is
  /// measured in terminal cells and must be nonnegative.
  public init(
    columns: [FlexConstraint] = [.fill(1)],
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  ) {
    precondition(spacing >= 0, "Grid spacing must be nonnegative.")
    self.columns = columns.isEmpty ? [.fill(1)] : columns
    self.spacing = spacing
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
    distribution(proposal, subviews: subviews).size
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    let result = distribution(proposal, subviews: subviews)
    let children = Subviews(subviews)
    guard result.columnWidths.isEmpty == false else {
      return
    }

    var rowOrigin = bounds.origin.row
    for row in result.rowHeights.indices {
      var columnOrigin = bounds.origin.column
      for column in result.columnWidths.indices {
        let index = row * result.columnWidths.count + column
        guard index < children.count else {
          break
        }
        let width = result.columnWidths[column]
        let height = result.rowHeights[row]
        children[index].place(
          at: TerminalPosition(column: columnOrigin, row: rowOrigin),
          proposal: ProposedSize(width: width, height: height),
          clip: bounds
        )
        columnOrigin = _gridAdd(columnOrigin, width)
        if column != result.columnWidths.index(before: result.columnWidths.endIndex) {
          columnOrigin = _gridAdd(columnOrigin, spacing)
        }
      }
      rowOrigin = _gridAdd(rowOrigin, result.rowHeights[row])
      if row != result.rowHeights.index(before: result.rowHeights.endIndex) {
        rowOrigin = _gridAdd(rowOrigin, spacing)
      }
    }
  }

  private func distribution(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> Distribution {
    let columnCount = columns.count
    let children = Subviews(subviews)
    guard children.isEmpty == false else {
      return Distribution(
        columnWidths: Array(repeating: 0, count: columnCount),
        rowHeights: [],
        size: TerminalSize(columns: 0, rows: 0)
      )
    }

    let idealProposal = ProposedSize(width: nil, height: proposal.height)
    let minimumProposal = ProposedSize(width: 0, height: proposal.height)
    var ideals = Array(repeating: 0, count: columnCount)
    var minimums = Array(repeating: 0, count: columnCount)

    for index in children.indices {
      let column = index % columnCount
      ideals[column] = max(
        ideals[column], children[index].sizeThatFits(idealProposal).columns)
      minimums[column] = max(
        minimums[column], children[index].sizeThatFits(minimumProposal).columns)
    }

    let spacingTotal = _gridMultiply(spacing, max(columnCount - 1, 0))
    let available = proposal.width.map { max($0 - spacingTotal, 0) }
    let items = columns.indices.map { index in
      _FlexResolverItem.constraint(
        columns[index],
        available: available,
        measuredIdeal: ideals[index],
        measuredMinimum: minimums[index],
        priority: 0
      )
    }
    let resolution = _FlexResolver.resolve(available: available, spacing: 0, items: items)
    let widths = resolution.allocations.map { max($0, 0) }
    let rowCount = (children.count + columnCount - 1) / columnCount
    var heights = Array(repeating: 0, count: rowCount)

    for index in children.indices {
      let row = index / columnCount
      let width = widths[index % columnCount]
      let measured = children[index].sizeThatFits(
        ProposedSize(width: width, height: proposal.height)
      )
      heights[row] = max(heights[row], measured.rows)
    }

    let contentWidth = _gridAdd(widths.reduce(0, _gridAdd), spacingTotal)
    let contentHeight = _gridAdd(
      heights.reduce(0, _gridAdd),
      _gridMultiply(spacing, max(rowCount - 1, 0))
    )
    return Distribution(
      columnWidths: widths,
      rowHeights: heights,
      size: TerminalSize(
        columns: proposal.width ?? contentWidth,
        rows: proposal.height ?? contentHeight
      )
    )
  }
}

private func _gridAdd(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.addingReportingOverflow(rhs)
  return result.overflow ? (rhs >= 0 ? Int.max : Int.min) : result.partialValue
}

private func _gridMultiply(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.multipliedReportingOverflow(by: rhs)
  return result.overflow ? Int.max : result.partialValue
}
