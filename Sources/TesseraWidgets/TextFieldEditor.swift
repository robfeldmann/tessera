import Foundation
import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput

struct _TextFieldEditor: InputLeafView, _PointerResponderView {
  typealias Body = Never

  struct State {
    var cursor = 0
    var anchor = 0
    var reveal = 0
  }

  let text: Binding<String>
  let prompt: Text?
  let onSubmit: ((String) -> Void)?
  let isEnabled: Bool
  var terminalRequirements: TerminalRequirements {
    TerminalRequirements(wantsBracketedPaste: true)
  }

  func makeState() -> State {
    State()
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout State,
    environment: EnvironmentValues
  ) -> TerminalSize {
    let metrics = _TextFieldMetrics(text: text.wrappedValue, environment: environment)
    reconcile(&state, metrics: metrics)

    let promptWidth =
      prompt.map {
        _TextFieldMetrics(text: _singleLine($0.content), environment: environment)
          .totalWidth
      } ?? 0
    let idealWidth = max(metrics.totalWidth, promptWidth) + 2
    let columns = max(0, proposal.width ?? idealWidth)
    let rows = min(3, max(0, proposal.height ?? 3))
    return TerminalSize(columns: columns, rows: rows)
  }

  func render(
    in region: inout RenderRegion,
    state: inout State,
    environment: EnvironmentValues
  ) {
    let metrics = _TextFieldMetrics(text: text.wrappedValue, environment: environment)
    let bounds = region.bounds
    let framed = bounds.size.columns >= 2 && bounds.size.rows >= 3
    let inputOrigin = TerminalPosition(
      column: framed ? 1 : 0,
      row: framed ? 1 : 0
    )
    let inputWidth = max(0, bounds.size.columns - (framed ? 2 : 0))
    reconcile(&state, metrics: metrics, viewportWidth: inputWidth)

    guard !bounds.isEmpty else {
      return
    }

    let enabled = environment.isEnabled
    let focused = environment.isFocused
    let fieldStyle =
      enabled
      ? (focused ? environment.semanticStyles.focus : environment.semanticStyles.primary)
      : environment.semanticStyles.disabled
    let textStyle =
      enabled ? environment.semanticStyles.primary : environment.semanticStyles.disabled
    let promptStyle = environment.semanticStyles.secondary
    let selectedStyle = environment.semanticStyles.accent.reverse()

    for row in 0..<bounds.size.rows {
      for column in 0..<bounds.size.columns {
        region.write(
          " ",
          at: TerminalPosition(column: column, row: row),
          style: fieldStyle
        )
      }
    }

    if framed {
      drawFrame(in: &region, bounds: bounds, style: fieldStyle)
    }

    guard inputWidth > 0 else {
      return
    }

    if metrics.isEmpty {
      if let prompt, !prompt.content.isEmpty {
        let promptText = _singleLine(prompt.content)
        region.write(promptText, at: inputOrigin, style: promptStyle)
      }
    } else {
      drawText(
        metrics: metrics,
        state: state,
        viewportWidth: inputWidth,
        in: &region,
        at: inputOrigin,
        normalStyle: textStyle,
        selectedStyle: selectedStyle
      )
    }

    guard focused, enabled else {
      return
    }

    let cursorColumn =
      inputOrigin.column + metrics.displayOffset(at: state.cursor) - state.reveal
    guard cursorColumn >= inputOrigin.column,
      cursorColumn < inputOrigin.column + inputWidth
    else {
      return
    }
    region.setCursorPosition(
      TerminalPosition(column: cursorColumn, row: inputOrigin.row)
    )
  }

  func handleEvent(
    _ event: InputEvent,
    state: inout State,
    context: inout ResponderContext
  ) -> EventDisposition {
    guard isEnabled, context.isFocused else {
      return .ignored
    }

    switch event {
    case .paste(let payload):
      let environment = EnvironmentValues()
      let metrics = _TextFieldMetrics(text: text.wrappedValue, environment: environment)
      guard !payload.isEmpty else {
        return .handled
      }
      let normalized = _singleLine(payload)
      guard !normalized.isEmpty else {
        return .handled
      }
      replaceSelection(with: normalized, state: &state, metrics: metrics)
      context.setNeedsLayout()
      return .handled

    case .key(let key):
      guard key.kind != .release else {
        return .ignored
      }
      let environment = EnvironmentValues()
      let metrics = _TextFieldMetrics(text: text.wrappedValue, environment: environment)
      reconcile(&state, metrics: metrics)
      return handleKey(key, state: &state, metrics: metrics, context: &context)

    default:
      return .ignored
    }
  }

