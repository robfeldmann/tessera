import Tessera
import TesseraTerminalSnapshotSupport

/// The screen as characters with the blank spacer cell after each wide grapheme marked.
struct CellGrid {
  let cells: [[Character]]
  let columns: Int
  let rows: Int
  private let spacers: [[Bool]]

  init(_ screen: ScreenSnapshot) {
    cells = screen.cells.map { $0.map(\.character) }
    rows = cells.count
    columns = cells.map(\.count).max() ?? 0
    spacers = cells.map { row in
      var flags = Array(repeating: false, count: row.count)
      var column = 0
      while column < row.count {
        if Cell(character: row[column]).width == 2, column + 1 < row.count {
          flags[column + 1] = true
          column += 1
        }
        column += 1
      }
      return flags
    }
  }

  func isSpacer(row: Int, column: Int) -> Bool {
    spacers[row][column]
  }

  func isBlank(row: Int, column: Int) -> Bool {
    cells[row][column] == " "
  }

  var rowStrings: [String] {
    cells.indices.map { row in
      var text = ""
      for column in cells[row].indices where !spacers[row][column] {
        text.append(cells[row][column])
      }
      return text
    }
  }
}

/// Attributes visible screen text to leaf nodes using geometry alone.
///
/// `GraphDiagnostics` carries no view values, so a node's text is recovered from the
/// screen. The leaves are the nodes with no children; they paint in `nodes` order (a
/// pre-order walk, the order `ViewGraph.render` visits them), so the last leaf whose
/// clip covers a cell is the one whose pixels are visible there. A leaf's `text` is the
/// characters of the cells it owns, with cells owned by later leaves blanked.
///
/// The model is geometric: a leaf is assumed to paint every cell of its clip. A leaf that
/// paints nothing but covers cells (a `Spacer` with extent, an empty custom leaf) still
/// steals ownership from earlier leaves. That residue is surfaced as `textOverlaps` rather
/// than hidden.
struct TextAttribution {
  let grid: CellGrid
  let nodes: [Projection.Node]

  func apply(to nodes: inout [Projection.Node]) {
    let bounds = Projection.Box(column: 0, row: 0, columns: grid.columns, rows: grid.rows)
    var regions: [Int: Projection.Box] = [:]
    var owner = Array(
      repeating: Array(repeating: -1, count: grid.columns),
      count: grid.rows
    )
    var covers = Array(
      repeating: Array(repeating: [Int](), count: grid.columns),
      count: grid.rows
    )

    for (index, node) in self.nodes.enumerated() where node.isLeaf {
      guard let region = node.clip.intersection(bounds) else {
        continue
      }
      regions[index] = region
      for row in region.row..<region.maxRow {
        for column in region.column..<region.maxColumn {
          owner[row][column] = index
          covers[row][column].append(index)
        }
      }
    }

    for (index, region) in regions {
      var lines: [String] = []
      var overlaps: Set<Int> = []
      for row in region.row..<region.maxRow {
        var line = ""
        for column in region.column..<region.maxColumn {
          if grid.isSpacer(row: row, column: column) {
            continue
          }
          if owner[row][column] == index {
            line.append(grid.cells[row][column])
          } else {
            line.append(" ")
          }
          if !grid.isBlank(row: row, column: column), covers[row][column].count > 1 {
            overlaps.formUnion(covers[row][column])
          }
        }
        lines.append(line.trailingTrimmed())
      }
      while lines.last?.isEmpty == true { lines.removeLast() }
      while lines.first?.isEmpty == true { lines.removeFirst() }
      nodes[index].text = lines.isEmpty ? nil : lines.joined(separator: "\n")
      overlaps.remove(index)
      nodes[index].textOverlaps =
        overlaps.isEmpty ? nil : overlaps.map { self.nodes[$0].path }.sorted()
    }
  }
}

extension String {
  func trailingTrimmed() -> String {
    var result = self
    while result.last == " " {
      result.removeLast()
    }
    return result
  }
}
