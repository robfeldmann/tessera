import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput

/// A controlled, keyed collection of focusable rows.
///
/// The data and selection remain application-owned. List derives rows from the current
/// collection on every visit, keeps only a cell-based scroll offset in graph-owned responder
/// state, and reuses the output-only `ScrollIndicator` for overflow.
public struct List<Data: RandomAccessCollection, Row: View>: View, _LayoutView,
  _ResponderView, _PointerResponderView
where Data.Element: Identifiable {
  public typealias Body = Never
  package typealias ResponderState = _ListResponderState

  private let data: Data
  private let selection: Binding<Data.Element.ID?>
  private let rowContent: (Data.Element) -> Row
  private let emptyMessage: String
  private let metrics: _ListMetrics
  private let indicatorMetrics: _ScrollIndicatorMetrics

  /// Creates a list whose selected identity is controlled by the application.
  public init(
    _ data: Data,
    selection: Binding<Data.Element.ID?>,
    emptyMessage: String = "No items",
    @ViewBuilder rowContent: @escaping (Data.Element) -> Row
  ) {
    self.data = data
    self.selection = selection
    self.emptyMessage = emptyMessage
    self.rowContent = rowContent
    metrics = _ListMetrics()
    indicatorMetrics = _ScrollIndicatorMetrics()
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    if data.isEmpty {
      visit(
        _ViewChild(
          slot: .index(0),
          view: Text(emptyMessage),
          environment: environment,
          environmentOverrides: environmentOverrides
        )
      )
    } else {
      for element in data {
        let id = element.id
        visit(
          _ViewChild(
            slot: .id(AnyHashable(id)),
            view: _ListRow(
              content: rowContent(element),
              id: id,
              selected: selection.wrappedValue == id,
              selection: selection
            ),
            environment: environment,
            environmentOverrides: environmentOverrides
          )
        )
      }
    }

    visit(
      _ViewChild(
        slot: .index(data.count + (data.isEmpty ? 1 : 0)),
        view: ScrollIndicator(axis: .vertical, metrics: indicatorMetrics),
        environment: environment,
        environmentOverrides: environmentOverrides
      )
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
    guard result.contentCount > 0 else {
      return
    }

    let viewportHeight = max(min(bounds.size.rows, metrics.viewportHeight), 0)
    let contentBounds = Rect(
      origin: bounds.origin,
      size: TerminalSize(columns: result.contentWidth, rows: viewportHeight)
    )
    let viewportBounds = Rect(
      origin: bounds.origin,
      size: TerminalSize(
        columns: result.contentWidth + (result.overflow ? 1 : 0), rows: viewportHeight)
    )
    var rowOrigin = _listSubtract(bounds.origin.row, metrics.offset)
    for index in 0..<result.contentCount {
      children[index].place(
        at: TerminalPosition(column: bounds.origin.column, row: rowOrigin),
        proposal: ProposedSize(
          width: result.contentWidth, height: result.rowHeights[index]),
        clip: contentBounds
      )
      rowOrigin = _listAdd(rowOrigin, result.rowHeights[index])
    }

    let indicatorIndex = result.contentCount
    if result.overflow {
      children[indicatorIndex].place(
        at: TerminalPosition(
          column: _listAdd(bounds.origin.column, result.contentWidth),
          row: bounds.origin.row
        ),
        proposal: ProposedSize(width: 1, height: viewportHeight),
        clip: viewportBounds
      )
    } else {
      children[indicatorIndex].place(
        at: TerminalPosition(column: bounds.origin.column, row: bounds.origin.row),
        proposal: ProposedSize(width: 0, height: 0),
        clip: bounds
      )
    }
  }

  package func _makeResponderState() -> _ListResponderState {
    _ListResponderState()
  }

  package func _updateResponderState(_ state: inout _ListResponderState) {
    state.offset = min(
      max(state.offset, 0), max(metrics.contentHeight - metrics.viewportHeight, 0))
    metrics.offset = state.offset
  }

  package func _handleEvent(
    _ event: InputEvent,
    state: inout _ListResponderState,
    context: inout ResponderContext
  ) -> EventDisposition {
    if case .mouse(let mouse) = event, case .scroll(let direction) = mouse.kind {
      let oldOffset = state.offset
      switch direction {
      case .down:
        state.offset = min(
          state.offset + 1, max(metrics.contentHeight - metrics.viewportHeight, 0))
      case .up:
        state.offset = max(state.offset - 1, 0)
      case .left, .right:
        return .ignored
      }
      guard oldOffset != state.offset else {
        return .ignored
      }
      metrics.offset = state.offset
      indicatorMetrics.update(
        contentExtent: metrics.contentHeight, viewportExtent: metrics.viewportHeight,
        effectiveOffset: state.offset)
      context.setNeedsLayout()
      return .handled
    }
    guard case .key(let key) = event else {
      return .ignored
    }

    let elements = Array(data)
    guard elements.isEmpty == false else {
      return .ignored
    }

    let currentIndex = selection.wrappedValue.flatMap { id in
      elements.firstIndex { $0.id == id }
    }
    let selectedIndex = currentIndex.map {
      elements.distance(from: elements.startIndex, to: $0)
    }
    let target: Int?
    switch key.code {
    case .up:
      target = max((selectedIndex ?? 0) - 1, 0)
    case .down:
      target = min((selectedIndex ?? -1) + 1, elements.count - 1)
    case .pageUp:
      target = max((selectedIndex ?? 0) - max(metrics.viewportHeight, 1), 0)
    case .pageDown:
      target = min(
        (selectedIndex ?? -1) + max(metrics.viewportHeight, 1),
        elements.count - 1
      )
    case .home:
      target = 0
    case .end:
      target = elements.count - 1
    default:
      return .ignored
    }

    guard let target else {
      return .ignored
    }
    selection.wrappedValue = elements[target].id
    ensureVisible(target, state: &state, viewport: context.nodeBounds.size.rows)
    context.setNeedsLayout()
    return .handled
  }

  package func _handlePointer(
    _ event: PointerEvent,
    state: inout _ListResponderState,
    context: inout ResponderContext
  ) -> EventDisposition {
    switch event.phase {
    case .down:
      guard context.nodeBounds.contains(event.position),
        let index = rowIndex(
          at: event.position, state: state, origin: context.nodeBounds.origin)
      else {
        return .ignored
      }
      state.pressedIndex = index
      return .handled
    case .up:
      guard let pressedIndex = state.pressedIndex else {
        return .ignored
      }
      state.pressedIndex = nil
      guard context.nodeBounds.contains(event.position),
        let index = rowIndex(
          at: event.position, state: state, origin: context.nodeBounds.origin),
        index == pressedIndex
      else {
        return .ignored
      }
      let elements = Array(data)
      guard index < elements.count else {
        return .ignored
      }
      selection.wrappedValue = elements[index].id
      ensureVisible(index, state: &state, viewport: context.nodeBounds.size.rows)
      context.setNeedsLayout()
      return .handled
    case .scrollDown:
      let oldOffset = state.offset
      state.offset = min(
        state.offset + 1, max(metrics.contentHeight - metrics.viewportHeight, 0))
      guard oldOffset != state.offset else {
        return .ignored
      }
      metrics.offset = state.offset
      indicatorMetrics.update(
        contentExtent: metrics.contentHeight, viewportExtent: metrics.viewportHeight,
        effectiveOffset: state.offset)
      context.setNeedsLayout()
      return .handled
    case .scrollUp:
      let oldOffset = state.offset
      state.offset = max(state.offset - 1, 0)
      guard oldOffset != state.offset else {
        return .ignored
      }
      metrics.offset = state.offset
      indicatorMetrics.update(
        contentExtent: metrics.contentHeight, viewportExtent: metrics.viewportHeight,
        effectiveOffset: state.offset)
      context.setNeedsLayout()
      return .handled
    case .scrollLeft, .scrollRight:
      return .ignored
    default:
      return .ignored
    }
  }

  private func rowIndex(
    at position: TerminalPosition, state: _ListResponderState, origin: TerminalPosition
  ) -> Int? {
    let row = position.row - origin.row + state.offset
    guard row >= 0 else {
      return nil
    }
    for index in metrics.rowStarts.indices {
      let end = _listAdd(metrics.rowStarts[index], metrics.rowHeights[index])
      if row >= metrics.rowStarts[index] && row < end {
        return index
      }
    }
    return nil
  }

  private func ensureVisible(
    _ index: Int,
    state: inout _ListResponderState,
    viewport: Int
  ) {
    guard index < metrics.rowStarts.count else {
      return
    }
    let top = metrics.rowStarts[index]
    let bottom = _listAdd(top, metrics.rowHeights[index])
    let visibleRows = max(viewport, metrics.viewportHeight, 1)
    if top < state.offset {
      state.offset = top
    } else if bottom > _listAdd(state.offset, visibleRows) {
      state.offset = max(bottom - visibleRows, 0)
    }
    state.offset = min(max(state.offset, 0), max(metrics.contentHeight - visibleRows, 0))
    metrics.offset = state.offset
    indicatorMetrics.update(
      contentExtent: metrics.contentHeight,
      viewportExtent: visibleRows,
      effectiveOffset: state.offset
    )
  }

  private func distribution(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> _ListDistribution {
    let contentCount = data.isEmpty ? 1 : data.count
    let children = Subviews(subviews)
    let initialWidth = proposal.width.map { max($0, 0) }
    var contentWidth = initialWidth ?? 0
    var rowHeights = measureRows(
      children,
      count: contentCount,
      width: initialWidth
    )
    var contentHeight = rowHeights.reduce(0, _listAdd)
    let viewport = max(proposal.height ?? contentHeight, 0)
    var overflow = contentHeight > viewport

    if overflow, let width = initialWidth {
      contentWidth = max(width - 1, 0)
      rowHeights = measureRows(
        children,
        count: contentCount,
        width: contentWidth
      )
      contentHeight = rowHeights.reduce(0, _listAdd)
      overflow = contentHeight > viewport
    }

    if initialWidth == nil {
      contentWidth = measureWidth(children, count: contentCount)
      if overflow {
        contentWidth = _listAdd(contentWidth, 1)
      }
    }

    metrics.contentHeight = contentHeight
    metrics.viewportHeight = viewport
    metrics.rowHeights = rowHeights
    metrics.rowStarts = []
    metrics.rowStarts.reserveCapacity(contentCount)
    var rowStart = 0
    for height in rowHeights {
      metrics.rowStarts.append(rowStart)
      rowStart = _listAdd(rowStart, height)
    }
    metrics.offset = min(max(metrics.offset, 0), max(contentHeight - viewport, 0))
    indicatorMetrics.update(
      contentExtent: contentHeight,
      viewportExtent: viewport,
      effectiveOffset: metrics.offset
    )

    return _ListDistribution(
      contentCount: contentCount,
      contentWidth: contentWidth,
      rowHeights: rowHeights,
      overflow: overflow,
      size: TerminalSize(
        columns: proposal.width ?? _listAdd(contentWidth, overflow ? 1 : 0),
        rows: proposal.height ?? contentHeight
      )
    )
  }

  private func measureRows(
    _ subviews: Subviews,
    count: Int,
    width: Int?
  ) -> [Int] {
    guard count > 0 else {
      return []
    }
    return (0..<count).map { index in
      guard index < subviews.count else {
        return 0
      }
      return max(
        subviews[index].sizeThatFits(ProposedSize(width: width, height: nil)).rows, 0)
    }
  }

  private func measureWidth(_ subviews: Subviews, count: Int) -> Int {
    guard count > 0 else {
      return 0
    }
    return (0..<count).reduce(0) { result, index in
      guard index < subviews.count else {
        return result
      }
      return max(subviews[index].sizeThatFits(.unspecified).columns, result)
    }
  }
}

private struct _ListDistribution {
  let contentCount: Int
  let contentWidth: Int
  let rowHeights: [Int]
  let overflow: Bool
  let size: TerminalSize
}

private final class _ListMetrics {
  var offset = 0
  var contentHeight = 0
  var viewportHeight = 0
  var rowHeights: [Int] = []
  var rowStarts: [Int] = []
}

package struct _ListResponderState {
  package var offset = 0
  package var pressedIndex: Int?
}

private struct _ListRow<Content: View, ID: Hashable>: View {
  let content: Content
  let id: ID
  let selected: Bool
  let selection: Binding<ID?>

  @ViewBuilder
  var body: some View {
    if selected {
      content.bold().onTap { _ in selection.wrappedValue = id }
    } else {
      content.onTap { _ in selection.wrappedValue = id }
    }
  }
}

private func _listAdd(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.addingReportingOverflow(rhs)
  return result.overflow ? (rhs >= 0 ? Int.max : Int.min) : result.partialValue
}

private func _listSubtract(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.subtractingReportingOverflow(rhs)
  return result.overflow ? (rhs >= 0 ? Int.min : Int.max) : result.partialValue
}
