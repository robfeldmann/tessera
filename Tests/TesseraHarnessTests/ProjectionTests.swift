import Foundation
import TesseraCore
import TesseraTerminalCore
import TesseraTerminalInput
import Testing

@testable import TesseraHarness

@MainActor
struct ProjectionTests {
  private let registry = ProjectionFixtures.registry()

  /// The projection of `name` at 40 columns by 12 rows, after the keys.
  private func project(
    of name: String, keys: [Character] = [], terminal: TerminalProfile = TerminalProfile()
  ) async throws -> Projection {
    final class Box {
      var projection: Projection?
    }
    let box = Box()
    try await registry.withHeadlessHost(
      name, at: .custom(TerminalSize(columns: 40, rows: 12)), terminal: terminal
    ) { host in
      for key in keys {
        try await host.send(.key(Key(code: .character(key))))
      }
      box.projection = host.projection
    }
    return try #require(box.projection)
  }

  private func node(_ projection: Projection, _ path: String) throws -> Projection.Node {
    try #require(projection.node(at: path), "no node at \(path)")
  }

  // MARK: Nodes

  @Test
  func
    `each node carries its short type and a container's layout, never a reflected name`()
    async throws
  {
    let projection = try await project(of: "layers")

    let types = projection.nodes.map(\.type)
    #expect(types.contains("VStack"))
    #expect(types.contains("ZStack"))
    #expect(types.contains("ForEach"))
    #expect(types.filter { $0 == "_LayoutContainer" }.count == 2)
    #expect(
      projection.nodes.filter { $0.type == "_LayoutContainer" }.compactMap(\.layout)
        == ["_FrameLayout", "_PaddingLayout"])
    #expect(
      projection.nodes.filter { $0.type != "_LayoutContainer" }.allSatisfy {
        $0.layout == nil
      })
    #expect(
      projection.nodes.allSatisfy { !$0.type.contains(".") && !$0.type.contains("<") })
  }

  @Test
  func
    `depth is the nesting and paint order is the position among the parent's children`()
    async throws
  {
    let projection = try await project(of: "layers")

    let root = try #require(projection.nodes.first)
    #expect(root.path == "root")
    #expect(root.depth == 0)
    #expect(root.parent == nil)
    let stack = try node(projection, "root/index(0)")
    #expect(stack.depth == 1)
    #expect(stack.children.count == 3)
    let positions = stack.children.compactMap { projection.node(at: $0)?.paintOrder }
    #expect(positions == [0, 1, 2])
    let items = try node(projection, "root/index(0)/index(2)")
    #expect(items.type == "ForEach")
    #expect(
      items.children == ["root/index(0)/index(2)/id(a)", "root/index(0)/index(2)/id(b)"])
    #expect(
      items.children.compactMap { projection.node(at: $0)?.paintOrder } == [0, 1])
  }

  @Test
  func `frames, clips, proposals, and measured sizes come from the graph`() async throws {
    let projection = try await project(of: "layers")

    let frame = try #require(projection.nodes.first { $0.layout == "_FrameLayout" })
    #expect(frame.frame == Projection.Box(column: 0, row: 0, columns: 2, rows: 1))
    let padding = try #require(projection.nodes.first { $0.layout == "_PaddingLayout" })
    #expect(padding.frame == Projection.Box(column: 0, row: 1, columns: 4, rows: 3))
    #expect(padding.measured == Projection.Extent(columns: 4, rows: 3))
    #expect(padding.proposal?.width == 40)
    #expect(projection.nodes.allSatisfy { !$0.needsLayout && !$0.needsRender })
  }

  // MARK: Text

  @Test
  func `text is attributed to the topmost leaf, so covered text is not the lower node's`()
    async throws
  {
    let projection = try await project(of: "layers")

    let status = try #require(
      projection.nodes.first { $0.text?.contains("atus") == true })
    #expect(status.text == "  atus")
    #expect(projection.nodes.contains { $0.text == "OK" })
    #expect(projection.nodes.contains { $0.text?.contains("status") == true } == false)
    let stack = try node(projection, "root/index(0)")
    #expect(
      stack.text == nil, "a container shows its leaves' text, and has none of its own")
  }

  @Test
  func `a wide grapheme's text is read from its cells and its leaf keeps its width`()
    async throws
  {
    let projection = try await project(of: "wide")

    let wide = try #require(projection.nodes.first { $0.text == "東京 map" })
    #expect(wide.frame == Projection.Box(column: 0, row: 0, columns: 8, rows: 1))
    #expect(projection.screen.rows.first == "東京 map")
  }

  // MARK: Screen and statistics

  @Test
  func `the screen holds its rows, cursor, and the runs of a style`() async throws {
    let projection = try await project(
      of: "styled", terminal: TerminalProfile(colors: .truecolor))

    #expect(Array(projection.screen.rows.prefix(3)) == ["bold", "plain", "blue"])
    #expect(projection.screen.columns == 40)
    #expect(
      projection.screen.styles == [
        Projection.Screen.StyleRun(
          row: 0, column: 0, columns: 4, style: "fg=#ff0000 bold"),
        Projection.Screen.StyleRun(
          row: 2, column: 0, columns: 4, style: "bg=indexed(4) underline"),
      ])
  }

  @Test
  func `the statistics carry the counters and the reasons, and no duration`() async throws
  {
    let projection = try await project(of: "layers")

    #expect(projection.statistics.invalidationReasons.contains("renderRequested"))
    #expect(projection.statistics.renderedNodes > 0)
    #expect(projection.statistics.measurements > 0)
    #expect(projection.statistics.placements > 0)
    let json = try #require(
      String(bytes: try JSONEncoder().encode(projection), encoding: .utf8))
    #expect(!json.lowercased().contains("duration"))
  }

  @Test
  func `the pass marker is the step that drew the projected frame`() async throws {
    let first = try await project(of: "steady")
    let third = try await project(of: "steady", keys: ["+", "+"])

    #expect(first.pass == 0)
    #expect(third.pass == 2)
  }

  // MARK: JSON

  @Test
  func `the JSON has sorted keys, a version, and the same bytes on every run`()
    async throws
  {
    let first = try await project(of: "layers")
    let second = try await project(of: "layers")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

    let json = try #require(String(bytes: try encoder.encode(first), encoding: .utf8))

    #expect(try encoder.encode(first) == encoder.encode(second))
    #expect(first.version == Projection.currentVersion)
    #expect(json.contains(#""version":1"#))
    // Sorted at every level: the top-level keys follow the node list, in order.
    #expect(json.hasPrefix(#"{"nodes":[{"#))
    let tail = try #require(json.range(of: #"],"pass":0,"requirements":{"#))
    let rest = json[tail.upperBound...]
    let screen = try #require(rest.range(of: #""screen":{"#))
    let statistics = try #require(rest.range(of: #""statistics":{"#))
    #expect(screen.lowerBound < statistics.lowerBound)
    #expect(json.hasSuffix(#""version":1}"#))
    #expect(!json.contains("TesseraCore"))
    #expect(!json.contains("unknown context"))
  }

  @Test
  func `a node's JSON leaves out what it does not have`() async throws {
    let projection = try await project(of: "layers")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let root = try #require(projection.nodes.first)

    let json = try #require(String(bytes: try encoder.encode(root), encoding: .utf8))

    #expect(!json.contains("\"parent\""))
    #expect(!json.contains("\"layout\""))
    #expect(!json.contains("\"text\""))
    #expect(json.contains("\"path\":\"root\""))
  }
}
