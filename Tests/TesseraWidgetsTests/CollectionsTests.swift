import TesseraCore
import TesseraLayout
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTestSupport
import Testing

@testable import TesseraWidgets

private func collectionTestFrame(size: TerminalSize, _ body: (borrowing Frame) -> Void)
  -> Buffer
{
  var buffer = Buffer(size: size)
  var cursorPosition: TerminalPosition?
  withUnsafeMutablePointer(to: &buffer) { bufferStorage in
    withUnsafeMutablePointer(to: &cursorPosition) { cursorStorage in
      body(Frame(buffer: bufferStorage, cursorPosition: cursorStorage))
    }
  }
  return buffer
}

private struct CollectionRecord: Identifiable, Equatable {
  let id: Int
  let title: String
}

private final class CollectionModel {
  var records: [CollectionRecord]
  var selection: Int?
  var sortOrder: [SortDescriptor<CollectionRecord>] = []
  var activated: Int?

  init(records: [CollectionRecord], selection: Int? = nil) {
    self.records = records
    self.selection = selection
  }
}

private func selectionBinding(_ model: CollectionModel) -> Binding<Int?> {
  Binding(get: { model.selection }, set: { model.selection = $0 })
}

private func sortBinding(_ model: CollectionModel) -> Binding<
  [SortDescriptor<CollectionRecord>]
> {
  Binding(get: { model.sortOrder }, set: { model.sortOrder = $0 })
}

@Test
func `List moves controlled selection and preserves keyed identity across reorder`() {
  let model = CollectionModel(
    records: [
      CollectionRecord(id: 1, title: "one"),
      CollectionRecord(id: 2, title: "two"),
      CollectionRecord(id: 3, title: "three"),
    ],
    selection: 1
  )
  let focus = FocusID("records")
  let graph = ViewGraph(
    root: {
      List(model.records, selection: selectionBinding(model)) { record in
        Text(record.title)
      }
      .focusable(focus)
    },
    size: TerminalSize(columns: 12, rows: 2)
  )

  graph.focus.focus(focus)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(model.selection == 2)

  model.records = [
    CollectionRecord(id: 3, title: "three"),
    CollectionRecord(id: 2, title: "two"),
  ]
  graph.update()
  #expect(model.selection == 2)

  model.records = [CollectionRecord(id: 3, title: "three")]
  graph.update()
  #expect(model.selection == 2)
}

@Test
func `List renders an explicit empty state and clamps keyboard at endpoints`() {
  let model = CollectionModel(
    records: [CollectionRecord(id: 1, title: "one")],
    selection: nil
  )
  let size = TerminalSize(columns: 12, rows: 2)
  let focus = FocusID("empty-list")
  let graph = ViewGraph(
    root: {
      List(model.records, selection: selectionBinding(model), emptyMessage: "Nothing here")
      { record in
        Text(record.title)
      }
      .focusable(focus)
    },
    size: size
  )

  graph.focus.focus(focus)
  #expect(graph.dispatch(.key(Key(code: .up))) == .handled)
  #expect(model.selection == 1)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(model.selection == 1)

  model.records = []
  graph.update()
  #expect(graph.dispatch(.key(Key(code: .down))) == .ignored)
  #expect(model.selection == 1)
  let emptyGraph = ViewGraph(
    root: {
      List(model.records, selection: selectionBinding(model), emptyMessage: "Nothing here")
      { Text($0.title) }
    },
    size: size
  )
  let buffer = collectionTestFrame(size: size) { emptyGraph.render(into: $0) }
  #expect(buffer[0, 0].content == Cell.Content.grapheme("N"))
}
@Test
func `Table headers write controlled sort order and Enter activates selected identity`() {
  let model = CollectionModel(
    records: [
      CollectionRecord(id: 1, title: "one"),
      CollectionRecord(id: 2, title: "two"),
    ],
    selection: 1
  )
  let focus = FocusID("table")
  let graph = ViewGraph(
    root: {
      Table(
        model.records,
        selection: selectionBinding(model),
        sortOrder: sortBinding(model),
        columns: [
          TableColumn("Title") { $0.title },
          TableColumn("ID", constraint: .length(3)) { String($0.id) },
        ]
      ) { model.activated = $0.id }
      .focusable(focus)
    },
    size: TerminalSize(columns: 18, rows: 4)
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .press(.left), position: TerminalPosition(column: 1, row: 0)))
    ) == .handled
  )
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .release(.left), position: TerminalPosition(column: 1, row: 0)))
    ) == .handled
  )
  #expect(model.sortOrder == [SortDescriptor(key: "Title")])

  graph.focus.focus(focus)
  #expect(graph.dispatch(.key(Key(code: .enter))) == .handled)
  #expect(model.activated == 1)
}

