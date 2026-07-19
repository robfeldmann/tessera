import TesseraCore
import TesseraTerminalCore

/// An integer-cell algorithm that measures and places a view's direct children.
public protocol Layout {
  /// Returns the size selected for `subviews` under `proposal`.
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize

  /// Places each visible child in absolute `bounds`.
  func placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: Subviews
  )
}

/// A value supplied by a child to its enclosing layout.
public protocol LayoutValueKey {
  /// The value supplied to a layout.
  associatedtype Value
  /// The value read when a child does not supply this key.
  static var defaultValue: Value { get }
}

/// The direct children available to a ``Layout`` implementation.
public struct Subviews: RandomAccessCollection {
  /// The collection's integer position.
  public typealias Index = Int

  /// One child measured and placed by a ``Layout``.
  public struct Subview {
    /// The child's allocation priority in a linear stack.
    public var priority: Int {
      self[_LayoutPriorityKey.self]
    }

    package var _isSpacer: Bool {
      self[_SpacerLayoutValueKey.self]
    }

    private let proxy: _LayoutSubviewProxy

    package init(_ proxy: _LayoutSubviewProxy) {
      self.proxy = proxy
    }

    /// Measures this child under `proposal`.
    public func sizeThatFits(_ proposal: ProposedSize) -> TerminalSize {
      proxy.measure(proposal)
    }

    /// Places this child at an absolute terminal-cell origin.
    public func place(
      at origin: TerminalPosition,
      proposal: ProposedSize
    ) {
      proxy.place(origin, proposal)
    }

    /// Reads a value supplied by this child for its enclosing layout.
    public subscript<Key: LayoutValueKey>(key: Key.Type) -> Key.Value {
      proxy.value(ObjectIdentifier(key)) as? Key.Value ?? Key.defaultValue
    }
  }

  /// The first valid subview index.
  public var startIndex: Int { proxy.startIndex }
  /// The end sentinel after the final subview index.
  public var endIndex: Int { proxy.endIndex }

  private let proxy: _LayoutSubviewsProxy

  package init(_ proxy: _LayoutSubviewsProxy) {
    self.proxy = proxy
  }

  /// Accesses the child at `position`.
  public subscript(position: Int) -> Subview {
    Subview(proxy[position])
  }
}

extension Layout {
  /// Creates a view whose direct children are managed by this layout value.
  public func callAsFunction<Content: View>(
    @ViewBuilder _ content: () -> Content
  ) -> some View {
    _LayoutContainer(layout: self, content: content())
  }
}

package struct _LayoutContainer<Algorithm: Layout, Content: View>: View, _LayoutView {
  package typealias Body = Never

  let layout: Algorithm
  let content: Content

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    _visitLayoutChildren(
      content,
      in: environment,
      environmentOverrides: environmentOverrides,
      visit
    )
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    layout.sizeThatFits(proposal, subviews: Subviews(subviews))
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    layout.placeSubviews(
      in: bounds,
      proposal: proposal,
      subviews: Subviews(subviews)
    )
  }
}
