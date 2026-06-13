/// Controls whether rendered frames use DEC synchronized output wrappers.
public enum SynchronizedOutputPolicy: Equatable, Sendable {
  /// Emit frame bytes without synchronized output wrappers.
  case disabled

  /// Wrap each frame in enter/exit synchronized output sequences.
  case enabled
}
