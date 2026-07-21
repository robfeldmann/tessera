/// A structural wrapper that lets reconciliation skip an unchanged equatable subtree.
public struct EquatableView<Content: View & Equatable>: View, _EquatableView {
  public typealias Body = Never

  package let content: Content

  /// Creates an equatable wrapper for `content`.
  public init(_ content: Content) {
    self.content = content
  }

  package func _isContentEqual(to other: any View) -> Bool {
    guard let other = other as? EquatableView<Content> else {
      return false
    }

    return content == other.content
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

extension View where Self: Equatable {
  /// Marks this view as equatable so an equal replacement can retain its whole subtree.
  public func equatable() -> EquatableView<Self> {
    EquatableView(self)
  }
}

/// Lets reconciliation compare the concrete value inside an ``EquatableView``.
package protocol _EquatableView: _StructuralView {
  func _isContentEqual(to other: any View) -> Bool
}
