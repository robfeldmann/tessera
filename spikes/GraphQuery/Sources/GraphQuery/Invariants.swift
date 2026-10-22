import Foundation

/// A v0 invariant over a projection; the raw value is the stable kebab-case id.
public enum Rule: String, CaseIterable, Codable, Sendable {
  case frameInsideClip = "frame-inside-clip"
  case measuredWithinProposal = "measured-within-proposal"
  case noDirtyAfterPass = "no-dirty-after-pass"
  case siblingsDisjoint = "siblings-disjoint"

  public static func parse(_ id: String) throws -> Rule {
    guard let rule = Rule(rawValue: id) else {
      throw RuleError.unknown(id)
    }
    return rule
  }
}

public enum RuleError: CustomStringConvertible, Equatable, Error {
  case unknown(String)

  public var description: String {
    switch self {
    case .unknown(let id):
      "unknown rule `\(id)`; accepted: \(Rule.allCases.map(\.rawValue).joined(separator: ", "))"
    }
  }
}

/// One failed invariant on one node.
public struct Violation: Codable, Equatable, Sendable {
  public enum Severity: String, Codable, Sendable {
    case error
    case warning
  }

  public var detail: String
  public var node: String
  public var related: [String]?
  public var rule: Rule
  public var severity: Severity
}

/// Policy knobs for rules whose answer depends on layout semantics the projection lacks.
public struct CheckOptions: Equatable, Sendable {
  /// Container types whose children may overlap by contract. Matched against the
  /// container's layout name: `Node.layout` when present, otherwise `Node.type`. Every other container is held to disjoint children.
  public var overlappingContainers: Set<String> = ["ZStack"]

  /// Container types whose descendants are clipped by design, so `frame-inside-clip` does
  /// not apply below them.
  public var scrollingContainers: Set<String> = ["ScrollView"]

  public init() {}
}

/// Runs invariants over a projection. A pure function: no graph and no screen access
/// beyond what the projection already holds.
public func check(
  _ projection: Projection,
  rules: [Rule] = Rule.allCases,
  options: CheckOptions = CheckOptions()
) -> [Violation] {
  let context = CheckContext(projection: projection, options: options)
  return rules.flatMap { rule -> [Violation] in
    switch rule {
    case .frameInsideClip: context.frameInsideClip()
    case .measuredWithinProposal: context.measuredWithinProposal()
    case .noDirtyAfterPass: context.noDirtyAfterPass()
    case .siblingsDisjoint: context.siblingsDisjoint()
    }
  }
}

private struct CheckContext {
  let projection: Projection
  let options: CheckOptions
  private let byPath: [String: Projection.Node]

  init(projection: Projection, options: CheckOptions) {
    self.projection = projection
    self.options = options
    byPath = Dictionary(
      projection.nodes.map { ($0.path, $0) },
      uniquingKeysWith: { first, _ in first }
    )
  }

  /// A node left dirty after the pass that should have cleaned it. The projection does not
  /// record which pass produced it, so this is only meaningful for a projection taken
  /// after `layoutIfNeeded()` and `render(into:)`.
  func noDirtyAfterPass() -> [Violation] {
    projection.nodes.compactMap { node in
      let flags = [
        node.needsLayout ? "needsLayout" : nil,
        node.needsRender ? "needsRender" : nil,
      ].compactMap { $0 }
      guard !flags.isEmpty else {
        return nil
      }
      return Violation(
        detail: "dirty after pass: \(flags.joined(separator: ", "))",
        node: node.path,
        related: nil,
        rule: .noDirtyAfterPass,
        severity: .error
      )
    }
  }

