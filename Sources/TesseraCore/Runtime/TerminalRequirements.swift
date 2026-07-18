/// Declarative terminal features requested by a view graph.
///
/// The graph only aggregates requests. A terminal session remains responsible for deciding
/// which requests can become effective and for owning every mode transition.
public struct TerminalRequirements: Equatable, Sendable {
  public var wantsKeyboardEnhancement: Bool
  public var wantsMouse: Bool
  public var wantsBracketedPaste: Bool
  public var wantsFocusReporting: Bool

  public init(
    wantsKeyboardEnhancement: Bool = false,
    wantsMouse: Bool = false,
    wantsBracketedPaste: Bool = false,
    wantsFocusReporting: Bool = false
  ) {
    self.wantsKeyboardEnhancement = wantsKeyboardEnhancement
    self.wantsMouse = wantsMouse
    self.wantsBracketedPaste = wantsBracketedPaste
    self.wantsFocusReporting = wantsFocusReporting
  }

  public static func union(_ lhs: Self, _ rhs: Self) -> Self {
    Self(
      wantsKeyboardEnhancement: lhs.wantsKeyboardEnhancement
        || rhs.wantsKeyboardEnhancement,
      wantsMouse: lhs.wantsMouse || rhs.wantsMouse,
      wantsBracketedPaste: lhs.wantsBracketedPaste || rhs.wantsBracketedPaste,
      wantsFocusReporting: lhs.wantsFocusReporting || rhs.wantsFocusReporting
    )
  }
}