  func handlePointer(
    _ event: PointerEvent,
    state: inout State,
    context: inout ResponderContext
  ) -> EventDisposition {
    guard isEnabled, event.button == nil || event.button == .left else {
      return .ignored
    }
    guard context.isFocusWithin || context.isFocused else {
      return .ignored
    }

    switch event.phase {
    case .down:
      let environment = EnvironmentValues()
      let metrics = _TextFieldMetrics(text: text.wrappedValue, environment: environment)
      let width = max(0, context.nodeBounds.size.columns - 2)
      let localColumn = event.position.column - context.nodeBounds.origin.column - 1
      guard event.position.row >= context.nodeBounds.origin.row + 1,
        event.position.row < context.nodeBounds.origin.row + context.nodeBounds.size.rows
          - 1,
        width > 0
      else {
        return .ignored
      }
      let targetCell = max(0, localColumn) + state.reveal
      state.cursor = metrics.nearestBoundary(toDisplayOffset: targetCell)
      state.anchor = state.cursor
      reconcile(&state, metrics: metrics, viewportWidth: width)
      context.setNeedsDisplay()
      return .handled

    case .up:
      return .handled

    case .move, .cancel:
      return .ignored

    case .scrollUp, .scrollDown, .scrollLeft, .scrollRight:
      return .ignored
    }
  }

  private func handleKey(
    _ key: Key,
    state: inout State,
    metrics: _TextFieldMetrics,
    context: inout ResponderContext
  ) -> EventDisposition {
    let shift = key.modifiers.contains(.shift)
    let control = key.modifiers.contains(.control)
    let alt = key.modifiers.contains(.alt)
    let unsupportedModifiers = key.modifiers.subtracting([
      .shift, .control, .alt, .capsLock, .numLock,
    ])

    switch key.code {
    case .left:
      guard unsupportedModifiers.isEmpty,
        !key.modifiers.contains(.control) || key.source == .kitty
      else {
        return .ignored
      }
      let word = alt || (control && key.source == .kitty)
      move(
        to: word
          ? metrics.precedingWordBoundary(before: state.cursor) : max(0, state.cursor - 1),
        extending: shift,
        state: &state,
        metrics: metrics,
        context: &context
      )
      return .handled

    case .right:
      guard unsupportedModifiers.isEmpty,
        !key.modifiers.contains(.control) || key.source == .kitty
      else {
        return .ignored
      }
      let word = alt || (control && key.source == .kitty)
      move(
        to: word
          ? metrics.followingWordBoundary(after: state.cursor)
          : min(metrics.count, state.cursor + 1),
        extending: shift,
        state: &state,
        metrics: metrics,
        context: &context
      )
      return .handled

    case .home:
      guard unsupportedModifiers.isEmpty, !control, !alt else {
        return .ignored
      }
      move(to: 0, extending: shift, state: &state, metrics: metrics, context: &context)
      return .handled

    case .end:
      guard unsupportedModifiers.isEmpty, !control, !alt else {
        return .ignored
      }
      move(
        to: metrics.count, extending: shift, state: &state, metrics: metrics,
        context: &context)
      return .handled

    case .backspace:
      guard unsupportedModifiers.isEmpty else {
        return .ignored
      }
      if !selectionIsEmpty(state) {
        replaceSelection(with: "", state: &state, metrics: metrics)
      } else if state.cursor > 0 {
        let target =
          alt || control
          ? metrics.precedingWordBoundary(before: state.cursor)
          : state.cursor - 1
        replace(range: target..<state.cursor, with: "", state: &state, metrics: metrics)
      }
      context.setNeedsLayout()
      return .handled

    case .delete:
      guard unsupportedModifiers.isEmpty else {
        return .ignored
      }
      if !selectionIsEmpty(state) {
        replaceSelection(with: "", state: &state, metrics: metrics)
      } else if state.cursor < metrics.count {
        let target =
          alt || control
          ? metrics.followingWordBoundary(after: state.cursor)
          : state.cursor + 1
        replace(range: state.cursor..<target, with: "", state: &state, metrics: metrics)
      }
      context.setNeedsLayout()
      return .handled

    case .enter:
      guard key.modifiers.isEmpty, let onSubmit else {
        return .ignored
      }
      onSubmit(text.wrappedValue)
      return .handled

    case .character(let character):
      guard key.modifiers.subtracting([.shift, .capsLock, .numLock]).isEmpty,
        let inserted = _printableString(for: character)
      else {
        return .ignored
      }
      replaceSelection(with: inserted, state: &state, metrics: metrics)
      context.setNeedsLayout()
      return .handled

    case .unidentified:
      guard key.modifiers.subtracting([.shift, .capsLock, .numLock]).isEmpty,
        let associatedText = key.associatedText
      else {
        return .ignored
      }
      let inserted = _singleLine(associatedText)
      guard !inserted.isEmpty else {
        return .ignored
      }
      replaceSelection(with: inserted, state: &state, metrics: metrics)
      context.setNeedsLayout()
      return .handled

    case .tab, .escape:
      return .ignored

    default:
      return .ignored
    }
  }

