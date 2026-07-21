import TesseraCore
import TesseraTerminalCore

private enum _LinearAxis {
  case horizontal
  case vertical
}

private struct _LinearMeasurement {
  let main: Int
  let cross: Int
}

private struct _LinearDistribution {
  let allocations: [Int]
  let crossSizes: [Int]
  let size: TerminalSize
}

private struct _LinearStackLayout: Layout {
  let axis: _LinearAxis
  let horizontalAlignment: HorizontalAlignment
  let verticalAlignment: VerticalAlignment
  let spacing: Int

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    distribution(proposal, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    let result = distribution(proposal, subviews: subviews)
    var mainOrigin = main(of: bounds.origin)
    let crossOrigin = cross(of: bounds.origin)
    let availableCross = cross(of: bounds.size)

    for index in subviews.indices {
      let childCross = result.crossSizes[index]
      let crossSlack = max(availableCross - childCross, 0)
      let childCrossOrigin = crossOrigin + alignmentOffset(for: crossSlack)
      let origin = position(main: mainOrigin, cross: childCrossOrigin)
      subviews[index].place(
        at: origin,
        proposal: proposedSize(
          main: result.allocations[index],
          cross: proposalCross(proposal)
        )
      )
      mainOrigin += result.allocations[index]
      if index != subviews.index(before: subviews.endIndex) {
        mainOrigin += spacing
      }
    }
  }

  private func distribution(
    _ proposal: ProposedSize,
    subviews: Subviews
  ) -> _LinearDistribution {
    guard subviews.isEmpty == false else {
      return _LinearDistribution(
        allocations: [],
        crossSizes: [],
        size: TerminalSize(columns: 0, rows: 0)
      )
    }

    let crossProposal = proposalCross(proposal)
    let idealProposal = proposedSize(main: nil, cross: crossProposal)
    let minimumProposal = proposedSize(main: 0, cross: crossProposal)
    let ideals = subviews.map { measurement($0.sizeThatFits(idealProposal)) }
    let minimums = subviews.map { measurement($0.sizeThatFits(minimumProposal)) }
    let spacingTotal = spacing * max(subviews.count - 1, 0)

    guard let proposedMain = proposalMain(proposal) else {
      let allocations = ideals.map(\.main)
      let crossSizes = ideals.map(\.cross)
      return result(
        allocations: allocations,
        crossSizes: crossSizes,
        spacingTotal: spacingTotal
      )
    }

    var allocations = Array(repeating: 0, count: subviews.count)
    var remaining = max(proposedMain - spacingTotal, 0)
    let priorities = Set(subviews.map(\.priority)).sorted(by: >)

    for priority in priorities {
      let indices = subviews.indices.filter { subviews[$0].priority == priority }
      let rigid = indices.filter {
        subviews[$0]._isSpacer == false && ideals[$0].main == minimums[$0].main
      }
      let flexible = indices.filter { rigid.contains($0) == false }

      for index in rigid {
        allocations[index] = ideals[index].main
        remaining -= allocations[index]
      }

      var flexibleLeft = flexible.count
      for index in flexible {
        let nonnegativeRemaining = max(remaining, 0)
        let share =
          flexibleLeft == 0
          ? 0
          : (nonnegativeRemaining + flexibleLeft - 1) / flexibleLeft
        let measured = measurement(
          subviews[index].sizeThatFits(
            proposedSize(main: share, cross: crossProposal)
          )
        )
        allocations[index] = max(minimums[index].main, measured.main, 0)
        remaining -= allocations[index]
        flexibleLeft -= 1
      }
    }

    let crossSizes = subviews.indices.map { index in
      measurement(
        subviews[index].sizeThatFits(
          proposedSize(main: allocations[index], cross: crossProposal)
        )
      ).cross
    }
    return result(
      allocations: allocations,
      crossSizes: crossSizes,
      spacingTotal: spacingTotal
    )
  }

  private func result(
    allocations: [Int],
    crossSizes: [Int],
    spacingTotal: Int
  ) -> _LinearDistribution {
    let main = allocations.reduce(0, +) + spacingTotal
    let cross = crossSizes.max() ?? 0
    let size: TerminalSize
    switch axis {
    case .horizontal:
      size = TerminalSize(columns: main, rows: cross)
    case .vertical:
      size = TerminalSize(columns: cross, rows: main)
    }
    return _LinearDistribution(
      allocations: allocations,
      crossSizes: crossSizes,
      size: size
    )
  }

