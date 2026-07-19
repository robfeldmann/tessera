extension Optional: View where Wrapped: View {
  public typealias Body = Never
}

extension Optional: _StructuralView, _ViewList where Wrapped: View {
  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    guard let content = self else {
      return
    }

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
