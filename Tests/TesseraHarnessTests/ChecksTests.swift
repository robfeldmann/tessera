import Testing

@testable import TesseraHarness

struct ChecksTests {
  private typealias Rect4 = (column: Int, row: Int, columns: Int, rows: Int)

  private func box(_ rect: Rect4) -> Projection.Box {
    Projection.Box(
      column: rect.column, row: rect.row, columns: rect.columns, rows: rect.rows)
  }

  private func node(
    _ path: String,
    parent: String? = nil,
    children: [String] = [],
    type: String = "Text",
    layout: String? = nil,
    frame: Rect4,
    clip: Rect4? = nil,
    proposal: (width: Int?, height: Int?)? = nil,
    measured: (columns: Int, rows: Int)? = nil,
    dirty: (layout: Bool, render: Bool) = (false, false),
    requirements: [String] = [],
    text: String? = nil
  ) -> Projection.Node {
    Projection.Node(
      path: path, parent: parent, children: children, depth: 0, paintOrder: 0, type: type,
      layout: layout,
      proposal: proposal.map { Projection.Proposal(width: $0.width, height: $0.height) },
      measured: measured.map { Projection.Extent(columns: $0.columns, rows: $0.rows) },
      frame: box(frame), clip: box(clip ?? frame), needsLayout: dirty.layout,
      needsRender: dirty.render, environmentOverrides: [], handlerKinds: [],
      requirements: requirements, text: text)
  }

  private func projection(
    _ nodes: [Projection.Node], requested: [String] = [], pass: Int = 3
  ) -> Projection {
    Projection(
      pass: pass, nodes: nodes,
      requirements: Projection.Requirements(effective: nil, requested: requested),
      screen: Projection.Screen(
        columns: 10, cursor: Projection.Screen.Cursor(column: 0, row: 0), rows: [],
        styles: []),
      statistics: Projection.Statistics(
        bodyEvaluations: 0, equatableSkips: 0, focusChanges: 0, invalidationReasons: [],
        leafUpdates: 0, measurements: 0, nodesCreated: 0, nodesDestroyed: 0,
        nodesUpdated: 0,
        placements: 0, renderedNodes: 0, terminalRequirementChanges: 0))
  }

  private func run(_ rule: CheckRule, _ projection: Projection) -> [Violation] {
    Checker.run([rule], on: projection)
  }

  // MARK: no-dirty-after-pass

