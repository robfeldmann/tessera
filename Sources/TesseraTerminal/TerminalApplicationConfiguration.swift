import TesseraTerminalIO

/// Configuration for a scoped live terminal application session.
public struct TerminalApplicationConfiguration: Equatable, Sendable {
  /// The default terminal application configuration.
  public static var `default`: Self {
    Self(modes: [.rawMode, .altScreen, .bracketedPaste])
  }

  /// Terminal modes to acquire for the session.
  public var modes: Set<ModeLifecycle.Mode>

  /// Whether draw transactions should use DEC synchronized output wrappers.
  public var synchronizedOutput: SynchronizedOutputPolicy

  /// Creates a terminal application configuration.
  public init(
    modes: Set<ModeLifecycle.Mode>,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled
  ) {
    self.modes = modes
    self.synchronizedOutput = synchronizedOutput
  }
}
