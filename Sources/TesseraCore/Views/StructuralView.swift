/// A stable location for a child in the declarative view tree.
package enum _ViewSlot: Hashable, CustomStringConvertible {
  /// A composite view's evaluated body.
  case body
  /// A selected conditional branch.
  case branch(Bool)
  /// An explicit identity modifier.
  case explicit(AnyHashable)
  /// A keyed ``ForEach`` element.
  case id(AnyHashable)
  /// A position within a fixed structural container.
  case index(Int)

  package var description: String {
    switch self {
    case .body:
      "body"
    case .index(let index):
      "index(\(index))"
    case .id(let id):
      "id(\(id))"
    case .branch(let isTrueBranch):
      "branch(\(isTrueBranch))"
    case .explicit(let id):
      "explicit(\(id))"
    }
  }

  /// The key used by a ``ForEach`` child, when this slot is keyed.
  package var keyedID: AnyHashable? {
    guard case .id(let id) = self else {
      return nil
    }

    return id
  }
}

/// A child supplied directly by a structural view to the reconciler.
///
/// `view` remains an existential containing the child's original dynamic type; no public
/// `AnyView` is introduced while lowering a structural container.
package struct _ViewChild {
  package let slot: _ViewSlot
  package let view: any View
  package let environment: EnvironmentValues
  package let environmentOverrides: [String]

  package init<Content: View>(
    slot: _ViewSlot,
    view: Content,
    environment: EnvironmentValues,
    environmentOverrides: [String]
  ) {
    self.slot = slot
    self.view = view
    self.environment = environment
    self.environmentOverrides = environmentOverrides
  }
}

/// The package-level lowering seam for views whose children are known without evaluating
/// ``View/body``.
package protocol _StructuralView: View {
  /// Visits each direct child synchronously with its stable slot and resolved environment.
  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  )
}