  private func move(
    to target: Int,
    extending: Bool,
    state: inout State,
    metrics: _TextFieldMetrics,
    context: inout ResponderContext
  ) {
    if extending {
      state.cursor = min(max(target, 0), metrics.count)
    } else if !selectionIsEmpty(state) {
      state.cursor =
        target < state.cursor
        ? min(state.cursor, state.anchor) : max(state.cursor, state.anchor)
      state.anchor = state.cursor
    } else {
      state.cursor = min(max(target, 0), metrics.count)
      state.anchor = state.cursor
    }
    reconcile(&state, metrics: metrics)
    context.setNeedsDisplay()
  }

  private func selectionIsEmpty(_ state: State) -> Bool {
    state.cursor == state.anchor
  }

  private func replaceSelection(
    with replacement: String,
    state: inout State,
    metrics: _TextFieldMetrics
  ) {
    let start = min(state.cursor, state.anchor)
    let end = max(state.cursor, state.anchor)
    replace(range: start..<end, with: replacement, state: &state, metrics: metrics)
  }

  private func replace(
    range: Range<Int>,
    with replacement: String,
    state: inout State,
    metrics: _TextFieldMetrics
  ) {
    let start = min(max(range.lowerBound, 0), metrics.count)
    let end = min(max(range.upperBound, start), metrics.count)
    let lower = metrics.boundaries[start]
    let upper = metrics.boundaries[end]
    var value = text.wrappedValue
    value.replaceSubrange(lower..<upper, with: replacement)
    text.wrappedValue = value

    let insertedCount = replacement.count
    state.cursor = start + insertedCount
    state.anchor = state.cursor
    let updated = _TextFieldMetrics(text: value, environment: EnvironmentValues())
    reconcile(&state, metrics: updated)
  }

  private func reconcile(
    _ state: inout State,
    metrics: _TextFieldMetrics,
    viewportWidth: Int? = nil
  ) {
    state.cursor = min(max(state.cursor, 0), metrics.count)
    state.anchor = min(max(state.anchor, 0), metrics.count)
    state.reveal = metrics.legalReveal(atOrBefore: state.reveal)

    guard let viewportWidth, viewportWidth > 0 else {
      return
    }
    let caret = metrics.displayOffset(at: state.cursor)
    while caret > state.reveal + viewportWidth {
      let next = metrics.nextBoundary(afterDisplayOffset: state.reveal)
      guard next > state.reveal else {
        break
      }
      state.reveal = next
    }
    if caret < state.reveal {
      state.reveal = metrics.legalReveal(atOrBefore: caret)
    }
  }

  private func drawFrame(
    in region: inout RenderRegion,
    bounds: Rect,
    style: Style
  ) {
    let columns = bounds.size.columns
    let rows = bounds.size.rows
    guard columns >= 2, rows >= 3 else {
      return
    }
    region.write("╭", at: TerminalPosition(column: 0, row: 0), style: style)
    region.write("╮", at: TerminalPosition(column: columns - 1, row: 0), style: style)
    region.write("╰", at: TerminalPosition(column: 0, row: rows - 1), style: style)
    region.write(
      "╯", at: TerminalPosition(column: columns - 1, row: rows - 1), style: style)
    for column in 1..<(columns - 1) {
      region.write("─", at: TerminalPosition(column: column, row: 0), style: style)
      region.write("─", at: TerminalPosition(column: column, row: rows - 1), style: style)
    }
    for row in 1..<(rows - 1) {
      region.write("│", at: TerminalPosition(column: 0, row: row), style: style)
      region.write("│", at: TerminalPosition(column: columns - 1, row: row), style: style)
    }
  }

