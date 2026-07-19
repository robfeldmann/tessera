/// A structural container whose children are identified by stable hashable keys.
public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View,
  _StructuralView, _ViewList
{
  public typealias Body = Never

  package let data: Data
  package let keyPath: KeyPath<Data.Element, ID>
  package let content: (Data.Element) -> Content

  /// Creates keyed children from `data` using `id` for each element's stable identity.
  public init(
    _ data: Data,
    id: KeyPath<Data.Element, ID>,
    @ViewBuilder content: @escaping (Data.Element) -> Content
  ) {
    self.data = data
    keyPath = id
    self.content = content
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    for element in data {
      visit(
        _ViewChild(
          slot: .id(AnyHashable(element[keyPath: keyPath])),
          view: content(element),
          environment: environment,
          environmentOverrides: environmentOverrides
        )
      )
    }
  }
}

extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
  /// Creates keyed children using each identifiable element's `id`.
  public init(
    _ data: Data,
    @ViewBuilder content: @escaping (Data.Element) -> Content
  ) {
    self.init(data, id: \.id, content: content)
  }
}
