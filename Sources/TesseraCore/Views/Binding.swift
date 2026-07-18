/// A controlled mutable value supplied and owned by the application.
@propertyWrapper
public struct Binding<Value> {
  private let getValue: () -> Value
  private let setValue: (Value) -> Void

  /// The application-owned value read and written through this binding.
  public var wrappedValue: Value {
    get {
      getValue()
    }
    nonmutating set {
      setValue(newValue)
    }
  }

  /// Returns this binding for property-wrapper projection.
  public var projectedValue: Self {
    self
  }

  /// Creates a binding from application-owned getter and setter closures.
  public init(
    get: @escaping () -> Value,
    set: @escaping (Value) -> Void
  ) {
    getValue = get
    setValue = set
  }

  /// Creates a read-only binding whose setter intentionally has no effect.
  public static func constant(_ value: Value) -> Self {
    Self(get: { value }, set: { _ in })
  }
}
