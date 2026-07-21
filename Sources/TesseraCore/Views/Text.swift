import TesseraTerminalBuffer
import TesseraTerminalCore

/// A non-wrapping text leaf rendered with the terminal buffer's grapheme-width rules.
public struct Text: Equatable, LeafView {
  public typealias Body = Never

  /// The source text, preserving every source line including empty trailing lines.
  public let content: String

  /// The style applied to each rendered grapheme.
  public let style: Style

  public init(_ content: String, style: Style = Style()) {
    self.content = content
    self.style = style
  }

  public func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    var maximumWidth = 0
    var rowCount = 0

    forEachNormalizedSourceLine { line in
      var lineWidth = 0
      for character in line where isBufferStored(character) {
        let width = Cell(character: character).width
        if width > Int.max - lineWidth {
          lineWidth = Int.max
          break
        }
        lineWidth += width
      }
      maximumWidth = max(maximumWidth, lineWidth)
      rowCount += 1
    }

    return TerminalSize(columns: maximumWidth, rows: rowCount)
  }

  public func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    var row = 0
    forEachNormalizedSourceLine { line in
      region.write(
        String(line),
        at: TerminalPosition(column: 0, row: row),
        style: style
      )
      row += 1
    }
  }

  /// Visits source lines after treating a CRLF pair as one newline.
  ///
  /// Empty source lines, including the row after a trailing newline, are deliberately
  /// emitted so intrinsic height remains the number of source rows.
  private func forEachNormalizedSourceLine(_ body: (Substring) -> Void) {
    var lineStart = content.startIndex
    var index = lineStart

    while index < content.endIndex {
      guard content[index] == "\n" || content[index] == "\r\n" else {
        index = content.index(after: index)
        continue
      }

      var lineEnd = index
      if lineEnd > lineStart {
        let previous = content.index(before: lineEnd)
        if content[previous] == "\r" {
          lineEnd = previous
        }
      }
      body(content[lineStart..<lineEnd])
      lineStart = content.index(after: index)
      index = lineStart
    }

    body(content[lineStart..<content.endIndex])
  }

  /// Mirrors the buffer's supported-grapheme predicate while obtaining width from `Cell`.
  private func isBufferStored(_ character: Character) -> Bool {
    guard
      !character.unicodeScalars.contains(where: { scalar in
        scalar == "\t" || scalar.value < 0x20 || (0x80...0x9F).contains(scalar.value)
      })
    else {
      return false
    }

    let width = Cell(character: character).width
    return width > 0 && width <= 2
  }
}
