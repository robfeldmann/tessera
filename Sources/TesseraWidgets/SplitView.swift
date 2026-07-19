import TesseraCore
import TesseraLayout
import TesseraTerminalCore

/// Application-owned sizing configuration for one pane in a ``SplitView``.
public struct SplitViewPaneSizing: Hashable {
  /// The pane's guaranteed extent along the split axis.
  public let minimum: Int

  /// The pane's preferred extent, clamped to ``minimum`` and ``maximum``.
  public var requestedIdeal: Int {
    didSet {
      requestedIdeal = clamped(requestedIdeal)
    }
  }

  /// The pane's optional maximum extent along the split axis.
  public let maximum: Int?

  /// Creates a valid sizing range, clamping all values to whole nonnegative cells.
  public init(minimum: Int = 0, requestedIdeal: Int, maximum: Int? = nil) {
    let minimum = Swift.max(minimum, 0)
    self.minimum = minimum
    self.maximum = maximum.map { Swift.max($0, minimum) }
    self.requestedIdeal = Self.clamped(
      requestedIdeal,
      minimum: minimum,
      maximum: self.maximum
    )
  }

  private static func clamped(_ value: Int, minimum: Int, maximum: Int?) -> Int {
    Swift.min(Swift.max(value, minimum), maximum ?? Int.max)
  }

  private func clamped(_ value: Int) -> Int {
    Self.clamped(value, minimum: minimum, maximum: maximum)
  }
}

/// Application-owned configuration for one pane in a ``SplitView``.
public struct SplitViewPane: Identifiable, Hashable {
  /// The stable identity of this pane.
  public let id: AnyHashable

  /// The pane's sizing configuration along the split axis.
  public var sizing: SplitViewPaneSizing

  /// Whether this pane is omitted from the visible pane sequence.
  public var isCollapsed: Bool

  /// Creates a pane configuration controlled by the application.
  public init<ID: Hashable>(
    id: ID,
    sizing: SplitViewPaneSizing,
    isCollapsed: Bool = false
  ) {
    self.id = AnyHashable(id)
    self.sizing = sizing
    self.isCollapsed = isCollapsed
  }
}

/// Places controlled panes in a horizontal or vertical sequence with dividers between visible panes.
public struct SplitView<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let axis: Binding<Axis>
  private let panes: Binding<[SplitViewPane]>
  private let content: Content

  /// Creates a controlled split view.
  public init(
    axis: Binding<Axis> = .constant(.horizontal),
    panes: Binding<[SplitViewPane]>,
    @ViewBuilder content: () -> Content
  ) {
    self.axis = axis
    self.panes = panes
    self.content = content()
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var contentChildren: [_ViewChild] = []
    _visitLayoutChildren(
      content,
      in: environment,
      environmentOverrides: environmentOverrides
    ) {
      contentChildren.append($0)
    }

    let configuration = validatedConfiguration(contentCount: contentChildren.count)
    guard configuration.count == contentChildren.count else {
      return
    }

    let splitAxis = axis.wrappedValue
    var childEnvironment: EnvironmentValues

    for (index, child) in contentChildren.enumerated() {
      childEnvironment = child.environment
      childEnvironment._stackAxis = splitAxis
      visit(
        _ViewChild(
          slot: .id(configuration[index].id),
          view: framedPane(
            child.view, configuration: configuration[index], axis: splitAxis),
          environment: childEnvironment,
          environmentOverrides: child.environmentOverrides + ["stackAxis"]
        )
      )

      guard configuration[index].isCollapsed == false else {
        continue
      }

      var followingVisiblePane: Int?
      for following in configuration.indices
      where following > index && !configuration[following].isCollapsed {
        followingVisiblePane = following
        break
      }
      guard let followingVisiblePane else {
        continue
      }

      visit(
        _ViewChild(
          slot: .explicit(
            AnyHashable(
              _SplitViewDividerID(
                leading: configuration[index].id,
                trailing: configuration[followingVisiblePane].id
              )
            )
          ),
          view: Divider(),
          environment: childEnvironment,
          environmentOverrides: child.environmentOverrides + ["stackAxis"]
        )
      )
    }
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    guard let layout = layout(for: subviews.count) else {
      return TerminalSize(columns: 0, rows: 0)
    }
    return layout.sizeThatFits(proposal, subviews: Subviews(subviews))
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    guard let layout = layout(for: subviews.count) else {
      return
    }
    layout.placeSubviews(in: bounds, proposal: proposal, subviews: Subviews(subviews))
  }

  private func validatedConfiguration(contentCount: Int) -> [SplitViewPane] {
    let configuration = panes.wrappedValue
    guard configuration.count == contentCount else {
      return []
    }

    var ids = Set<AnyHashable>()
    guard configuration.allSatisfy({ ids.insert($0.id).inserted }) else {
      return []
    }
    return configuration
  }

  private func framedPane(
    _ content: any View,
    configuration: SplitViewPane,
    axis: Axis
  ) -> any View {
    func open<PaneContent: View>(_ content: PaneContent) -> any View {
      _SplitPane(
        content: content,
        axis: axis,
        requestedIdeal: configuration.sizing.requestedIdeal
      )
    }
    return open(content)
  }

  private func layout(for subviewCount: Int) -> _SplitViewLayout? {
    let configuration = panes.wrappedValue
    var ids = Set<AnyHashable>()
    guard configuration.allSatisfy({ ids.insert($0.id).inserted }) else {
      return nil
    }
    let expectedSubviewCount =
      configuration.count
      + max(configuration.filter { !$0.isCollapsed }.count - 1, 0)
    guard expectedSubviewCount == subviewCount else {
      return nil
    }
    return _SplitViewLayout(axis: axis.wrappedValue, panes: configuration)
  }
}