  private func drawText(
    metrics: _TextFieldMetrics,
    state: State,
    viewportWidth: Int,
    in region: inout RenderRegion,
    at origin: TerminalPosition,
    normalStyle: Style,
    selectedStyle: Style
  ) {
    var column = origin.column
    let limit = origin.column + viewportWidth
    let start = metrics.firstIndex(atOrAfterDisplayOffset: state.reveal)
    for index in start..<metrics.count {
      let width = metrics.widths[index]
      let offset = metrics.displayOffsets[index] - state.reveal
      guard offset >= 0 else { continue }
      let targetColumn = origin.column + offset
      guard targetColumn < limit else { break }
      guard targetColumn + width <= limit || width == 0 else { break }
      let isSelected =
        index >= min(state.cursor, state.anchor)
        && index < max(state.cursor, state.anchor)
      region.write(
        String(metrics.characters[index]),
        at: TerminalPosition(column: targetColumn, row: origin.row),
        style: isSelected ? selectedStyle : normalStyle
      )
      column = targetColumn + width
    }
    _ = column
  }
}

private struct _TextFieldMetrics {
  let characters: [Character]
  let boundaries: [String.Index]
  let widths: [Int]
  let displayOffsets: [Int]
  let totalWidth: Int

  var count: Int { characters.count }
  var isEmpty: Bool { characters.isEmpty }

  init(text: String, environment: EnvironmentValues) {
    var characters: [Character] = []
    var boundaries: [String.Index] = [text.startIndex]
    var widths: [Int] = []
    var displayOffsets: [Int] = [0]
    var offset = 0
    var index = text.startIndex
    while index < text.endIndex {
      let next = text.index(after: index)
      guard let character = text[index..<next].first else {
        index = next
        continue
      }
      let grapheme = String(character)
      var state: Void = ()
      let measured = Text(grapheme).sizeThatFits(
        .unspecified,
        state: &state,
        environment: environment
      ).columns
      let width = max(0, min(measured, 2))
      characters.append(character)
      widths.append(width)
      offset += width
      displayOffsets.append(offset)
      boundaries.append(next)
      index = next
    }
    self.characters = characters
    self.boundaries = boundaries
    self.widths = widths
    self.displayOffsets = displayOffsets
    totalWidth = offset
  }

  func displayOffset(at index: Int) -> Int {
    displayOffsets[min(max(index, 0), count)]
  }

  func legalReveal(atOrBefore offset: Int) -> Int {
    let target = min(max(offset, 0), totalWidth)
    var result = 0
    for value in displayOffsets where value <= target {
      result = value
    }
    return result
  }

  func firstIndex(atOrAfterDisplayOffset offset: Int) -> Int {
    let target = legalReveal(atOrBefore: offset)
    let index = displayOffsets.firstIndex { $0 >= target }
    return index ?? count
  }

  func nextBoundary(afterDisplayOffset offset: Int) -> Int {
    let boundary = displayOffsets.first { $0 > offset }
    return boundary ?? offset
  }

  func nearestBoundary(toDisplayOffset offset: Int) -> Int {
    let target = min(max(offset, 0), totalWidth)
    var bestIndex = 0
    var bestDistance = Int.max
    for index in 0...count {
      let distance = abs(displayOffsets[index] - target)
      if distance < bestDistance {
        bestDistance = distance
        bestIndex = index
      }
    }
    return bestIndex
  }

  func precedingWordBoundary(before index: Int) -> Int {
    var cursor = min(max(index, 0), count)
    while cursor > 0 && characters[cursor - 1].isWhitespace {
      cursor -= 1
    }
    guard cursor > 0 else {
      return cursor
    }
    let word = _isWordCharacter(characters[cursor - 1])
    while cursor > 0 && _isWordCharacter(characters[cursor - 1]) == word {
      cursor -= 1
    }
    return cursor
  }

  func followingWordBoundary(after index: Int) -> Int {
    var cursor = min(max(index, 0), count)
    while cursor < count && characters[cursor].isWhitespace {
      cursor += 1
    }
    guard cursor < count else {
      return cursor
    }
    let word = _isWordCharacter(characters[cursor])
    while cursor < count && _isWordCharacter(characters[cursor]) == word {
      cursor += 1
    }
    return cursor
  }
}
private func _isWordCharacter(_ character: Character) -> Bool {
  character.isLetter || character.isNumber || character == "_"
}

private func _singleLine(_ value: String) -> String {
  value.replacingOccurrences(of: "\r\n", with: " ")
    .replacingOccurrences(of: "\r", with: " ")
    .replacingOccurrences(of: "\n", with: " ")
}

private func _printableString(for character: Character) -> String? {
  guard
    !character.unicodeScalars.contains(where: { scalar in
      scalar == "\t" || scalar == "\n" || scalar == "\r" || scalar.value < 0x20
    })
  else {
    return nil
  }
  return String(character)
}
