/// An environment override whose value can be compared without exposing that value.
package protocol _EquatableEnvironmentModifier: _StructuralView {

  /// The key path selected by this override.
  var environmentOverrideKeyPath: AnyKeyPath { get }

  /// Returns whether `other` identifies the same override and carries an equal value.
  func _hasSameEnvironmentOverride(as other: any _EquatableEnvironmentModifier) -> Bool

  /// Compares an erased candidate against this override's value.
  func _isEnvironmentOverrideValueEqual(to other: Any) -> Bool

  /// Visits the descendant using `resolvedEnvironment` when it is still valid.
  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    reusing resolvedEnvironment: EnvironmentValues?,
    _ visit: (_ViewChild) -> Void
  )
}

/// A structural environment override that applies only to its descendant subtree.
package struct _EnvironmentModifier<Content: View, Value>: View, _StructuralView {
  package typealias Body = Never

  package let content: Content
  package let keyPath: WritableKeyPath<EnvironmentValues, Value>
  package let value: Value
  package let environmentOverrideName: String

  package init(
    content: Content,
    keyPath: WritableKeyPath<EnvironmentValues, Value>,
    value: Value
  ) {
    self.content = content
    self.keyPath = keyPath
    self.value = value
    environmentOverrideName = String(reflecting: keyPath)
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    var resolvedEnvironment = environment
    resolvedEnvironment[keyPath: keyPath] = value

    var resolvedOverrides = environmentOverrides
    resolvedOverrides.append(environmentOverrideName)

    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: resolvedEnvironment,
        environmentOverrides: resolvedOverrides
      )
    )
  }
}

extension _EnvironmentModifier: _EquatableEnvironmentModifier where Value: Equatable {
  package var environmentOverrideKeyPath: AnyKeyPath {
    keyPath
  }

  package func _hasSameEnvironmentOverride(
    as other: any _EquatableEnvironmentModifier
  ) -> Bool {
    keyPath == other.environmentOverrideKeyPath
      && other._isEnvironmentOverrideValueEqual(to: value)
  }

  package func _isEnvironmentOverrideValueEqual(to other: Any) -> Bool {
    guard let other = other as? Value else {
      return false
    }
    return value == other
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    reusing resolvedEnvironment: EnvironmentValues?,
    _ visit: (_ViewChild) -> Void
  ) {
    let childEnvironment: EnvironmentValues
    if let resolvedEnvironment = resolvedEnvironment {
      childEnvironment = resolvedEnvironment
    } else {
      var resolved = environment
      resolved[keyPath: keyPath] = value
      childEnvironment = resolved
    }

    var resolvedOverrides = environmentOverrides
    resolvedOverrides.append(environmentOverrideName)

    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: childEnvironment,
        environmentOverrides: resolvedOverrides
      )
    )
  }
}

extension View {
  /// Overrides one environment value for this view's descendants.
  public func environment<Value>(
    _ keyPath: WritableKeyPath<EnvironmentValues, Value>,
    _ value: Value
  ) -> some View {
    _EnvironmentModifier(content: self, keyPath: keyPath, value: value)
  }
}
