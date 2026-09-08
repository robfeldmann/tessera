import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import Testing

@testable import TesseraWidgets

private final class NavigationSplitModel {
  var visibility: NavigationSplitViewVisibility = .all
  var preferredCompactColumn: NavigationSplitViewColumn = .detail

  var visibilityBinding: Binding<NavigationSplitViewVisibility> {
    Binding(get: { self.visibility }, set: { self.visibility = $0 })
  }

  var preferredBinding: Binding<NavigationSplitViewColumn> {
    Binding(
      get: { self.preferredCompactColumn }, set: { self.preferredCompactColumn = $0 })
  }
}

private func navigationPaneFrame(_ graph: ViewGraph, column: String) throws -> Rect {
  try #require(
    graph.diagnostics.nodes.first { $0.identity.description == "root/id(\(column))" }
  ).frame
}

@Test
func `navigation split view places visible roles and dividers in regular space`() throws {
  let model = NavigationSplitModel()
  let graph = ViewGraph(
    root: {
      NavigationSplitView(
        columnVisibility: model.visibilityBinding,
        preferredCompactColumn: model.preferredBinding,
        sidebar: { Text("S") },
        content: { Text("C") },
        detail: { Text("D") }
      )
    },
    size: TerminalSize(columns: 8, rows: 1)
  )

  graph.layoutIfNeeded()
  #expect(try navigationPaneFrame(graph, column: "sidebar").size.columns == 2)
  #expect(try navigationPaneFrame(graph, column: "content").size.columns == 2)
  #expect(try navigationPaneFrame(graph, column: "detail").size.columns == 2)
  #expect(try navigationPaneFrame(graph, column: "sidebar").origin.column == 0)
  #expect(try navigationPaneFrame(graph, column: "content").origin.column == 3)
  #expect(try navigationPaneFrame(graph, column: "detail").origin.column == 6)
}

@Test
func
  `navigation split view shows preferred role and uses semantic fallback in compact space`()
  throws
{
  let model = NavigationSplitModel()
  let graph = ViewGraph(
    root: {
      NavigationSplitView(
        columnVisibility: model.visibilityBinding,
        preferredCompactColumn: model.preferredBinding,
        sidebar: { Text("S") },
        content: { Text("C") },
        detail: { Text("D") }
      )
    },
    size: TerminalSize(columns: 2, rows: 1)
  )

  graph.layoutIfNeeded()
  #expect(try navigationPaneFrame(graph, column: "sidebar").size.columns == 0)
  #expect(try navigationPaneFrame(graph, column: "content").size.columns == 0)
  #expect(try navigationPaneFrame(graph, column: "detail").size.columns == 2)

  model.visibility = [.sidebar, .content]
  graph.update()
  graph.layoutIfNeeded()
  #expect(try navigationPaneFrame(graph, column: "sidebar").size.columns == 2)
  #expect(try navigationPaneFrame(graph, column: "content").size.columns == 0)
  #expect(try navigationPaneFrame(graph, column: "detail").size.columns == 0)
}

@Test
func
  `navigation split view preserves focused role across regular and compact transitions`()
  throws
{
  let model = NavigationSplitModel()
  let sidebarID = FocusID("navigation.sidebar")
  let detailID = FocusID("navigation.detail")
  let graph = ViewGraph(
    root: {
      NavigationSplitView(
        columnVisibility: model.visibilityBinding,
        preferredCompactColumn: model.preferredBinding,
        sidebar: { Text("S").focusable(sidebarID) },
        content: { Text("C") },
        detail: { Text("D").focusable(detailID) }
      )
    },
    size: TerminalSize(columns: 8, rows: 1)
  )

  graph.focus.focus(detailID)
  #expect(graph.focus.focused == detailID)
  graph.resize(to: TerminalSize(columns: 2, rows: 1))
  #expect(graph.focus.focused == detailID)

  model.visibility = [.sidebar]
  graph.update()
  #expect(graph.focus.focused == nil)
  #expect(graph.focus.focusableIDs.contains(sidebarID))
}
