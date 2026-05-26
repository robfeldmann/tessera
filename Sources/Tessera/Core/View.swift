/// The core protocol for all renderable elements in Tessera.
///
/// Any type that conforms to `View` can be rendered in the terminal.
public protocol View: Sendable {
  /// Returns the intrinsic size of the view.
  func measure()

  /// Renders the view into the current buffer.
  func render()
}
