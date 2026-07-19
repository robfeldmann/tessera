import InlineSnapshotTesting
import SnapshotTesting
import Tessera
import TesseraTerminal
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import Testing
@testable import TesseraShowcase

@Suite(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  ),
  .serialized
)
struct ShowcaseFixtureTests {
  @Test
  func `regular fixture dispatches and renders deterministically`() {
    let result = render(.regular)
    assertModel(result.model, fixture: .regular)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                                                                                             three roles
      ────────────────────────┬──────────────────────────────────────────────────────────────────────┬────────────────────────
      Catalog                 │Playground                                                            │Inspector
      > Text                  │Selected: Text                                                        │node: selected
      Overview                │                                                                      │proposal: 120x24
      Primitives              │Text specimen                                                         │frame: absolute
        Divider               │Hello, Tessera                                                        │clip: parent
        Frame                 │Unicode: café 你好                                                    │state: app-owned
        Padding               │                                                                      │render: ready
        Spacer                │[Button placeholder]                                                  │
      Layout                  │[Toggle placeholder: off]                                             │
        HStack                │                                                                      │
        VStack                │Layout diagnostics remain                                             │
        ZStack                │visible through the Inspector.                                        │
        SplitView             │                                                                      │
      Scrolling               │                                                                      │
        ScrollView            │                                                                      │
      Diagnostics             │                                                                      │
        ViewGraph             │                                                                      │
        Frames                │                                                                      │
        Clips                 │                                                                      │
        Proposals             │                                                                      │
                              │                                                                      │
                              │                                                                      │
      """
    }
  }

  @Test
  func `standard fixture dispatches and renders deterministically`() {
    let result = render(.standard)
    assertModel(result.model, fixture: .standard)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                                                     three roles
      ────────────────────────┬──────────────────────────────┬────────────────────────
      Catalog                 │Playground                    │Inspector
      > Text                  │Selected: Text                │node: selected
      Overview                │                              │proposal: 80x24
      Primitives              │Text specimen                 │frame: absolute
        Divider               │Hello, Tessera                │clip: parent
        Frame                 │Unicode: café 你好            │state: app-owned
        Padding               │                              │render: ready
        Spacer                │[Button placeholder]          │
      Layout                  │[Toggle placeholder: off]     │
        HStack                │                              │
        VStack                │Layout diagnostics remain     │
        ZStack                │visible through the Inspector.│
        SplitView             │                              │
      Scrolling               │                              │
        ScrollView            │                              │
      Diagnostics             │                              │
        ViewGraph             │                              │
        Frames                │                              │
        Clips                 │                              │
        Proposals             │                              │
                              │                              │
                              │                              │
      """
    }
  }

  @Test
  func `short standard fixture dispatches and renders deterministically`() {
    let result = render(.standardShort)
    assertModel(result.model, fixture: .standardShort)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                                                     three roles
      ────────────────────────┬──────────────────────────────┬────────────────────────
      Catalog                 │Playground                    │Inspector
      > Text                  │Selected: Text                │node: selected
      Overview                │                              │proposal: 80x16
      Primitives              │Text specimen                 │frame: absolute
        Divider               │Hello, Tessera                │clip: parent
        Frame                 │Unicode: café 你好            │state: app-owned
        Padding               │                              │render: ready
        Spacer                │[Button placeholder]          │
      Layout                  │[Toggle placeholder: off]     │
        HStack                │                              │
        VStack                │Layout diagnostics remain     │
        ZStack                │visible through the Inspector.│
        SplitView             │                              │
      Scrolling               │                              │
      """
    }
  }

  @Test
  func `compact fixture dispatches and renders deterministically`() {
    let result = render(.compact)
    assertModel(result.model, fixture: .compact)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                one role
      ────────────────────────────────────────
      Catalog
      > Text
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
      """
    }
  }

  @Test
  func `guard fixture dispatches and renders deterministically`() {
    let result = render(.guardSize)
    assertModel(result.model, fixture: .guardSize)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Resize to at least 23x









      """
    }
  }

  @Test
  func `responsive boundary snapshots preserve negotiated Showcase roles`() {
    let sizes = [
      TerminalSize(columns: 22, rows: 10),
      TerminalSize(columns: 23, rows: 10),
      TerminalSize(columns: 47, rows: 10),
      TerminalSize(columns: 48, rows: 10),
      TerminalSize(columns: 72, rows: 10),
      TerminalSize(columns: 73, rows: 10),
      TerminalSize(columns: 119, rows: 24),
      TerminalSize(columns: 120, rows: 24),
      TerminalSize(columns: 121, rows: 24),
      TerminalSize(columns: 73, rows: 9),
      TerminalSize(columns: 73, rows: 10),
    ]
    let summary = sizes.map { size in
      let model = ShowcaseModel(size: size)
      let graph = model.makeGraph()
      graph.layoutIfNeeded()
      return [
        "\(size.columns)x\(size.rows)",
        model.viewportRole.rawValue,
        "catalog=\(region(named: "ShowcaseCatalog", in: graph))",
        "playground=\(region(named: "ShowcasePlayground", in: graph))",
        "inspector=\(region(named: "ShowcaseInspector", in: graph))",
      ].joined(separator: " ")
    }.joined(separator: "\n")

    assertInlineSnapshot(of: summary, as: .lines) {
      """
      22x10 resize guard catalog=- playground=- inspector=-
      23x10 one role catalog=0+23 playground=- inspector=-
      47x10 one role catalog=0+47 playground=- inspector=-
      48x10 two roles catalog=0+24 playground=25+23 inspector=-
      72x10 two roles catalog=0+24 playground=25+47 inspector=-
      73x10 three roles catalog=0+24 playground=25+23 inspector=49+24
      119x24 three roles catalog=0+24 playground=25+69 inspector=95+24
      120x24 three roles catalog=0+24 playground=25+70 inspector=96+24
      121x24 three roles catalog=0+24 playground=25+71 inspector=97+24
      73x9 resize guard catalog=- playground=- inspector=-
      73x10 three roles catalog=0+24 playground=25+23 inspector=49+24
      """
    }
  }

  @Test
  func `workspace divider uses T junctions at responsive pane boundaries`() throws {
    let widths = [47, 48, 72, 73]
    let summary = try widths.map { width in
      let size = TerminalSize(columns: width, rows: 10)
      let model = ShowcaseModel(size: size)
      let graph = model.makeGraph()
      let snapshot = VirtualTerminal.snapshot(size: size) { frame in
        graph.render(into: frame)
      }
      let separator = try #require(snapshot.cells.dropFirst().first)
      return "\(width): \(String(separator.map(\.character)))"
    }.joined(separator: "\n")

    assertInlineSnapshot(of: summary, as: .lines) {
      """
      47: ───────────────────────────────────────────────
      48: ────────────────────────┬───────────────────────
      72: ────────────────────────┬───────────────────────────────────────────────
      73: ────────────────────────┬───────────────────────┬────────────────────────
      """
    }
  }

  @Test
  func `model state and controlled ideals survive responsive role replacement`() {
    let initialSize = TerminalSize(columns: 73, rows: 10)
    let model = ShowcaseModel(size: initialSize)
    let graph = model.makeGraph()
    let widePanes = model.widePanes
    let standardPanes = model.standardPanes
    model.controlValue = true
    model.isSpecimenVisible = false
    model.catalogOffset = TerminalPosition(column: 0, row: 3)
    graph.layoutIfNeeded()

    model.resize(to: TerminalSize(columns: 47, rows: 10))
    graph.resize(to: model.size)
    graph.update()
    graph.layoutIfNeeded()
    #expect(model.viewportRole == .compact)

    model.resize(to: initialSize)
    graph.resize(to: model.size)
    graph.update()
    graph.layoutIfNeeded()

    #expect(model.viewportRole == .regular)
    #expect(model.controlValue)
    #expect(model.isSpecimenVisible == false)
    #expect(model.catalogOffset == TerminalPosition(column: 0, row: 3))
    #expect(model.widePanes == widePanes)
    #expect(model.standardPanes == standardPanes)
  }

  private func region(named name: String, in graph: ViewGraph) -> String {
    let node = graph.diagnostics.nodes.first { node in
      node.viewType.hasSuffix(name)
    }
    guard let node else {
      if name == "ShowcaseCatalog",
        let viewport = graph.diagnostics.nodes.first(where: {
          $0.viewType.hasPrefix("TesseraWidgets.ScrollView<")
        })
      {
        return "\(viewport.clip.origin.column)+\(viewport.clip.size.columns)"
      }
      return "-"
    }
    return "\(node.clip.origin.column)+\(node.clip.size.columns)"
  }

  private func render(
    _ fixture: ShowcaseFixture
  ) -> (model: ShowcaseModel, snapshot: ScreenSnapshot) {
    let script = ShowcaseScript(events: [
      .paste("fixture"),
      .resize(fixture.size),
    ])
    let model = ShowcaseModel(size: fixture.size)
    model.dispatch(script)
    let graph = model.makeGraph()
    let snapshot = VirtualTerminal.snapshot(size: fixture.size) { frame in
      graph.render(into: frame)
    }
    return (model, snapshot)
  }

  private func assertModel(_ model: ShowcaseModel, fixture: ShowcaseFixture) {
    #expect(model.eventCount == 2)
    #expect(model.lastPaste == "fixture")
    #expect(model.size == fixture.size)
  }
}
