import TesseraTerminalCore

package struct BufferBoundsError: Error, Equatable, Sendable {
  package let row: Int
  package let column: Int
  package let size: TerminalSize
}
