import TesseraTerminalCore

/// A named invariant over a ``Projection``.
///
/// Every rule is a pure function of the projection: it reads no graph and no screen beyond what
/// the projection holds, so it runs on a crafted value as well as on a live run. The rule ids
/// are stable kebab-case names that a scenario's `check` statement writes. A rule added in a
/// minor release runs only when it is named and joins bare `check` at the next major, so a
/// release cannot fail an app's CI with a rule the app never asked for.
package enum CheckRule: String, CaseIterable, Sendable {
  /// A leaf's content is placed outside its clip.
  case frameInsideClip = "frame-inside-clip"

  /// A view measured more than the size it was offered on a constrained axis.
  case measuredWithinProposal = "measured-within-proposal"

  /// A node is still dirty after a completed pass.
  case noDirtyAfterPass = "no-dirty-after-pass"

  /// A terminal requirement does not roll up from the node that asks for it to the graph.
  case requirementsAggregate = "requirements-aggregate"

  /// Two children of one container show a cell in common.
  case siblingsDisjoint = "siblings-disjoint"

  /// How a violation of a rule counts.
  package enum Severity: String, Sendable {
    case error
    case warning
  }

  /// Every rule, in the order bare `check` runs them. The cases are declared in alphabetical
  /// order, so this list is what `allCases` is.
  package static let allCases: [Self] = [
    .noDirtyAfterPass, .frameInsideClip, .measuredWithinProposal, .siblingsDisjoint,
    .requirementsAggregate,
  ]

  /// The rule ids, in the order bare `check` runs them, for the error that names the
  /// vocabulary.
  package static var accepted: String {
    allCases.map(\.rawValue).joined(separator: ", ")
  }

  /// How a violation of the rule counts.
  ///
  /// An error fails the `check` statement. A warning is reported and does not fail a bare
  /// `check`, because the content it flags can be clipped on purpose; naming the rule asks for
  /// it to hold, so a named rule fails on a warning too.
  package var severity: Severity {
    switch self {
    case .frameInsideClip: .warning
    case .measuredWithinProposal, .noDirtyAfterPass, .requirementsAggregate,
      .siblingsDisjoint:
      .error
    }
  }
}

/// One invariant that does not hold, on one node.
package struct Violation: Equatable, Encodable, Sendable {
  /// The id of the rule, such as `siblings-disjoint`.
  package var rule: String

  /// `error` or `warning`.
  package var severity: String

  /// The identity path of the node the rule found at fault.
  package var node: String

  /// What is wrong, with the numbers that show it.
  package var detail: String

  /// The line a human reads: the severity, the rule, the node, and the detail.
  package var text: String {
    "\(severity) \(rule) \(node): \(detail)"
  }
}

/// The container layouts whose children overlap by contract.
///
/// A container is matched by its layout algorithm when it has one and by its type otherwise.
/// Every other container is held to disjoint children, so a new overlay, popover, or modal
/// container must join this list or `siblings-disjoint` fails loudly on it.
private let overlappingContainers: Set<String> = ["ZStack"]

/// The containers whose descendants are clipped on purpose, so a clipped leaf under one is the
/// container doing its job.
private let scrollingContainers: Set<String> = ["ScrollView"]

/// One projection, indexed for the rules.
private struct CheckContext {
  let projection: Projection
  let byPath: [String: Projection.Node]

  init(_ projection: Projection) {
    self.projection = projection
    byPath = Dictionary(projection.nodes.map { ($0.path, $0) }) { first, _ in first }
  }

  func violation(_ rule: CheckRule, _ node: Projection.Node, _ detail: String)
    -> Violation
  {
    Violation(
      rule: rule.rawValue, severity: rule.severity.rawValue, node: node.path,
      detail: detail)
  }

  /// The node whose layout places `node`'s children: `node` itself, or the nearest ancestor
  /// that is not a view list when `node` is one.
  func placingContainer(of node: Projection.Node) -> Projection.Node {
    var current = node
    while current.isList, let parent = current.parent.flatMap({ byPath[$0] }) {
      current = parent
    }
    return current
  }

  /// A node still marked for layout or rendering once the pass that drew the screen is over.
  func noDirtyAfterPass() -> [Violation] {
    projection.nodes.compactMap { node in
      let flags = [
        node.needsLayout ? "needsLayout" : nil, node.needsRender ? "needsRender" : nil,
      ].compactMap(\.self)
      guard !flags.isEmpty else {
        return nil
      }
      return violation(
        .noDirtyAfterPass, node,
        "still dirty after pass \(projection.pass): \(flags.joined(separator: ", "))")
    }
  }

  /// A leaf with cells whose frame reaches past its clip: some of its content is not drawn.
  func frameInsideClip() -> [Violation] {
    projection.nodes.compactMap { node in
      guard node.isLeaf, !node.frame.isEmpty, !isScrolled(node) else {
        return nil
      }
      let visible = node.frame.rect.intersection(node.clip.rect)
      guard visible != node.frame.rect else {
        return nil
      }
      let shown = visible.map { Projection.Box($0).text } ?? "nothing"
      let content = node.text.map { " (visible text `\($0.firstLine)`)" } ?? ""
      return violation(
        .frameInsideClip, node,
        "frame \(node.frame.text) is clipped to \(shown)\(content)")
    }
  }

