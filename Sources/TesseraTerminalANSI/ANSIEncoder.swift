/// Encodes semantic terminal control sequences into ANSI/VT byte streams.
public enum ANSIEncoder {
  /// Returns the bytes for `sequences` in order.
  public static func encode(_ sequences: some Sequence<ControlSequence>) -> [UInt8] {
    var bytes: [UInt8] = []
    for sequence in sequences {
      sequence.encode(into: &bytes)
    }
    return bytes
  }
}
