private enum _IsEnabledKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  /// Whether controls in this subtree accept focus and interaction.
  public var isEnabled: Bool {
    get { self[_IsEnabledKey.self] }
    set { self[_IsEnabledKey.self] = newValue }
  }
}

extension View {
  /// Enables or disables controls in this subtree.
  public func disabled(_ disabled: Bool = true) -> some View {
    environment(\.isEnabled, !disabled)
  }
}
