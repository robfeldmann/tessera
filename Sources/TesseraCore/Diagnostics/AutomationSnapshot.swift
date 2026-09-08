import TesseraTerminalCore

/// An explicit semantic role for developer automation, not an inferred accessibility tree.
public enum AutomationRole: String, CaseIterable, Sendable {
  /// An action control whose keyboard activation is Enter or Space.
  case button
  /// A named container with no activation behavior of its own.
  case group
  /// A named, noninteractive text surface. Its text is not exported implicitly.
  case text
}

/// One explicitly annotated element at the graph's latest completed layout.
/// Identifiers do not grant focus, mutation, or event-delivery authority.
public struct AutomationElement: Equatable, Sendable {
  private static let buttonActivationKeys = ["enter", "space"]

  /// The caller-supplied identifier, independent of reconciliation identity and FocusID.
  public let identifier: String
  /// The caller-declared semantic role.
  public let role: AutomationRole
  /// The structural identity retained by the reconciler.
  public let nodeIdentity: NodeIdentity
  /// The latest absolute bounds, before clipping.
  public let frame: Rect
  /// The latest effective clip, including ancestor clips.
  public let clip: Rect
  /// Whether this annotated subtree is enabled by its inherited environment.
  public let isEnabled: Bool
  /// Whether the current focus target is inside this annotated subtree.
  public let isFocused: Bool

  /// Supported activation keys for the declared role; disabled elements offer none.
  /// Pointer and held-key protocols are deliberately not advertised by this projection.
  public var activationKeys: [String] {
    role == .button && isEnabled ? Self.buttonActivationKeys : []
  }
}

/// A read-only, value-free semantic projection in deterministic tree order.
public struct AutomationSnapshot: Equatable, Sendable {
  /// Lookup fails before any event can be sent when an identifier is absent or ambiguous.
  public enum LookupError: Error, Equatable, CustomStringConvertible {
    /// Several annotated elements have the requested identifier.
    case ambiguous(identifier: String, candidates: [AutomationElement])
    /// No annotated element has the requested identifier.
    case missing(identifier: String, available: [String])

    /// A deterministic failure summary including available IDs or candidate geometry.
    public var description: String {
      switch self {
      case .ambiguous(let identifier, let candidates):
        "Ambiguous automation identifier '\(identifier)': "
          + candidates.map { "\($0.nodeIdentity) frame=\($0.frame) clip=\($0.clip)" }
          .joined(separator: "; ")
      case .missing(let identifier, let available):
        "Missing automation identifier '\(identifier)'; available: \(available.joined(separator: ", "))"
      }
    }
  }

  /// Only explicitly annotated elements are included. App text and objects are not reflected.
  public let elements: [AutomationElement]

  /// Resolves exactly one identifier without changing the graph or choosing the first match.
  public func resolve(_ identifier: String) throws(LookupError) -> AutomationElement {
    var match: AutomationElement?
    var duplicates: [AutomationElement] = []
    for element in elements where element.identifier == identifier {
      if let first = match {
        if duplicates.isEmpty {
          duplicates.append(first)
        }
        duplicates.append(element)
      } else {
        match = element
      }
    }
    guard duplicates.isEmpty else {
      throw .ambiguous(identifier: identifier, candidates: duplicates)
    }
    guard let match else {
      throw .missing(identifier: identifier, available: elements.map(\.identifier))
    }
    return match
  }
}
