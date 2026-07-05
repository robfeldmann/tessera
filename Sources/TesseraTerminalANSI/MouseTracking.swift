/// Granularity of terminal mouse reporting.
public enum MouseTracking: Hashable, Sendable {
  /// Any-event tracking (DECSET 1003): reports motion even with no button held.
  case anyEvent

  /// Button-event tracking (DECSET 1002): presses, releases, scroll, and drags only.
  case buttonEvents
}
