import TesseraCore
import TesseraTerminalCore

/// A main-axis sizing rule consumed by ``Flex`` and custom layouts.
public enum FlexConstraint: Equatable, LayoutValueKey, Sendable {
  case fill(Int)
  case length(Int)
  case max(Int)
  case min(Int)
  case percentage(Int)
  case ratio(Int, Int)

  public static let defaultValue: Self? = nil

  package func validate() {
    switch self {
    case .fill(let weight):
      precondition(weight >= 0, "Flex fill weight must be nonnegative.")
    case .length(let extent), .max(let extent), .min(let extent):
      precondition(extent >= 0, "Flex extent must be nonnegative.")
    case .percentage(let percentage):
      precondition(
        (0...100).contains(percentage),
        "Flex percentage must be between zero and one hundred."
      )
    case .ratio(let numerator, let denominator):
      precondition(numerator >= 0, "Flex ratio numerator must be nonnegative.")
      precondition(denominator > 0, "Flex ratio denominator must be positive.")
    }
  }
}

extension View {
  /// Supplies an explicit main-axis constraint to the nearest enclosing layout.
  public func flex(_ constraint: FlexConstraint) -> some View {
    constraint.validate()
    return layoutValue(key: FlexConstraint.self, value: constraint)
  }
}

package enum _FlexCompression {
  case fill
  case fixed
  case minimum
}

package struct _FlexResolverItem {
  package var allocation: Int
  package let compression: _FlexCompression
  package let floor: Int
  package let growthCap: Int?
  package let growthWeight: Int
  package let priority: Int

  package static func constraint(
    _ constraint: FlexConstraint?,
    available: Int?,
    measuredIdeal: Int,
    measuredMinimum: Int,
    priority: Int
  ) -> Self {
    let ideal = Swift.max(measuredIdeal, 0)
    let minimum = Swift.max(measuredMinimum, 0)

    guard let constraint else {
      return Self(
        allocation: Swift.max(ideal, minimum),
        compression: .minimum,
        floor: minimum,
        growthCap: nil,
        growthWeight: 1,
        priority: priority
      )
    }

    constraint.validate()
    switch constraint {
    case .length(let extent):
      return fixed(extent, priority: priority)
    case .percentage(let percentage):
      let resolved =
        available.map {
          _saturatingMultiplyDivide($0, percentage, 100)
        } ?? ideal
      return fixed(resolved, priority: priority)
    case .ratio(let numerator, let denominator):
      let resolved =
        available.map {
          _saturatingMultiplyDivide($0, numerator, denominator)
        } ?? ideal
      return fixed(resolved, priority: priority)
    case .max(let extent):
      return fixed(Swift.min(ideal, extent), priority: priority)
    case .min(let extent):
      let floor = Swift.max(minimum, extent)
      return Self(
        allocation: Swift.max(ideal, floor),
        compression: .minimum,
        floor: floor,
        growthCap: nil,
        growthWeight: 1,
        priority: priority
      )
    case .fill(let weight):
      return Self(
        allocation: weight == 0 ? 0 : ideal,
        compression: .fill,
        floor: 0,
        growthCap: nil,
        growthWeight: weight,
        priority: priority
      )
    }
  }

  package static func fixed(_ extent: Int, priority: Int = 0) -> Self {
    let extent = Swift.max(extent, 0)
    return Self(
      allocation: extent,
      compression: .fixed,
      floor: extent,
      growthCap: extent,
      growthWeight: 0,
      priority: priority
    )
  }

  package static func range(
    minimum: Int,
    ideal: Int,
    maximum: Int?,
    priority: Int
  ) -> Self {
    precondition(minimum >= 0, "Flex range minimum must be nonnegative.")
    precondition(ideal >= minimum, "Flex range ideal must not be below its minimum.")
    if let maximum {
      precondition(maximum >= ideal, "Flex range maximum must not be below its ideal.")
    }
    return Self(
      allocation: ideal,
      compression: .minimum,
      floor: minimum,
      growthCap: maximum,
      growthWeight: 1,
      priority: priority
    )
  }
}

package struct _FlexResolution {
  package let allocations: [Int]
  package let total: Int
}