@Test
func `Section remains a structural boundary for empty and adjacent content`() {
  let graph = ViewGraph(
    root: {
      VStack(spacing: 0) {
        Section("First") { Text("A") }
        Section(spacing: 1, header: { Text("Second") }, content: { EmptyView() })
      }
    },
    size: TerminalSize(columns: 12, rows: 5)
  )

  graph.layoutIfNeeded()
  let dump = graph.dump()
  #expect(dump.contains("measured=(5x3)"))
  #expect(dump.contains("frame=(0,3,6x2)"))
}
@Test
func `List row pointer selection and wheel offset stay controlled`() {
  let model = CollectionModel(
    records: (0..<8).map { CollectionRecord(id: $0, title: String($0)) })
  let focus = FocusID("pointer-list")
  let graph = ViewGraph(
    root: {
      List(model.records, selection: selectionBinding(model)) { Text($0.title) }
        .focusable(focus)
    },
    size: TerminalSize(columns: 8, rows: 3)
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .press(.left), position: TerminalPosition(column: 1, row: 1)))
    ) == .handled
  )
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .release(.left), position: TerminalPosition(column: 1, row: 1)))
    ) == .handled
  )
  #expect(model.selection == 1)

  graph.focus.focus(focus)
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .scroll(.down), position: TerminalPosition(column: 1, row: 1)))
    ) == .handled
  )
}
@Test
func `Table row pointer removal endpoint clamp and resize preserve controlled selection`()
{
  let model = CollectionModel(
    records: [
      CollectionRecord(id: 1, title: "one"),
      CollectionRecord(id: 2, title: "two"),
    ],
    selection: 1
  )
  let focus = FocusID("table-boundary")
  let graph = ViewGraph(
    root: {
      Table(
        model.records,
        selection: selectionBinding(model),
        columns: [TableColumn("Title") { $0.title }]
      )
      .focusable(focus)
    },
    size: TerminalSize(columns: 12, rows: 4)
  )

  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .press(.left), position: TerminalPosition(column: 1, row: 3)))
    ) == .handled
  )
  #expect(
    graph.dispatch(
      .mouse(
        MouseEvent(kind: .release(.left), position: TerminalPosition(column: 1, row: 3)))
    ) == .handled
  )
  #expect(model.selection == 2)

  graph.focus.focus(focus)
  #expect(graph.dispatch(.key(Key(code: .down))) == .handled)
  #expect(model.selection == 2)
  graph.resize(to: TerminalSize(columns: 6, rows: 2))
  #expect(model.selection == 2)

  model.records = [CollectionRecord(id: 1, title: "one")]
  graph.update()
  #expect(model.selection == 2)

  model.records = []
  graph.update()
  #expect(graph.dispatch(.key(Key(code: .down))) == .ignored)
  #expect(model.selection == 2)
}
@Test
func `List clips rows before a following Grid at persistent sizes`() {
  let records = (0..<4).map { CollectionRecord(id: $0, title: "row-\($0)") }
  let model = CollectionModel(records: records)
  let selection = selectionBinding(model)
  let graph = ViewGraph(
    root: {
      VStack(spacing: 1) {
        List(records, selection: selection) { Text($0.title) }
          .frame(height: 2)
        Grid(columns: [.fill(1), .fill(1)], spacing: 1) {
          Text("Grid A")
          Text("Grid B")
        }
      }
    },
    size: TerminalSize(columns: 20, rows: 8)
  )
  for size in [TerminalSize(columns: 20, rows: 8), TerminalSize(columns: 40, rows: 16)] {
    graph.resize(to: size)
    let buffer = collectionTestFrame(size: size) { graph.render(into: $0) }
    let row = (0..<size.columns).map { column in
      if case .grapheme(let value) = buffer[3, column].content {
        return value
      }
      return " "
    }.joined()
    #expect(row.contains("Grid A"))
    #expect(row.contains("Grid B"))
  }
}
@Test
func `multiline List rows do not paint through a following Grid sibling`() {
  let records = [
    CollectionRecord(id: 1, title: "Inbox"),
    CollectionRecord(id: 2, title: "Today"),
    CollectionRecord(id: 3, title: "Archive"),
    CollectionRecord(id: 4, title: "Empty"),
  ]
  let model = CollectionModel(records: records)
  let graph = ViewGraph(
    root: {
      VStack(alignment: .leading, spacing: 1) {
        Section("Collections", spacing: 1) {
          List(records, selection: selectionBinding(model)) { record in
            Button(
              action: { model.selection = record.id },
              label: {
                VStack(alignment: .leading, spacing: 0) {
                  Text(record.title)
                  Text("Long-lived synthetic history")
                }
              }
            )
          }
        }
        Grid(columns: [.fill(1), .fill(1)], spacing: 1) {
          Text("Grid A")
          Text("Grid B")
          Text("Grid C")
          Text("Grid D")
        }
      }
    },
    size: TerminalSize(columns: 40, rows: 16)
  )

  graph.layoutIfNeeded()
  let size = TerminalSize(columns: 40, rows: 16)
  let buffer = collectionTestFrame(size: size) { graph.render(into: $0) }
  let rows = (0..<size.rows).map { row in
    (0..<size.columns).map { column in
      if case .grapheme(let value) = buffer[row, column].content {
        return value
      }
      return " "
    }.joined()
  }
  let gridRows = rows.filter { $0.contains("Grid A") }
  #expect(gridRows.count == 1)
  #expect(gridRows[0].contains("Grid B"))
  #expect(!gridRows[0].contains("Long-lived synthetic history"))
}
@Test
func `Section zero proposal and maximum spacing remain bounded`() {
  let graph = ViewGraph(
    root: {
      Section(spacing: Int.max, header: { Text("Header") }, content: { Text("Content") })
    },
    size: TerminalSize(columns: 10, rows: 0)
  )

  graph.layoutIfNeeded()
  #expect(graph.dump().contains("measured=(7x0)"))
}
