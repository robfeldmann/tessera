/// Type-erases a view while retaining its wrapped dynamic type for reconciliation.
///
/// Descendant identity is preserved while the wrapped dynamic type remains the same. When
/// that type changes, the graph replaces the erased descendant subtree.
public struct AnyView: View, _StructuralView, _AnyViewIdentityBarrier {
  public typealias Body = Never

  package let content: any View

  package var erasedContentType: ObjectIdentifier {
    ObjectIdentifier(type(of: content))
  }

  /// Erases `content` while preserving it for runtime reconciliation.
  public init<Content: View>(_ content: Content) {
    self.content = content
  }

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
}

/// Exposes the wrapped type that defines an erased descendant's identity boundary.
package protocol _AnyViewIdentityBarrier: _StructuralView {
  var erasedContentType: ObjectIdentifier { get }
}
