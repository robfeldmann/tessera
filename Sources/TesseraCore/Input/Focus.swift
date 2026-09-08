/// An explicit, stable identity for one focusable view.
///
/// The erased value is immutable and can only be initialized from a Sendable value.
/// The unchecked conformance preserves that invariant across AnyHashable's type erasure;
/// no mutable graph or focus-manager reference crosses isolation through this value.
public struct FocusID: Hashable, @unchecked Sendable {
  private let value: AnyHashable

  /// Creates an identity from an application-owned hashable value.
  public init<Value: Hashable & Sendable>(_ value: Value) {
    self.value = AnyHashable(value)
  }
}

private enum _IsFocusedKey: EnvironmentKey {
  static let defaultValue = false
}

private enum _IsFocusWithinKey: EnvironmentKey {
  static let defaultValue = false
}

private struct _FocusEnvironment: Equatable {
  let manager: FocusManager

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.manager === rhs.manager
  }
}

private enum _FocusEnvironmentKey: EnvironmentKey {
  static var defaultValue: _FocusEnvironment? { nil }
}

extension EnvironmentValues {
  /// Whether this view's nearest focusable ancestor owns the current focus.
  public var isFocused: Bool {
    get { self[_IsFocusedKey.self] }
    set { self[_IsFocusedKey.self] = newValue }
  }

  /// Whether the current focus is owned by this view or a live descendant.
  public var isFocusWithin: Bool {
    get { self[_IsFocusWithinKey.self] }
    set { self[_IsFocusWithinKey.self] = newValue }
  }

  package var _focusManager: FocusManager? {
    get { self[_FocusEnvironmentKey.self]?.manager }
    set {
      self[_FocusEnvironmentKey.self] = newValue.map(_FocusEnvironment.init(manager:))
    }
  }

  package var _focusedID: FocusID? {
    _focusManager?.focused
  }
}

/// A direction through the document-ordered focus list.
public enum FocusDirection: Equatable, Sendable {
  case backward
  case forward
}

/// Owns the current focus and the live document-ordered focus list for a graph.
public final class FocusManager {
  /// The currently focused live identity, or `nil` when focus is clear.
  public private(set) var focused: FocusID?

  /// Live focus identities in depth-first document order.
  public private(set) var focusableIDs: [FocusID] = []

  package var onChange: ((FocusID?) -> Void)?

  package init() {}

  /// Focuses a live identity, or clears focus when `id` is `nil` or no longer live.
  public func focus(_ id: FocusID?) {
    let resolved = id.flatMap { focusableIDs.contains($0) ? $0 : nil }
    guard resolved != focused else {
      return
    }
    focused = resolved
    onChange?(resolved)
  }

  /// Advances through live identities in document order and wraps at either end.
  public func advance(_ direction: FocusDirection) {
    guard !focusableIDs.isEmpty else {
      focus(nil)
      return
    }

    guard let focused, let index = focusableIDs.firstIndex(of: focused) else {
      focus(direction == .forward ? focusableIDs[0] : focusableIDs[focusableIDs.count - 1])
      return
    }

    switch direction {
    case .backward:
      focus(focusableIDs[(index - 1 + focusableIDs.count) % focusableIDs.count])
    case .forward:
      focus(focusableIDs[(index + 1) % focusableIDs.count])
    }
  }

  package func replaceFocusableIDs(
    _ ids: [FocusID],
    preserving pendingIDs: Set<FocusID> = []
  ) {
    var seen: Set<FocusID> = []
    focusableIDs = ids.filter { seen.insert($0).inserted }
    if let focused, !seen.contains(focused), !pendingIDs.contains(focused) {
      focus(nil)
    }
  }
}
