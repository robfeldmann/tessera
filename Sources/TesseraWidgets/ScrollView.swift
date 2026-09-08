import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput

package final class _ScrollResponderState {
  enum DragAxis { case horizontal, vertical }
  var contentSize = TerminalSize(columns: 0, rows: 0)
  var viewportSize = TerminalSize(columns: 0, rows: 0)
  var isEnabled = true
  var dragAxis: DragAxis?
  var dragStartPosition: TerminalPosition?
  var dragStartOffset: TerminalPosition?
}

/// A viewport that presents a translated portion of its content.
///
/// A viewport with a fixed proposal reserves an overflowing indicator inside that assigned
/// rectangle. When its parent leaves the cross axis unspecified, the viewport includes the
/// indicator's one-cell edge in its natural size so the edge does not replace content.
///
/// A scroll view marked ``focusable(whileScrollable:)`` registers itself as focusable
/// only while its content actually overflows the viewport on an enabled axis, so focus
/// traversal never stops on a viewport with nothing to scroll. Focus is telegraphed by
/// the overflow indicators themselves: a focused viewport paints its indicator thumbs in
/// the focus accent instead of decorating the content it scrolls.
public struct ScrollView<Content: View>: View, _FocusableView,
  _FocusAppearanceFallbackRendering, _FocusAppearanceResponder, _LayoutView,
  _ResponderView,
  _PointerResponderView
{
  public typealias Body = Never

  private struct ViewportGeometry {
    let size: TerminalSize
    let showsVerticalIndicator: Bool
    let showsHorizontalIndicator: Bool
  }

  private let axes: Axis.Set
  private var focusID: FocusID?
  private let offset: Binding<TerminalPosition>?
  private let content: Content
  private let verticalIndicatorMetrics: _ScrollIndicatorMetrics
  private let horizontalIndicatorMetrics: _ScrollIndicatorMetrics
  private let responderState: _ScrollResponderState

  /// Creates a scroll view that measures intrinsically along each scrolling axis.
  public init(
    _ axes: Axis.Set = .vertical,
    offset: Binding<TerminalPosition>? = nil,
    @ViewBuilder content: () -> Content
  ) {
    self.axes = axes
    self.offset = offset
    self.content = content()
    verticalIndicatorMetrics = _ScrollIndicatorMetrics()
    horizontalIndicatorMetrics = _ScrollIndicatorMetrics()
    responderState = _ScrollResponderState()
  }

  /// Returns a scroll view that owns `id` and joins keyboard focus traversal only while
  /// its content overflows the viewport on an enabled axis, withdrawing again when a
  /// resize or content change makes everything fit.
  ///
  /// Requires an `offset` binding: scrolling is the only interaction the focus stop can
  /// perform, so a viewport without one never registers. Prefer this over the
  /// unconditional `focusable(_:)` wrapper for viewports whose only interaction is
  /// scrolling; the wrapper keeps a stable Tab stop even when there is nothing to do.
  /// Combining both registers two nested focus stops and is a caller mistake.
  public func focusable(whileScrollable id: FocusID) -> Self {
    var copy = self
    copy.focusID = id
    return copy
  }

  package func _focusID(in environment: EnvironmentValues) -> FocusID? {
    guard environment.isEnabled, let focusID, offset != nil else {
      return nil
    }
    let horizontal =
      axes.contains(.horizontal)
      && responderState.contentSize.columns > responderState.viewportSize.columns
    let vertical =
      axes.contains(.vertical)
      && responderState.contentSize.rows > responderState.viewportSize.rows
    return horizontal || vertical ? focusID : nil
  }

  package func _resolveFocusAppearance(
    in context: FocusAppearanceContext
  ) -> FocusAppearanceDisposition {
    .deferred
  }

  /// Focus visibility rides the overflow indicators (see `ScrollIndicator`): painting
  /// nothing here keeps scrolled content unobscured. Callers that focus a viewport with
  /// no visible indicator can host a ring with `focusAppearance(_:)` or a `Box`.
  package func _renderFocusAppearanceFallback(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  ) {}

  package func _makeResponderState() -> _ScrollResponderState {
    responderState
  }

  package func _updateResponderState(_ state: inout _ScrollResponderState) {
    responderState.contentSize = state.contentSize
    responderState.viewportSize = state.viewportSize
    state = responderState
  }

  package func _handleEvent(
    _ event: InputEvent,
    state: inout _ScrollResponderState,
    context: inout ResponderContext
  ) -> EventDisposition {
    guard
      context.isFocused || context.isFocusWithin,
      state.isEnabled,
      let offset,
      case .key(let key) = event,
      key.kind == .press || key.kind == .repeat,
      key.modifiers.isEmpty
    else {
      return .ignored
    }

    let requested = offset.wrappedValue
    let current = effectiveOffset(
      contentSize: state.contentSize,
      viewportSize: state.viewportSize
    )
    let maximumColumn = max(state.contentSize.columns - state.viewportSize.columns, 0)
    let maximumRow = max(state.contentSize.rows - state.viewportSize.rows, 0)
    var column: Int?
    var row: Int?

    switch key.code {
    case .left where axes.contains(.horizontal):
      column = current.column > 0 ? current.column - 1 : current.column
    case .right where axes.contains(.horizontal):
      column = current.column < maximumColumn ? current.column + 1 : current.column
    case .up where axes.contains(.vertical):
      row = current.row > 0 ? current.row - 1 : current.row
    case .down where axes.contains(.vertical):
      row = current.row < maximumRow ? current.row + 1 : current.row
    case .pageUp where axes.contains(.vertical):
      row =
        current.row > state.viewportSize.rows
        ? current.row - state.viewportSize.rows
        : 0
    case .pageDown where axes.contains(.vertical):
      row =
        current.row < maximumRow - state.viewportSize.rows
        ? current.row + state.viewportSize.rows
        : maximumRow
    case .home:
      if axes.contains(.horizontal) {
        column = 0
      }
      if axes.contains(.vertical) {
        row = 0
      }
    case .end:
      if axes.contains(.horizontal) {
        column = maximumColumn
      }
      if axes.contains(.vertical) {
        row = maximumRow
      }
    default:
      return .ignored
    }

    let movedColumn = column.map { $0 != current.column } ?? false
    let movedRow = row.map { $0 != current.row } ?? false
    guard movedColumn || movedRow else {
      return .ignored
    }

    offset.wrappedValue = TerminalPosition(
      column: column ?? requested.column,
      row: row ?? requested.row
    )
    context.setNeedsLayout()
    return .handled
  }

  package func _handlePointer(
    _ event: PointerEvent,
    state: inout _ScrollResponderState,
    context: inout ResponderContext
  ) -> EventDisposition {
    guard state.isEnabled, let offset else {
      return .ignored
    }
    let maximumColumn = max(state.contentSize.columns - state.viewportSize.columns, 0)
    let maximumRow = max(state.contentSize.rows - state.viewportSize.rows, 0)
    let current = effectiveOffset(
      contentSize: state.contentSize, viewportSize: state.viewportSize)

    switch event.phase {
    case .scrollUp, .scrollDown, .scrollLeft, .scrollRight:
      var nextColumn = current.column
      var nextRow = current.row
      switch event.phase {
      case .scrollUp where axes.contains(.vertical): nextRow -= 1
      case .scrollDown where axes.contains(.vertical): nextRow += 1
      case .scrollLeft where axes.contains(.horizontal): nextColumn -= 1
      case .scrollRight where axes.contains(.horizontal): nextColumn += 1
      default: return .ignored
      }
      let next = TerminalPosition(
        column: min(max(nextColumn, 0), maximumColumn),
        row: min(max(nextRow, 0), maximumRow))
      guard next != current else {
        return .ignored
      }
      offset.wrappedValue = next
      context.setNeedsLayout()
      return .handled

    case .down where event.button == .left:
      let localColumn = event.position.column - context.nodeBounds.origin.column
      let localRow = event.position.row - context.nodeBounds.origin.row
      if axes.contains(.vertical), state.contentSize.rows > state.viewportSize.rows,
        localColumn == max(context.nodeBounds.size.columns - 1, 0),
        localRow >= 0, localRow < state.viewportSize.rows
      {
        state.dragAxis = .vertical
        state.dragStartPosition = event.position
        state.dragStartOffset = current
        _ = setTrackOffset(
          axis: .vertical, trackPosition: localRow, offset: current,
          state: state, binding: offset, context: &context)
        return .handled
      }
      if axes.contains(.horizontal),
        state.contentSize.columns > state.viewportSize.columns,
        localRow == max(context.nodeBounds.size.rows - 1, 0),
        localColumn >= 0, localColumn < state.viewportSize.columns
      {
        state.dragAxis = .horizontal
        state.dragStartPosition = event.position
        state.dragStartOffset = current
        _ = setTrackOffset(
          axis: .horizontal, trackPosition: localColumn, offset: current,
          state: state, binding: offset, context: &context)
        return .handled
      }
      return .ignored

    case .move:
      guard let axis = state.dragAxis, let start = state.dragStartPosition,
        let initial = state.dragStartOffset
      else {
        return .ignored
      }
      let delta =
        axis == .vertical
        ? event.position.row - start.row
        : event.position.column - start.column
      let contentExtent =
        axis == .vertical ? state.contentSize.rows : state.contentSize.columns
      let viewportExtent =
        axis == .vertical ? state.viewportSize.rows : state.viewportSize.columns
      let trackLength = max(viewportExtent, 0)
      let thumbLength = min(
        max(1, (trackLength * viewportExtent) / max(contentExtent, 1)), trackLength)
      let trackTravel = max(trackLength - thumbLength, 1)
      let offsetTravel = max(contentExtent - viewportExtent, 0)
      let movedRow =
        initial.row + (axis == .vertical ? delta * offsetTravel / trackTravel : 0)
      let movedColumn =
        initial.column + (axis == .horizontal ? delta * offsetTravel / trackTravel : 0)
      let next = TerminalPosition(
        column: min(max(movedColumn, 0), maximumColumn),
        row: min(max(movedRow, 0), maximumRow))
      guard next != current else {
        return .handled
      }
      offset.wrappedValue = next
      context.setNeedsLayout()
      return .handled

    case .up, .cancel:
      guard state.dragAxis != nil else {
        return .ignored
      }
      state.dragAxis = nil
      state.dragStartPosition = nil
      state.dragStartOffset = nil
      return .handled

    default:
      return .ignored
    }
  }

  package func _revealFocus(
    _ focusedBounds: Rect,
    state: inout _ScrollResponderState,
    context: inout ResponderContext
  ) -> Bool {
    guard state.isEnabled, let offset else {
      return false
    }
    let viewport = context.nodeBounds
    let current = effectiveOffset(
      contentSize: state.contentSize, viewportSize: state.viewportSize)
    var next = current
    if axes.contains(.vertical) {
      if focusedBounds.origin.row < viewport.origin.row {
        next = TerminalPosition(
          column: next.column,
          row: next.row - (viewport.origin.row - focusedBounds.origin.row))
      } else if focusedBounds.maxRow > viewport.maxRow {
        next = TerminalPosition(
          column: next.column, row: next.row + (focusedBounds.maxRow - viewport.maxRow))
      }
    }
    if axes.contains(.horizontal) {
      if focusedBounds.origin.column < viewport.origin.column {
        next = TerminalPosition(
          column: next.column - (viewport.origin.column - focusedBounds.origin.column),
          row: next.row)
      } else if focusedBounds.maxColumn > viewport.maxColumn {
        next = TerminalPosition(
          column: next.column + (focusedBounds.maxColumn - viewport.maxColumn),
          row: next.row)
      }
    }
    let maximum = TerminalPosition(
      column: max(state.contentSize.columns - state.viewportSize.columns, 0),
      row: max(state.contentSize.rows - state.viewportSize.rows, 0))
    next = TerminalPosition(
      column: min(max(next.column, 0), maximum.column),
      row: min(max(next.row, 0), maximum.row))
    guard next != current else {
      return false
    }
    offset.wrappedValue = next
    context.setNeedsLayout()
    return true
  }

  private func setTrackOffset(
    axis: Axis,
    trackPosition: Int,
    offset: TerminalPosition,
    state: _ScrollResponderState,
    binding: Binding<TerminalPosition>,
    context: inout ResponderContext
  ) -> Bool {
    let contentExtent =
      axis == .vertical ? state.contentSize.rows : state.contentSize.columns
    let viewportExtent =
      axis == .vertical ? state.viewportSize.rows : state.viewportSize.columns
    let maximum = max(contentExtent - viewportExtent, 0)
    let trackLength = max(viewportExtent, 0)
    let thumbLength = min(
      max(1, (trackLength * viewportExtent) / max(contentExtent, 1)), trackLength)
    let travel = max(trackLength - thumbLength, 1)
    let thumbStart = maximum == 0 ? 0 : offsetValue(axis, offset) * travel / maximum
    let target: Int
    if trackPosition < thumbStart {
      target = offsetValue(axis, offset) - viewportExtent
    } else if trackPosition >= thumbStart + thumbLength {
      target = offsetValue(axis, offset) + viewportExtent
    } else {
      return false
    }
    let clamped = min(max(target, 0), maximum)
    guard clamped != offsetValue(axis, offset) else {
      return false
    }
    let next =
      axis == .vertical
      ? TerminalPosition(column: offset.column, row: clamped)
      : TerminalPosition(column: clamped, row: offset.row)
    binding.wrappedValue = next
    context.setNeedsLayout()
    return true
  }

  private func offsetValue(_ axis: Axis, _ offset: TerminalPosition) -> Int {
    axis == .vertical ? offset.row : offset.column
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    responderState.isEnabled = environment.isEnabled
    var childEnvironment = environment
    if focusID != nil {
      childEnvironment.isFocused = isFocused(in: environment)
    }
    var index = 0
    _visitLayoutChildren(
      content,
      in: childEnvironment,
      environmentOverrides: environmentOverrides
    ) { child in
      visit(
        _ViewChild(
          slot: .index(index),
          view: child.view,
          environment: child.environment,
          environmentOverrides: child.environmentOverrides
        )
      )
      index += 1
    }
    visit(
      _ViewChild(
        slot: .index(index),
        view: ScrollIndicator(axis: .vertical, metrics: verticalIndicatorMetrics),
        environment: childEnvironment,
        environmentOverrides: environmentOverrides
      )
    )
    visit(
      _ViewChild(
        slot: .index(index + 1),
        view: ScrollIndicator(axis: .horizontal, metrics: horizontalIndicatorMetrics),
        environment: childEnvironment,
        environmentOverrides: environmentOverrides
      )
    )
  }

  /// Whether this scroll view is focused, either through an enclosing `focusable`
  /// wrapper's environment or through its own focus identity.
  private func isFocused(in environment: EnvironmentValues) -> Bool {
    environment.isFocused || (focusID != nil && environment._focusedID == focusID)
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    let childProposal = contentProposal(for: proposal)
    let contentSize = measuredContentSize(
      subviews,
      proposal: childProposal,
      contentSubviewCount: contentSubviewCount(in: subviews)
    )
    let seedVerticalIndicator =
      axes.contains(.vertical)
      && proposal.height.map { contentSize.rows > $0 } == true
    let seedHorizontalIndicator =
      axes.contains(.horizontal)
      && proposal.width.map { contentSize.columns > $0 } == true
    var size = TerminalSize(
      columns: proposal.width
        ?? contentSize.columns + (seedVerticalIndicator ? 1 : 0),
      rows: proposal.height
        ?? contentSize.rows + (seedHorizontalIndicator ? 1 : 0)
    )

    // A fixed viewport owns indicator space inside its assigned rectangle. When the
    // parent leaves the cross axis unspecified, include that edge in the natural size so
    // the indicator does not consume and clip the content's final row or column. Resolve
    // both axes together because reserving one edge can induce overflow on the other.
    for _ in 0..<2 {
      let viewport = viewportGeometry(
        contentSize: contentSize,
        bounds: Rect(
          origin: TerminalPosition(column: 0, row: 0),
          size: size
        )
      )
      let resolved = TerminalSize(
        columns: proposal.width
          ?? contentSize.columns + (viewport.showsVerticalIndicator ? 1 : 0),
        rows: proposal.height
          ?? contentSize.rows + (viewport.showsHorizontalIndicator ? 1 : 0)
      )
      guard resolved != size else {
        break
      }
      size = resolved
    }
    return size
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    let contentSubviewCount = contentSubviewCount(in: subviews)
    var childProposal = contentProposal(for: proposal)
    var contentSize = measuredContentSize(
      subviews,
      proposal: childProposal,
      contentSubviewCount: contentSubviewCount
    )
    var viewport = viewportGeometry(contentSize: contentSize, bounds: bounds)

    // Indicator reservation shrinks the viewport, so content must be re-proposed the
    // reserved extents on the non-scrolling axes or its trailing cells would land under
    // the indicator chrome. Seeding keeps reservation monotonic within the pass.
    let reservedProposal = contentProposal(for: proposal, reservedBy: viewport)
    if reservedProposal != childProposal {
      childProposal = reservedProposal
      contentSize = measuredContentSize(
        subviews,
        proposal: childProposal,
        contentSubviewCount: contentSubviewCount
      )
      viewport = viewportGeometry(
        contentSize: contentSize,
        bounds: bounds,
        verticalSeed: viewport.showsVerticalIndicator,
        horizontalSeed: viewport.showsHorizontalIndicator
      )
    }
    responderState.contentSize = contentSize
    responderState.viewportSize = viewport.size
    let translation = effectiveOffset(
      contentSize: contentSize,
      viewportSize: viewport.size
    )
    let contentBounds = Rect(origin: bounds.origin, size: viewport.size)
    let origin = TerminalPosition(
      column: translated(bounds.origin.column, by: translation.column),
      row: translated(bounds.origin.row, by: translation.row)
    )

    let subviews = Subviews(subviews)
    for index in 0..<contentSubviewCount {
      subviews[index].place(at: origin, proposal: childProposal, clip: contentBounds)
    }

    if viewport.showsVerticalIndicator {
      verticalIndicatorMetrics.update(
        contentExtent: contentSize.rows,
        viewportExtent: viewport.size.rows,
        effectiveOffset: translation.row
      )
      subviews[contentSubviewCount].place(
        at: TerminalPosition(
          column: contentBounds.maxColumn,
          row: contentBounds.origin.row
        ),
        proposal: ProposedSize(width: 1, height: viewport.size.rows)
      )
    }

    if viewport.showsHorizontalIndicator {
      horizontalIndicatorMetrics.update(
        contentExtent: contentSize.columns,
        viewportExtent: viewport.size.columns,
        effectiveOffset: translation.column
      )
      subviews[contentSubviewCount + 1].place(
        at: TerminalPosition(
          column: contentBounds.origin.column,
          row: contentBounds.maxRow
        ),
        proposal: ProposedSize(width: viewport.size.columns, height: 1)
      )
    }
  }

  private func contentProposal(for proposal: ProposedSize) -> ProposedSize {
    ProposedSize(
      width: axes.contains(.horizontal) ? nil : proposal.width,
      height: axes.contains(.vertical) ? nil : proposal.height
    )
  }

  /// The content proposal once indicator reservation is known: reserved extents replace
  /// the proposed extents on non-scrolling axes so chrome and content never share cells.
  /// Axes the parent left unspecified stay unspecified.
  private func contentProposal(
    for proposal: ProposedSize,
    reservedBy viewport: ViewportGeometry
  ) -> ProposedSize {
    ProposedSize(
      width: axes.contains(.horizontal)
        ? nil : proposal.width.map { _ in viewport.size.columns },
      height: axes.contains(.vertical)
        ? nil : proposal.height.map { _ in viewport.size.rows }
    )
  }

  private func measuredContentSize(
    _ subviews: _LayoutSubviewsProxy,
    proposal: ProposedSize,
    contentSubviewCount: Int
  ) -> TerminalSize {
    var columns = 0
    var rows = 0
    for index in 0..<contentSubviewCount {
      let size = subviews[index].measure(proposal)
      columns = max(columns, size.columns)
      rows = max(rows, size.rows)
    }
    return TerminalSize(columns: columns, rows: rows)
  }

  private func contentSubviewCount(in subviews: _LayoutSubviewsProxy) -> Int {
    max(subviews.count - 2, 0)
  }

  private func viewportGeometry(
    contentSize: TerminalSize,
    bounds: Rect,
    verticalSeed: Bool = false,
    horizontalSeed: Bool = false
  ) -> ViewportGeometry {
    let availableSize = TerminalSize(
      columns: max(bounds.size.columns, 0),
      rows: max(bounds.size.rows, 0)
    )
    var showsVerticalIndicator = verticalSeed
    var showsHorizontalIndicator = horizontalSeed

    // Each reservation can induce overflow on the other axis. There are only two axes,
    // so this monotonic fixed point is reached after at most two additions.
    for _ in 0..<2 {
      let nextVertical =
        showsVerticalIndicator
        || shouldShowVerticalIndicator(
          contentSize: contentSize,
          availableSize: availableSize,
          horizontalReserved: showsHorizontalIndicator
        )
      let nextHorizontal =
        showsHorizontalIndicator
        || shouldShowHorizontalIndicator(
          contentSize: contentSize,
          availableSize: availableSize,
          verticalReserved: showsVerticalIndicator
        )

      guard
        nextVertical != showsVerticalIndicator
          || nextHorizontal != showsHorizontalIndicator
      else {
        break
      }

      showsVerticalIndicator = nextVertical
      showsHorizontalIndicator = nextHorizontal
    }

    return ViewportGeometry(
      size: viewportSize(
        availableSize: availableSize,
        verticalReserved: showsVerticalIndicator,
        horizontalReserved: showsHorizontalIndicator
      ),
      showsVerticalIndicator: showsVerticalIndicator,
      showsHorizontalIndicator: showsHorizontalIndicator
    )
  }

  private func shouldShowVerticalIndicator(
    contentSize: TerminalSize,
    availableSize: TerminalSize,
    horizontalReserved: Bool
  ) -> Bool {
    guard axes.contains(.vertical) else {
      return false
    }

    let viewportSize = viewportSize(
      availableSize: availableSize,
      verticalReserved: true,
      horizontalReserved: horizontalReserved
    )
    return viewportSize.columns > 0
      && viewportSize.rows > 0
      && contentSize.rows > viewportSize.rows
  }

  private func shouldShowHorizontalIndicator(
    contentSize: TerminalSize,
    availableSize: TerminalSize,
    verticalReserved: Bool
  ) -> Bool {
    guard axes.contains(.horizontal) else {
      return false
    }

    let viewportSize = viewportSize(
      availableSize: availableSize,
      verticalReserved: verticalReserved,
      horizontalReserved: true
    )
    return viewportSize.columns > 0
      && viewportSize.rows > 0
      && contentSize.columns > viewportSize.columns
  }

  private func viewportSize(
    availableSize: TerminalSize,
    verticalReserved: Bool,
    horizontalReserved: Bool
  ) -> TerminalSize {
    TerminalSize(
      columns: max(availableSize.columns - (verticalReserved ? 1 : 0), 0),
      rows: max(availableSize.rows - (horizontalReserved ? 1 : 0), 0)
    )
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
