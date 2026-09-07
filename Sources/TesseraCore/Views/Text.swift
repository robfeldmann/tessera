import Foundation
import TesseraTerminalBuffer
import TesseraTerminalCore

/// Controls how text uses a finite proposed width.
public enum TextWrapping: Equatable, Sendable {
  /// Breaks only between extended grapheme clusters.
  case character
  /// Preserves source rows without introducing additional line breaks.
  case none
  /// Breaks at whitespace boundaries, falling back to grapheme boundaries for long words.
  case word
}

/// Controls which portion of an overlong row remains visible.
public enum TextTruncation: Equatable, Sendable {
  /// Leaves overflow for the allocated render region to clip.
  case clip
  /// Replaces the invisible prefix with a truncation mark.
  case head
  /// Replaces the invisible middle with a truncation mark.
  case middle
  /// Replaces the invisible suffix with a truncation mark.
  case tail
}

/// An immutable text leaf rendered with the terminal buffer's grapheme-width rules.
public struct Text: Equatable, LeafView {
  public typealias Body = Never

  /// The source text, with CRLF pairs normalized to a single newline.
  public let content: String

  /// The style applied to each rendered grapheme.
  public let style: Style

  /// The row-reflow policy.
  public let wrapping: TextWrapping

  /// The policy used when a rendered row exceeds its allocated width.
  public let truncationMode: TextTruncation

  /// Creates non-wrapping text that clips at its allocated render-region boundary.
  public init(_ content: String, style: Style = Style()) {
    self.init(
      content,
      style: style,
      wrapping: .none,
      truncationMode: .clip
    )
  }

  private init(
    _ content: String,
    style: Style,
    wrapping: TextWrapping,
    truncationMode: TextTruncation
  ) {
    self.content = Self.normalizingCRLF(in: content)
    self.style = style
    self.wrapping = wrapping
    self.truncationMode = truncationMode
  }

  private static func normalizingCRLF(in content: String) -> String {
    guard content.contains("\r\n") else {
      return content
    }
    return content.replacingOccurrences(of: "\r\n", with: "\n")
  }

  /// Returns a copy with the requested row-reflow policy.
  public func wrapped(_ wrapping: TextWrapping) -> Self {
    Self(
      content,
      style: style,
      wrapping: wrapping,
      truncationMode: truncationMode
    )
  }

  /// Returns a copy with the requested overflow policy.
  public func truncation(_ truncation: TextTruncation) -> Self {
    Self(
      content,
      style: style,
      wrapping: wrapping,
      truncationMode: truncation
    )
  }

