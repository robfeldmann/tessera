import TesseraTerminalCore

// Cases intentionally follow pointer lifecycle order: motion, wheel, press, release, cancel.
// swiftlint:disable sorted_enum_cases
/// A normalized pointer phase delivered to view responders.
public enum PointerPhase: Equatable, Sendable {
  /// Cancellation caused by focus loss, removal, disablement, or an invalid release.
  case cancel
  /// A primary/button press at the event location.
  case down
  /// Pointer motion, with or without a button held.
  case move
  /// A wheel step in the indicated direction.
  case scrollUp
  case scrollDown
  case scrollLeft
  case scrollRight
  /// A button release at the event location.
  case up
}

// swiftlint:enable sorted_enum_cases

/// A normalized pointer event from terminal mouse input. Down/up phases carry a button;
/// move reports motion and cancel clears an interaction without representing hover state.
public struct PointerEvent: Equatable, Sendable {
  /// The normalized pointer phase.
  public var phase: PointerPhase

  /// The button associated with this phase, if the terminal report identifies one.
  public var button: MouseButton?

  /// The terminal cell position where the phase occurred.
  public var position: TerminalPosition

  /// Modifier keys active for the pointer phase.
  public var modifiers: Modifiers

  /// Creates a normalized pointer event.
  public init(
    phase: PointerPhase,
    button: MouseButton? = nil,
    position: TerminalPosition,
    modifiers: Modifiers = []
  ) {
    self.phase = phase
    self.button = button
    self.position = position
    self.modifiers = modifiers
  }

  /// Converts a parsed mouse event to its normalized pointer phase.
  public init?(mouse event: MouseEvent) {
    let phase: PointerPhase
    let button: MouseButton?
    switch event.kind {
    case .press(let value):
      phase = .down
      button = value
    case .release(let value):
      phase = .up
      button = value
    case .drag(let value):
      phase = .move
      button = value
    case .move:
      phase = .move
      button = nil
    case .scroll(let direction):
      switch direction {
      case .up: phase = .scrollUp
      case .down: phase = .scrollDown
      case .left: phase = .scrollLeft
      case .right: phase = .scrollRight
      }
      button = nil
    }
    self.init(
      phase: phase, button: button, position: event.position, modifiers: event.modifiers)
  }
}
