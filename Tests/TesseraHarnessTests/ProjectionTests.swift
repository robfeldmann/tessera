import CustomDump
import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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

    assertInlineSnapshot(
      of: projection.nodes.map { ($0.path, $0.type, $0.layout) }, as: .customDump
    ) {
      """
      [
        [0]: (
          "root",
          "TupleView",
          nil
        ),
        [1]: (
          "root/index(0)",
          "VStack",
          nil
        ),
        [2]: (
          "root/index(0)/index(0)",
          "ZStack",
          nil
        ),
        [3]: (
          "root/index(0)/index(0)/index(0)",
          "Text",
          nil
        ),
        [4]: (
          "root/index(0)/index(0)/index(1)",
          "_LayoutContainer",
          "_FrameLayout"
        ),
        [5]: (
          "root/index(0)/index(0)/index(1)/index(0)",
          "Text",
          nil
        ),
        [6]: (
          "root/index(0)/index(1)",
          "_LayoutContainer",
          "_PaddingLayout"
        ),
        [7]: (
          "root/index(0)/index(1)/index(0)",
          "Text",
          nil
        ),
        [8]: (
          "root/index(0)/index(2)",
          "ForEach",
          nil
        ),
        [9]: (
          "root/index(0)/index(2)/id(a)",
          "TupleView",
          nil
        ),
        [10]: (
          "root/index(0)/index(2)/id(a)/index(0)",
          "Text",
          nil
        ),
        [11]: (
          "root/index(0)/index(2)/id(b)",
          "TupleView",
          nil
        ),
        [12]: (
          "root/index(0)/index(2)/id(b)/index(0)",
          "Text",
          nil
        )
      ]
      """
    }
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

    assertInlineSnapshot(
      of: projection.nodes.map {
        ($0.path, $0.parent, $0.depth, $0.paintOrder, $0.children)
      },
      as: .customDump
    ) {
      """
      [
        [0]: (
          "root",
          nil,
          0,
          0,
          [
            [0]: "root/index(0)"
          ]
        ),
        [1]: (
          "root/index(0)",
          "root",
          1,
          0,
          [
            [0]: "root/index(0)/index(0)",
            [1]: "root/index(0)/index(1)",
            [2]: "root/index(0)/index(2)"
          ]
        ),
        [2]: (
          "root/index(0)/index(0)",
          "root/index(0)",
          2,
          0,
          [
            [0]: "root/index(0)/index(0)/index(0)",
            [1]: "root/index(0)/index(0)/index(1)"
          ]
        ),
        [3]: (
          "root/index(0)/index(0)/index(0)",
          "root/index(0)/index(0)",
          3,
          0,
          []
        ),
        [4]: (
          "root/index(0)/index(0)/index(1)",
          "root/index(0)/index(0)",
          3,
          1,
          [
            [0]: "root/index(0)/index(0)/index(1)/index(0)"
          ]
        ),
        [5]: (
          "root/index(0)/index(0)/index(1)/index(0)",
          "root/index(0)/index(0)/index(1)",
          4,
          0,
          []
        ),
        [6]: (
          "root/index(0)/index(1)",
          "root/index(0)",
          2,
          1,
          [
            [0]: "root/index(0)/index(1)/index(0)"
          ]
        ),
        [7]: (
          "root/index(0)/index(1)/index(0)",
          "root/index(0)/index(1)",
          3,
          0,
          []
        ),
        [8]: (
          "root/index(0)/index(2)",
          "root/index(0)",
          2,
          2,
          [
            [0]: "root/index(0)/index(2)/id(a)",
            [1]: "root/index(0)/index(2)/id(b)"
          ]
        ),
        [9]: (
          "root/index(0)/index(2)/id(a)",
          "root/index(0)/index(2)",
          3,
          0,
          [
            [0]: "root/index(0)/index(2)/id(a)/index(0)"
          ]
        ),
        [10]: (
          "root/index(0)/index(2)/id(a)/index(0)",
          "root/index(0)/index(2)/id(a)",
          4,
          0,
          []
        ),
        [11]: (
          "root/index(0)/index(2)/id(b)",
          "root/index(0)/index(2)",
          3,
          1,
          [
            [0]: "root/index(0)/index(2)/id(b)/index(0)"
          ]
        ),
        [12]: (
          "root/index(0)/index(2)/id(b)/index(0)",
          "root/index(0)/index(2)/id(b)",
          4,
          0,
          []
        )
      ]
      """
    }
  }

  @Test
  func `frames, clips, proposals, and measured sizes come from the graph`() async throws {
    let projection = try await project(of: "layers")

    assertInlineSnapshot(
      of: projection.nodes.map { ($0.path, $0.frame, $0.clip, $0.proposal, $0.measured) },
      as: .customDump
    ) {
      """
      [
        [0]: (
          "root",
          Projection.Box(
            column: 0,
            row: 0,
            columns: 40,
            rows: 12
          ),
          Projection.Box(
            column: 0,
            row: 0,
            columns: 40,
            rows: 12
          ),
          Projection.Proposal(
            width: 40,
            height: 12
          ),
          Projection.Extent(
            columns: 6,
            rows: 6
          )
        ),
        [1]: (
          "root/index(0)",
          Projection.Box(
            column: 0,
            row: 0,
            columns: 40,
            rows: 12
          ),
          Projection.Box(
            column: 0,
            row: 0,
            columns: 40,
            rows: 12
          ),
          Projection.Proposal(
            width: 40,
            height: 12
          ),
          Projection.Extent(
            columns: 6,
            rows: 6
          )
        ),
        [2]: (
          "root/index(0)/index(0)",
          Projection.Box(
            column: 0,
            row: 0,
            columns: 6,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 0,
            columns: 6,
            rows: 1
          ),
          Projection.Proposal(
            width: 40,
            height: 1
          ),
          Projection.Extent(
            columns: 6,
            rows: 1
          )
        ),
        [3]: (
          "root/index(0)/index(0)/index(0)",
          Projection.Box(
            column: 0,
            row: 0,
            columns: 6,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 0,
            columns: 6,
            rows: 1
          ),
          Projection.Proposal(
            width: 6,
            height: 1
          ),
          Projection.Extent(
            columns: 6,
            rows: 1
          )
        ),
        [4]: (
          "root/index(0)/index(0)/index(1)",
          Projection.Box(
            column: 0,
            row: 0,
            columns: 2,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 0,
            columns: 2,
            rows: 1
          ),
          Projection.Proposal(
            width: 6,
            height: 1
          ),
          Projection.Extent(
            columns: 2,
            rows: 1
          )
        ),
        [5]: (
          "root/index(0)/index(0)/index(1)/index(0)",
          Projection.Box(
            column: 0,
            row: 0,
            columns: 2,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 0,
            columns: 2,
            rows: 1
          ),
          Projection.Proposal(
            width: 2,
            height: 1
          ),
          Projection.Extent(
            columns: 2,
            rows: 1
          )
        ),
        [6]: (
          "root/index(0)/index(1)",
          Projection.Box(
            column: 0,
            row: 1,
            columns: 4,
            rows: 3
          ),
          Projection.Box(
            column: 0,
            row: 1,
            columns: 4,
            rows: 3
          ),
          Projection.Proposal(
            width: 40,
            height: 3
          ),
          Projection.Extent(
            columns: 4,
            rows: 3
          )
        ),
        [7]: (
          "root/index(0)/index(1)/index(0)",
          Projection.Box(
            column: 1,
            row: 2,
            columns: 2,
            rows: 1
          ),
          Projection.Box(
            column: 1,
            row: 2,
            columns: 2,
            rows: 1
          ),
          Projection.Proposal(
            width: 2,
            height: 1
          ),
          Projection.Extent(
            columns: 2,
            rows: 1
          )
        ),
        [8]: (
          "root/index(0)/index(2)",
          Projection.Box(
            column: 0,
            row: 4,
            columns: 1,
            rows: 2
          ),
          Projection.Box(
            column: 0,
            row: 4,
            columns: 1,
            rows: 2
          ),
          nil,
          nil
        ),
        [9]: (
          "root/index(0)/index(2)/id(a)",
          Projection.Box(
            column: 0,
            row: 4,
            columns: 1,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 4,
            columns: 1,
            rows: 1
          ),
          nil,
          nil
        ),
        [10]: (
          "root/index(0)/index(2)/id(a)/index(0)",
          Projection.Box(
            column: 0,
            row: 4,
            columns: 1,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 4,
            columns: 1,
            rows: 1
          ),
          Projection.Proposal(
            width: 40,
            height: 1
          ),
          Projection.Extent(
            columns: 1,
            rows: 1
          )
        ),
        [11]: (
          "root/index(0)/index(2)/id(b)",
          Projection.Box(
            column: 0,
            row: 5,
            columns: 1,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 5,
            columns: 1,
            rows: 1
          ),
          nil,
          nil
        ),
        [12]: (
          "root/index(0)/index(2)/id(b)/index(0)",
          Projection.Box(
            column: 0,
            row: 5,
            columns: 1,
            rows: 1
          ),
          Projection.Box(
            column: 0,
            row: 5,
            columns: 1,
            rows: 1
          ),
          Projection.Proposal(
            width: 40,
            height: 1
          ),
          Projection.Extent(
            columns: 1,
            rows: 1
          )
        )
      ]
      """
    }
    #expect(projection.nodes.allSatisfy { !$0.needsLayout && !$0.needsRender })
  }

  // MARK: Text

  @Test
  func `text is attributed to the topmost leaf, so covered text is not the lower node's`()
    async throws
  {
    let projection = try await project(of: "layers")

    assertInlineSnapshot(of: projection.nodes.map { ($0.path, $0.text) }, as: .customDump)
    {
      """
      [
        [0]: (
          "root",
          nil
        ),
        [1]: (
          "root/index(0)",
          nil
        ),
        [2]: (
          "root/index(0)/index(0)",
          nil
        ),
        [3]: (
          "root/index(0)/index(0)/index(0)",
          "  atus"
        ),
        [4]: (
          "root/index(0)/index(0)/index(1)",
          nil
        ),
        [5]: (
          "root/index(0)/index(0)/index(1)/index(0)",
          "OK"
        ),
        [6]: (
          "root/index(0)/index(1)",
          nil
        ),
        [7]: (
          "root/index(0)/index(1)/index(0)",
          "Go"
        ),
        [8]: (
          "root/index(0)/index(2)",
          nil
        ),
        [9]: (
          "root/index(0)/index(2)/id(a)",
          nil
        ),
        [10]: (
          "root/index(0)/index(2)/id(a)/index(0)",
          "a"
        ),
        [11]: (
          "root/index(0)/index(2)/id(b)",
          nil
        ),
        [12]: (
          "root/index(0)/index(2)/id(b)/index(0)",
          "b"
        )
      ]
      """
    }
  }

  @Test
  func `a wide grapheme's text is read from its cells and its leaf keeps its width`()
    async throws
  {
    let projection = try await project(of: "wide")

    let wide = try #require(projection.nodes.first { $0.text == "東京 map" })
    assertInlineSnapshot(of: wide.frame, as: .customDump) {
      """
      Projection.Box(
        column: 0,
        row: 0,
        columns: 8,
        rows: 1
      )
      """
    }
    #expect(projection.screen.rows.first == "東京 map")
  }

  // MARK: Screen and statistics

  @Test
  func `the screen holds its rows, cursor, and the runs of a style`() async throws {
    let projection = try await project(
      of: "styled", terminal: TerminalProfile(colors: .truecolor))

    assertInlineSnapshot(of: projection.screen, as: .customDump) {
      """
      Projection.Screen(
        columns: 40,
        cursor: Projection.Screen.Cursor(
          column: 39,
          row: 11
        ),
        rows: [
          [0]: "bold",
          [1]: "plain",
          [2]: "blue",
          [3]: "",
          [4]: "",
          [5]: "",
          [6]: "",
          [7]: "",
          [8]: "",
          [9]: "",
          [10]: "",
          [11]: ""
        ],
        styles: [
          [0]: Projection.Screen.StyleRun(
            row: 0,
            column: 0,
            columns: 4,
            style: "fg=#ff0000 bold"
          ),
          [1]: Projection.Screen.StyleRun(
            row: 2,
            column: 0,
            columns: 4,
            style: "bg=indexed(4) underline"
          )
        ]
      )
      """
    }
  }

  @Test
  func `the statistics carry the counters and the reasons, and no duration`() async throws
  {
    let projection = try await project(of: "layers")

    assertInlineSnapshot(of: projection.statistics, as: .customDump) {
      """
      Projection.Statistics(
        bodyEvaluations: 0,
        equatableSkips: 0,
        focusChanges: 0,
        invalidationReasons: [
          [0]: "layoutEnvironmentChanged",
          [1]: "layoutViewChanged",
          [2]: "renderEnvironmentChanged",
          [3]: "renderRequested",
          [4]: "renderViewChanged",
          [5]: "updateRequested"
        ],
        leafUpdates: 5,
        measurements: 29,
        nodesCreated: 0,
        nodesDestroyed: 0,
        nodesUpdated: 13,
        placements: 13,
        renderedNodes: 5,
        terminalRequirementChanges: 0
      )
      """
    }
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

    assertInlineSnapshot(of: json, as: .lines) {
      #"""
      {"children":["root\/index(0)"],"clip":{"column":0,"columns":40,"row":0,"rows":12},"depth":0,"environmentOverrides":[],"frame":{"column":0,"columns":40,"row":0,"rows":12},"handlerKinds":[],"isList":true,"measured":{"columns":6,"rows":6},"needsLayout":false,"needsRender":false,"paintOrder":0,"path":"root","proposal":{"height":12,"width":40},"requirements":[],"type":"TupleView"}
      """#
    }
  }
}
