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
    let isEqual: (Self) -> Bool

    init<Value>(_ value: Value) {
      self.value = value
      if let equatable = value as? any Equatable {
        isEqual = { other in Self.valuesEqual(equatable, other.value) }
      } else {
        isEqual = { _ in false }
      }
    }

    private static func valuesEqual(_ lhs: any Equatable, _ rhs: Any) -> Bool {
      func compare<Value: Equatable>(_ typed: Value) -> Bool {
        (rhs as? Value) == typed
      }
      return compare(lhs)
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

  /// Whether both environments carry equal values for the same keys.
  ///
  /// Distinct copy-on-write storage created while threading unchanged values (for example a
  /// stack setting its axis every pass) still compares equal, so reconciliation can reuse the
  /// prior subtree. Keys holding non-`Equatable` values compare unequal, invalidating safely.
  package func _hasEqualValues(as other: Self) -> Bool {
    guard storage.values.count == other.storage.values.count else {
      return false
    }
    for (key, box) in storage.values {
      guard let otherBox = other.storage.values[key], box.isEqual(otherBox) else {
        return false
      }
    }
    return true
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
