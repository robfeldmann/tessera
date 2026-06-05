import CustomDump

/// A custom dump wrapper for renderer byte output.
public struct RendererCustomDump: CustomDumpStringConvertible, Sendable {
  public var bytes: [UInt8]

  /// Renders exact bytes and readable terminal text in semantic chunks.
  ///
  /// For example:
  ///
  /// ```text
  /// [home]
  /// bytes: 1B 5B 48
  /// text:  ␛[H
  ///
  /// [row 0]
  /// bytes: 20 20 20 0D 0A
  /// text:  ···␍␊
  /// ```
  public var customDumpDescription: String {
    semanticChunks(from: bytes)
      .map { chunk in
        """
        [\(chunk.name)]
        bytes: \(chunk.bytes.map(hexByte).joined(separator: " "))
        text:  \(chunk.bytes.map(visibleByte).joined())
        """
      }
      .joined(separator: "\n\n")
  }

  public init(bytes: [UInt8]) {
    self.bytes = bytes
  }
}

private struct RendererChunk {
  var name: String
  var bytes: [UInt8]
}

private func semanticChunks(from bytes: [UInt8]) -> [RendererChunk] {
  var chunks: [RendererChunk] = []
  var index = bytes.startIndex

  if bytes.starts(with: [0x1B, 0x5B, 0x48]) {
    chunks.append(RendererChunk(name: "home", bytes: Array(bytes[..<3])))
    index = 3
  }

  var row = 0
  while index < bytes.endIndex {
    let start = index

    while index < bytes.endIndex {
      if index + 1 < bytes.endIndex, bytes[index] == 0x0D, bytes[index + 1] == 0x0A {
        index += 2
        break
      }

      index += 1
    }

    chunks.append(RendererChunk(name: "row \(row)", bytes: Array(bytes[start..<index])))
    row += 1
  }

  return chunks
}

private func hexByte(_ byte: UInt8) -> String {
  let hex = String(byte, radix: 16, uppercase: true)
  return hex.count == 1 ? "0\(hex)" : hex
}

private func visibleByte(_ byte: UInt8) -> String {
  switch byte {
  case 0x0A:
    "␊"
  case 0x0D:
    "␍"
  case 0x1B:
    "␛"
  case 0x20:
    "·"
  case 0x21...0x7E:
    String(UnicodeScalar(byte))
  default:
    "<0x\(hexByte(byte))>"
  }
}
