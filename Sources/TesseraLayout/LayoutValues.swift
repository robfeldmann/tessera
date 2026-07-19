import TesseraCore

package enum _LayoutPriorityKey: LayoutValueKey {
  package static let defaultValue = 0
}

package enum _SpacerLayoutValueKey: LayoutValueKey {
  package static let defaultValue = false
}

package struct _LayoutValueModifier<Content: View, Key: LayoutValueKey>: View,
  _LayoutValueProvider, _StructuralView
{
  package typealias Body = Never

  let content: Content
  let value: Key.Value

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

  package func _layoutValue(for key: ObjectIdentifier) -> Any? {
    guard key == ObjectIdentifier(Key.self) else {
      return nil
    }
    return value
  }
}

extension View {
  /// Supplies a custom value to the nearest enclosing layout.
  public func layoutValue<Key: LayoutValueKey>(
    key: Key.Type,
    value: Key.Value
  ) -> some View {
    _LayoutValueModifier<Self, Key>(content: self, value: value)
  }

  /// Sets the allocation priority read by an enclosing linear stack.
  public func layoutPriority(_ priority: Int) -> some View {
    layoutValue(key: _LayoutPriorityKey.self, value: priority)
  }
}
