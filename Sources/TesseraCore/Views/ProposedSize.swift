/// The size offered to a leaf during layout. `nil` means unconstrained.
public struct ProposedSize: Hashable, Sendable {
  public static let unspecified = Self(width: nil, height: nil)

  public var width: Int?
  public var height: Int?

  public init(width: Int?, height: Int?) {
    self.width = width
    self.height = height
  }
}
