import TesseraTerminalBuffer
import TesseraTerminalCore

func withTestFrame(
  size: TerminalSize,
  _ body: (borrowing Frame) -> Void
) -> (buffer: Buffer, cursor: TerminalPosition?) {
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      body(Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return (buffer, cursorPosition)
}
