/// Coordinates terminal mode ownership for a live terminal session.
public actor ModeLifecycle {
  /// Terminal modes Tessera can acquire for an application session.
  public enum Mode: Hashable, Sendable {
    /// Raw input mode.
    case rawMode

    /// Alternate screen buffer.
    case altScreen

    /// Mouse tracking. Deferred to Phase 3.
    case mouseTracking

    /// Bracketed paste. Deferred to Phase 3.
    case bracketedPaste

    /// Focus events. Deferred to Phase 3.
    case focusEvents

    /// Kitty keyboard protocol. Deferred to Phase 3.
    case kittyKeyboard
  }

  private let io: PlatformIO
  private var modes: Set<Mode> = []

  /// The modes currently believed active by this lifecycle manager.
  public var activeModes: Set<Mode> {
    modes
  }

  /// Creates a lifecycle manager over owned package-internal terminal I/O.
  package init(io: PlatformIO) {
    self.io = io
  }

  /// Records requested modes. Phase 2 implements ordered acquisition and rollback.
  public func enter(_ modes: Set<Mode>) async throws {
    self.modes = modes
  }

  /// Clears recorded modes. Phase 2 implements ordered teardown.
  public func exit() async throws {
    modes = []
  }
}
