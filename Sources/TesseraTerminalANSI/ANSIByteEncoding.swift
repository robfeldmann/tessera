/// Private byte-building helpers for ANSI/VT control sequences.
enum ANSIByteEncoding {
  /// ESC, the C0 escape control character used to introduce 7-bit escape sequences.
  static let escape: UInt8 = 0x1B

  /// BEL, the C0 bell control character.
  static let bell: UInt8 = 0x07

  /// Appends a 7-bit Control Sequence Introducer: `ESC [` followed by `body`.
  static func appendCSI(_ body: String, into buffer: inout [UInt8]) {
    buffer.append(Self.escape)
    buffer.append(0x5B)
    buffer.append(contentsOf: body.utf8)
  }

  /// Appends a 7-bit Operating System Command introducer: `ESC ]` followed by `body`.
  static func appendOSC(_ body: String, into buffer: inout [UInt8]) {
    buffer.append(Self.escape)
    buffer.append(0x5D)
    buffer.append(contentsOf: body.utf8)
  }

  /// Appends an ECMA-48 Select Graphic Rendition sequence: `CSI Ps ... m`.
  static func appendSGR(_ parameters: [Int], into buffer: inout [UInt8]) {
    Self.appendCSI(
      parameters.map(String.init).joined(separator: ";") + "m",
      into: &buffer
    )
  }

  static func appendInteger(_ value: Int, into buffer: inout [UInt8]) {
    buffer.append(contentsOf: String(value).utf8)
  }
}
