import TesseraTerminalBuffer

/// Tessera's sole terminal-cell style type.
public typealias Style = TesseraTerminalBuffer.Style

/// The terminal color used by style modifiers and semantic roles.
public typealias Color = TesseraTerminalBuffer.Style.ColorValue

private enum _DefaultStyleKey: EnvironmentKey {
  static let defaultValue = Style()._resolved
}

private enum _TruncationMarkKey: EnvironmentKey {
  static let defaultValue = "…"
}

extension EnvironmentValues {
  /// The complete style inherited by text-producing descendants.
  public var defaultStyle: Style {
    get { self[_DefaultStyleKey.self] }
    set { self[_DefaultStyleKey.self] = newValue._resolved }
  }

  /// The single-cell marker used by head, middle, and tail text truncation.
  public var truncationMark: String {
    get { self[_TruncationMarkKey.self] }
    set {
      self[_TruncationMarkKey.self] =
        newValue.count == 1
          && terminalCellWidth(of: newValue) == 1
          && isSupportedStoredGrapheme(newValue)
        ? newValue : _TruncationMarkKey.defaultValue
    }
  }
}
