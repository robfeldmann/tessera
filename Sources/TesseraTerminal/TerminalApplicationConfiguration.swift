import TesseraTerminalIO

/// Configuration for a scoped live terminal application session.
public struct TerminalApplicationConfiguration: Equatable, Sendable {
  /// The default terminal application configuration.
  public static var `default`: Self {
    Self(modes: [.rawMode, .altScreen])
  }

  /// Terminal modes to acquire for the session.
  public var modes: Set<ModeLifecycle.Mode>

  /// Creates a terminal application configuration.
  public init(modes: Set<ModeLifecycle.Mode>) {
    self.modes = modes
  }
}
