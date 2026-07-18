/// The two possible values of an `if` / `else` expression.
public struct ConditionalView<TrueContent: View, FalseContent: View>: View, _StructuralView
{
  public typealias Body = Never

  package enum Storage {
    case trueContent(TrueContent)
    case falseContent(FalseContent)
  }

  package let storage: Storage

  package init(storage: Storage) {
    self.storage = storage
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    switch storage {
    case .trueContent(let content):
      visit(
        _ViewChild(
          slot: .branch(true),
          view: content,
          environment: environment,
          environmentOverrides: environmentOverrides
        )
      )
    case .falseContent(let content):
      visit(
        _ViewChild(
          slot: .branch(false),
          view: content,
          environment: environment,
          environmentOverrides: environmentOverrides
        )
      )
    }
  }
}
