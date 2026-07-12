import TesseraTerminalCore

/// A semantic terminal mouse event parsed from SGR mouse reports.
public struct MouseEvent: Equatable, Sendable {
  public var kind: MouseEventKind
  public var modifiers: Modifiers
  public var position: TerminalPosition

  public init(
    kind: MouseEventKind,
    position: TerminalPosition,
    modifiers: Modifiers = []
  ) {
    self.kind = kind
    self.modifiers = modifiers
    self.position = position
  }
}

/// The semantic kind of a terminal mouse event.
public enum MouseEventKind: Equatable, Sendable {
  case drag(MouseButton)
  case move
  case press(MouseButton)
  case release(MouseButton?)
  case scroll(MouseScrollDirection)
}

/// Mouse buttons represented by SGR mouse reports.
public enum MouseButton: Equatable, Sendable {
  case left
  case middle
  case right
}

/// Scroll-wheel direction represented by SGR mouse reports.
public enum MouseScrollDirection: Equatable, Sendable {
  case down
  case left
  case right
  case up
}
