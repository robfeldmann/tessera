import Foundation
import TesseraTerminalCore

/// A Kitty Graphics Protocol image payload format.
public enum KittyImageFormat: Equatable, Sendable {
  /// PNG image bytes; dimensions come from the PNG itself.
  case png

  /// Raw RGB pixels with explicit pixel dimensions.
  case rgb(width: Int, height: Int)

  /// Raw RGBA pixels with explicit pixel dimensions.
  case rgba(width: Int, height: Int)
}

/// Kitty Graphics Protocol response-noise policy.
public enum KittyGraphicsQuiet: Equatable, Sendable {
  /// Suppress both OK and failure responses.
  case suppressFailures

  /// Suppress OK responses while preserving failures.
  case suppressOK

  /// Request verbose responses.
  case verbose
}

/// A direct Kitty Graphics Protocol image transmission.
public struct KittyGraphicsTransmission: Equatable, Sendable {
  /// Raw pixel or PNG bytes; not pre-base64 encoded.
  public var data: [UInt8]

  /// Payload format metadata.
  public var format: KittyImageFormat

  /// Protocol image id.
  public var id: KittyImageID

  /// Response-noise policy. Defaults to suppressing OK responses only.
  public var quiet: KittyGraphicsQuiet

  public init(
    id: KittyImageID,
    format: KittyImageFormat,
    data: [UInt8],
    quiet: KittyGraphicsQuiet = .suppressOK
  ) {
    self.data = data
    self.format = format
    self.id = id
    self.quiet = quiet
  }
}

/// A Kitty Graphics Protocol placement command.
public struct KittyGraphicsPlacement: Equatable, Sendable {
  /// Cell columns the placement occupies.
  public var columns: Int?

  /// Protocol image id.
  public var id: KittyImageID

  /// Optional protocol placement id.
  public var placement: KittyPlacementID?

  /// Response-noise policy. Defaults to suppressing OK responses only.
  public var quiet: KittyGraphicsQuiet

  /// Cell rows the placement occupies.
  public var rows: Int?

  /// Placement z-index.
  public var zIndex: Int32

  public init(
    id: KittyImageID,
    placement: KittyPlacementID? = nil,
    columns: Int? = nil,
    rows: Int? = nil,
    zIndex: Int32 = 0,
    quiet: KittyGraphicsQuiet = .suppressOK
  ) {
    self.columns = columns
    self.id = id
    self.placement = placement
    self.quiet = quiet
    self.rows = rows
    self.zIndex = zIndex
  }
}

/// A Kitty Graphics Protocol deletion target.
public enum KittyGraphicsDelete: Equatable, Sendable {
  /// Delete all images and placements.
  case all

  /// Delete an image and its data.
  case image(KittyImageID)

  /// Delete one placement while retaining image data.
  case placement(KittyImageID, KittyPlacementID)
}

/// A Kitty Graphics Protocol command.
public enum KittyGraphicsCommand: Equatable, Sendable {
  /// Delete images or placements.
  case delete(KittyGraphicsDelete)

  /// Place a previously-transmitted image.
  case place(KittyGraphicsPlacement)

  /// Query support for direct RGB Kitty Graphics Protocol commands.
  case query(id: KittyImageID)

  /// Transmit image data directly through the terminal stream.
  case transmit(KittyGraphicsTransmission)
}

extension KittyGraphicsCommand {
  func encode(into buffer: inout [UInt8]) {
    switch self {
    case .delete(let delete):
      ANSIByteEncoding.appendAPC("G" + delete.controlString, into: &buffer)
      ANSIByteEncoding.appendST(into: &buffer)

    case .place(let placement):
      ANSIByteEncoding.appendAPC("G" + placement.controlString, into: &buffer)
      ANSIByteEncoding.appendST(into: &buffer)

    case .query(let id):
      ANSIByteEncoding.appendAPC(
        "Gi=\(id.rawValue),s=1,v=1,a=q,t=d,f=24;AAAA",
        into: &buffer
      )
      ANSIByteEncoding.appendST(into: &buffer)

    case .transmit(let transmission):
      transmission.encodeChunks(into: &buffer)
    }
  }
}

extension KittyGraphicsDelete {
  fileprivate var controlString: String {
    switch self {
    case .all:
      return "a=d,d=A"
    case .image(let id):
      return "a=d,d=I,i=\(id.rawValue)"
    case .placement(let id, let placementID):
      return "a=d,d=i,i=\(id.rawValue),p=\(placementID.rawValue)"
    }
  }
}

extension KittyGraphicsPlacement {
  fileprivate var controlString: String {
    var keys = ["a=p", "i=\(id.rawValue)"]
    if let placement {
      keys.append("p=\(placement.rawValue)")
    }
    if let columns {
      keys.append("c=\(columns)")
    }
    if let rows {
      keys.append("r=\(rows)")
    }
    keys.append("z=\(zIndex)")
    keys.append("C=1")
    keys.append("q=\(quiet.wireValue)")
    return keys.joined(separator: ",")
  }
}

extension KittyGraphicsQuiet {
  fileprivate var wireValue: Int {
    switch self {
    case .suppressFailures:
      return 2
    case .suppressOK:
      return 1
    case .verbose:
      return 0
    }
  }
}

extension KittyGraphicsTransmission {
  fileprivate func encodeChunks(into buffer: inout [UInt8]) {
    let base64 = Array(Data(data).base64EncodedString().utf8)
    let chunkSize = 4_096
    var offset = 0
    var isFirstChunk = true

    repeat {
      let end = min(offset + chunkSize, base64.count)
      let isLastChunk = end == base64.count

      var keys: [String] = []
      if isFirstChunk {
        keys.append("a=t")
        keys.append("i=\(id.rawValue)")
        switch format {
        case .png:
          keys.append("f=100")
        case .rgb(let width, let height):
          keys.append("f=24")
          keys.append("s=\(width)")
          keys.append("v=\(height)")
        case .rgba(let width, let height):
          keys.append("f=32")
          keys.append("s=\(width)")
          keys.append("v=\(height)")
        }
        keys.append("t=d")
        keys.append("q=\(quiet.wireValue)")
      }
      keys.append("m=\(isLastChunk ? 0 : 1)")

      ANSIByteEncoding.appendAPC("G" + keys.joined(separator: ",") + ";", into: &buffer)
      buffer.append(contentsOf: base64[offset..<end])
      ANSIByteEncoding.appendST(into: &buffer)

      offset = end
      isFirstChunk = false
    } while offset < base64.count
  }
}
