/// A stable, human-readable path to a node in a ``ViewGraph``.
public struct NodeIdentity: CustomStringConvertible, Hashable, Sendable {
  /// The root node identity.
  public static let root = Self(components: ["root"])

  private let components: [String]

  /// The slash-delimited structural path from the root.
  public var description: String {
    components.joined(separator: "/")
  }

  package init(components: [String]) {
    self.components = components
  }

  package func appending(_ component: String) -> Self {
    Self(components: components + [component])
  }
}