package enum _FlexResolver {
  package static func resolve(
    available: Int?,
    spacing: Int,
    items sourceItems: [_FlexResolverItem]
  ) -> _FlexResolution {
    precondition(spacing >= 0, "Flex spacing must be nonnegative.")
    guard sourceItems.isEmpty == false else {
      return _FlexResolution(allocations: [], total: 0)
    }

    var items = sourceItems
    var allocations = items.map { Swift.max($0.allocation, 0) }
    let spacingTotal = _saturatingMultiply(spacing, items.count - 1)

    if let available {
      let childAvailable = Swift.max(available, 0)
      let initial = _saturatingSum(allocations)
      if initial < childAvailable {
        var remainder = childAvailable - initial
        let priorities = Set(items.map(\.priority)).sorted(by: >)
        for priority in priorities where remainder > 0 {
          grow(
            indices: items.indices.filter { items[$0].priority == priority },
            items: &items,
            allocations: &allocations,
            remainder: &remainder
          )
        }
      } else if initial > childAvailable {
        var deficit = initial - childAvailable
        compress(
          phase: .fill,
          items: items,
          allocations: &allocations,
          deficit: &deficit
        )
        compress(
          phase: .minimum,
          items: items,
          allocations: &allocations,
          deficit: &deficit
        )
      }
    }

    return _FlexResolution(
      allocations: allocations,
      total: _saturatingAdd(_saturatingSum(allocations), spacingTotal)
    )
  }

  private static func grow(
    indices: [Int],
    items: inout [_FlexResolverItem],
    allocations: inout [Int],
    remainder: inout Int
  ) {
    while remainder > 0 {
      let eligible = indices.filter { index in
        guard items[index].growthWeight > 0 else {
          return false
        }
        return items[index].growthCap.map { allocations[index] < $0 } ?? true
      }
      guard eligible.isEmpty == false else {
        return
      }

      let totalWeight = _saturatingSum(eligible.map { items[$0].growthWeight })
      guard totalWeight > 0 else {
        return
      }
      let passRemainder = remainder
      var changed = false

      for index in eligible where remainder > 0 {
        let room = items[index].growthCap.map { $0 - allocations[index] } ?? Int.max
        let share = _saturatingMultiplyDivide(
          passRemainder,
          items[index].growthWeight,
          totalWeight
        )
        let increase = Swift.min(share, room, remainder)
        guard increase > 0 else { continue }
        allocations[index] = _saturatingAdd(allocations[index], increase)
        remainder -= increase
        changed = true
      }

      for index in eligible where remainder > 0 {
        let room = items[index].growthCap.map { $0 - allocations[index] } ?? Int.max
        guard room > 0 else {
          continue
        }
        allocations[index] += 1
        remainder -= 1
        changed = true
      }

      guard changed else {
        return
      }
    }
  }

  private static func compress(
    phase: _FlexCompression,
    items: [_FlexResolverItem],
    allocations: inout [Int],
    deficit: inout Int
  ) {
    let priorities = Set(items.map(\.priority)).sorted()
    for priority in priorities where deficit > 0 {
      let tier = items.indices.filter {
        items[$0].compression == phase
          && items[$0].priority == priority
          && allocations[$0] > items[$0].floor
      }
      shrink(
        indices: tier,
        items: items,
        allocations: &allocations,
        deficit: &deficit
      )
    }
  }

  private static func shrink(
    indices: [Int],
    items: [_FlexResolverItem],
    allocations: inout [Int],
    deficit: inout Int
  ) {
    while deficit > 0 {
      let eligible = indices.filter { allocations[$0] > items[$0].floor }
      guard eligible.isEmpty == false else {
        return
      }

      let totalWeight = _saturatingSum(
        eligible.map { Swift.max(items[$0].growthWeight, 1) })
      let passDeficit = deficit
      var changed = false

      for index in eligible.reversed() where deficit > 0 {
        let removable = allocations[index] - items[index].floor
        let share = _saturatingMultiplyDivide(
          passDeficit,
          Swift.max(items[index].growthWeight, 1),
          totalWeight
        )
        let decrease = Swift.min(share, removable, deficit)
        guard decrease > 0 else { continue }
        allocations[index] -= decrease
        deficit -= decrease
        changed = true
      }

      for index in eligible.reversed() where deficit > 0 {
        guard allocations[index] > items[index].floor else {
          continue
        }
        allocations[index] -= 1
        deficit -= 1
        changed = true
      }

      guard changed else {
        return
      }
    }
  }
}

private struct _FlexDistribution {
  let allocations: [Int]
  let crossSizes: [Int]
  let size: TerminalSize
}

