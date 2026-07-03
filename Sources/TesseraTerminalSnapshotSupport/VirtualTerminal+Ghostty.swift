#if canImport(CGhosttyVT)

  import CGhosttyVT
  import IssueReporting
  import Synchronization
  import TesseraTerminalCore

  extension VirtualTerminal {
    /// Creates a Ghostty-backed virtual terminal session.
    public static func ghostty(cols: Int, rows: Int) -> Self {
      do {
        let state = try GhosttyTerminalState(columns: cols, rows: rows)
        return Self(
          feed: { bytes in state.feed(bytes) },
          text: { row in state.text(row: row) },
          cell: { row, column in state.cell(row: row, column: column) },
          cursor: { state.cursorPosition() },
          snapshot: { state.snapshot() }
        )
      } catch {
        reportIssue("Failed to create Ghostty virtual terminal: \(error)")
        return Self()
      }
    }
  }

  private final class GhosttyTerminalState: Sendable {
    private let handles: Mutex<GhosttyTerminalHandles>

    init(columns: Int, rows: Int) throws {
      guard columns > 0, rows > 0 else {
        throw VirtualTerminalError.invalidSize(cols: columns, rows: rows)
      }
      guard columns <= Int(UInt16.max), rows <= Int(UInt16.max) else {
        throw VirtualTerminalError.invalidSize(cols: columns, rows: rows)
      }

      var terminal: GhosttyTerminal?
      try check(
        ghostty_terminal_new(
          nil,
          &terminal,
          GhosttyTerminalOptions(
            cols: UInt16(columns),
            rows: UInt16(rows),
            max_scrollback: 0
          )
        ),
        "ghostty_terminal_new"
      )

      var renderState: GhosttyRenderState?
      do {
        try check(ghostty_render_state_new(nil, &renderState), "ghostty_render_state_new")
      } catch {
        ghostty_terminal_free(terminal)
        throw error
      }

      var rowIterator: GhosttyRenderStateRowIterator?
      do {
        try check(
          ghostty_render_state_row_iterator_new(nil, &rowIterator),
          "ghostty_render_state_row_iterator_new"
        )
      } catch {
        ghostty_render_state_free(renderState)
        ghostty_terminal_free(terminal)
        throw error
      }

      var rowCells: GhosttyRenderStateRowCells?
      do {
        try check(
          ghostty_render_state_row_cells_new(nil, &rowCells),
          "ghostty_render_state_row_cells_new"
        )
      } catch {
        ghostty_render_state_row_iterator_free(rowIterator)
        ghostty_render_state_free(renderState)
        ghostty_terminal_free(terminal)
        throw error
      }

      self.handles = Mutex(
        GhosttyTerminalHandles(
          columns: columns,
          rows: rows,
          terminalAddress: try address(terminal, "ghostty_terminal_new"),
          renderStateAddress: try address(renderState, "ghostty_render_state_new"),
          rowIteratorAddress: try address(
            rowIterator,
            "ghostty_render_state_row_iterator_new"
          ),
          rowCellsAddress: try address(rowCells, "ghostty_render_state_row_cells_new")
        )
      )
    }

    func feed(_ bytes: [UInt8]) {
      self.handles.withLock { handles in
        bytes.withUnsafeBufferPointer { buffer in
          ghostty_terminal_vt_write(
            handles.terminal,
            buffer.baseAddress,
            buffer.count
          )
        }
      }
    }

    func text(row: Int) -> String {
      self.handles.withLock { handles in
        guard let cells = handles.cells(row: row) else {
          return ""
        }
        var text = ""
        while ghostty_render_state_row_cells_next(cells) {
          text.append(handles.currentCellCharacter())
        }
        return text
      }
    }

    func cell(row: Int, column: Int) -> RenderedCell {
      self.handles.withLock { handles in
        guard let cells = handles.cells(row: row), column >= 0 else {
          return .blank
        }
        let result = ghostty_render_state_row_cells_select(cells, UInt16(column))
        guard result == GHOSTTY_SUCCESS else {
          return .blank
        }
        return handles.currentRenderedCell()
      }
    }

    func cursorPosition() -> TerminalPosition {
      self.handles.withLock { handles in
        handles.cursorPosition()
      }
    }

    func snapshot() -> ScreenSnapshot {
      self.handles.withLock { handles in
        handles.updateRenderState()
        var rows: [[RenderedCell]] = []
        rows.reserveCapacity(handles.rows)
        handles.resetRowIterator()
        for _ in 0..<handles.rows {
          guard ghostty_render_state_row_iterator_next(handles.rowIterator) else {
            break
          }
          guard let rowCells = handles.currentRowCells() else {
            rows.append([])
            continue
          }
          var row: [RenderedCell] = []
          row.reserveCapacity(handles.columns)
          while ghostty_render_state_row_cells_next(rowCells) {
            row.append(handles.currentRenderedCell())
          }
          rows.append(row)
        }
        return ScreenSnapshot(cells: rows, cursor: handles.cursorPosition())
      }
    }

    deinit {
      self.handles.withLock { handles in
        ghostty_render_state_row_cells_free(handles.rowCells)
        ghostty_render_state_row_iterator_free(handles.rowIterator)
        ghostty_render_state_free(handles.renderState)
        ghostty_terminal_free(handles.terminal)
      }
    }
  }

  private struct GhosttyTerminalHandles: Sendable {
    let columns: Int
    let rows: Int
    private var terminalAddress: UInt
    private var renderStateAddress: UInt
    private var rowIteratorAddress: UInt
    private var rowCellsAddress: UInt

    var terminal: GhosttyTerminal? { GhosttyTerminal(bitPattern: self.terminalAddress) }
    var renderState: GhosttyRenderState? {
      GhosttyRenderState(bitPattern: self.renderStateAddress)
    }
    var rowIterator: GhosttyRenderStateRowIterator? {
      GhosttyRenderStateRowIterator(bitPattern: self.rowIteratorAddress)
    }
    var rowCells: GhosttyRenderStateRowCells? {
      GhosttyRenderStateRowCells(bitPattern: self.rowCellsAddress)
    }

    init(
      columns: Int,
      rows: Int,
      terminalAddress: UInt,
      renderStateAddress: UInt,
      rowIteratorAddress: UInt,
      rowCellsAddress: UInt
    ) {
      self.columns = columns
      self.rows = rows
      self.terminalAddress = terminalAddress
      self.renderStateAddress = renderStateAddress
      self.rowIteratorAddress = rowIteratorAddress
      self.rowCellsAddress = rowCellsAddress
    }

    mutating func updateRenderState() {
      report(
        ghostty_render_state_update(self.renderState, self.terminal),
        "ghostty_render_state_update"
      )
    }

    mutating func resetRowIterator() {
      self.updateRenderState()
      var iterator: GhosttyRenderStateRowIterator? = self.rowIterator
      withUnsafeMutablePointer(to: &iterator) { pointer in
        self.getRenderStateData(
          GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR,
          out: pointer,
          "ghostty_render_state_get row iterator"
        )
      }
      if let iterator {
        self.rowIteratorAddress = UInt(bitPattern: iterator)
      }
    }

    mutating func cells(row: Int) -> GhosttyRenderStateRowCells? {
      guard row >= 0, row < self.rows else {
        return nil
      }
      self.resetRowIterator()
      for _ in 0...row {
        guard ghostty_render_state_row_iterator_next(self.rowIterator) else {
          return nil
        }
      }
      return self.currentRowCells()
    }

    mutating func currentRowCells() -> GhosttyRenderStateRowCells? {
      var cells: GhosttyRenderStateRowCells? = self.rowCells
      withUnsafeMutablePointer(to: &cells) { pointer in
        self.getRowData(
          GHOSTTY_RENDER_STATE_ROW_DATA_CELLS,
          out: pointer,
          "ghostty_render_state_row_get cells"
        )
      }
      if let cells {
        self.rowCellsAddress = UInt(bitPattern: cells)
      }
      return cells
    }

    mutating func cursorPosition() -> TerminalPosition {
      self.updateRenderState()
      var column: UInt16 = 0
      var row: UInt16 = 0
      withUnsafeMutablePointer(to: &column) { pointer in
        self.getRenderStateData(
          GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_X,
          out: pointer,
          "ghostty_render_state_get cursor x"
        )
      }
      withUnsafeMutablePointer(to: &row) { pointer in
        self.getRenderStateData(
          GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_Y,
          out: pointer,
          "ghostty_render_state_get cursor y"
        )
      }
      return TerminalPosition(column: Int(column), row: Int(row))
    }

    func currentRenderedCell() -> RenderedCell {
      var style = GhosttyStyle(
        size: MemoryLayout<GhosttyStyle>.size,
        fg_color: GhosttyStyleColor(
          tag: GHOSTTY_STYLE_COLOR_NONE,
          value: GhosttyStyleColorValue()
        ),
        bg_color: GhosttyStyleColor(
          tag: GHOSTTY_STYLE_COLOR_NONE,
          value: GhosttyStyleColorValue()
        ),
        underline_color: GhosttyStyleColor(
          tag: GHOSTTY_STYLE_COLOR_NONE,
          value: GhosttyStyleColorValue()
        ),
        bold: false,
        italic: false,
        faint: false,
        blink: false,
        inverse: false,
        invisible: false,
        strikethrough: false,
        overline: false,
        underline: 0
      )
      withUnsafeMutablePointer(to: &style) { pointer in
        self.getCellData(
          GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_STYLE,
          out: pointer,
          "ghostty_render_state_row_cells_get style"
        )
      }
      return RenderedCell(
        character: self.currentCellCharacter(),
        foreground: RenderedColor(style.fg_color),
        background: RenderedColor(style.bg_color),
        bold: style.bold,
        dim: style.faint,
        italic: style.italic,
        reverse: style.inverse,
        strikethrough: style.strikethrough,
        underline: style.underline != 0
      )
    }

    func currentCellCharacter() -> Character {
      var length: UInt32 = 0
      withUnsafeMutablePointer(to: &length) { pointer in
        self.getCellData(
          GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_LEN,
          out: pointer,
          "ghostty_render_state_row_cells_get grapheme length"
        )
      }
      guard length > 0 else {
        return " "
      }
      var codepoints = Array(repeating: UInt32(0), count: Int(length))
      codepoints.withUnsafeMutableBufferPointer { buffer in
        report(
          ghostty_render_state_row_cells_get(
            self.rowCells,
            GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_BUF,
            buffer.baseAddress
          ),
          "ghostty_render_state_row_cells_get grapheme buffer"
        )
      }
      let scalars = codepoints.compactMap(UnicodeScalar.init)
      guard !scalars.isEmpty else {
        return " "
      }
      return Character(String(String.UnicodeScalarView(scalars)))
    }

    func getRenderStateData(
      _ data: GhosttyRenderStateData,
      out: UnsafeMutableRawPointer,
      _ operation: String
    ) {
      report(ghostty_render_state_get(self.renderState, data, out), operation)
    }

    func getRowData(
      _ data: GhosttyRenderStateRowData,
      out: UnsafeMutableRawPointer,
      _ operation: String
    ) {
      report(ghostty_render_state_row_get(self.rowIterator, data, out), operation)
    }

    func getCellData(
      _ data: GhosttyRenderStateRowCellsData,
      out: UnsafeMutableRawPointer,
      _ operation: String
    ) {
      report(ghostty_render_state_row_cells_get(self.rowCells, data, out), operation)
    }
  }

  extension RenderedColor {
    init(_ color: GhosttyStyleColor) {
      switch color.tag {
      case GHOSTTY_STYLE_COLOR_PALETTE:
        self = .indexed(color.value.palette)
      case GHOSTTY_STYLE_COLOR_RGB:
        self = .rgb(color.value.rgb.r, color.value.rgb.g, color.value.rgb.b)
      default:
        self = .default
      }
    }
  }

  private func check(_ result: GhosttyResult, _ operation: String) throws {
    guard result == GHOSTTY_SUCCESS else {
      throw VirtualTerminalError.ghostty(operation: operation, result: result)
    }
  }

  private func report(_ result: GhosttyResult, _ operation: String) {
    guard result == GHOSTTY_SUCCESS else {
      reportIssue("\(operation) failed with Ghostty result \(result)")
      return
    }
  }

  private func address(_ pointer: OpaquePointer?, _ operation: String) throws -> UInt {
    guard let pointer else {
      throw VirtualTerminalError.ghostty(
        operation: operation,
        result: GHOSTTY_INVALID_VALUE
      )
    }
    return UInt(bitPattern: pointer)
  }

#endif
