import Tessera

private struct ShowcaseRoot: View {
  let model: ShowcaseModel

  var body: some View {
    if model.viewportRole == .guardSize {
      Text("Resize to at least 23x10")
    } else {
      VStack {
        HStack {
          Text("Tessera Showcase")
          Spacer()
          Text(model.viewportRole.rawValue)
        }
        ShowcaseWorkspaceDivider(model: model)
        switch model.viewportRole {
        case .regular:
          SplitView(
            axis: model.binding(\.splitAxis),
            panes: model.binding(\.widePanes)
          ) {
            ShowcaseCatalog(model: model)
              .layoutPriority(1)
            ShowcasePlayground(model: model)
            ShowcaseInspector(model: model)
              .layoutPriority(1)
          }
        case .standard:
          SplitView(
            axis: model.binding(\.splitAxis),
            panes: model.binding(\.standardPanes)
          ) {
            ShowcaseCatalog(model: model)
              .layoutPriority(1)
            ShowcasePlayground(model: model)
          }
        case .compact:
          ScrollView(.vertical, offset: model.binding(\.compactOffset)) {
            ShowcaseCatalogContent(model: model)
          }
        case .guardSize:
          EmptyView()
        }
      }
    }
  }
}

private struct ShowcaseWorkspaceDivider: LeafView {
  let model: ShowcaseModel

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: proposal.width ?? 1, rows: 1)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    let columns = max(region.bounds.size.columns, 0)
    region.write(
      String(repeating: "─", count: columns),
      at: TerminalPosition(column: 0, row: 0)
    )
    guard model.splitAxis == .horizontal else {
      return
    }

    switch model.viewportRole {
    case .regular:
      writeJunction(at: 24, in: &region)
      writeJunction(at: columns - 25, in: &region)
    case .standard:
      writeJunction(at: 24, in: &region)
    case .compact, .guardSize:
      break
    }
  }

  private func writeJunction(at column: Int, in region: inout RenderRegion) {
    guard column >= 0, column < region.bounds.size.columns else {
      return
    }
    region.write("┬", at: TerminalPosition(column: column, row: 0))
  }
}

private struct ShowcaseCatalog: View {
  let model: ShowcaseModel

  var body: some View {
    ScrollView(.vertical, offset: model.binding(\.catalogOffset)) {
      ShowcaseCatalogContent(model: model)
    }
  }
}

private struct ShowcaseCatalogContent: View {
  let model: ShowcaseModel

  var body: some View {
    Text(
      """
      Catalog
      > \(model.catalogSelection.rawValue)
      Overview
      Primitives
        Divider
        Frame
        Padding
        Spacer
      Layout
        HStack
        VStack
        ZStack
        SplitView
      Scrolling
        ScrollView
      Diagnostics
        ViewGraph
        Frames
        Clips
        Proposals
      """
    )
  }
}

private struct ShowcasePlayground: View {
  let model: ShowcaseModel

  var body: some View {
    ScrollView(.vertical, offset: model.binding(\.playgroundOffset)) {
      Text(
        """
        Playground
        Selected: \(model.isSpecimenVisible ? model.catalogSelection.rawValue : "hidden")

        Text specimen
        Hello, Tessera
        Unicode: café 你好

        [Button placeholder]
        [Toggle placeholder: \(model.controlValue ? "on" : "off")]

        Layout diagnostics remain
        visible through the Inspector.
        """
      )
    }
  }
}

private struct ShowcaseInspector: View {
  let model: ShowcaseModel

  var body: some View {
    ScrollView(.vertical, offset: model.binding(\.inspectorOffset)) {
      Text(
        """
        Inspector
        node: selected
        proposal: \(model.size.columns)x\(model.size.rows)
        frame: absolute
        clip: parent
        state: app-owned
        render: ready
        """
      )
    }
  }
}

extension ShowcaseModel {
  func makeGraph() -> ViewGraph {
    ViewGraph(root: { ShowcaseRoot(model: self) }, size: size)
  }
}
