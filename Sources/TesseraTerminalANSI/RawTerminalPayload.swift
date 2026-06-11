/// Raw terminal bytes that Tessera does not semantically model yet.
public struct RawTerminalPayload: Equatable, Sendable {
  /// The bytes to append to the terminal output stream.
  public let bytes: [UInt8]

  /// The caller-declared display width, if the payload affects visible cells.
  public let declaredWidth: UInt?

  public init(bytes: [UInt8], declaredWidth: UInt? = nil) {
    self.bytes = bytes
    self.declaredWidth = declaredWidth
  }
}