  public func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    layout(
      for: measurementWidth(from: proposal),
      truncationMarkWidth: terminalCellWidth(of: environment.truncationMark)
    ).size
  }

  public func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    let style = environment.defaultStyle._merging(style)._resolved
    let truncationMark = environment.truncationMark
    let truncationMarkWidth = terminalCellWidth(of: truncationMark)
    let layout = layout(
      for: max(region.bounds.size.columns, 0),
      truncationMarkWidth: truncationMarkWidth
    )
    let rowLimit = max(region.bounds.size.rows, 0)

    for (row, line) in layout.lines.enumerated() {
      guard row < rowLimit else {
        break
      }

      switch line.truncation {
      case nil:
        write(
          line.prefix, width: line.prefixWidth, row: row, column: 0, to: &region,
          style: style)
      case .clip:
        write(
          line.prefix, width: line.prefixWidth, row: row, column: 0, to: &region,
          style: style)
      case .tail:
        write(
          line.prefix, width: line.prefixWidth, row: row, column: 0, to: &region,
          style: style)
        region.write(
          truncationMark,
          at: TerminalPosition(column: line.prefixWidth, row: row),
          style: style
        )
      case .head:
        region.write(
          truncationMark,
          at: TerminalPosition(column: 0, row: row),
          style: style
        )
        if let suffix = line.suffix {
          write(
            suffix,
            width: line.suffixWidth,
            row: row,
            column: truncationMarkWidth,
            to: &region,
            style: style
          )
        }
      case .middle:
        write(
          line.prefix, width: line.prefixWidth, row: row, column: 0, to: &region,
          style: style)
        region.write(
          truncationMark,
          at: TerminalPosition(column: line.prefixWidth, row: row),
          style: style
        )
        if let suffix = line.suffix {
          write(
            suffix,
            width: line.suffixWidth,
            row: row,
            column: line.prefixWidth + truncationMarkWidth,
            to: &region,
            style: style
          )
        }
      }
    }
  }

  /// A no-wrap, clipping text view keeps its intrinsic extent. All other finite-width
  /// policies need the proposal to create rows or reserve a truncation mark.
  private func measurementWidth(from proposal: ProposedSize) -> Int? {
    guard let width = proposal.width else {
      return nil
    }
    guard wrapping != .none || truncationMode != .clip else {
      return nil
    }
    return max(width, 0)
  }

  /// Produces the same grapheme-safe rows for both measurement and rendering.
  private func layout(for maximumColumns: Int?, truncationMarkWidth: Int) -> _TextLayout {
    var lines: [_TextLine] = []

    forEachSourceLine { range in
      if let maximumColumns, wrapping != .none {
        switch wrapping {
        case .none:
          appendUnwrappedLine(
            in: range,
            maximumColumns: maximumColumns,
            truncationMarkWidth: truncationMarkWidth,
            to: &lines
          )
        case .word:
          appendWordWrappedLines(in: range, maximumColumns: maximumColumns, to: &lines)
        case .character:
          appendCharacterWrappedLine(in: range, maximumColumns: maximumColumns, to: &lines)
        }
      } else {
        appendUnwrappedLine(
          in: range,
          maximumColumns: maximumColumns,
          truncationMarkWidth: truncationMarkWidth,
          to: &lines
        )
      }
    }

    let columns = lines.reduce(into: 0) { maximum, line in
      maximum = max(maximum, line.width)
    }
    return _TextLayout(
      lines: lines,
      size: TerminalSize(columns: columns, rows: lines.count)
    )
  }

  private func appendUnwrappedLine(
    in range: Range<String.Index>,
    maximumColumns: Int?,
    truncationMarkWidth: Int,
    to lines: inout [_TextLine]
  ) {
    let width = displayWidth(in: range)
    guard
      let maximumColumns,
      width > maximumColumns,
      truncationMode != .clip
    else {
      lines.append(.normal(range, width: width))
      return
    }

    guard maximumColumns >= truncationMarkWidth else {
      let empty = range.lowerBound..<range.lowerBound
      lines.append(.normal(empty, width: 0))
      return
    }

    let visibleWidth = maximumColumns - truncationMarkWidth
    switch truncationMode {
    case .clip:
      let prefix = prefixFitting(in: range, within: maximumColumns)
      lines.append(.normal(prefix.range, width: prefix.width))
    case .tail:
      let prefix = prefixFitting(in: range, within: visibleWidth)
      lines.append(
        _TextLine(
          prefix: prefix.range,
          prefixWidth: prefix.width,
          suffix: nil,
          suffixWidth: 0,
          truncation: .tail,
          width: prefix.width + truncationMarkWidth
        )
      )
    case .head:
      let suffix = suffixFitting(in: range, within: visibleWidth)
      lines.append(
        _TextLine(
          prefix: range.lowerBound..<range.lowerBound,
          prefixWidth: 0,
          suffix: suffix.range,
          suffixWidth: suffix.width,
          truncation: .head,
          width: suffix.width + truncationMarkWidth
        )
      )
    case .middle:
      let prefixBudget = visibleWidth / 2 + visibleWidth % 2
      let prefix = prefixFitting(in: range, within: prefixBudget)
      let suffixBudget = visibleWidth - prefix.width
      let suffix = suffixFitting(
        in: prefix.range.upperBound..<range.upperBound,
        within: suffixBudget
      )
      lines.append(
        _TextLine(
          prefix: prefix.range,
          prefixWidth: prefix.width,
          suffix: suffix.range,
          suffixWidth: suffix.width,
          truncation: .middle,
          width: prefix.width + truncationMarkWidth + suffix.width
        )
      )
    }
  }

  private func appendCharacterWrappedLine(
    in range: Range<String.Index>,
    maximumColumns: Int,
    to lines: inout [_TextLine]
  ) {
    guard maximumColumns > 0 else {
      lines.append(.normal(range.lowerBound..<range.lowerBound, width: 0))
      return
    }

    let start = lines.count
    var current = _TextLineBuilder()
    appendCharacterWrapped(
      in: range,
      maximumColumns: maximumColumns,
      current: &current,
      to: &lines
    )
    current.finish(into: &lines)

    if lines.count == start {
      lines.append(.normal(range.lowerBound..<range.lowerBound, width: 0))
    }
  }

  private func appendWordWrappedLines(
    in range: Range<String.Index>,
    maximumColumns: Int,
    to lines: inout [_TextLine]
  ) {
    guard maximumColumns > 0 else {
      lines.append(.normal(range.lowerBound..<range.lowerBound, width: 0))
      return
    }

    let start = lines.count
    var current = _TextLineBuilder()
    var pendingWhitespace: _TextRun?
    var index = range.lowerBound

    while index < range.upperBound {
      let whitespace = content[index].isWhitespace
      let run = nextRun(
        in: range,
        from: index,
        containingWhitespace: whitespace
      )
      index = run.range.upperBound

      if whitespace {
        pendingWhitespace =
          pendingWhitespace.map {
            _TextRun(
              range: $0.range.lowerBound..<run.range.upperBound,
              width: saturatedAdd($0.width, run.width)
            )
          } ?? run
        continue
      }

      guard run.width > 0 else {
        continue
      }

      if !current.isEmpty {
        let pendingWidth = pendingWhitespace?.width ?? 0
        if fits(
          current.width,
          plus: pendingWidth,
          plus: run.width,
          within: maximumColumns
        ) {
          if let pendingWhitespace {
            current.append(pendingWhitespace.range, width: pendingWhitespace.width)
          }
          current.append(run.range, width: run.width)
        } else {
          current.finish(into: &lines)
          appendWord(
            run,
            maximumColumns: maximumColumns,
            current: &current,
            to: &lines
          )
        }
      } else {
        appendWord(
          run,
          maximumColumns: maximumColumns,
          current: &current,
          to: &lines
        )
      }

      pendingWhitespace = nil
    }

    if let pendingWhitespace {
      if current.isEmpty {
        appendCharacterWrapped(
          in: pendingWhitespace.range,
          maximumColumns: maximumColumns,
          current: &current,
          to: &lines
        )
      } else if fits(current.width, plus: pendingWhitespace.width, within: maximumColumns)
      {
        current.append(pendingWhitespace.range, width: pendingWhitespace.width)
      } else {
        current.finish(into: &lines)
        appendCharacterWrapped(
          in: pendingWhitespace.range,
          maximumColumns: maximumColumns,
          current: &current,
          to: &lines
        )
      }
    }

    current.finish(into: &lines)
    if lines.count == start {
      lines.append(.normal(range.lowerBound..<range.lowerBound, width: 0))
    }
  }

  private func appendWord(
    _ word: _TextRun,
    maximumColumns: Int,
    current: inout _TextLineBuilder,
    to lines: inout [_TextLine]
  ) {
    if word.width <= maximumColumns {
      current.append(word.range, width: word.width)
    } else {
      appendCharacterWrapped(
        in: word.range,
        maximumColumns: maximumColumns,
        current: &current,
        to: &lines
      )
    }
  }

  private func appendCharacterWrapped(
    in range: Range<String.Index>,
    maximumColumns: Int,
    current: inout _TextLineBuilder,
    to lines: inout [_TextLine]
  ) {
    var index = range.lowerBound

    while index < range.upperBound {
      let next = content.index(after: index)
      let width = displayWidth(of: content[index])
      defer { index = next }

      guard width > 0, width <= maximumColumns else {
        continue
      }

      if !current.isEmpty && width > maximumColumns - current.width {
        current.finish(into: &lines)
      }
      current.append(index..<next, width: width)
    }
  }

  private func nextRun(
    in range: Range<String.Index>,
    from start: String.Index,
    containingWhitespace whitespace: Bool
  ) -> _TextRun {
    var index = start
    var width = 0

    while index < range.upperBound, content[index].isWhitespace == whitespace {
      width = saturatedAdd(width, displayWidth(of: content[index]))
      index = content.index(after: index)
    }

    return _TextRun(range: start..<index, width: width)
  }

  private func prefixFitting(
    in range: Range<String.Index>,
    within maximumColumns: Int
  ) -> _TextRun {
    var width = 0
    var index = range.lowerBound

    while index < range.upperBound {
      let next = content.index(after: index)
      let graphemeWidth = displayWidth(of: content[index])
      guard graphemeWidth == 0 || graphemeWidth <= maximumColumns - width else {
        break
      }
      width = saturatedAdd(width, graphemeWidth)
      index = next
    }

    return _TextRun(range: range.lowerBound..<index, width: width)
  }

  private func suffixFitting(
    in range: Range<String.Index>,
    within maximumColumns: Int
  ) -> _TextRun {
    var width = 0
    var index = range.upperBound

    while index > range.lowerBound {
      let previous = content.index(before: index)
      let graphemeWidth = displayWidth(of: content[previous])
      guard graphemeWidth == 0 || graphemeWidth <= maximumColumns - width else {
        break
      }
      width = saturatedAdd(width, graphemeWidth)
      index = previous
    }

    return _TextRun(range: index..<range.upperBound, width: width)
  }

  private func displayWidth(in range: Range<String.Index>) -> Int {
    var width = 0
    var index = range.lowerBound

    while index < range.upperBound {
      width = saturatedAdd(width, displayWidth(of: content[index]))
      index = content.index(after: index)
    }

    return width
  }

  private func displayWidth(of character: Character) -> Int {
    let grapheme = String(character)
    guard isSupportedStoredGrapheme(grapheme) else {
      return 0
    }
    return terminalCellWidth(of: grapheme)
  }

  private func write(
    _ range: Range<String.Index>,
    width: Int,
    row: Int,
    column: Int,
    to region: inout RenderRegion,
    style: Style
  ) {
    guard width > 0 else {
      return
    }
    region.write(
      String(content[range]),
      at: TerminalPosition(column: column, row: row),
      style: style
    )
  }

  /// Visits every normalized source row, including an empty trailing row.
  private func forEachSourceLine(_ body: (Range<String.Index>) -> Void) {
    var lineStart = content.startIndex
    var index = lineStart

    while index < content.endIndex {
      guard content[index] == "\n" else {
        index = content.index(after: index)
        continue
      }

      body(lineStart..<index)
      index = content.index(after: index)
      lineStart = index
    }

    body(lineStart..<content.endIndex)
  }

}