private struct _SplitPane<Content: View>: View, _LayoutView {
  typealias Body = Never

  let content: Content
  let axis: Axis
  let requestedIdeal: Int

  package func _visitChildren(
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

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    let main = main(of: proposal) ?? requestedIdeal
    guard let child = Subviews(subviews).first else {
      return size(main: main, cross: 0)
    }
    let childSize = child.sizeThatFits(
      proposedSize(main: main, cross: cross(of: proposal))
    )
    return size(
      main: main,
      cross: cross(of: proposal) ?? cross(of: childSize)
    )
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    guard let child = Subviews(subviews).first else {
      return
    }
    child.place(
      at: bounds.origin,
      proposal: proposedSize(
        main: main(of: proposal) ?? requestedIdeal,
        cross: cross(of: bounds.size)
      )
    )
  }

  private func main(of proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.width
    case .vertical:
      proposal.height
    }
  }

  private func cross(of proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.height
    case .vertical:
      proposal.width
    }
  }

  private func cross(of size: TerminalSize) -> Int {
    switch axis {
    case .horizontal:
      size.rows
    case .vertical:
      size.columns
    }
  }

  private func proposedSize(main: Int?, cross: Int?) -> ProposedSize {
    switch axis {
    case .horizontal:
      ProposedSize(width: main, height: cross)
    case .vertical:
      ProposedSize(width: cross, height: main)
    }
  }

  private func size(main: Int, cross: Int) -> TerminalSize {
    switch axis {
    case .horizontal:
      TerminalSize(columns: main, rows: cross)
    case .vertical:
      TerminalSize(columns: cross, rows: main)
    }
  }
}

private struct _SplitViewDividerID: Hashable {
  let leading: AnyHashable
  let trailing: AnyHashable
}

/// An immutable pane frame resolved for one SplitView layout pass.
package struct _SplitViewResolvedPaneFrame {
  package let id: AnyHashable
  package let frame: Rect
}

