import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalRendering

extension VirtualTerminal {
  /// Renders a borrowed frame into a virtual terminal and returns its completed screen.
  ///
  /// This test-only seam exercises the production `Frame`, `Buffer`, and `Renderer`
  /// pipeline without opening a live terminal session.
  public static func snapshot(
    size: TerminalSize,
    draw: (borrowing Frame) throws -> Void
  ) rethrows -> ScreenSnapshot {
    var buffer = Buffer(size: size)
    var cursorPosition: TerminalPosition?

    try withUnsafeMutablePointer(to: &buffer) { bufferPointer in
      try withUnsafeMutablePointer(to: &cursorPosition) { cursorPointer in
        let frame = Frame(buffer: bufferPointer, cursorPosition: cursorPointer)
        try draw(frame)
      }
    }

    let terminal = ghosttyOrUnavailable(cols: size.columns, rows: size.rows)
    terminal.feed(Renderer.render(buffer))
    return terminal.snapshot()
  }
}