  /// A node that measured wider or taller than the axis it was offered. A node that was never
  /// placed keeps a stale probe measurement, so one whose frame is empty and differs from its
  /// measurement is skipped.
  func measuredWithinProposal() -> [Violation] {
    projection.nodes.compactMap { node in
      guard let proposal = node.proposal, let measured = node.measured else {
        return nil
      }
      if node.frame.isEmpty,
        node.frame.columns != measured.columns || node.frame.rows != measured.rows
      {
        return nil
      }
      var overflows: [String] = []
      if let width = proposal.width, measured.columns > width {
        overflows.append("\(measured.columns) columns where \(width) were offered")
      }
      if let height = proposal.height, measured.rows > height {
        overflows.append("\(measured.rows) rows where \(height) were offered")
      }
      guard !overflows.isEmpty else {
        return nil
      }
      return violation(
        .measuredWithinProposal, node, "measured \(overflows.joined(separator: " and "))")
    }
  }

  /// Two children of one container that show a cell in common, unless the container overlaps
  /// its children by contract.
  ///
  /// A child shows its frame clipped to its clip, so a child wider than its segment that is
  /// clipped to it (a `Flex` child whose content overflows) does not overlap its neighbour;
  /// two children placed on one frame (the `ForEach` defect) do. Layout looks through a view
  /// list (`ForEach`, `if`, a group of views) to its elements, so the container that decides
  /// whether they overlap is the nearest ancestor that is not a list: the elements of a
  /// `ForEach` under a `ZStack` are layers, and under a `VStack` they are not.
  func siblingsDisjoint() -> [Violation] {
    var violations: [Violation] = []
    for parent in projection.nodes where parent.children.count > 1 {
      let name = parent.layout ?? parent.type
      let container = placingContainer(of: parent)
      guard !overlappingContainers.contains(container.layout ?? container.type) else {
        continue
      }
      let children = parent.children.compactMap { byPath[$0] }
      for (index, later) in children.enumerated() {
        guard let shown = visible(later) else {
          continue
        }
        for earlier in children[..<index] {
          guard let other = visible(earlier), other.intersection(shown) != nil else {
            continue
          }
          violations.append(
            violation(
              .siblingsDisjoint, later,
              "shows \(Projection.Box(shown).text), which overlaps sibling "
                + "\(earlier.path) showing \(Projection.Box(other).text) under \(name)"))
        }
      }
    }
    return violations
  }

  /// A requirement some node asks for that the graph does not request, and one the graph
  /// requests that no node asks for.
  func requirementsAggregate() -> [Violation] {
    guard let root = projection.nodes.first else {
      return []
    }
    var violations: [Violation] = []
    let requested = Set(projection.requirements.requested)
    let names = Set(projection.nodes.flatMap(\.requirements)).union(requested).sorted()
    for name in names {
      let sources = projection.nodes.filter { $0.requirements.contains(name) }
      if let source = sources.first, !requested.contains(name) {
        violations.append(
          violation(
            .requirementsAggregate, source,
            "asks for `\(name)`, which the graph does not request"))
      } else if sources.isEmpty {
        violations.append(
          violation(
            .requirementsAggregate, root,
            "the graph requests `\(name)` and no node asks for it"))
      }
    }
    return violations
  }

  /// The cells a node shows: its frame clipped to its clip, or `nil` when it shows none.
  private func visible(_ node: Projection.Node) -> Rect? {
    node.frame.rect.intersection(node.clip.rect)
  }

  private func isScrolled(_ node: Projection.Node) -> Bool {
    var cursor = node.parent.flatMap { byPath[$0] }
    while let ancestor = cursor {
      if scrollingContainers.contains(ancestor.layout ?? ancestor.type) {
        return true
      }
      cursor = ancestor.parent.flatMap { byPath[$0] }
    }
    return false
  }
}

/// Runs invariants over a projection.
package enum Checker {
  /// The violations of `rules` in `projection`, rule by rule in the order given and node by
  /// node in tree order, so the same projection always yields the same list.
  package static func run(_ rules: [CheckRule], on projection: Projection) -> [Violation]
  {
    let context = CheckContext(projection)
    return rules.flatMap { rule -> [Violation] in
      switch rule {
      case .noDirtyAfterPass: context.noDirtyAfterPass()
      case .frameInsideClip: context.frameInsideClip()
      case .measuredWithinProposal: context.measuredWithinProposal()
      case .siblingsDisjoint: context.siblingsDisjoint()
      case .requirementsAggregate: context.requirementsAggregate()
      }
    }
  }
}

extension String {
  /// The first line, for a detail that quotes text.
  fileprivate var firstLine: String {
    split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(
      Self.init)
      ?? self
  }
}
