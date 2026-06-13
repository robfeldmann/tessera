import TesseraTerminalANSI

/// Controls how the renderer compares and repaints a cell.
///
/// Ordinary cells diff by equality, opaque cells are skipped because another subsystem
/// owns their screen region, and always-repaint cells force output even when equal.
public enum CellDiffPolicy: Equatable, Sendable {
  case alwaysRepaint
  case normal
  case opaque
}

/// A single terminal grid cell.
///
/// Wide grapheme and raw regions store their leading content in one cell and use
/// `.continuation` in covered trailing cells so each grid column has explicit state.
public struct Cell: Equatable, Sendable {
  /// The visible or renderer-owned payload stored in a terminal cell.
  public enum Content: Equatable, Sendable {
    /// Empty display cell.
    case blank

    /// Trailing cell covered by a preceding wide grapheme or raw region.
    case continuation

    /// A printable grapheme cluster preserved as received from Swift string iteration.
    case grapheme(String)

    /// Raw terminal bytes anchored at this grid position.
    case raw(RawTerminalPayload)
  }

  public static let blank = Self()

  public var content: Content
  public var style: Style
  public var diffPolicy: CellDiffPolicy

  public var width: Int {
    switch content {
    case .blank:
      1
    case .continuation:
      0
    case .grapheme(let grapheme):
      terminalCellWidth(of: grapheme)
    case .raw(let payload):
      Int(payload.declaredWidth ?? 0)
    }
  }

  public init(
    content: Content = .blank,
    style: Style = Style(),
    diffPolicy: CellDiffPolicy = .normal
  ) {
    self.content = content
    self.style = style
    self.diffPolicy = diffPolicy
  }

  public init(character: Character, style: Style = Style()) {
    self.init(content: .grapheme(String(character)), style: style)
  }
}
