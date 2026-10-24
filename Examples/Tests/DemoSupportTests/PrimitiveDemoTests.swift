import Tessera
import Testing

@testable import DemoSupport
@testable import TesseraHarness

/// The demos of the layout primitives: each renders at both its viewports, takes its keys, quits
/// on `q`, and keeps the invariants that hold for it.
@MainActor
struct PrimitiveDemoTests {
  nonisolated static let demos = [
    "flex", "foreach", "frame-padding", "stacks", "text", "zstack",
  ]

  /// The rules a demo keeps with no help: every rule, except for the demos that overflow or clip
  /// on purpose, where a fixed frame or a bar is wider than what it was offered by design and so
  /// `measured-within-proposal` and `frame-inside-clip` would flag the demonstration itself.
  private static func rules(for demo: String) -> [CheckRule] {
    ["flex", "frame-padding"].contains(demo)
      ? [.noDirtyAfterPass, .siblingsDisjoint, .requirementsAggregate]
      : CheckRule.allCases
  }

  private func key(_ character: Character) -> InputEvent {
    .key(Key(code: .character(character)))
  }

  @Test(arguments: Self.demos)
  func `a demo renders at each viewport it declares and passes its rules`(demo: String)
    async throws
  {
    let registry = Demos.registry()
    let entry = try registry.entry(named: demo)

    #expect(entry.viewports == [.desktop, .mobile])
    for viewport in entry.viewports {
      try await registry.withHeadlessHost(demo, at: viewport) { host in
        #expect(host.screenRows.contains { !$0.isEmpty }, "\(demo) at \(viewport.name)")
        let violations = Checker.run(Self.rules(for: demo), on: host.projection)
        #expect(
          violations.isEmpty, "\(demo) at \(viewport.name): \(violations.map(\.text))")
      }
    }
  }

  @Test(arguments: Self.demos)
  func `a demo fits the minimum it declares and its mobile height is its natural height`(
    demo: String
  ) async throws {
    let registry = Demos.registry()
    let minimum = try #require(try registry.entry(named: demo).minimum)

    try await registry.withHeadlessHost(demo, at: .mobile) { host in
      #expect(host.size.columns == 40)
      #expect(
        host.size.rows == minimum.rows, "\(demo)'s natural height is its minimum rows")
      #expect(minimum.columns == 40)
    }
  }

  @Test(arguments: Self.demos)
  func `q finishes a demo and a modified q does not`(demo: String) async throws {
    try await Demos.registry().withHeadlessHost(demo, at: .desktop) { host in
      try await host.send(.key(Key(code: .character("q"), modifiers: .control)))
      #expect(!host.isFinished)
      try await host.send(key("q"))
      #expect(host.isFinished)
    }
  }

  @Test(arguments: Self.demos)
  func `a demo's key changes its screen and leaves no node dirty`(demo: String)
    async throws
  {
    let keys: [String: Character] = [
      "flex": "w", "foreach": "r", "frame-padding": "a", "stacks": "s", "text": "n",
      "zstack": "s",
    ]
    try await Demos.registry().withHeadlessHost(demo, at: .desktop) { host in
      let before = host.screenRows
      try await host.send(key(try #require(keys[demo])))
      #expect(host.screenRows != before, "\(demo)")
      #expect(host.projection.nodes.allSatisfy { !$0.needsLayout && !$0.needsRender })
      #expect(host.projection.pass == 1)
    }
  }

  // MARK: What each demo shows

  @Test
  func `text measures wide and clustered content in cells`() async throws {
    try await Demos.registry().withHeadlessHost("text", at: .desktop) { host in
      let wide = host.projection.nodes.first { $0.text == "東京 中文 한글" }
      #expect(wide?.frame == Projection.Box(column: 9, row: 3, columns: 14, rows: 1))
      #expect(host.screenRows[3] == "wide     東京 中文 한글")
      for (sample, columns) in [
        ("wide", 4), ("emoji", 2), ("combining", 1), ("halfwidth", 3),
      ] {
        try await host.send(key("n"))
        let probe = host.projection.nodes.filter { $0.layout == "_FrameLayout" }[6]
        #expect(probe.frame.columns == columns, "\(sample)")
        #expect(probe.frame.rows == 2, "\(sample)")
      }
    }
  }

  @Test
  func `frame and padding report the sizes the catalog gives them`() async throws {
    try await Demos.registry().withHeadlessHost("frame-padding", at: .desktop) { host in
      let projection = host.projection
      let frames = projection.nodes.filter { $0.layout == "_FrameLayout" }.map(\.frame)
      let paddings = projection.nodes.filter { $0.layout == "_PaddingLayout" }.map(
        \.frame)

      #expect(frames[0] == Projection.Box(column: 0, row: 3, columns: 8, rows: 3))
      #expect(frames[1].columns == 6)
      #expect(frames[2].columns == 4)
      #expect(frames[3].columns == 12)
      #expect(paddings.map(\.columns) == [4, 5, 4, 10])
      #expect(paddings.map(\.rows) == [3, 2, 3, 3])
    }
  }

  @Test
  func `the padding keys change the reserved cells from none to three on every edge`()
    async throws
  {
    try await Demos.registry().withHeadlessHost("frame-padding", at: .desktop) { host in
      // `+` and `-` step the uniform padding of the `pad` sample, which starts at one cell and
      // stops at zero and at three: 2n + 2 columns by 2n + 1 rows around `Go`.
      for (pressed, columns, rows) in [
        ("+", 6, 5), ("+", 8, 7), ("+", 8, 7), ("-", 6, 5),
      ] {
        try await host.send(key(Character(pressed)))
        let padding = host.projection.nodes.first { $0.layout == "_PaddingLayout" }
        #expect(padding?.frame.columns == columns, "after \(pressed)")
        #expect(padding?.frame.rows == rows, "after \(pressed)")
      }
      for _ in 0..<5 {
        try await host.send(key("-"))
      }
      let none = host.projection.nodes.first { $0.layout == "_PaddingLayout" }
      #expect(none?.frame == Projection.Box(column: 0, row: 7, columns: 2, rows: 1))
    }
  }

  @Test
  func `a zstack's later layer shows and an empty zstack has no size`() async throws {
    try await Demos.registry().withHeadlessHost("zstack", at: .desktop) { host in
      #expect(host.screenRows[3].hasPrefix("OKatus   Go······   bbAA"))
      let zstacks = host.projection.nodes.filter { $0.type == "ZStack" }
      #expect(zstacks[3].frame == Projection.Box(column: 1, row: 7, columns: 0, rows: 0))
      try await host.send(key("s"))
      #expect(host.screenRows[3].hasSuffix("AAAA"))
      #expect(host.screenRows[9].hasPrefix("alignment topLeading, A on top"))
    }
  }

  @Test
  func `layers a ForEach and an if group build are layers that check does not flag`()
    async throws
  {
    try await Demos.registry().withHeadlessHost("zstack", at: .desktop) { host in
      // The two ForEach items share one frame under the ZStack, and `efcd` is that overlap.
      let list = try #require(host.projection.nodes.first { $0.type == "ForEach" })
      let frames = list.children.compactMap { host.projection.node(at: $0)?.frame }
      #expect(frames.count == 2)
      #expect(frames[0].column == frames[1].column && frames[0].row == frames[1].row)
      #expect(host.screenRows[7].hasSuffix("efcd    base"))
      #expect(Checker.run(CheckRule.allCases, on: host.projection).isEmpty)

      // `g` adds an `if` group of two texts on one frame, over `base`.
      try await host.send(key("g"))
      #expect(host.screenRows[7].hasSuffix("efcd    hase"))
      let group = host.projection.nodes.last { $0.type == "TupleView" }
      #expect(group?.children.count == 2)
      #expect(Checker.run(CheckRule.allCases, on: host.projection).isEmpty)
    }
  }

  @Test
  func `the spacers of the stacks demo share what is left by the rules of the catalog`()
    async throws
  {
    // The vertical Spacer is 0 columns wide. Then one spacer takes 78 cells, two share 77 as 39
    // and 38, `minLength: 20` changes nothing at 80 columns, and the priority spacer takes 77
    // while the unprioritised one gets nothing.
    try await Demos.registry().withHeadlessHost("stacks", at: .desktop) { host in
      let spacers = host.projection.nodes.filter { $0.type == "Spacer" }.map(
        \.frame.columns)
      #expect(spacers == [0, 78, 39, 38, 39, 38, 77, 0])
    }
    // At 40 columns the share would be 19, so the floor of 20 binds and the plain Spacer is
    // left 17.
    try await Demos.registry().withHeadlessHost("stacks", at: .mobile) { host in
      let spacers = host.projection.nodes.filter { $0.type == "Spacer" }.map(
        \.frame.columns)
      #expect(spacers == [0, 38, 19, 18, 20, 17, 37, 0])
    }
  }

  @Test
  func `a spacer in a vstack takes the rows between its neighbours`() async throws {
    try await Demos.registry().withHeadlessHost("stacks", at: .desktop) { host in
      let vertical = host.projection.nodes.first { $0.type == "Spacer" }
      #expect(vertical?.frame == Projection.Box(column: 24, row: 9, columns: 0, rows: 1))
      #expect(host.screenRows[8].hasSuffix("A"))
      #expect(host.screenRows[10].hasSuffix("B"))
    }
  }

  @Test
  func `flex page two shows a priority tier, an unflexed child, and the cross axis`()
    async throws
  {
    try await Demos.registry().withHeadlessHost("flex", at: .desktop) { host in
      try await host.send(key("n"))
      let frames = Dictionary(
        host.projection.nodes.compactMap { node in node.text.map { ($0, node.frame) } }
      ) { first, _ in first }
      #expect(host.screenRows[0] == "Flex: priority, defaults, cross axis")
      // Three equal fills split 75 cells; with a priority tier the third takes them all.
      #expect(frames["E"]?.column == 27)
      #expect(frames["H"]?.column == 2)
      #expect(frames["I"]?.column == 4)
      // No flex value is weight 1 beside a fill(1): 38 cells each, the odd one to the first.
      #expect(frames["K"]?.column == 41)
      // A child smaller than the cross axis sits at the leading edge.
      #expect(frames["•"] == Projection.Box(column: 2, row: 9, columns: 1, rows: 1))
      #expect(frames["◦"]?.column == 0)
      let violations = Checker.run(CheckRule.allCases, on: host.projection)
      #expect(violations.isEmpty, "\(violations.map(\.text))")
      try await host.send(key("n"))
      #expect(host.screenRows[0] == "Flex: constraints")
    }
  }

  @Test
  func `flex gives each constraint the allocation its rule resolves to`() async throws {
    try await Demos.registry().withHeadlessHost("flex", at: .mobile) { host in
      let modifiers = host.projection.nodes.filter { $0.type == "_LayoutValueModifier" }
      // Children's origins after their predecessors' allocations: 4, 30, and 4 around two
      // spacing cells; 9 and 29 for the percentages of the 39 cells after the spacing; 13 and
      // 26; the equal fills 20 and 19; and the min child growing into the space left.
      #expect(
        modifiers.map(\.frame.column).prefix(11) == [
          0, 5, 36, 0, 10, 0, 14, 0, 21, 0, 39,
        ])
    }
  }

  @Test
  func `foreach keeps each item's identity when the order is reversed`() async throws {
    func rows(_ projection: Projection) -> [Int?] {
      ["a", "b", "c"].map { key in
        projection.nodes.first {
          $0.path.hasSuffix("id(\(key))") && $0.type == "TupleView"
        }
        .map(\.frame.row)
      }
    }
    try await Demos.registry().withHeadlessHost("foreach", at: .desktop) { host in
      #expect(rows(host.projection) == [4, 5, 6])
      try await host.send(key("r"))
      #expect(rows(host.projection) == [6, 5, 4])
      let violations = Checker.run([.siblingsDisjoint], on: host.projection)
      #expect(violations.isEmpty)
    }
  }
}