  /// A leaf whose frame extends past its clip: some of its content is not drawn. Leaves
  /// only, because a clipped container always has a clipped leaf to report; nodes under a
  /// scrolling container are exempt because clipping is the point there.
  func frameInsideClip() -> [Violation] {
    projection.nodes.compactMap { node in
      guard node.isLeaf, !node.frame.isEmpty, !isScrolled(node) else {
        return nil
      }
      let visible = node.frame.intersection(node.clip)
      guard visible != node.frame else {
        return nil
      }
      let shown = visible.map(\.description) ?? "nothing"
      let content = node.text.map { " (visible text \(Locator.quoted($0)))" } ?? ""
      return Violation(
        detail: "frame \(node.frame.description) is clipped to \(shown)\(content)",
        node: node.path,
        related: nil,
        rule: .frameInsideClip,
        severity: .warning
      )
    }
  }

  /// A node that measured larger than the size it was offered on an axis that was
  /// constrained. Nodes that were never placed keep a stale probe measurement and are
  /// skipped (an empty frame that disagrees with the measurement).
  func measuredWithinProposal() -> [Violation] {
    projection.nodes.compactMap { node in
      guard let proposal = node.proposal, let measured = node.measured else {
        return nil
      }
      if node.frame.isEmpty, node.frame.columns != measured.columns || node.frame.rows != measured.rows {
        return nil
      }
      var overflows: [String] = []
      if let width = proposal.width, measured.columns > width {
        overflows.append("\(measured.columns) columns > proposed \(width)")
      }
      if let height = proposal.height, measured.rows > height {
        overflows.append("\(measured.rows) rows > proposed \(height)")
      }
      guard !overflows.isEmpty else {
        return nil
      }
      return Violation(
        detail: "measured exceeds proposal: \(overflows.joined(separator: "; "))",
        node: node.path,
        related: nil,
        rule: .measuredWithinProposal,
        severity: .error
      )
    }
  }

  /// Siblings of a container whose layout contract is non-overlapping must not share a
  /// cell of frame area. Empty frames (spacers, hidden nodes) never overlap anything.
  func siblingsDisjoint() -> [Violation] {
    var violations: [Violation] = []
    for parent in projection.nodes where parent.children.count > 1 {
      guard !options.overlappingContainers.contains(layoutName(of: parent)) else {
        continue
      }
      let children = parent.children.compactMap { byPath[$0] }
      for (index, later) in children.enumerated() {
        for earlier in children[..<index] {
          guard let shared = earlier.frame.intersection(later.frame) else {
            continue
          }
          violations.append(
            Violation(
              detail:
                "frame \(later.frame.description) overlaps sibling \(earlier.path) "
                + "frame \(earlier.frame.description) in \(shared.description) "
                + "under \(layoutName(of: parent))",
              node: later.path,
              related: [earlier.path],
              rule: .siblingsDisjoint,
              severity: .error
            )
          )
        }
      }
    }
    return violations
  }

  private func isScrolled(_ node: Projection.Node) -> Bool {
    var cursor = node.parent.flatMap { byPath[$0] }
    while let ancestor = cursor {
      if options.scrollingContainers.contains(layoutName(of: ancestor)) {
        return true
      }
      cursor = ancestor.parent.flatMap { byPath[$0] }
    }
    return false
  }

  private func layoutName(of node: Projection.Node) -> String {
    node.layout ?? node.type
  }
}

extension TypeName {
  /// For `TesseraLayout._LayoutContainer<Algorithm, Content>`, the concise name of
  /// `Algorithm`; `nil` for every other type.
  static func layoutAlgorithm(of typeName: String) -> String? {
    let marker = "_LayoutContainer<"
    guard let range = typeName.range(of: marker),
      typeName[..<range.lowerBound].allSatisfy({ $0 != "<" })
    else {
      return nil
    }
    var depth = 0
    var argument = ""
    for character in typeName[range.upperBound...] {
      if character == "<" || character == "(" { depth += 1 }
      if character == ">" || character == ")" {
        if depth == 0 { break }
        depth -= 1
      }
      if character == "," && depth == 0 { break }
      argument.append(character)
    }
    return concise(argument.trimmingWhitespace())
  }
}
