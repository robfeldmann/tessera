/// A view with no children and no rendered output.
public struct EmptyView: View, _StructuralView, _ViewList {
  public typealias Body = Never

  /// Creates an empty view.
  public init() {}

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {}
}
