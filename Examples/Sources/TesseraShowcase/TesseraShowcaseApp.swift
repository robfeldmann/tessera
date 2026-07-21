import ExampleSupport
import Tessera

@main
enum TesseraShowcase {
  static func main() async throws {
    guard TerminalExampleSupport.isRunningInInteractiveTerminal() else {
      TerminalExampleSupport.printTerminalRequiredMessage(
        applicationName: "TesseraShowcase",
        features: ["raw mode", "terminal resize events", "immediate keyboard input"],
        runCommand: "swift run --package-path Examples TesseraShowcase",
        attachSchemeName: "TesseraShowcase (Attach)"
      )
      return
    }

    let configuration = TerminalApplicationConfiguration.default
    try await TerminalSession.withApplicationTerminal(
      configuration: configuration,
      run
    )
  }

  private static func run(terminal: isolated TerminalSession) async throws -> sending Void
  {
    let model = ShowcaseModel(size: ShowcaseFixture.standard.size)
    let graph = model.makeGraph()
    try await render(model, graph: graph, to: terminal)

    while true {
      let event = try await terminal.nextEvent()
      if case .key(let key) = event, key == Key(code: .character("q")) {
        return
      }

      _ = graph.dispatch(event)
      model.dispatch(event)
      if case .resize(let size) = event {
        graph.resize(to: size)
      }
      graph.update()
      if graph.needsRender {
        try await render(model, graph: graph, to: terminal)
      }
    }
  }

  static func render(
    _ model: ShowcaseModel,
    graph: ViewGraph,
    to terminal: isolated TerminalSession
  ) async throws {
    try await terminal.draw { frame in
      if model.size != frame.size {
        model.resize(to: frame.size)
        graph.resize(to: frame.size)
        graph.update()
      }
      graph.render(into: frame)
    }
  }
}
