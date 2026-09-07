import TesseraTerminalCore

/// A synchronous, UI-scoped invalidation capability supplied while handling an event.
///
/// It deliberately contains no render, terminal, or application-state authority. Runtime
/// code consumes the package-visible requests after the event handler returns.
public struct ResponderContext: ~Copyable {
  package var needsDisplay = false
  package var needsLayout = false
  private let requestFocus: (FocusID?) -> Void
  private let requestFocusAdvance: (FocusDirection) -> Void

  /// The final laid-out bounds of the responder receiving this callback.
  public let nodeBounds: Rect

  /// Whether the responder receiving this callback owns current focus.
  public let isFocused: Bool

  /// Whether current focus lives on the responder receiving this callback or on one of
  /// its descendants. Lets an enclosing viewport act on keys its focused descendant
  /// declined, so unconsumed scroll keys bubble to the nearest ancestor that can use
  /// them.
  public let isFocusWithin: Bool

  package init(
    nodeBounds: Rect = Rect(column: 0, row: 0, columns: 0, rows: 0),
    isFocused: Bool = false,
    isFocusWithin: Bool = false,
    requestFocus: @escaping (FocusID?) -> Void = { _ in },
    requestFocusAdvance: @escaping (FocusDirection) -> Void = { _ in }
  ) {
    self.nodeBounds = nodeBounds
    self.isFocused = isFocused
    self.isFocusWithin = isFocusWithin
    self.requestFocus = requestFocus
    self.requestFocusAdvance = requestFocusAdvance
  }

  /// Requests another render pass after the current event dispatch completes.
  public mutating func setNeedsDisplay() {
    needsDisplay = true
  }

  /// Requests a new layout pass after the current event dispatch completes.
  public mutating func setNeedsLayout() {
    needsLayout = true
    needsDisplay = true
  }

  /// Moves focus to a live explicit identity, or clears it with `nil`.
  public mutating func focus(_ id: FocusID?) {
    requestFocus(id)
  }

  /// Advances focus through the live document-order list.
  public mutating func focusAdvance(_ direction: FocusDirection) {
    requestFocusAdvance(direction)
  }
}
