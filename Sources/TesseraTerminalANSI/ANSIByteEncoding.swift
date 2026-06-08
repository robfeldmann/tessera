/// Private byte-building helpers for ANSI/VT control sequences.
enum ANSIByteEncoding {
  static let escape: UInt8 = 0x1B
  static let bell: UInt8 = 0x07

  static func appendCSI(_ body: String, into buffer: inout [UInt8]) {
    buffer.append(Self.escape)
    buffer.append(0x5B)
    buffer.append(contentsOf: body.utf8)
  }

  static func appendOSC(_ body: String, into buffer: inout [UInt8]) {
    buffer.append(Self.escape)
    buffer.append(0x5D)
    buffer.append(contentsOf: body.utf8)
  }

  static func appendSGR(_ parameters: [Int], into buffer: inout [UInt8]) {
    Self.appendCSI(parameters.map(String.init).joined(separator: ";") + "m", into: &buffer)
  }

  static func appendInteger(_ value: Int, into buffer: inout [UInt8]) {
    buffer.append(contentsOf: String(value).utf8)
  }
}
