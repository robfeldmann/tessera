/// Constructs a view from the environment resolved at its location in the tree.
public struct EnvironmentReader<Content: View>: View, _StructuralView {
  public typealias Body = Never

  private let content: (EnvironmentValues) -> Content

  /// Creates a reader whose content is evaluated by reconciliation with the local values.
  public init(@ViewBuilder _ content: @escaping (EnvironmentValues) -> Content) {
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
        view: content(environment),
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}
