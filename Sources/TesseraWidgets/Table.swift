import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput

/// A small, controlled sort descriptor. Table records header intent; the application sorts
/// its data and supplies the resulting collection on the next update.
public struct SortDescriptor<Element>: Equatable {
  /// The column key recorded in sort intent.
  public let key: String
  /// Whether application-side ordering is ascending.
  public let ascending: Bool

  /// Creates a sort descriptor for a named table column.
  public init(key: String, ascending: Bool = true) {
    self.key = key
    self.ascending = ascending
  }

  public func reversed() -> Self {
    Self(key: key, ascending: !ascending)
  }
}

/// A column description consumed by ``Table`` and the shared Flex resolver.
public struct TableColumn<Element> {
  /// The displayed column heading.
  public let title: String
  /// The shared Flex width constraint.
  public let constraint: FlexConstraint
  /// The priority used when columns are compressed.
  public let dropPriority: Int
  private let value: (Element) -> String

  /// Creates a column with a display value closure.
  public init(
    _ title: String,
    constraint: FlexConstraint = .fill(1),
    dropPriority: Int = 0,
    value: @escaping (Element) -> String
  ) {
    self.title = title
    self.constraint = constraint
    self.dropPriority = dropPriority
    self.value = value
  }

  fileprivate func text(for element: Element) -> String {
    value(element)
  }
}

/// Presentation roles used by a table's header, selected rows, inactive rows, and rule.
public struct TableStyle: Equatable, Sendable {
  public var header: Style
  public var selection: Style
  public var inactiveSelection: Style
  public var rule: Style

  public init(
    header: Style = Style(attributes: .bold),
    selection: Style = Style(attributes: .reverse),
    inactiveSelection: Style = Style(attributes: .reverse),
    rule: Style = Style()
  ) {
    self.header = header
    self.selection = selection
    self.inactiveSelection = inactiveSelection
    self.rule = rule
  }
}

private enum _TableStyleKey: EnvironmentKey {
  static let defaultValue = TableStyle()
}

extension EnvironmentValues {
  /// The inherited presentation roles used by ``Table``.
  public var tableStyle: TableStyle {
    get { self[_TableStyleKey.self] }
    set { self[_TableStyleKey.self] = newValue }
  }
}

extension View {
  /// Sets presentation roles for descendant tables.
  public func tableStyle(_ style: TableStyle) -> some View {
    environment(\.tableStyle, style)
  }
}

/// A controlled, columnar collection with keyed selection and app-owned ordering.
public struct Table<Data: RandomAccessCollection>: View, _LayoutView, _ResponderView,
  _PointerResponderView