  @Test
  func
    `a node still dirty after the pass is a violation that names the pass and the flags`()
  {
    let found = run(
      .noDirtyAfterPass,
      projection([
        node("root", children: ["root/a"], type: "VStack", frame: (0, 0, 4, 1)),
        node(
          "root/a", parent: "root", frame: (0, 0, 4, 1),
          dirty: (layout: true, render: true)),
      ]))

    #expect(
      found == [
        Violation(
          rule: "no-dirty-after-pass", severity: "error", node: "root/a",
          detail: "still dirty after pass 3: needsLayout, needsRender")
      ])
  }

  @Test
  func `a clean graph has no dirty node`() {
    #expect(
      run(.noDirtyAfterPass, projection([node("root", frame: (0, 0, 4, 1))])).isEmpty)
  }

  // MARK: frame-inside-clip

  @Test
  func `a leaf whose frame reaches past its clip is a warning that quotes what shows`() {
    let found = run(
      .frameInsideClip,
      projection([
        node("root", frame: (0, 0, 10, 1), clip: (0, 0, 4, 1), text: "Hello, world")
      ]))

    #expect(found.map(\.severity) == ["warning"])
    #expect(found.map(\.node) == ["root"])
    #expect(
      found.map(\.detail) == [
        "frame 0,0,10x1 is clipped to 0,0,4x1 (visible text `Hello, world`)"
      ])
  }

  @Test
  func `a clip that leaves nothing of the frame says so`() {
    let found = run(
      .frameInsideClip,
      projection([node("root", frame: (5, 0, 3, 1), clip: (0, 0, 4, 1))]))

    #expect(found.map(\.detail) == ["frame 5,0,3x1 is clipped to nothing"])
  }

  @Test
  func `containers, empty frames, and scrolled leaves are not clipped content`() {
    let found = run(
      .frameInsideClip,
      projection([
        node(
          "root", children: ["root/box", "root/scroll"], type: "VStack",
          frame: (0, 0, 10, 4), clip: (0, 0, 2, 2)),
        node("root/box", parent: "root", frame: (0, 0, 0, 0), clip: (0, 0, 0, 0)),
        node(
          "root/scroll", parent: "root", children: ["root/scroll/text"],
          type: "ScrollView",
          frame: (0, 0, 10, 2)),
        node(
          "root/scroll/text", parent: "root/scroll", frame: (0, 0, 10, 30),
          clip: (0, 0, 10, 2)),
      ]))

    #expect(found.isEmpty)
  }

  // MARK: measured-within-proposal

  @Test
  func `a node that measured more than it was offered names each axis it overflowed`() {
    let found = run(
      .measuredWithinProposal,
      projection([
        node(
          "root", frame: (0, 0, 12, 3), proposal: (width: 4, height: 1),
          measured: (columns: 12, rows: 3))
      ]))

    #expect(
      found.map(\.detail) == [
        "measured 12 columns where 4 were offered and 3 rows where 1 were offered"
      ])
    #expect(found.map(\.severity) == ["error"])
  }

  @Test
  func `an axis nobody constrained cannot be overflowed`() {
    let found = run(
      .measuredWithinProposal,
      projection([
        node(
          "root", frame: (0, 0, 80, 40), proposal: (width: nil, height: nil),
          measured: (columns: 80, rows: 40)),
        node(
          "root/b", frame: (0, 0, 80, 1), proposal: (width: 80, height: nil),
          measured: (columns: 80, rows: 1)),
      ]))

    #expect(found.isEmpty)
  }

  @Test
  func `a node that was never placed keeps a stale measurement and is skipped`() {
    let found = run(
      .measuredWithinProposal,
      projection([
        node(
          "root", frame: (0, 0, 0, 0), proposal: (width: 0, height: 0),
          measured: (columns: 7, rows: 1))
      ]))

    #expect(found.isEmpty)
  }

  // MARK: siblings-disjoint

  @Test
  func `two children placed on one frame are a violation on the later one`() {
    let found = run(
      .siblingsDisjoint,
      projection([
        node(
          "root", children: ["root/id(a)", "root/id(b)"], type: "VStack",
          frame: (0, 0, 4, 2)),
        node("root/id(a)", parent: "root", frame: (0, 0, 4, 1)),
        node("root/id(b)", parent: "root", frame: (0, 0, 4, 1)),
      ]))

    #expect(
      found == [
        Violation(
          rule: "siblings-disjoint", severity: "error", node: "root/id(b)",
          detail:
            "shows 0,0,4x1, which overlaps sibling root/id(a) showing 0,0,4x1 under VStack"
        )
      ])
  }

  @Test
  func `a ZStack lays its children over one another by contract`() {
    let found = run(
      .siblingsDisjoint,
      projection([
        node(
          "root", children: ["root/a", "root/b"], type: "ZStack", frame: (0, 0, 6, 1)),
        node("root/a", parent: "root", frame: (0, 0, 6, 1)),
        node("root/b", parent: "root", frame: (0, 0, 2, 1)),
      ]))

    #expect(found.isEmpty)
  }

  @Test
  func `a custom layout is held to disjoint children under its own name`() {
    let found = run(
      .siblingsDisjoint,
      projection([
        node(
          "root", children: ["root/a", "root/b"], type: "_LayoutContainer",
          layout: "Stagger",
          frame: (0, 0, 6, 2)),
        node("root/a", parent: "root", frame: (0, 0, 4, 1)),
        node("root/b", parent: "root", frame: (2, 0, 4, 1)),
      ]))

    #expect(found.map(\.node) == ["root/b"])
    #expect(found.map(\.detail).first?.hasSuffix("under Stagger") == true)
  }

  @Test
  func `children that overflow their segments but are clipped to them do not overlap`() {
    let found = run(
      .siblingsDisjoint,
      projection([
        node("root", children: ["root/a", "root/b"], type: "Flex", frame: (0, 0, 10, 1)),
        node("root/a", parent: "root", frame: (0, 0, 80, 1), clip: (0, 0, 4, 1)),
        node("root/b", parent: "root", frame: (5, 0, 80, 1), clip: (5, 0, 5, 1)),
      ]))

    #expect(found.isEmpty)
  }

  @Test
  func `a child that shows nothing overlaps nothing`() {
    let found = run(
      .siblingsDisjoint,
      projection([
        node(
          "root", children: ["root/a", "root/b"], type: "HStack", frame: (0, 0, 4, 1)),
        node("root/a", parent: "root", frame: (0, 0, 4, 1)),
        node(
          "root/b", parent: "root", type: "Spacer", frame: (2, 0, 2, 0),
          clip: (2, 0, 0, 0)),
      ]))

    #expect(found.isEmpty)
  }

  // MARK: requirements-aggregate

  @Test
  func `a requirement a node asks for and the graph does not request is a violation`() {
    let found = run(
      .requirementsAggregate,
      projection(
        [
          node("root", children: ["root/a"], type: "VStack", frame: (0, 0, 4, 1)),
          node("root/a", parent: "root", frame: (0, 0, 4, 1), requirements: ["mouse"]),
        ], requested: []))

    #expect(
      found == [
        Violation(
          rule: "requirements-aggregate", severity: "error", node: "root/a",
          detail: "asks for `mouse`, which the graph does not request")
      ])
  }

  @Test
  func
    `a requirement the graph requests and no node asks for is a violation at the root`()
  {
    let found = run(
      .requirementsAggregate,
      projection([node("root", frame: (0, 0, 4, 1))], requested: ["focus"]))

    #expect(found.map(\.node) == ["root"])
    #expect(found.map(\.detail) == ["the graph requests `focus` and no node asks for it"])
  }

  @Test
  func `requirements that roll up are consistent`() {
    let found = run(
      .requirementsAggregate,
      projection(
        [
          node("root", children: ["root/a"], type: "VStack", frame: (0, 0, 4, 1)),
          node(
            "root/a", parent: "root", frame: (0, 0, 4, 1),
            requirements: ["keyboard", "mouse"]),
        ], requested: ["keyboard", "mouse"]))

    #expect(found.isEmpty)
  }

  // MARK: The runner

  @Test
  func `rules run in the order given and each violation carries its rule's severity`() {
    let crafted = projection([
      node(
        "root", children: ["root/a", "root/b"], type: "VStack", frame: (0, 0, 4, 2),
        dirty: (layout: true, render: false)),
      node("root/a", parent: "root", frame: (0, 0, 4, 1), clip: (0, 0, 2, 1)),
      node("root/b", parent: "root", frame: (0, 0, 4, 1)),
    ])

    let forward = Checker.run(
      [.noDirtyAfterPass, .frameInsideClip, .siblingsDisjoint], on: crafted)
    let backward = Checker.run(
      [.siblingsDisjoint, .frameInsideClip, .noDirtyAfterPass], on: crafted)

    #expect(
      forward.map(\.rule) == [
        "no-dirty-after-pass", "frame-inside-clip", "siblings-disjoint",
      ])
    #expect(
      backward.map(\.rule) == [
        "siblings-disjoint", "frame-inside-clip", "no-dirty-after-pass",
      ])
    #expect(forward.map(\.severity) == ["error", "warning", "error"])
    #expect(Checker.run([], on: crafted).isEmpty)
  }

  @Test
  func `the rule ids are the five the catalog names, in the order bare check runs them`()
  {
    #expect(
      CheckRule.allCases.map(\.rawValue) == [
        "no-dirty-after-pass", "frame-inside-clip", "measured-within-proposal",
        "siblings-disjoint", "requirements-aggregate",
      ])
    #expect(
      CheckRule.accepted
        == "no-dirty-after-pass, frame-inside-clip, measured-within-proposal, "
        + "siblings-disjoint, requirements-aggregate")
    #expect(CheckRule.allCases.filter { $0.severity == .warning } == [.frameInsideClip])
  }
}
