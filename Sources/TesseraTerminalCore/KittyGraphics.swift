/// A Kitty Graphics Protocol image identifier.
public struct KittyImageID: Equatable, Hashable, RawRepresentable, Sendable {
  public var rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

/// A Kitty Graphics Protocol placement identifier.
public struct KittyPlacementID: Equatable, Hashable, RawRepresentable, Sendable {
  public var rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

/// A Kitty Graphics Protocol response parsed from terminal APC input.
public struct KittyGraphicsResponse: Equatable, Sendable {
  public var id: KittyImageID?
  public var message: String
  public var placement: KittyPlacementID?
  public var success: Bool

  public init(
    id: KittyImageID? = nil,
    placement: KittyPlacementID? = nil,
    message: String
  ) {
    self.id = id
    self.message = message
    self.placement = placement
    self.success = message == "OK"
  }
}