private struct _FlexLayout: Layout {
  let axis: Axis
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
      let childCrossOrigin = _saturatingOffset(
        crossOrigin,
        alignmentOffset(slack: Swift.max(availableCross - childCross, 0))
      )
      let origin = position(main: mainOrigin, cross: childCrossOrigin)
      let childProposal = proposedSize(
        main: result.allocations[index],
        cross: proposalCross(proposal)
      )
      let segment = Rect(
        origin: position(main: mainOrigin, cross: crossOrigin),
        size: size(main: result.allocations[index], cross: availableCross)
      )
      subviews[index].place(at: origin, proposal: childProposal, clip: segment)
      mainOrigin = _saturatingOffset(mainOrigin, result.allocations[index])
      if index != subviews.index(before: subviews.endIndex) {
        mainOrigin = _saturatingOffset(mainOrigin, spacing)
      }
    }
  }

  private func distribution(
    _ proposal: ProposedSize,
    subviews: Subviews
  ) -> _FlexDistribution {
    guard subviews.isEmpty == false else {
      return _FlexDistribution(
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
    let spacingTotal = _saturatingMultiply(spacing, subviews.count - 1)
    let available = proposalMain(proposal).map {
      Swift.max($0 - Swift.min($0, spacingTotal), 0)
    }
    let items = subviews.indices.map { index in
      _FlexResolverItem.constraint(
        subviews[index][FlexConstraint.self],
        available: available,
        measuredIdeal: ideals[index].main,
        measuredMinimum: minimums[index].main,
        priority: subviews[index].priority
      )
    }
    let resolution = _FlexResolver.resolve(
      available: available,
      spacing: spacing,
      items: items
    )
    let crossSizes = subviews.indices.map { index in
      measurement(
        subviews[index].sizeThatFits(
          proposedSize(main: resolution.allocations[index], cross: crossProposal)
        )
      ).cross
    }
    let crossSize = crossSizes.max() ?? 0
    return _FlexDistribution(
      allocations: resolution.allocations,
      crossSizes: crossSizes,
      size: size(main: resolution.total, cross: crossSize)
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

  private func measurement(_ size: TerminalSize) -> (main: Int, cross: Int) {
    switch axis {
    case .horizontal:
      (size.columns, size.rows)
    case .vertical:
      (size.rows, size.columns)
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

  private func size(main: Int, cross: Int) -> TerminalSize {
    switch axis {
    case .horizontal:
      TerminalSize(columns: main, rows: cross)
    case .vertical:
      TerminalSize(columns: cross, rows: main)
    }
  }

  private func alignmentOffset(slack: Int) -> Int {
    switch axis {
    case .horizontal:
      _alignmentOffset(slack: slack, alignment: VerticalAlignment.top)
    case .vertical:
      _alignmentOffset(slack: slack, alignment: HorizontalAlignment.leading)
    }
  }
}

/// Arranges children on one axis using explicit integer-cell constraints.
public struct Flex<Content: View>: View, _LayoutView {
  public typealias Body = Never

  private let axis: Axis
  private let content: Content
  private let spacing: Int

  public init(
    _ axis: Axis,
    spacing: Int = 0,
    @ViewBuilder content: () -> Content
  ) {
    precondition(spacing >= 0, "Flex spacing must be nonnegative.")
    self.axis = axis
    self.content = content()
    self.spacing = spacing
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var environment = environment
    environment._stackAxis = axis
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
    _FlexLayout(axis: axis, spacing: spacing)
      .sizeThatFits(proposal, subviews: Subviews(subviews))
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    _FlexLayout(axis: axis, spacing: spacing)
      .placeSubviews(in: bounds, proposal: proposal, subviews: Subviews(subviews))
  }
}

package func _saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
  let (result, overflow) = lhs.addingReportingOverflow(rhs)
  return overflow ? Int.max : Swift.max(result, 0)
}

package func _saturatingOffset(_ origin: Int, _ delta: Int) -> Int {
  let (result, overflow) = origin.addingReportingOverflow(delta)
  return overflow ? Int.max : result
}

package func _saturatingMultiply(_ lhs: Int, _ rhs: Int) -> Int {
  guard lhs > 0, rhs > 0 else {
    return 0
  }
  let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
  return overflow ? Int.max : result
}

package func _saturatingMultiplyDivide(
  _ lhs: Int,
  _ rhs: Int,
  _ denominator: Int
) -> Int {
  precondition(lhs >= 0 && rhs >= 0 && denominator > 0)
  guard lhs > 0, rhs > 0 else {
    return 0
  }
  let product = UInt(lhs).multipliedFullWidth(by: UInt(rhs))
  let divisor = UInt(denominator)
  guard product.high < divisor else {
    return Int.max
  }
  let quotient = divisor.dividingFullWidth(product).quotient
  return quotient > UInt(Int.max) ? Int.max : Int(quotient)
}

package func _saturatingSum<S: Sequence>(_ values: S) -> Int where S.Element == Int {
  values.reduce(0, _saturatingAdd)
}
