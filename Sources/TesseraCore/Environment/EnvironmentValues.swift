/// A copy-on-write collection of values inherited by view descendants.
public struct EnvironmentValues {
  private final class Storage {
    var values: [ObjectIdentifier: ValueBox]

    init(values: [ObjectIdentifier: ValueBox] = [:]) {
      self.values = values
    }

    init(copying storage: Storage) {
      values = storage.values
    }
  }

  private struct ValueBox {
    let value: Any

    init<Value>(_ value: Value) {
      self.value = value
    }
  }

  private var storage: Storage

  /// Creates an environment populated only by each key's default value.
  public init() {
    storage = Storage()
  }

  package func _hasSameStorage(as other: Self) -> Bool {
    storage === other.storage
  }

  private mutating func ensureUniqueStorage() {
    guard !isKnownUniquelyReferenced(&storage) else {
      return
    }

    storage = Storage(copying: storage)
  }

  /// Reads or overrides the value associated with `key`.
  public subscript<Key: EnvironmentKey>(key: Key.Type) -> Key.Value {
    get {
      let identifier = ObjectIdentifier(key)
      guard let value = storage.values[identifier] else {
        return Key.defaultValue
      }

      // The identifier is derived from `Key`, so this cast pairs only with a value set
      // through this same subscript. Boxing preserves an explicitly stored optional nil.
      guard let typedValue = value.value as? Key.Value else {
        preconditionFailure("An environment key was paired with a value of another type.")
      }
      return typedValue
    }
    set {
      ensureUniqueStorage()
      storage.values[ObjectIdentifier(key)] = ValueBox(newValue)
    }
  }
}
