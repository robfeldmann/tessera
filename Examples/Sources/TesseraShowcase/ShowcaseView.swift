import Tessera

private struct ShowcaseRoot: View {
  let model: ShowcaseModel

  var body: some View {
    if model.viewportRole == .guardSize {
      Text("Resize to at least 40x12")
    } else {
      Text("Tessera Showcase")
      if model.isSpecimenVisible {
        Text("Selected: \(model.catalogSelection.rawValue)")
      } else {
        Text("Selected: hidden")
      }
      Text("Diagnostics: ViewGraph ready")
    }
  }
}

extension ShowcaseModel {
  func makeGraph() -> ViewGraph {
    ViewGraph(root: { ShowcaseRoot(model: self) }, size: size)
  }
}