package struct _SplitViewLayout: Layout {
  let axis: Axis
  let panes: [SplitViewPane]

  package func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    let allocations = allocations(proposal: proposal, subviews: subviews)
    return size(main: allocations.totalMain, cross: allocations.cross)
  }

  package func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    let allocations = allocations(proposal: proposal, subviews: subviews)
    let placementCross = Swift.max(cross(of: bounds.size), 0)
    let crossOrigin = cross(of: bounds.origin)
    var mainOrigin = main(of: bounds.origin)
    var subviewIndex = 0

    for index in panes.indices {
      let pane = panes[index]
      guard pane.isCollapsed == false else {
        subviewIndex += 1
        continue
      }

      let paneFrame = frame(
        main: mainOrigin,
        cross: crossOrigin,
        mainSize: allocations.paneMain[index],
        crossSize: placementCross
      )
      subviews[subviewIndex].place(
        at: paneFrame.origin,
        proposal: proposedSize(main: allocations.paneMain[index], cross: placementCross),
        clip: paneFrame
      )
      subviewIndex += 1
      mainOrigin = _saturatingAdd(mainOrigin, allocations.paneMain[index])

      guard hasVisiblePane(after: index) else {
        continue
      }

      let dividerFrame = frame(
        main: mainOrigin,
        cross: crossOrigin,
        mainSize: allocations.dividerMain[index],
        crossSize: placementCross
      )
      subviews[subviewIndex].place(
        at: dividerFrame.origin,
        proposal: proposedSize(
          main: allocations.dividerMain[index], cross: placementCross),
        clip: dividerFrame
      )
      subviewIndex += 1
      mainOrigin = _saturatingAdd(mainOrigin, allocations.dividerMain[index])
    }
  }

  /// Resolves pane frames for the current layout pass without retaining layout state.
  package func resolvedPaneFrames(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) -> [_SplitViewResolvedPaneFrame] {
    let allocations = allocations(proposal: proposal, subviews: subviews)
    let placementCross = Swift.max(cross(of: bounds.size), 0)
    let crossOrigin = cross(of: bounds.origin)
    var mainOrigin = main(of: bounds.origin)
    var frames: [_SplitViewResolvedPaneFrame] = []

    for index in panes.indices {
      guard panes[index].isCollapsed == false else {
        continue
      }
      let paneFrame = frame(
        main: mainOrigin,
        cross: crossOrigin,
        mainSize: allocations.paneMain[index],
        crossSize: placementCross
      )
      frames.append(_SplitViewResolvedPaneFrame(id: panes[index].id, frame: paneFrame))
      mainOrigin = _saturatingAdd(mainOrigin, allocations.paneMain[index])
      if hasVisiblePane(after: index) {
        mainOrigin = _saturatingAdd(mainOrigin, allocations.dividerMain[index])
      }
    }

    return frames
  }

  private func allocations(
    proposal: ProposedSize,
    subviews: Subviews
  ) -> _SplitViewAllocations {
    let crossProposal = cross(of: proposal)
    var items: [_FlexResolverItem] = []
    var entries: [_SplitViewAllocationEntry] = []
    var subviewIndex = 0

    for index in panes.indices {
      let pane = panes[index]
      guard pane.isCollapsed == false else {
        subviewIndex += 1
        continue
      }

      items.append(
        .range(
          minimum: pane.sizing.minimum,
          ideal: pane.sizing.requestedIdeal,
          maximum: pane.sizing.maximum,
          priority: subviews[subviewIndex].priority
        )
      )
      entries.append(.pane(index: index, subviewIndex: subviewIndex))
      subviewIndex += 1

      guard hasVisiblePane(after: index) else {
        continue
      }
      items.append(.fixed(1))
      entries.append(.divider(after: index, subviewIndex: subviewIndex))
      subviewIndex += 1
    }

    let resolution = _FlexResolver.resolve(
      available: main(of: proposal),
      spacing: 0,
      items: items
    )
    var paneMain = Array(repeating: 0, count: panes.count)
    var dividerMain = Array(repeating: 0, count: panes.count)
    var largestCross = 0

    for (index, entry) in entries.enumerated() {
      let allocation = resolution.allocations[index]
      switch entry {
      case .pane(let paneIndex, let subviewIndex):
        paneMain[paneIndex] = allocation
        let measured = subviews[subviewIndex].sizeThatFits(
          proposedSize(main: allocation, cross: crossProposal)
        )
        largestCross = Swift.max(largestCross, cross(of: measured), 0)
      case .divider(let paneIndex, let subviewIndex):
        dividerMain[paneIndex] = allocation
        let measured = subviews[subviewIndex].sizeThatFits(
          proposedSize(main: allocation, cross: crossProposal)
        )
        largestCross = Swift.max(largestCross, cross(of: measured), 0)
      }
    }

    return _SplitViewAllocations(
      paneMain: paneMain,
      dividerMain: dividerMain,
      totalMain: resolution.total,
      cross: largestCross
    )
  }

  private func hasVisiblePane(after index: Int) -> Bool {
    panes.indices.contains { $0 > index && !panes[$0].isCollapsed }
  }

  private func main(of size: TerminalSize) -> Int {
    switch axis {
    case .horizontal:
      size.columns
    case .vertical:
      size.rows
    }
  }

  private func cross(of size: TerminalSize) -> Int {
    switch axis {
    case .horizontal:
      size.rows
    case .vertical:
      size.columns
    }
  }

  private func main(of position: TerminalPosition) -> Int {
    switch axis {
    case .horizontal:
      position.column
    case .vertical:
      position.row
    }
  }

  private func cross(of position: TerminalPosition) -> Int {
    switch axis {
    case .horizontal:
      position.row
    case .vertical:
      position.column
    }
  }

  private func main(of proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.width
    case .vertical:
      proposal.height
    }
  }

  private func cross(of proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.height
    case .vertical:
      proposal.width
    }
  }

  private func frame(main: Int, cross: Int, mainSize: Int, crossSize: Int) -> Rect {
    Rect(
      origin: position(main: main, cross: cross),
      size: size(main: mainSize, cross: crossSize)
    )
  }

  private func position(main: Int, cross: Int) -> TerminalPosition {
    switch axis {
    case .horizontal:
      TerminalPosition(column: main, row: cross)
    case .vertical:
      TerminalPosition(column: cross, row: main)
    }
  }

  private func proposedSize(main: Int?, cross: Int?) -> ProposedSize {
    switch axis {
    case .horizontal:
      ProposedSize(width: main, height: cross)
    case .vertical:
      ProposedSize(width: cross, height: main)
    }
  }

  private func size(main: Int, cross: Int) -> TerminalSize {
    switch axis {
    case .horizontal:
      TerminalSize(columns: Swift.max(main, 0), rows: Swift.max(cross, 0))
    case .vertical:
      TerminalSize(columns: Swift.max(cross, 0), rows: Swift.max(main, 0))
    }
  }
}

private enum _SplitViewAllocationEntry {
  case divider(after: Int, subviewIndex: Int)
  case pane(index: Int, subviewIndex: Int)
}

private struct _SplitViewAllocations {
  let paneMain: [Int]
  let dividerMain: [Int]
  let totalMain: Int
  let cross: Int
}
