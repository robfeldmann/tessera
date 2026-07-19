import TesseraTerminalCore

/// Type-erased callbacks that let a downstream layout module measure and place one child.
package struct _LayoutSubviewProxy {
  package let measure: (ProposedSize) -> TerminalSize
  package let place: (TerminalPosition, ProposedSize) -> Void
  package let value: (ObjectIdentifier) -> Any?

  package init(
    measure: @escaping (ProposedSize) -> TerminalSize,
    place: @escaping (TerminalPosition, ProposedSize) -> Void,
    value: @escaping (ObjectIdentifier) -> Any?
  ) {
    self.measure = measure
    self.place = place
    self.value = value
  }
}

/// The direct children offered to a downstream layout implementation.
package struct _LayoutSubviewsProxy: RandomAccessCollection {
  package typealias Index = Int

  private let elements: [_LayoutSubviewProxy]

  package var startIndex: Int { elements.startIndex }
  package var endIndex: Int { elements.endIndex }

  package init(_ elements: [_LayoutSubviewProxy]) {
    self.elements = elements
  }

  package subscript(position: Int) -> _LayoutSubviewProxy {
    elements[position]
  }
}

/// A structural view whose direct children are measured and placed by a custom algorithm.
package protocol _LayoutView: _StructuralView {
  func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize

  func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  )
}

/// Supplies type-erased values read by an enclosing layout.
package protocol _LayoutValueProvider {
  func _layoutValue(for key: ObjectIdentifier) -> Any?
}
