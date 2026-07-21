import TesseraTerminalANSI
import TesseraTerminalCore

/// A scoped, borrowed drawing surface for one terminal render transaction.
///
/// `Frame` is `~Copyable, ~Escapable`: it cannot be copied, stored, returned, or captured
/// by an escaping task. It is a non-owning view onto buffer storage owned by the render
/// transaction (see `TerminalSession.draw`), so its lifetime is tied to that storage and
/// it can only be touched synchronously while the transaction's body runs. It is a dumb,
/// borrowed write surface with no view-layer knowledge so rendering can mutate only the
/// transaction-owned buffer.
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

  /// Lends a clipped, translated region over this frame for the duration of `body`.
  ///
  /// `rect` and `clip` use frame coordinates. The yielded region starts its own coordinate
  /// system at `(0, 0)`, preserves `rect` as its local bounds, and silently clips writes to
  /// both the frame and `clip`.
  public borrowing func withRenderRegion(
    in rect: Rect,
    clip: Rect? = nil,
    _ body: (inout FrameRegion) -> Void
  ) {
    let frameBounds = Rect(
      origin: TerminalPosition(column: 0, row: 0),
      size: size
    )
    let regionClip = rect.intersection(frameBounds).flatMap { visibleRect in
      guard let clip else {
        return visibleRect
      }
      return visibleRect.intersection(clip)
    }
    var region = FrameRegion(
      buffer: buffer,
      cursorPosition: cursorPosition,
      origin: rect.origin,
      bounds: Rect(
        origin: TerminalPosition(column: 0, row: 0),
        size: rect.size
      ),
      clip: regionClip
    )
    body(&region)
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

/// A clipped, translated, borrowed window over a frame buffer.
///
/// This is intentionally a terminal-buffer primitive rather than a view-layer type: it
/// owns the frame's private borrowed pointers while exposing only cell-level drawing
/// operations. Higher layers may alias it, but cannot obtain the underlying buffer or
/// terminal session authority.
public struct FrameRegion: ~Copyable, ~Escapable {
  private let buffer: UnsafeMutablePointer<Buffer>
  private let cursorPosition: UnsafeMutablePointer<TerminalPosition?>
  private let origin: TerminalPosition
  private let localBounds: Rect
  private let clip: Rect?

  /// Local coordinates for this region. The origin is always `(0, 0)`.
  public var bounds: Rect {
    localBounds
  }

  @_lifetime(borrow buffer, borrow cursorPosition)
  package init(
    buffer: UnsafeMutablePointer<Buffer>,
    cursorPosition: UnsafeMutablePointer<TerminalPosition?>,
    origin: TerminalPosition,
    bounds: Rect,
    clip: Rect?
  ) {
    self.buffer = buffer
    self.cursorPosition = cursorPosition
    self.origin = origin
    self.localBounds = bounds
    self.clip = clip
  }

  /// Writes text without wrapping, clipping every grapheme to this region.
  public mutating func write(
    _ string: String,
    at position: TerminalPosition,
    style: Style = Style()
  ) {
    guard containsLocalRow(position.row) else {
      return
    }

    var column = position.column
    for character in string {
      let grapheme = String(character)
      guard isSupportedStoredGrapheme(grapheme) else {
        continue
      }

      let width = terminalCellWidth(of: grapheme)
      guard width > 0 else {
        continue
      }

      guard column >= 0 else {
        guard let nextColumn = adding(width, to: column) else {
          return
        }
        column = nextColumn
        continue
      }

      guard column < localBounds.size.columns,
        width <= localBounds.size.columns - column,
        let absolutePosition = absolutePosition(
          for: TerminalPosition(column: column, row: position.row)
        ),
        let clip
      else {
        return
      }

      if absolutePosition.column < clip.origin.column {
        guard let nextColumn = adding(width, to: column) else {
          return
        }
        column = nextColumn
        continue
      }

      guard hasVisibleWidth(width, from: absolutePosition, in: clip),
        canReplaceCells(
          fromColumn: absolutePosition.column,
          width: width,
          row: absolutePosition.row,
          in: clip
        )
      else {
        return
      }

      buffer.pointee.write(grapheme, at: absolutePosition, style: style)
      guard let nextColumn = adding(width, to: column) else {
        return
      }
      column = nextColumn
    }
  }

  /// Sets one local buffer cell when its position lies inside this region.
  public mutating func setCell(_ cell: Cell, at position: TerminalPosition) {
    guard containsLocal(position),
      let absolutePosition = absolutePosition(for: position),
      let clip,
      clip.contains(absolutePosition),
      let width = replacementWidth(of: cell),
      hasVisibleWidth(width, from: absolutePosition, in: clip),
      canReplaceCells(
        fromColumn: absolutePosition.column,
        width: max(width, 1),
        row: absolutePosition.row,
        in: clip
      )
    else {
      return
    }

    buffer.pointee.setClusterCell(
      cell,
      row: absolutePosition.row,
      column: absolutePosition.column
    )
  }

  /// Fills the intersection of `rect` and this region with `cell`.
  public mutating func fill(_ cell: Cell, in rect: Rect) {
    guard clip != nil,
      let visibleRect = localBounds.intersection(rect)
    else {
      return
    }

    let step = max(replacementWidth(of: cell) ?? 1, 1)
    for row in visibleRect.rowRange {
      var column = visibleRect.origin.column
      while column < visibleRect.maxColumn {
        setCell(cell, at: TerminalPosition(column: column, row: row))
        column += step
      }
    }
  }

  /// Lends a local sub-region translated from this region and clipped to its visible area.
  public mutating func with(_ rect: Rect, _ body: (inout Self) -> Void) {
    let childBounds = Rect(
      origin: TerminalPosition(column: 0, row: 0),
      size: rect.size
    )
    guard let childOrigin = absolutePosition(for: rect.origin) else {
      var child = Self(
        buffer: buffer,
        cursorPosition: cursorPosition,
        origin: TerminalPosition(column: 0, row: 0),
        bounds: childBounds,
        clip: nil
      )
      body(&child)
      return
    }

    let childRect = Rect(origin: childOrigin, size: rect.size)
    var child = Self(
      buffer: buffer,
      cursorPosition: cursorPosition,
      origin: childOrigin,
      bounds: childBounds,
      clip: clip.flatMap { $0.intersection(childRect) }
    )
    body(&child)
  }

  /// Anchors a raw terminal payload inside this region.
  public mutating func raw(_ payload: RawTerminalPayload, at position: TerminalPosition) {
    guard containsLocal(position),
      let absolutePosition = absolutePosition(for: position),
      let clip,
      clip.contains(absolutePosition),
      let width = rawWidth(of: payload),
      hasVisibleWidth(width, from: absolutePosition, in: clip),
      canReplaceCells(
        fromColumn: absolutePosition.column,
        width: max(width, 1),
        row: absolutePosition.row,
        in: clip
      )
    else {
      return
    }

    buffer.pointee.writeRaw(
      payload,
      at: absolutePosition,
      occupying: Rect(
        origin: absolutePosition,
        size: TerminalSize(columns: width, rows: 1)
      )
    )
  }

  /// Requests the hardware cursor at a local position if it is visible in this region.
  public mutating func requestCursor(at position: TerminalPosition) {
    guard containsLocal(position),
      let absolutePosition = absolutePosition(for: position),
      let clip,
      clip.contains(absolutePosition)
    else {
      return
    }

    cursorPosition.pointee = absolutePosition
  }

  private func containsLocalRow(_ row: Int) -> Bool {
    row >= 0 && row < localBounds.size.rows
  }

  private func containsLocal(_ position: TerminalPosition) -> Bool {
    position.column >= 0
      && position.column < localBounds.size.columns
      && containsLocalRow(position.row)
  }

  private func absolutePosition(for localPosition: TerminalPosition) -> TerminalPosition? {
    guard let column = adding(localPosition.column, to: origin.column),
      let row = adding(localPosition.row, to: origin.row)
    else {
      return nil
    }

    return TerminalPosition(column: column, row: row)
  }

  private func hasVisibleWidth(
    _ width: Int,
    from position: TerminalPosition,
    in clip: Rect
  ) -> Bool {
    guard width >= 0,
      position.column >= clip.origin.column,
      position.row >= clip.origin.row,
      position.row < clip.maxRow
    else {
      return false
    }

    return width <= clip.maxColumn - position.column
  }

  private func replacementWidth(of cell: Cell) -> Int? {
    switch cell.content {
    case .blank, .continuation:
      return 1
    case .grapheme(let grapheme):
      return terminalCellWidth(of: grapheme)
    case .raw(let payload):
      return payload.declaredWidth.flatMap(Int.init(exactly:)) ?? 0
    }
  }

  private func rawWidth(of payload: RawTerminalPayload) -> Int? {
    let width = payload.declaredWidth ?? 0
    guard width <= UInt(Int.max) else {
      return nil
    }
    return Int(width)
  }

  private func canReplaceCells(
    fromColumn column: Int,
    width: Int,
    row: Int,
    in clip: Rect
  ) -> Bool {
    guard width > 0 else {
      return true
    }

    for targetColumn in column..<(column + width) {
      guard
        clusterContaining(row: row, column: targetColumn)
          .map({ cluster in
            cluster.leadingColumn >= clip.origin.column
              && cluster.leadingColumn + cluster.width <= clip.maxColumn
          }) ?? true
      else {
        return false
      }
    }

    return true
  }

  private func clusterContaining(row: Int, column: Int) -> (
    leadingColumn: Int, width: Int
  )? {
    guard let cell = buffer.pointee.cell(row: row, column: column) else {
      return nil
    }

    var leadingColumn = column
    if cell.content == .continuation {
      while leadingColumn > 0,
        buffer.pointee.cell(row: row, column: leadingColumn)?.content == .continuation
      {
        leadingColumn -= 1
      }
    }

    guard let leadingCell = buffer.pointee.cell(row: row, column: leadingColumn),
      leadingCell.width > 0,
      leadingColumn + leadingCell.width > column
    else {
      return nil
    }

    return (leadingColumn, leadingCell.width)
  }

  private func adding(_ rhs: Int, to lhs: Int) -> Int? {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    return overflow ? nil : result
  }
}
