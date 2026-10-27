import TesseraTerminalInput

/// The terminal's own colors, as its replies to the OSC 10, 11, and 4 color round report
/// them.
///
/// Every input is optional: a terminal that does not answer, or answers only some slots,
/// leaves the rest `nil`, which means unknown rather than failed. A later reply, such as
/// one that follows a color-scheme change, replaces the stored value.
public struct TerminalColorReport: Equatable, Sendable {
  /// The ANSI palette slots Tessera asks for: 0 through 15.
  public static let slotRange = 0...15

  /// The terminal's default foreground color (OSC 10), or `nil` when unknown.
  public var foreground: TerminalRGBColor?

  /// The terminal's default background color (OSC 11), or `nil` when unknown.
  public var background: TerminalRGBColor?

  /// The reported ANSI palette colors (OSC 4), keyed by slot index. A slot with no entry
  /// is unknown.
  public var slots: [Int: TerminalRGBColor]

  /// Creates a color report; the default has every input unknown.
  public init(
    foreground: TerminalRGBColor? = nil,
    background: TerminalRGBColor? = nil,
    slots: [Int: TerminalRGBColor] = [:]
  ) {
    self.foreground = foreground
    self.background = background
    self.slots = slots
  }

  /// Stores a reply, replacing any earlier value for the same color. A reply for a slot
  /// outside ``slotRange`` is ignored.
  package mutating func record(_ reply: TerminalColorReply) {
    switch reply.role {
    case .background:
      background = reply.color
    case .foreground:
      foreground = reply.color
    case .slot(let index) where Self.slotRange.contains(index):
      slots[index] = reply.color
    case .slot:
      break
    }
  }

  /// The reported color for `role`, or `nil` when it is unknown.
  public subscript(role: TerminalColorRole) -> TerminalRGBColor? {
    switch role {
    case .background:
      background
    case .foreground:
      foreground
    case .slot(let index):
      slots[index]
    }
  }
}