private struct _TextLayout {
  let lines: [_TextLine]
  let size: TerminalSize
}

private struct _TextLine {
  let prefix: Range<String.Index>
  let prefixWidth: Int
  let suffix: Range<String.Index>?
  let suffixWidth: Int
  let truncation: TextTruncation?
  let width: Int

  static func normal(_ range: Range<String.Index>, width: Int) -> Self {
    Self(
      prefix: range,
      prefixWidth: width,
      suffix: nil,
      suffixWidth: 0,
      truncation: nil,
      width: width
    )
  }
}

private struct _TextRun {
  let range: Range<String.Index>
  let width: Int
}

private struct _TextLineBuilder {
  private(set) var range: Range<String.Index>?
  private(set) var width = 0

  var isEmpty: Bool {
    range == nil
  }

  mutating func append(_ range: Range<String.Index>, width: Int) {
    guard width > 0 else {
      return
    }

    if let existing = self.range {
      self.range = existing.lowerBound..<range.upperBound
    } else {
      self.range = range
    }
    self.width = saturatedAdd(self.width, width)
  }

  mutating func finish(into lines: inout [_TextLine]) {
    guard let range else {
      return
    }
    lines.append(.normal(range, width: width))
    self = Self()
  }
}

private func fits(_ first: Int, plus second: Int, within maximum: Int) -> Bool {
  guard first <= maximum, second <= maximum - first else {
    return false
  }
  return true
}

private func fits(_ first: Int, plus second: Int, plus third: Int, within maximum: Int)
  -> Bool
{
  guard fits(first, plus: second, within: maximum) else {
    return false
  }
  return fits(first + second, plus: third, within: maximum)
}

private func saturatedAdd(_ lhs: Int, _ rhs: Int) -> Int {
  let (sum, overflow) = lhs.addingReportingOverflow(rhs)
  return overflow ? Int.max : sum
}
