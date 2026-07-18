/// A synchronous, UI-scoped invalidation capability supplied while handling an event.
///
/// It deliberately contains no render, terminal, or application-state authority. Runtime
/// code consumes the package-visible requests after the event handler returns.
public struct ResponderContext: ~Copyable {
  package var needsDisplay = false
  package var needsLayout = false

  package init() {}

  /// Requests another render pass after the current event dispatch completes.
  public mutating func setNeedsDisplay() {
    needsDisplay = true
  }

  /// Requests a new layout pass after the current event dispatch completes.
  public mutating func setNeedsLayout() {
    needsLayout = true
    needsDisplay = true
  }
}
