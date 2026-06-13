/// The outcome of writing a single grapheme into a terminal buffer.
public enum GraphemeWriteResult: Equatable, Sendable {
  /// The grapheme did not fit in the target row and no cells were changed.
  case clipped

  /// The grapheme is not displayable or is not supported by Tessera's cell model.
  case unsupported

  /// The grapheme was written and subsequent output should continue at `nextColumn`.
  case written(nextColumn: Int)
}
