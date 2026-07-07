/// A Kitty Graphics Protocol image stored in a virtual terminal.
public struct RenderedKittyImage: Equatable, Sendable {
  public let format: RenderedKittyImageFormat
  public let height: Int
  public let id: UInt32
  public let width: Int

  public init(format: RenderedKittyImageFormat, height: Int, id: UInt32, width: Int) {
    self.format = format
    self.height = height
    self.id = id
    self.width = width
  }
}

/// A Kitty Graphics Protocol image format stored in a virtual terminal.
public enum RenderedKittyImageFormat: Equatable, Sendable {
  case gray
  case grayAlpha
  case png
  case rgb
  case rgba
  case unknown
}

/// A Kitty Graphics Protocol placement visible in a virtual terminal.
public struct RenderedKittyPlacement: Equatable, Sendable {
  public let column: Int
  public let columns: Int
  public let imageID: UInt32
  public let placementID: UInt32
  public let row: Int
  public let rows: Int
  public let zIndex: Int32

  public init(
    column: Int,
    columns: Int,
    imageID: UInt32,
    placementID: UInt32,
    row: Int,
    rows: Int,
    zIndex: Int32
  ) {
    self.column = column
    self.columns = columns
    self.imageID = imageID
    self.placementID = placementID
    self.row = row
    self.rows = rows
    self.zIndex = zIndex
  }
}
