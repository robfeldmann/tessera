import TesseraCore
import TesseraLayout
import TesseraTerminalCore

/// Application-owned configuration for one pane in a ``SplitView``.
public struct SplitViewPane: Identifiable, Hashable {
  /// The stable identity of this pane.
  public let id: AnyHashable

  /// The pane's requested extent along the split axis, clamped to whole nonnegative cells.
  public var requestedSize: Int {
    didSet {
      requestedSize = max(requestedSize, 0)
    }
  }

  /// Whether this pane is omitted from the visible pane sequence.
  public var isCollapsed: Bool

  /// Creates a pane configuration controlled by the application.
  public init<ID: Hashable>(
    id: ID,
    requestedSize: Int,
    isCollapsed: Bool = false
  ) {
    self.id = AnyHashable(id)
    self.requestedSize = max(requestedSize, 0)
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
        requestedSize: configuration.requestedSize
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
  let requestedSize: Int

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
    guard let child = Subviews(subviews).first else {
      return size(main: requestedSize, cross: 0)
    }
    let childSize = child.sizeThatFits(
      proposedSize(main: requestedSize, cross: cross(of: proposal))
    )
    return size(
      main: requestedSize,
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
        main: requestedSize,
        cross: cross(of: bounds.size)
      )
    )
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

private struct _SplitViewLayout: Layout {
  let axis: Axis
  let panes: [SplitViewPane]
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    let allocations = allocations(proposal: proposal, subviews: subviews)
    return size(main: allocations.totalMain, cross: allocations.cross)
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    let allocations = allocations(proposal: proposal, subviews: subviews)
    let placementCross = max(cross(of: bounds.size), 0)
    let crossOrigin = cross(of: bounds.origin)
    var mainOrigin = main(of: bounds.origin)
    var subviewIndex = 0

    for index in panes.indices {
      let pane = panes[index]
      guard pane.isCollapsed == false else {
        subviewIndex += 1
        continue
      }

      let allocation = allocations.paneMain[index]
      subviews[subviewIndex].place(
        at: position(main: mainOrigin, cross: crossOrigin),
        proposal: proposedSize(main: allocation, cross: placementCross)
      )
      subviewIndex += 1
      mainOrigin += allocation

      guard hasVisiblePane(after: index) else {
        continue
      }
      subviews[subviewIndex].place(
        at: position(main: mainOrigin, cross: crossOrigin),
        proposal: proposedSize(main: 1, cross: placementCross)
      )
      subviewIndex += 1
      mainOrigin += 1
    }
  }

  private func allocations(
    proposal: ProposedSize,
    subviews: Subviews
  ) -> (paneMain: [Int], totalMain: Int, cross: Int) {
    let crossProposal = cross(of: proposal)
    var paneMain = Array(repeating: 0, count: panes.count)
    var totalMain = 0
    var largestCross = 0
    var subviewIndex = 0

    for index in panes.indices {
      let pane = panes[index]
      guard pane.isCollapsed == false else {
        subviewIndex += 1
        continue
      }

      let allocation = max(pane.requestedSize, 0)
      paneMain[index] = allocation
      let measured = subviews[subviewIndex].sizeThatFits(
        proposedSize(main: allocation, cross: crossProposal)
      )
      totalMain += allocation
      largestCross = max(largestCross, cross(of: measured), 0)
      subviewIndex += 1

      guard hasVisiblePane(after: index) else {
        continue
      }
      let divider = subviews[subviewIndex].sizeThatFits(
        proposedSize(main: 1, cross: crossProposal)
      )
      totalMain += max(main(of: divider), 0)
      largestCross = max(largestCross, cross(of: divider), 0)
      subviewIndex += 1
    }

    return (paneMain, totalMain, largestCross)
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

  private func cross(of proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.height
    case .vertical:
      proposal.width
    }
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
      TerminalSize(columns: max(main, 0), rows: max(cross, 0))
    case .vertical:
      TerminalSize(columns: max(cross, 0), rows: max(main, 0))
    }
  }
}
