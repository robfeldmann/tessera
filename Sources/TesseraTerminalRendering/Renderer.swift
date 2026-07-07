import Foundation
import TesseraTerminalANSI
import TesseraTerminalBuffer
import TesseraTerminalCore

/// Encodes damage-tracked terminal buffer frames.
package struct Renderer {
  private var currentStyle: Style?
  private var currentHyperlink: Hyperlink?
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

    let shouldErase =
      eraseBeforeNextRepaint || previous == nil || previous?.size != current.size
    if shouldErase {
      closeCurrentHyperlink(into: &bytes)
      ControlSequence.eraseInDisplay(.all).encode(into: &bytes)
      believedCursorPosition = nil
      currentStyle = nil
      currentHyperlink = nil
    }

    let damagePrevious = shouldErase ? nil : previous
    for run in BufferDiff.damageRuns(previous: damagePrevious, current: current) {
      encode(run: run, from: current, into: &bytes)
    }

    closeCurrentHyperlink(into: &bytes)
    ControlSequence.resetAttributes.encode(into: &bytes)
    currentStyle = Style()
    currentHyperlink = nil
    eraseBeforeNextRepaint = false

    if wrapInSynchronizedOutput {
      ControlSequence.exitSynchronizedOutput.encode(into: &bytes)
    }
  }

  package mutating func invalidate() {
    currentStyle = nil
    believedCursorPosition = nil
    currentHyperlink = nil
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

      hyperlinkDelta(to: cell.style.hyperlink, into: &bytes)
      sgrDelta(from: currentStyle, to: cell.style, into: &bytes)
      currentStyle = cell.style
      currentHyperlink = cell.style.hyperlink
      encodeContent(cell.content, into: &bytes)
      believedCursorPosition = TerminalPosition(column: column + cell.width, row: run.row)
    }
  }

  private mutating func hyperlinkDelta(to target: Hyperlink?, into bytes: inout [UInt8]) {
    guard currentHyperlink != target else {
      return
    }
    closeCurrentHyperlink(into: &bytes)
    if let target {
      ControlSequence.openHyperlink(target).encode(into: &bytes)
    }
  }

  private mutating func closeCurrentHyperlink(into bytes: inout [UInt8]) {
    guard currentHyperlink != nil else {
      return
    }
    ControlSequence.closeHyperlink.encode(into: &bytes)
    currentHyperlink = nil
  }

  private func encodeContent(_ content: Cell.Content, into bytes: inout [UInt8]) {
    switch content {
    case .blank:
      ControlSequence.text(" ").encode(into: &bytes)
    case .continuation:
      break
    case .grapheme(let grapheme):
      ControlSequence.text(terminalText(for: grapheme)).encode(into: &bytes)
    case .raw(let payload):
      ControlSequence.raw(payload).encode(into: &bytes)
    }
  }

  private func terminalText(for grapheme: String) -> String {
    guard grapheme.unicodeScalars.count > 1 else {
      return grapheme
    }

    return grapheme.precomposedStringWithCanonicalMapping
  }
}
