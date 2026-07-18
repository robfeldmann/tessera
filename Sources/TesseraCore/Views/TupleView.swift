/// A fixed structural container whose children retain their individual dynamic view types.
public struct TupleView<each Content: View>: View, _StructuralView {
  public typealias Body = Never

  package let content: (repeat each Content)

  package init(_ content: repeat each Content) {
    self.content = (repeat each content)
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var index = 0

    for child in repeat each content {
      visit(
        _ViewChild(
          slot: .index(index),
          view: child,
          environment: environment,
          environmentOverrides: environmentOverrides
        )
      )
      index += 1
    }
  }
}
