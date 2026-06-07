/// A terminal color reconstructed by the virtual terminal.
public enum RenderedColor: Sendable, Equatable {
  case `default`
  case indexed(UInt8)
  case rgb(UInt8, UInt8, UInt8)
}
