import Tessera
import TesseraTerminalSnapshotSupport

/// An application the headless runner can drive.
///
/// `ViewGraph.dispatch` is a stub at HEAD (investigation 039), so input never reaches
/// views. The app therefore owns its model: ``apply(_:)`` is the seam where a real
/// runner would deliver the event after `graph.dispatch` returned `.ignored`.
public protocol DemoApp: AnyObject {
  associatedtype Root: View

  static var name: String { get }

  init()

  var root: Root { get }

  /// Applies one input event to app-owned state.
  func apply(_ event: InputEvent)
}

/// The type-erased surface the scenario runner uses.
protocol ScenarioHost: AnyObject {
  var size: TerminalSize { get }
  var screenRows: [String] { get }
  var diagnostics: GraphDiagnostics { get }
  func send(_ event: InputEvent)
}

/// Runs the canonical loop once per event:
/// `resize → graph.dispatch → app.apply → graph.update → Buffer → Renderer → Ghostty`.
final class Driver<App: DemoApp>: ScenarioHost {
  private let app: App
  private let graph: ViewGraph
  private(set) var size: TerminalSize
  private var screen = ScreenSnapshot.empty

  init(size: TerminalSize) {
    let app = App()
    app.apply(.resize(size))
    self.app = app
    self.size = size
    graph = ViewGraph(root: { app.root }, size: size)
    present()
  }

  var diagnostics: GraphDiagnostics {
    graph.diagnostics
  }

  var screenRows: [String] {
    screen.cells.map { row in
      var text = String(row.map(\.character))
      while text.last == " " {
        text.removeLast()
      }
      return text
    }
  }

  func send(_ event: InputEvent) {
    if case .resize(let newSize) = event {
      size = newSize
      graph.resize(to: newSize)
    }
    _ = graph.dispatch(event)
    app.apply(event)
    graph.update()
    present()
  }

  private func present() {
    let graph = graph
    screen = VirtualTerminal.snapshot(size: size) { frame in
      graph.render(into: frame)
    }
  }
}
