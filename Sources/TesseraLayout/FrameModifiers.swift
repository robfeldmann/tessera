import TesseraCore
import TesseraTerminalCore

private struct _FrameLayout: Layout {
  let width: Int?
  let height: Int?
  let minWidth: Int?
  let maxWidth: Int?
  let minHeight: Int?
  let maxHeight: Int?
  let alignment: Alignment

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    guard let child = subviews.first else {
      return TerminalSize(columns: width ?? minWidth ?? 0, rows: height ?? minHeight ?? 0)
    }
    let childProposal = ProposedSize(
      width: proposedAxis(parent: proposal.width, fixed: width, maximum: maxWidth),
      height: proposedAxis(parent: proposal.height, fixed: height, maximum: maxHeight)
    )
    let childSize = child.sizeThatFits(childProposal)
    return TerminalSize(
      columns: resolvedAxis(
        child: childSize.columns, fixed: width, minimum: minWidth, maximum: maxWidth),
      rows: resolvedAxis(
        child: childSize.rows, fixed: height, minimum: minHeight, maximum: maxHeight)
    )
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    guard let child = subviews.first else {
      return
    }
    let childProposal = ProposedSize(
      width: proposedAxis(parent: bounds.size.columns, fixed: width, maximum: maxWidth),
      height: proposedAxis(parent: bounds.size.rows, fixed: height, maximum: maxHeight)
    )
    let childSize = child.sizeThatFits(childProposal)
    let horizontal = _alignmentOffset(
      slack: max(bounds.size.columns - childSize.columns, 0),
      alignment: alignment.horizontal
    )
    let vertical = _alignmentOffset(
      slack: max(bounds.size.rows - childSize.rows, 0),
      alignment: alignment.vertical
    )
    child.place(
      at: TerminalPosition(
        column: bounds.origin.column + horizontal,
        row: bounds.origin.row + vertical
      ),
      proposal: childProposal
    )
  }

  private func proposedAxis(parent: Int?, fixed: Int?, maximum: Int?) -> Int? {
    if let fixed {
      return fixed
    }
    guard let maximum else {
      return parent
    }
    return min(parent ?? maximum, maximum)
  }

  private func resolvedAxis(
    child: Int,
    fixed: Int?,
    minimum: Int?,
    maximum: Int?
  ) -> Int {
    if let fixed {
      return fixed
    }
    return min(max(child, minimum ?? child), maximum ?? Int.max)
  }
}

private struct _PaddingLayout: Layout {
  let insets: EdgeInsets

  private var insetSize: TerminalSize {
    TerminalSize(
      columns: insets.leading + insets.trailing,
      rows: insets.top + insets.bottom
    )
  }

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    guard let child = subviews.first else {
      return insetSize
    }
    let size = child.sizeThatFits(reduced(proposal))
    return TerminalSize(
      columns: size.columns + insetSize.columns,
      rows: size.rows + insetSize.rows
    )
  }

  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  ) {
    guard let child = subviews.first else {
      return
    }
    child.place(
      at: TerminalPosition(
        column: bounds.origin.column + insets.leading,
        row: bounds.origin.row + insets.top
      ),
      proposal: reduced(
        ProposedSize(width: bounds.size.columns, height: bounds.size.rows)
      )
    )
  }

  private func reduced(_ proposal: ProposedSize) -> ProposedSize {
    ProposedSize(
      width: proposal.width.map { max($0 - insetSize.columns, 0) },
      height: proposal.height.map { max($0 - insetSize.rows, 0) }
    )
  }
}

extension View {
  /// Places this view in a frame with optional fixed axes.
  public func frame(
    width: Int? = nil,
    height: Int? = nil,
    alignment: Alignment = .topLeading
  ) -> some View {
    _validateExtent(width, name: "width")
    _validateExtent(height, name: "height")
    return _FrameLayout(
      width: width,
      height: height,
      minWidth: nil,
      maxWidth: nil,
      minHeight: nil,
      maxHeight: nil,
      alignment: alignment
    ) {
      self
    }
  }

  /// Places this view in a frame that clamps its measured axes to supplied bounds.
  public func frame(
    minWidth: Int? = nil,
    maxWidth: Int? = nil,
    minHeight: Int? = nil,
    maxHeight: Int? = nil,
    alignment: Alignment = .topLeading
  ) -> some View {
    _validateBounds(minimum: minWidth, maximum: maxWidth, axis: "width")
    _validateBounds(minimum: minHeight, maximum: maxHeight, axis: "height")
    return _FrameLayout(
      width: nil,
      height: nil,
      minWidth: minWidth,
      maxWidth: maxWidth,
      minHeight: minHeight,
      maxHeight: maxHeight,
      alignment: alignment
    ) {
      self
    }
  }

  /// Reserves explicit nonnegative cells around this view.
  public func padding(_ insets: EdgeInsets) -> some View {
    _PaddingLayout(insets: insets) {
      self
    }
  }

  /// Reserves the same nonnegative cell count on every edge.
  public func padding(_ all: Int = 1) -> some View {
    padding(EdgeInsets(all))
  }
}

private func _validateExtent(_ extent: Int?, name: String) {
  if let extent {
    precondition(extent >= 0, "Frame \(name) must be nonnegative.")
  }
}

private func _validateBounds(minimum: Int?, maximum: Int?, axis: String) {
  _validateExtent(minimum, name: "minimum \(axis)")
  _validateExtent(maximum, name: "maximum \(axis)")
  if let minimum, let maximum {
    precondition(minimum <= maximum, "Frame minimum \(axis) must not exceed its maximum.")
  }
}
