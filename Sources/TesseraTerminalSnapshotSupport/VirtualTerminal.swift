import IssueReporting
import TesseraTerminalCore

/// A dependency client for inspecting a virtual terminal session.
public struct VirtualTerminal: Sendable {
  /// Returns the rendered cell at a zero-based row and column.
  public var cell: @Sendable (_ row: Int, _ column: Int) -> RenderedCell

  /// Returns the terminal cursor position.
  public var cursor: @Sendable () -> TerminalPosition

  /// Feeds raw terminal bytes into the virtual terminal.
  public var feed: @Sendable ([UInt8]) -> Void

  /// Returns Kitty Graphics Protocol images stored by the terminal.
  public var kittyImages: @Sendable () -> [RenderedKittyImage]

  /// Returns Kitty Graphics Protocol placements visible in the terminal.
  public var kittyPlacements: @Sendable () -> [RenderedKittyPlacement]

  /// Returns the visible terminal screen.
  public var snapshot: @Sendable () -> ScreenSnapshot

  /// Returns the visible text for a zero-based row.
  public var text: @Sendable (Int) -> String

  public init(
    feed: @escaping @Sendable ([UInt8]) -> Void = unimplemented(
      "VirtualTerminal.feed"
    ),
    text: @escaping @Sendable (Int) -> String = unimplemented(
      "VirtualTerminal.text",
      placeholder: ""
    ),
    cell:
      @escaping @Sendable (
        _ row: Int,
        _ column: Int
      ) -> RenderedCell = unimplemented(
        "VirtualTerminal.cell",
        placeholder: .blank
      ),
    cursor: @escaping @Sendable () -> TerminalPosition = unimplemented(
      "VirtualTerminal.cursor",
      placeholder: TerminalPosition(column: 0, row: 0)
    ),
    kittyImages: @escaping @Sendable () -> [RenderedKittyImage] = unimplemented(
      "VirtualTerminal.kittyImages",
      placeholder: []
    ),
    kittyPlacements: @escaping @Sendable () -> [RenderedKittyPlacement] = unimplemented(
      "VirtualTerminal.kittyPlacements",
      placeholder: []
    ),
    snapshot: @escaping @Sendable () -> ScreenSnapshot = unimplemented(
      "VirtualTerminal.snapshot",
      placeholder: ScreenSnapshot.empty
    )
  ) {
    self.feed = feed
    self.text = text
    self.cell = cell
    self.cursor = cursor
    self.snapshot = snapshot
    self.kittyImages = kittyImages
    self.kittyPlacements = kittyPlacements
  }

  /// Feeds UTF-8 text into the virtual terminal.
  public func feed(_ string: String) {
    self.feed(Array(string.utf8))
  }

  /// Returns the visible text for a zero-based row.
  public func text(row: Int) -> String {
    self.text(row)
  }

  /// Returns the rendered cell at a zero-based row and column.
  public func cell(row: Int, column: Int) -> RenderedCell {
    self.cell(row, column)
  }

  /// Returns the terminal cursor position.
  public func cursorPosition() -> TerminalPosition {
    self.cursor()
  }
}
