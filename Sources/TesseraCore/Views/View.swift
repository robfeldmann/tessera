/// A value that describes a portion of a terminal user interface.
///
/// Views are ordinary, non-`Sendable` values. Composite views describe their descendants
/// through ``body``; the view graph evaluates that property during reconciliation only.
public protocol View {
  /// The declarative view produced by this value.
  associatedtype Body: View

  /// Describes this composite view's direct body.
  @ViewBuilder var body: Body { get }
}

/// Supplies the unreachable body implementation used by leaves and structural views.
extension View where Body == Never {
  /// A primitive has no body for the graph to evaluate.
  public var body: Never {
    fatalError("A primitive or structural view's body must not be evaluated.")
  }
}

extension Never: View {
  public typealias Body = Never

}
