import Tessera

/// Coordinates synchronous application work in the host's isolation domain.
///
/// The app owns its model and root factory. Every event is followed by one explicit
/// update; observation never performs graph work. Presentation completes only after
/// the session has flushed the borrowed render transaction. No async work is drained.
package final class ApplicationDriver {
  private struct BaselineModes {
    let mouseTracking: MouseTrackingMode
    let keyboardProtocol: KeyboardProtocolMode
    let focusEventsEnabled: Bool
    let bracketedPasteEnabled: Bool
  }

  package let graph: ViewGraph
  package private(set) var frameSequence = 0

  private let traversesFocus: Bool
  private var baselineModes: BaselineModes?

  package init<Root: View>(
    size: TerminalSize, focusTraversal: Bool = false, root: @escaping () -> Root
  ) {
    traversesFocus = focusTraversal
    graph = ViewGraph(root: root, size: size)
  }

  /// Routes ordinary semantic input before applying the host's unhandled quit policy.
  /// Returns whether the host should continue accepting input.
  @discardableResult
  package func step(_ event: InputEvent) -> Bool {
    let disposition = graph.dispatch(event)
    if disposition == .ignored, traversesFocus,
      case .key(let key) = event, key.kind == .press, key.code == .tab
    {
      if key.modifiers.isEmpty {
        graph.focus.advance(.forward)
      } else if key.modifiers == .shift {
        graph.focus.advance(.backward)
      }
    }
    if case .resize(let size) = event {
      graph.resize(to: size)
    }
    graph.update()
    graph.revealFocusedContent()
    if disposition == .ignored,
      case .key(let key) = event,
      key.kind == .press, key.code == .character("q"), key.modifiers.isEmpty
    {
      return false
    }
    return true
  }

  /// Explicitly reconciles externally completed model work, without presenting it.
  package func update() {
    graph.update()
    graph.revealFocusedContent()
  }

  /// Presents at most once, using actual device geometry, and awaits output completion.
  /// The caller must use the same isolation domain that created this driver.
  @discardableResult
  package func present(to terminal: isolated TerminalSession) async throws -> Bool {
    try await applyTerminalRequirements(to: terminal)
    guard graph.needsRender else {
      return false
    }
    var rendered = false
    try await terminal.draw { frame in
      // Borrowed frame geometry is authoritative for this checkpoint. Resize before
      // focus reveal so off-screen descendants are revealed against the real terminal.
      graph.resize(to: frame.size)
      graph.revealFocusedContent()
      guard graph.needsRender else {
        return
      }
      graph.render(into: frame)
      rendered = true
    }
    guard rendered else {
      return false
    }
    // Layout can change terminal demand (for example, a newly inserted input leaf).
    // Reconcile modes after the single render transaction without drawing again.
    try await applyTerminalRequirements(to: terminal)
    frameSequence += 1
    return true
  }

  private func applyTerminalRequirements(to terminal: isolated TerminalSession)
    async throws
  {
    if baselineModes == nil {
      baselineModes = BaselineModes(
        mouseTracking: terminal.mouseTracking,
        keyboardProtocol: terminal.keyboardProtocol,
        focusEventsEnabled: terminal.focusEventsEnabled,
        bracketedPasteEnabled: terminal.bracketedPasteEnabled
      )
    }
    let requirements = graph.terminalRequirements
    guard let baselineModes else {
      return
    }
    let desiredMouse =
      requirements.wantsMouseMotion
      ? .anyEvent
      : requirements.wantsMouse
        ? (baselineModes.mouseTracking == .disabled
          ? .buttonEvents : baselineModes.mouseTracking)
        : baselineModes.mouseTracking
    if terminal.mouseTracking != desiredMouse {
      try await terminal.setMouseTracking(desiredMouse)
    }
    let desiredKeyboard =
      requirements.wantsKeyboardEnhancement
      ? (baselineModes.keyboardProtocol == .legacyOnly
        ? .kittyIfAvailable : baselineModes.keyboardProtocol)
      : baselineModes.keyboardProtocol
    if terminal.keyboardProtocol != desiredKeyboard {
      try await terminal.setKeyboardProtocol(desiredKeyboard)
    }
    let desiredFocusEvents =
      requirements.wantsFocusReporting || baselineModes.focusEventsEnabled
    if terminal.focusEventsEnabled != desiredFocusEvents {
      try await terminal.setFocusEvents(desiredFocusEvents)
    }
    let desiredBracketedPaste =
      requirements.wantsBracketedPaste || baselineModes.bracketedPasteEnabled
    if terminal.bracketedPasteEnabled != desiredBracketedPaste {
      try await terminal.setBracketedPaste(desiredBracketedPaste)
    }
  }
}
