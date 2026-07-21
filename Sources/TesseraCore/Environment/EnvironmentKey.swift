/// Defines a value that can be supplied through a view subtree.
public protocol EnvironmentKey {
  /// The value stored for this environment key.
  associatedtype Value

  /// The value supplied when no ancestor overrides this key.
  static var defaultValue: Value { get }
}
