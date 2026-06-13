import TesseraTerminalANSI
import TesseraTerminalBuffer
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

  /// The visible terminal size for this frame.
  public var size: TerminalSize {
    buffer.pointee.size
  }

  /// Creates a frame that writes into caller-owned `buffer` storage.
  ///
  /// The frame borrows `buffer` for its entire lifetime; the storage must outlive every
  /// use of the frame. `TerminalSession.draw` satisfies this by lending a pointer to a
  /// buffer that lives for the duration of the synchronous render body.
  @_lifetime(borrow buffer)
  package init(buffer: UnsafeMutablePointer<Buffer>) {
    self.buffer = buffer
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
}