where Data.Element: Identifiable {
  public typealias Body = Never
  package typealias ResponderState = _TableResponderState

  private let data: Data
  private let selection: Binding<Data.Element.ID?>
  private let sortOrder: Binding<[SortDescriptor<Data.Element>]>?
  private let columns: [TableColumn<Data.Element>]
  private let onActivate: ((Data.Element) -> Void)?
  private let emptyMessage: String
  private let metrics: _TableMetrics
  private let indicatorMetrics: _ScrollIndicatorMetrics

  /// Creates a controlled table. The app retains data, selection, and optional sort order.
  public init(
    _ data: Data,
    selection: Binding<Data.Element.ID?>,
    sortOrder: Binding<[SortDescriptor<Data.Element>]>? = nil,
    columns: [TableColumn<Data.Element>],
    emptyMessage: String = "No items",
    onActivate: ((Data.Element) -> Void)? = nil
  ) {
    precondition(columns.isEmpty == false, "Table requires at least one column.")
    self.data = data
    self.selection = selection
    self.sortOrder = sortOrder
    self.columns = columns
    self.emptyMessage = emptyMessage
    self.onActivate = onActivate
    metrics = _TableMetrics()
    indicatorMetrics = _ScrollIndicatorMetrics()
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: _TableHeader(
          columns: columns,
          style: environment.tableStyle,
          sortOrder: sortOrder
        ),
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
    visit(
      _ViewChild(
        slot: .index(1),
        view: Divider(style: .light),
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )

    if data.isEmpty {
      visit(
        _ViewChild(
          slot: .index(2),
          view: _TableEmptyRow(message: emptyMessage, style: environment.tableStyle),
          environment: environment,
          environmentOverrides: environmentOverrides
        )
      )
    } else {
      for element in data {
        visit(
          _ViewChild(
            slot: .id(AnyHashable(element.id)),
            view: _TableRow(
              element: element,
              columns: columns,
              selected: selection.wrappedValue == element.id,
              focused: environment.isFocused || environment.isFocusWithin,
              selection: selection,
              style: environment.tableStyle
            ),
            environment: environment,
            environmentOverrides: environmentOverrides
          )
        )
      }
    }

    visit(
      _ViewChild(
        slot: .index(data.count + 2),
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
    let rowStart = bounds.origin.row
    children[0].place(
      at: TerminalPosition(column: bounds.origin.column, row: rowStart),
      proposal: ProposedSize(width: result.contentWidth, height: result.headerHeight),
      clip: bounds
    )
    children[1].place(
      at: TerminalPosition(
        column: bounds.origin.column, row: _tableAdd(rowStart, result.headerHeight)),
      proposal: ProposedSize(width: result.contentWidth, height: 1),
      clip: bounds
    )

    var rowOrigin = _tableAdd(rowStart, _tableAdd(result.headerHeight, 1))
    for index in 0..<result.rowCount {
      children[index + 2].place(
        at: TerminalPosition(
          column: bounds.origin.column, row: _tableSubtract(rowOrigin, metrics.offset)),
        proposal: ProposedSize(
          width: result.contentWidth, height: result.rowHeights[index]),
        clip: Rect(
          origin: bounds.origin,
          size: TerminalSize(columns: result.contentWidth, rows: bounds.size.rows)
        )
      )
      rowOrigin = _tableAdd(rowOrigin, result.rowHeights[index])
    }

    let indicatorIndex = result.rowCount + 2
    if result.overflow {
      children[indicatorIndex].place(
        at: TerminalPosition(
          column: _tableAdd(bounds.origin.column, result.contentWidth),
          row: bounds.origin.row
        ),
        proposal: ProposedSize(width: 1, height: bounds.size.rows),
        clip: bounds
      )
    } else {
      children[indicatorIndex].place(
        at: bounds.origin,
        proposal: ProposedSize(width: 0, height: 0),
        clip: bounds
      )
    }
  }

  package func _makeResponderState() -> _TableResponderState {
    _TableResponderState()
  }

  package func _updateResponderState(_ state: inout _TableResponderState) {
    state.offset = min(
      max(state.offset, 0), max(metrics.contentHeight - metrics.viewportHeight, 0))
    metrics.offset = state.offset
  }

  package func _handleEvent(
    _ event: InputEvent,
    state: inout _TableResponderState,
    context: inout ResponderContext
  ) -> EventDisposition {
    switch event {
    case .mouse(let mouse):
      guard case .scroll(let direction) = mouse.kind else {
        return .ignored
      }
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
        contentExtent: metrics.contentHeight,
        viewportExtent: metrics.viewportHeight,
        effectiveOffset: state.offset
      )
      context.setNeedsLayout()
      return .handled
    case .key(let key):
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
      switch key.code {
      case .enter:
        guard let selectedIndex else {
          return .ignored
        }
        onActivate?(elements[selectedIndex])
        return .handled
      case .up, .down, .pageUp, .pageDown, .home, .end:
        let target: Int
        switch key.code {
        case .up: target = max((selectedIndex ?? 0) - 1, 0)
        case .down: target = min((selectedIndex ?? -1) + 1, elements.count - 1)
        case .pageUp:
          target = max((selectedIndex ?? 0) - max(metrics.viewportHeight, 1), 0)
        case .pageDown:
          target = min(
            (selectedIndex ?? -1) + max(metrics.viewportHeight, 1),
            elements.count - 1
          )
        case .home: target = 0
        case .end: target = elements.count - 1
        default: target = 0
        }
        selection.wrappedValue = elements[target].id
        ensureVisible(target, state: &state, viewport: context.nodeBounds.size.rows)
        context.setNeedsLayout()
        return .handled
      default:
        return .ignored
      }
    default:
      return .ignored
    }
  }
  package func _handlePointer(
    _ event: PointerEvent,
    state: inout _TableResponderState,
    context: inout ResponderContext
  ) -> EventDisposition {
    switch event.phase {
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

  private func ensureVisible(
    _ index: Int,
    state: inout _TableResponderState,
    viewport: Int
  ) {
    guard index < metrics.rowStarts.count else {
      return
    }
    let top = _tableAdd(metrics.headerHeight + 1, metrics.rowStarts[index])
    let bottom = _tableAdd(top, metrics.rowHeights[index])
    let visible = max(viewport, metrics.viewportHeight, 1)
    if top < state.offset { state.offset = top }
    if bottom > _tableAdd(state.offset, visible) {
      state.offset = max(bottom - visible, 0)
    }
    state.offset = min(max(state.offset, 0), max(metrics.contentHeight - visible, 0))
    metrics.offset = state.offset
  }

  private func distribution(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> _TableDistribution {
    let rowCount = data.isEmpty ? 1 : data.count
    let children = Subviews(subviews)
    let headerNatural = children[0].sizeThatFits(.unspecified)
    var contentWidth = proposal.width.map { max($0, 0) } ?? headerNatural.columns
    var headerHeight = max(headerNatural.rows, 1)
    var rowHeights = (0..<rowCount).map { index in
      max(
        children[index + 2].sizeThatFits(ProposedSize(width: contentWidth, height: nil))
          .rows, 1)
    }
    var contentHeight = _tableAdd(
      headerHeight, _tableAdd(1, rowHeights.reduce(0, _tableAdd)))
    let viewport = max(proposal.height ?? contentHeight, 0)
    var overflow = contentHeight > viewport

    if overflow, let width = proposal.width {
      contentWidth = max(width - 1, 0)
      headerHeight = max(
        children[0].sizeThatFits(ProposedSize(width: contentWidth, height: nil)).rows, 1)
      rowHeights = (0..<rowCount).map { index in
        max(
          children[index + 2].sizeThatFits(ProposedSize(width: contentWidth, height: nil))
            .rows, 1)
      }
      contentHeight = _tableAdd(
        headerHeight, _tableAdd(1, rowHeights.reduce(0, _tableAdd)))
      overflow = contentHeight > viewport
    }

    metrics.contentHeight = contentHeight
    metrics.viewportHeight = viewport
    metrics.headerHeight = headerHeight
    metrics.rowHeights = rowHeights
    metrics.rowStarts = []
    var start = 0
    for height in rowHeights {
      metrics.rowStarts.append(start)
      start = _tableAdd(start, height)
    }
    metrics.offset = min(max(metrics.offset, 0), max(contentHeight - viewport, 0))
    indicatorMetrics.update(
      contentExtent: contentHeight,
      viewportExtent: viewport,
      effectiveOffset: metrics.offset
    )

    return _TableDistribution(
      rowCount: rowCount,
      contentWidth: contentWidth,
      headerHeight: headerHeight,
      rowHeights: rowHeights,
      overflow: overflow,
      size: TerminalSize(
        columns: proposal.width ?? _tableAdd(contentWidth, overflow ? 1 : 0),
        rows: proposal.height ?? contentHeight
      )
    )
  }
}

private struct _TableDistribution {
  let rowCount: Int
  let contentWidth: Int
  let headerHeight: Int
  let rowHeights: [Int]
  let overflow: Bool
  let size: TerminalSize
}

private final class _TableMetrics {
  var offset = 0
  var contentHeight = 0
  var viewportHeight = 0
  var headerHeight = 1
  var rowHeights: [Int] = []
  var rowStarts: [Int] = []
}

package struct _TableResponderState {
  package var offset = 0
}

private struct _TableHeader<Element>: View, _LayoutView {
  typealias Body = Never
  let columns: [TableColumn<Element>]
  let style: TableStyle
  let sortOrder: Binding<[SortDescriptor<Element>]>?

  func _visitChildren(
    in environment: EnvironmentValues, environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    for (index, column) in columns.enumerated() {
      visit(
        _ViewChild(
          slot: .index(index),
          view: _TableHeaderCell(
            column: column, style: style.header, sortOrder: sortOrder),
          environment: environment, environmentOverrides: environmentOverrides))
    }
  }

  func _sizeThatFits(_ proposal: ProposedSize, subviews: _LayoutSubviewsProxy)
    -> TerminalSize
  {
    let children = Subviews(subviews)
    let widths = _tableColumnWidths(
      columns: columns, proposal: proposal, subviews: children)
    let heights = children.indices.map {
      children[$0].sizeThatFits(ProposedSize(width: widths[$0], height: proposal.height))
        .rows
    }
    return TerminalSize(columns: _tableWidth(widths), rows: heights.max() ?? 0)
  }

  func _placeSubviews(
    in bounds: Rect, proposal: ProposedSize, subviews: _LayoutSubviewsProxy
  ) {
    let children = Subviews(subviews)
    let widths = _tableColumnWidths(
      columns: columns, proposal: proposal, subviews: children)
    var x = bounds.origin.column
    for index in children.indices {
      children[index].place(
        at: TerminalPosition(column: x, row: bounds.origin.row),
        proposal: ProposedSize(width: widths[index], height: bounds.size.rows),
        clip: bounds)
      x = _tableAdd(x, widths[index])
      if index != children.index(before: children.endIndex) { x = _tableAdd(x, 1) }
    }
  }
}

private struct _TableHeaderCell<Element>: View {
  let column: TableColumn<Element>
  let style: Style
  let sortOrder: Binding<[SortDescriptor<Element>]>?

  var body: some View {
    Text(column.title, style: style).truncation(.tail).onTap { _ in
      guard let sortOrder else {
        return
      }
      var order = sortOrder.wrappedValue
      if let index = order.firstIndex(where: { $0.key == column.title }) {
        order[index] = order[index].reversed()
      } else {
        order.insert(SortDescriptor(key: column.title), at: 0)
      }
      sortOrder.wrappedValue = order
    }
  }
}

private struct _TableRow<Element: Identifiable>: View, _LayoutView, _ResponderView,
  _PointerResponderView
{
  typealias Body = Never
  typealias ResponderState = Void
  let element: Element
  let columns: [TableColumn<Element>]
  let selected: Bool
  let focused: Bool
  let selection: Binding<Element.ID?>
  let style: TableStyle

  func _visitChildren(
    in environment: EnvironmentValues, environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    let cellStyle =
      selected ? (focused ? style.selection : style.inactiveSelection) : Style()
    for (index, column) in columns.enumerated() {
      visit(
        _ViewChild(
          slot: .index(index),
          view: Text(column.text(for: element), style: cellStyle).truncation(.tail),
          environment: environment, environmentOverrides: environmentOverrides))
    }
  }
  func _sizeThatFits(_ proposal: ProposedSize, subviews: _LayoutSubviewsProxy)
    -> TerminalSize
  {
    let children = Subviews(subviews)
    let widths = _tableColumnWidths(
      columns: columns, proposal: proposal, subviews: children)
    return TerminalSize(
      columns: _tableWidth(widths),
      rows: children.map { $0.sizeThatFits(.unspecified).rows }.max() ?? 0)
  }

  func _placeSubviews(
    in bounds: Rect, proposal: ProposedSize, subviews: _LayoutSubviewsProxy
  ) {
    let children = Subviews(subviews)
    let widths = _tableColumnWidths(
      columns: columns, proposal: proposal, subviews: children)
    var x = bounds.origin.column
    for index in children.indices {
      children[index].place(
        at: TerminalPosition(column: x, row: bounds.origin.row),
        proposal: ProposedSize(width: widths[index], height: bounds.size.rows),
        clip: bounds)
      x = _tableAdd(x, widths[index])
      if index != children.index(before: children.endIndex) { x = _tableAdd(x, 1) }
    }
  }

  func _makeResponderState() {}
  func _handleEvent(
    _ event: InputEvent, state: inout Void, context: inout ResponderContext
  ) -> EventDisposition { .ignored }
  func _handlePointer(
    _ event: PointerEvent, state: inout Void, context: inout ResponderContext
  ) -> EventDisposition {
    guard event.button == .left else {
      return .ignored
    }
    guard event.phase == .up else {
      return event.phase == .down ? .handled : .ignored
    }
    selection.wrappedValue = element.id
    context.setNeedsDisplay()
    return .handled
  }
  func _cancelResponderState(_ state: inout Void) {}
  func _updateResponderState(_ state: inout Void) {}
  func _updateResponderStateProjection(
    _ projection: inout _ResponderStateProjection, state: Void
  ) {}
}

private struct _TableEmptyRow: View {
  let message: String
  let style: TableStyle
  var body: some View { Text(message, style: style.inactiveSelection).truncation(.middle) }
}

private func _tableColumnWidths<Element>(
  columns: [TableColumn<Element>],
  proposal: ProposedSize,
  subviews: Subviews
) -> [Int] {
  guard columns.isEmpty == false else {
    return []
  }
  let ideals = columns.indices.map { index in
    index < subviews.count ? subviews[index].sizeThatFits(.unspecified).columns : 0
  }
  let minimums = columns.indices.map { index in
    index < subviews.count
      ? subviews[index].sizeThatFits(ProposedSize(width: 0, height: nil)).columns : 0
  }
  let available = proposal.width.map { max($0 - max(columns.count - 1, 0), 0) }
  let items = columns.indices.map { index in
    _FlexResolverItem.constraint(
      columns[index].constraint, available: available, measuredIdeal: ideals[index],
      measuredMinimum: minimums[index], priority: columns[index].dropPriority)
  }
  return _FlexResolver.resolve(available: available, spacing: 0, items: items).allocations
    .map { max($0, 0) }
}

private func _tableWidth(_ widths: [Int]) -> Int {
  guard widths.isEmpty == false else {
    return 0
  }
  return _tableAdd(widths.reduce(0, _tableAdd), max(widths.count - 1, 0))
}

private func _tableAdd(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.addingReportingOverflow(rhs)
  return result.overflow ? (rhs >= 0 ? Int.max : Int.min) : result.partialValue
}

private func _tableSubtract(_ lhs: Int, _ rhs: Int) -> Int {
  let result = lhs.subtractingReportingOverflow(rhs)
  return result.overflow ? (rhs >= 0 ? Int.min : Int.max) : result.partialValue
}
