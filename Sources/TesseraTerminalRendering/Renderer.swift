import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore

/// Encodes damage-tracked terminal buffer frames.
package struct Renderer {
  private var currentStyle: Style?
  private var eraseBeforeNextRepaint = false
  private var believedCursorPosition: TerminalPosition?

  package init() {}

  package static func render(_ buffer: Buffer) -> [UInt8] {
    render(previous: nil, current: buffer)
  }

  package static func render(previous: Buffer?, current: Buffer) -> [UInt8] {
    var renderer = Self()
    var bytes: [UInt8] = []
    renderer.encodeFrame(
      previous: previous,
      current: current,
      wrapInSynchronizedOutput: false,
      into: &bytes
    )
    return bytes
  }

  package mutating func encodeFrame(
    previous: Buffer?,
    current: Buffer,
    wrapInSynchronizedOutput: Bool,
    into bytes: inout [UInt8]
  ) {
    if wrapInSynchronizedOutput {
      ControlSequence.enterSynchronizedOutput.encode(into: &bytes)
    }

    let shouldErase = eraseBeforeNextRepaint || previous == nil
    if shouldErase {
      ControlSequence.eraseInDisplay(.all).encode(into: &bytes)
      believedCursorPosition = nil
      currentStyle = nil
    }

    let damagePrevious = shouldErase ? nil : previous
    for run in BufferDiff.damageRuns(previous: damagePrevious, current: current) {
      encode(run: run, from: current, into: &bytes)
    }

    ControlSequence.resetAttributes.encode(into: &bytes)
    currentStyle = Style()
    eraseBeforeNextRepaint = false

    if wrapInSynchronizedOutput {
      ControlSequence.exitSynchronizedOutput.encode(into: &bytes)
    }
  }

  package mutating func invalidate() {
    currentStyle = nil
    believedCursorPosition = nil
    eraseBeforeNextRepaint = true
  }

  private mutating func encode(
    run: RowDamageRun,
    from buffer: Buffer,
    into bytes: inout [UInt8]
  ) {
    for column in run.columns {
      let cell = buffer[run.row, column]
      guard cell.content != .continuation else {
        continue
      }

      let position = TerminalPosition(column: column, row: run.row)
      if believedCursorPosition != position {
        ControlSequence.cursorPosition(position).encode(into: &bytes)
        believedCursorPosition = position
      }

      sgrDelta(from: currentStyle, to: cell.style, into: &bytes)
      currentStyle = cell.style
      encodeContent(cell.content, into: &bytes)
      believedCursorPosition = TerminalPosition(column: column + cell.width, row: run.row)
    }
  }

  private func encodeContent(_ content: Cell.Content, into bytes: inout [UInt8]) {
    switch content {
    case .blank:
      ControlSequence.text(" ").encode(into: &bytes)
    case .continuation:
      break
    case .grapheme(let grapheme):
      ControlSequence.text(grapheme).encode(into: &bytes)
    case .raw(let payload):
      ControlSequence.raw(payload).encode(into: &bytes)
    }
  }
}
