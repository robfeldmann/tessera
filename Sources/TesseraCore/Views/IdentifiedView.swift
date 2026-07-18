/// Applies a stable explicit identity to the wrapped subtree.
package struct _IDView<Content: View, ID: Hashable>: View, _StructuralView {
  package typealias Body = Never

  package let content: Content
  package let id: ID

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .explicit(AnyHashable(id)),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}

extension View {
  /// Assigns an explicit identity to this view's descendant subtree.
  public func id<ID: Hashable>(_ id: ID) -> some View {
    _IDView(content: self, id: id)
  }
}
