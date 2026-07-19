import Tessera

private struct ShowcaseRoot: View {
  let model: ShowcaseModel

  var body: some View {
    if model.viewportRole == .guardSize {
      Text("Resize to at least 40x12")
    } else {
      VStack {
        HStack {
          Text("Tessera Showcase")
          Spacer()
          Text(model.viewportRole.rawValue)
        }
        Divider()
        if model.size.columns >= 120 {
          SplitView(
            axis: model.binding(\.splitAxis),
            panes: model.binding(\.widePanes)
          ) {
            ShowcaseCatalog(model: model)
            ShowcasePlayground(model: model)
            ShowcaseInspector(model: model)
          }
        } else if model.size.columns >= 80 {
          SplitView(
            axis: model.binding(\.splitAxis),
            panes: model.binding(\.standardPanes)
          ) {
            ShowcaseCatalog(model: model)
            ShowcasePlayground(model: model)
          }
        } else {
          ScrollView(.vertical, offset: model.binding(\.compactOffset)) {
            ShowcaseCatalogContent(model: model)
          }
        }
      }
    }
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
