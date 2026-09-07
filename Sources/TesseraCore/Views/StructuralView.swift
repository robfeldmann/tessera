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
  /// A nested list path flattened into one enclosing layout child.
  indirect case nested(Self, Self)

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
    case .nested(let outer, let inner):
      "\(outer)/\(inner)"
    case .explicit(let id):
      "explicit(\(id))"
    }
  }

  /// The key used by a ``ForEach`` child, when this slot is keyed.
  package var keyedID: AnyHashable? {
    switch self {
    case .id(let id):
      id
    case .nested(let outer, let inner):
      inner.keyedID ?? outer.keyedID
    case .body, .branch, .explicit, .index:
      nil
    }
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

/// A structural value whose children participate independently in an enclosing layout.
package protocol _ViewList: _StructuralView {}

/// Visits the independent layout children produced by `content`.
package func _visitLayoutChildren<Content: View>(
  _ content: Content,
  in environment: EnvironmentValues,
  environmentOverrides: [String],
  _ visit: (_ViewChild) -> Void
) {
  func visitFlattened(_ child: _ViewChild) {
    if let list = child.view as? any _ViewList {
      list._visitChildren(
        in: child.environment,
        environmentOverrides: child.environmentOverrides
      ) { nested in
        visitFlattened(
          _ViewChild(
            slot: .nested(child.slot, nested.slot),
            view: nested.view,
            environment: nested.environment,
            environmentOverrides: nested.environmentOverrides
          )
        )
      }
    } else {
      visit(child)
    }
  }

  if let list = content as? any _ViewList {
    list._visitChildren(
      in: environment,
      environmentOverrides: environmentOverrides,
      visitFlattened
    )
  } else {
    visitFlattened(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}
