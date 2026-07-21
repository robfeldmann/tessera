/// Builds a structural view tree from declarative view expressions.
@resultBuilder
public enum ViewBuilder {
  /// Builds an empty block as an ``EmptyView``.
  public static func buildBlock() -> EmptyView {
    EmptyView()
  }

  /// Builds a fixed structural container using Swift parameter packs.
  public static func buildBlock<each Content: View>(
    _ content: repeat each Content
  ) -> TupleView<repeat each Content> {
    TupleView(repeat each content)
  }

  /// Builds the true branch of a conditional expression.
  public static func buildEither<TrueContent: View, FalseContent: View>(
    first content: TrueContent
  ) -> ConditionalView<TrueContent, FalseContent> {
    ConditionalView(storage: .trueContent(content))
  }

  /// Builds the false branch of a conditional expression.
  public static func buildEither<TrueContent: View, FalseContent: View>(
    second content: FalseContent
  ) -> ConditionalView<TrueContent, FalseContent> {
    ConditionalView(storage: .falseContent(content))
  }

  /// Builds an optional expression without evaluating an absent child.
  public static func buildOptional<Content: View>(_ content: Content?) -> Content? {
    content
  }

  /// Admits a view expression unchanged.
  public static func buildExpression<Content: View>(_ content: Content) -> Content {
    content
  }
}