  private func proposalMain(_ proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.width
    case .vertical:
      proposal.height
    }
  }

  private func proposalCross(_ proposal: ProposedSize) -> Int? {
    switch axis {
    case .horizontal:
      proposal.height
    case .vertical:
      proposal.width
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

  private func measurement(_ size: TerminalSize) -> _LinearMeasurement {
    switch axis {
    case .horizontal:
      _LinearMeasurement(main: size.columns, cross: size.rows)
    case .vertical:
      _LinearMeasurement(main: size.rows, cross: size.columns)
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

  private func cross(of size: TerminalSize) -> Int {
    switch axis {
    case .horizontal:
      size.rows
    case .vertical:
      size.columns
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

  private func alignmentOffset(for slack: Int) -> Int {
    switch axis {
    case .horizontal:
      _alignmentOffset(slack: slack, alignment: verticalAlignment)
    case .vertical:
      _alignmentOffset(slack: slack, alignment: horizontalAlignment)
    }
  }
}

/// Arranges children from leading to trailing in source order.
public struct HStack<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let alignment: VerticalAlignment
  private let content: Content
  private let spacing: Int

  private var layout: _LinearStackLayout {
    _LinearStackLayout(
      axis: .horizontal,
      horizontalAlignment: .leading,
      verticalAlignment: alignment,
      spacing: spacing
    )
  }

  public init(
    alignment: VerticalAlignment = .top,
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  ) {
    precondition(spacing >= 0, "HStack spacing must be nonnegative.")
    self.alignment = alignment
    self.content = content()
    self.spacing = spacing
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var environment = environment
    environment._stackAxis = .horizontal
    _visitLayoutChildren(
      content,
      in: environment,
      environmentOverrides: environmentOverrides + ["stackAxis"],
      visit
    )
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    layout.sizeThatFits(proposal, subviews: Subviews(subviews))
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    layout.placeSubviews(in: bounds, proposal: proposal, subviews: Subviews(subviews))
  }

}

/// Arranges children from top to bottom in source order.
public struct VStack<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let alignment: HorizontalAlignment
  private let content: Content
  private let spacing: Int

  private var layout: _LinearStackLayout {
    _LinearStackLayout(
      axis: .vertical,
      horizontalAlignment: alignment,
      verticalAlignment: .top,
      spacing: spacing
    )
  }

  public init(
    alignment: HorizontalAlignment = .leading,
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  ) {
    precondition(spacing >= 0, "VStack spacing must be nonnegative.")
    self.alignment = alignment
    self.content = content()
    self.spacing = spacing
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var environment = environment
    environment._stackAxis = .vertical
    _visitLayoutChildren(
      content,
      in: environment,
      environmentOverrides: environmentOverrides + ["stackAxis"],
      visit
    )
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    layout.sizeThatFits(proposal, subviews: Subviews(subviews))
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    layout.placeSubviews(in: bounds, proposal: proposal, subviews: Subviews(subviews))
  }

}

/// Overlays children in source order inside common bounds.
public struct ZStack<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let alignment: Alignment
  private let content: Content

  public init(
    alignment: Alignment = .topLeading,
    @ViewBuilder content: () -> Content
  ) {
    self.alignment = alignment
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
    var columns = 0
    var rows = 0
    for subview in Subviews(subviews) {
      let size = subview.sizeThatFits(proposal)
      columns = max(columns, size.columns)
      rows = max(rows, size.rows)
    }
    return TerminalSize(columns: columns, rows: rows)
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    let childProposal = ProposedSize(
      width: bounds.size.columns,
      height: bounds.size.rows
    )
    for subview in Subviews(subviews) {
      let size = subview.sizeThatFits(childProposal)
      let horizontal = _alignmentOffset(
        slack: max(bounds.size.columns - size.columns, 0),
        alignment: alignment.horizontal
      )
      let vertical = _alignmentOffset(
        slack: max(bounds.size.rows - size.rows, 0),
        alignment: alignment.vertical
      )
      subview.place(
        at: TerminalPosition(
          column: bounds.origin.column + horizontal,
          row: bounds.origin.row + vertical
        ),
        proposal: childProposal
      )
    }
  }
}

/// Flexible empty space in the main axis of a linear stack.
public struct Spacer: LeafView, _LayoutValueProvider {
  public typealias Body = Never

  private let minLength: Int

  public init(minLength: Int = 0) {
    precondition(minLength >= 0, "Spacer minLength must be nonnegative.")
    self.minLength = minLength
  }

  public func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    switch environment._stackAxis {
    case .horizontal:
      TerminalSize(columns: max(proposal.width ?? minLength, minLength), rows: 0)
    case .vertical:
      TerminalSize(columns: 0, rows: max(proposal.height ?? minLength, minLength))
    case nil:
      TerminalSize(columns: 0, rows: 0)
    }
  }

  public func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {}

  package func _layoutValue(for key: ObjectIdentifier) -> Any? {
    guard key == ObjectIdentifier(_SpacerLayoutValueKey.self) else {
      return nil
    }
    return true
  }
}
