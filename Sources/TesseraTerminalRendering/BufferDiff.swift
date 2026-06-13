import TesseraTerminalBuffer
import TesseraTerminalCore

package struct RowDamageRun: Equatable, Sendable {
  package var row: Int
  package var columns: Range<Int>

  package init(row: Int, columns: Range<Int>) {
    self.row = row
    self.columns = columns
  }
}

package enum BufferDiff {
  package static func damageRuns(previous: Buffer?, current: Buffer) -> [RowDamageRun] {
    guard let previous, previous.size == current.size else {
      return fullRepaintRuns(in: current)
    }

    var runs: [RowDamageRun] = []
    for row in 0..<current.size.rows {
      guard
        let dirtyColumns = dirtyColumns(
          inRow: row,
          previous: previous,
          current: current
        )
      else {
        continue
      }

      runs.append(
        contentsOf: splitAroundOpaqueCells(
          row: row,
          columns: dirtyColumns,
          buffer: current
        )
      )
    }

    return runs
  }

  private static func fullRepaintRuns(in buffer: Buffer) -> [RowDamageRun] {
    (0..<buffer.size.rows).flatMap { row in
      splitAroundOpaqueCells(row: row, columns: 0..<buffer.size.columns, buffer: buffer)
    }
  }

  private static func dirtyColumns(
    inRow row: Int,
    previous: Buffer,
    current: Buffer
  ) -> Range<Int>? {
    var firstDirtyColumn: Int?
    var lastDirtyColumn: Int?

    for column in 0..<current.size.columns {
      let oldCell = previous[row, column]
      let newCell = current[row, column]

      guard oldCell != newCell || newCell.diffPolicy == .alwaysRepaint else {
        continue
      }

      firstDirtyColumn = min(firstDirtyColumn ?? column, column)
      lastDirtyColumn = max(lastDirtyColumn ?? column, column)
    }

    guard let firstDirtyColumn, let lastDirtyColumn else {
      return nil
    }

    return firstDirtyColumn..<(lastDirtyColumn + 1)
  }

  private static func splitAroundOpaqueCells(
    row: Int,
    columns: Range<Int>,
    buffer: Buffer
  ) -> [RowDamageRun] {
    var runs: [RowDamageRun] = []
    var runStart: Int?

    for column in columns {
      if buffer[row, column].diffPolicy == .opaque {
        if let start = runStart, start < column {
          runs.append(RowDamageRun(row: row, columns: start..<column))
        }
        runStart = nil
      } else if runStart == nil {
        runStart = column
      }
    }

    if let start = runStart, start < columns.upperBound {
      runs.append(RowDamageRun(row: row, columns: start..<columns.upperBound))
    }

    return runs
  }
}
