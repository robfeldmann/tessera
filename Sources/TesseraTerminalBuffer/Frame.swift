import TesseraTerminalANSI
import TesseraTerminalCore

/// A scoped, borrowed drawing surface for one terminal render transaction.
///
/// `Frame` is `~Copyable, ~Escapable`: it cannot be copied, stored, returned, or captured
/// by an escaping task. It is a non-owning view onto buffer storage owned by the render
/// transaction (see `TerminalSession.draw`), so its lifetime is tied to that storage and
/// it can only be touched synchronously while the transaction's body runs. See
/// `docs/Spec.md` Phase 2 Slice 4 ("Width-aware `Buffer` + damage-tracking renderer") for
/// why the frame is a dumb, borrowed write surface with no view-layer knowledge.
public struct Frame: ~Copyable, ~Escapable {
  private let buffer: UnsafeMutablePointer<Buffer>
  private let cursorPosition: UnsafeMutablePointer<TerminalPosition?>

  /// The visible terminal size for this frame.
  public var size: TerminalSize {
    buffer.pointee.size
  }

  /// Creates a frame that writes into caller-owned `buffer` storage.
  ///
  /// The frame borrows `buffer` for its entire lifetime; the storage must outlive every
  /// use of the frame. `TerminalSession.draw` satisfies this by lending a pointer to a
  /// buffer that lives for the duration of the synchronous render body.
  @_lifetime(borrow buffer, borrow cursorPosition)
  package init(
    buffer: UnsafeMutablePointer<Buffer>,
    cursorPosition: UnsafeMutablePointer<TerminalPosition?>
  ) {
    self.buffer = buffer
    self.cursorPosition = cursorPosition
  }

  /// Writes text into the frame buffer.
  public borrowing func write(
    _ string: String,
    at position: TerminalPosition,
    style: Style = Style()
  ) {
    buffer.pointee.write(string, at: position, style: style)
  }

  /// Anchors raw terminal bytes in the frame buffer.
  public borrowing func writeRaw(
    _ payload: RawTerminalPayload,
    at position: TerminalPosition,
    occupying occupied: Rect,
    repaintPolicy: CellDiffPolicy = .alwaysRepaint
  ) {
    buffer.pointee.writeRaw(
      payload,
      at: position,
      occupying: occupied,
      repaintPolicy: repaintPolicy
    )
  }

  /// Marks a frame region as externally owned until later reclaimed by normal writes.
  public borrowing func markOpaque(_ region: Rect) {
    buffer.pointee.markOpaque(region)
  }

  /// Encodes an `a=p` Kitty image placement anchored at `position` and reserves `region`.
  ///
  /// `position` must equal `region.origin`: KGP places images extending right and down
  /// from the cursor, so the anchor is always the placement's top-left cell. The anchor
  /// is always repainted because re-sending the same image/placement pair is a
  /// flicker-free in-place replacement; this self-heals after terminal clears and resizes.
  /// The terminal can still evict underlying image data under quota pressure; apps should
  /// watch `KittyGraphicsResponse` failures and retransmit when needed.
  public borrowing func placeImage(
    _ placement: KittyGraphicsPlacement,
    at position: TerminalPosition,
    occupying region: Rect
  ) {
    let payload = RawTerminalPayload(
      bytes: ControlSequence.kittyGraphics(.place(placement)).bytes
    )
    writeRaw(payload, at: position, occupying: region, repaintPolicy: .alwaysRepaint)

    if region.size.columns > 1 {
      markOpaque(
        Rect(
          column: position.column + 1,
          row: position.row,
          columns: region.size.columns - 1,
          rows: 1
        )
      )
    }
    if region.size.rows > 1 {
      markOpaque(
        Rect(
          column: region.origin.column,
          row: position.row + 1,
          columns: region.size.columns,
          rows: region.size.rows - 1
        )
      )
    }
  }

  /// Makes the cursor visible at `position` after this frame is drawn.
  ///
  /// Frames hide the cursor by default. Text-input UIs should call this once per frame
  /// when an insertion point should be visible.
  public borrowing func setCursorPosition(_ position: TerminalPosition) {
    cursorPosition.pointee = position
  }
}
