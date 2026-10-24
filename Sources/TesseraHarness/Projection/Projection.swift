import TesseraCore
import TesseraTerminalCore

/// What a locator, a check, `dump`, and `tree` read: the graph's diagnostics after one
/// completed pass, joined to the screen that pass drew.
///
/// A projection is a value. It holds no view value, closure, or reflected type name, so it
/// serializes as sorted-key JSON and two runs of one scenario project to the same bytes. The
/// runtime returns the facts (`GraphDiagnostics`) and the harness judges them here: locators
/// pick nodes from it, and every invariant is a pure function of it.
///
/// The JSON carries a `version` and is not part of the 1.0 promise: a field may be added,
/// renamed, or removed in any release, and the version says when.
package struct Projection: Encodable, Equatable, Sendable {
  /// A cell rectangle, half-open like `Rect`.
  struct Box: Equatable, Encodable, Sendable {
    var column: Int
    var row: Int
    var columns: Int
    var rows: Int

    var rect: Rect {
      Rect(column: column, row: row, columns: columns, rows: rows)
    }

    var isEmpty: Bool {
      rect.isEmpty
    }

    /// `X,Y,WxH`, the notation `expect node … frame` and `tree` use.
    var text: String {
      "\(column),\(row),\(columns)x\(rows)"
    }

    init(_ rect: Rect) {
      column = rect.origin.column
      row = rect.origin.row
      columns = rect.size.columns
      rows = rect.size.rows
    }

    init(column: Int, row: Int, columns: Int, rows: Int) {
      self.column = column
      self.row = row
      self.columns = columns
      self.rows = rows
    }
  }

  /// A size in cells.
  struct Extent: Equatable, Encodable, Sendable {
    var columns: Int
    var rows: Int
  }

  /// The size a node was offered; a missing axis was unconstrained.
  struct Proposal: Equatable, Encodable, Sendable {
    var width: Int?
    var height: Int?
  }

  /// One node of the view graph.
  struct Node: Equatable, Encodable, Sendable {
    /// The identity path, such as `root/index(2)/id(catalog)`; unique per node.
    var path: String
    var parent: String?
    var children: [String]
    var depth: Int

    /// The zero-based position among the parent's children, which is the order they paint in
    /// (the root is 0).
    var paintOrder: Int

    /// The module-free, generic-free type name: `Text`, `VStack`, `_LayoutContainer`.
    var type: String

    /// For a `_LayoutContainer` (`frame`, `padding`, an app's own `Layout`), the short name of
    /// its algorithm; absent for every other node.
    var layout: String?
    var proposal: Proposal?
    var measured: Extent?
    var frame: Box
    var clip: Box
    var needsLayout: Bool
    var needsRender: Bool
    var environmentOverrides: [String]
    var handlerKinds: [String]
    var requirements: [String]

    /// The screen text attributed to this node, which only a leaf has: the characters of the
    /// cells it owns, where a cell belongs to the last leaf in paint order that covers it, so
    /// text that another node paints over is not its text. Absent when it owns no text.
    var text: String?

    var isLeaf: Bool {
      children.isEmpty
    }
  }

  /// The terminal features the graph asks for.
  struct Requirements: Equatable, Encodable, Sendable {
    var effective: [String]?  // swiftlint:disable:this discouraged_optional_collection
    var requested: [String]
  }

  /// The screen the pass drew.
  struct Screen: Equatable, Encodable, Sendable {
    /// Where the cursor is.
    struct Cursor: Equatable, Encodable, Sendable {
      var column: Int
      var row: Int
    }

    /// A run of non-default style.
    struct StyleRun: Equatable, Encodable, Sendable {
      var row: Int
      var column: Int
      var columns: Int
      var style: String
    }

    var columns: Int
    var cursor: Cursor

    /// The text of each row with trailing spaces removed; a wide grapheme is one character,
    /// so a character index is not always a column.
    var rows: [String]
    var styles: [StyleRun]
  }

  /// The pass counters. Durations are left out: they are not deterministic.
  struct Statistics: Equatable, Encodable, Sendable {
    var bodyEvaluations: Int
    var equatableSkips: Int
    var focusChanges: Int
    var invalidationReasons: [String]
    var leafUpdates: Int
    var measurements: Int
    var nodesCreated: Int
    var nodesDestroyed: Int
    var nodesUpdated: Int
    var placements: Int
    var renderedNodes: Int
    var terminalRequirementChanges: Int
  }

  /// The schema version the JSON carries.
  package static let currentVersion = 1

  var version = Self.currentVersion

  /// The step whose completed pass this projects: 0 is the first frame, and each event the
  /// scenario delivers adds one. A projection is only taken between steps, after the pass has
  /// laid out and drawn, which is why a node that is still dirty is a finding.
  var pass: Int
  var nodes: [Node]
  var requirements: Requirements
  var screen: Screen
  var statistics: Statistics

  /// Memberwise creation, for tests that craft a projection a check should judge.
  init(
    pass: Int, nodes: [Node], requirements: Requirements, screen: Screen,
    statistics: Statistics
  ) {
    self.pass = pass
    self.nodes = nodes
    self.requirements = requirements
    self.screen = screen
    self.statistics = statistics
  }

  /// Projects `diagnostics` and the screen drawn by the same pass.
  init(diagnostics: GraphDiagnostics, screen grid: ScreenGrid, pass: Int) {
    let depths = Self.depths(of: diagnostics.nodes)
    let orders = Self.paintOrders(of: diagnostics.nodes)
    var nodes = diagnostics.nodes.enumerated().map { index, node in
      Node(node, depth: depths[index], paintOrder: orders[index])
    }
    ScreenText(grid: grid).attribute(to: &nodes)
    self.init(
      pass: pass,
      nodes: nodes,
      requirements: Requirements(
        effective: diagnostics.effectiveTerminalRequirements.map(Self.names),
        requested: Self.names(diagnostics.requestedTerminalRequirements)),
      screen: Screen(
        columns: grid.columns,
        cursor: Screen.Cursor(column: grid.cursor.column, row: grid.cursor.row),
        rows: grid.textRows,
        styles: grid.styleRuns.map {
          Screen.StyleRun(
            row: $0.row, column: $0.column, columns: $0.columns, style: $0.style)
        }),
      statistics: Statistics(diagnostics.statistics))
  }

  private static func depths(of nodes: [NodeDiagnostics]) -> [Int] {
    var depths: [String: Int] = [:]
    return nodes.map { node in
      let depth = node.parentIdentity.map { (depths[$0.description] ?? -1) + 1 } ?? 0
      depths[node.identity.description] = depth
      return depth
    }
  }

  /// Each node's position among its parent's children, in node order.
  private static func paintOrders(of nodes: [NodeDiagnostics]) -> [Int] {
    var positions: [String: Int] = [:]
    for node in nodes {
      for (position, child) in node.childIdentities.enumerated() {
        positions[child.description] = position
      }
    }
    return nodes.map { positions[$0.identity.description] ?? 0 }
  }

  /// The names a terminal requirement set spells.
  static func names(_ requirements: TerminalRequirements) -> [String] {
    var names: [String] = []
    if requirements.wantsBracketedPaste {
      names.append("bracketedPaste")
    }
    if requirements.wantsFocusReporting {
      names.append("focus")
    }
    if requirements.wantsKeyboardEnhancement {
      names.append("keyboard")
    }
    if requirements.wantsMouse {
      names.append("mouse")
    }
    return names
  }

  /// The node whose identity path is `path`.
  func node(at path: String) -> Node? {
    nodes.first { $0.path == path }
  }
}

extension Projection.Node {
  init(_ node: NodeDiagnostics, depth: Int, paintOrder: Int) {
    path = node.identity.description
    parent = node.parentIdentity?.description
    children = node.childIdentities.map(\.description)
    self.depth = depth
    self.paintOrder = paintOrder
    type = TypeName.short(node.viewType)
    layout = TypeName.layout(of: node.viewType)
    proposal = node.proposal.map {
      Projection.Proposal(width: $0.width, height: $0.height)
    }
    measured = node.measuredSize.map {
      Projection.Extent(columns: $0.columns, rows: $0.rows)
    }
    frame = Projection.Box(node.frame)
    clip = Projection.Box(node.clip)
    needsLayout = node.needsLayout
    needsRender = node.needsRender
    environmentOverrides = node.environmentOverrides
    handlerKinds = node.handlerKinds
    requirements = Projection.names(node.requestedTerminalRequirements)
    text = nil
  }
}

extension Projection.Statistics {
  init(_ statistics: GraphStatistics) {
    bodyEvaluations = statistics.bodyEvaluations
    equatableSkips = statistics.equatableSkips
    focusChanges = statistics.focusChanges
    invalidationReasons = statistics.invalidationReasons.values.map(\.rawValue)
    leafUpdates = statistics.leafUpdates
    measurements = statistics.measurements
    nodesCreated = statistics.nodesCreated
    nodesDestroyed = statistics.nodesDestroyed
    nodesUpdated = statistics.nodesUpdated
    placements = statistics.placements
    renderedNodes = statistics.renderedNodes
    terminalRequirementChanges = statistics.terminalRequirementChanges
  }
}

/// Attributes the screen's text to the leaf nodes that painted it.
///
/// `GraphDiagnostics` holds no view values, so a node's text can only come from the screen.
/// Leaves paint in node order (a pre-order walk, the order `ViewGraph.render` visits them), so
/// the last leaf whose clip covers a cell is the one whose content shows there. A leaf's text
/// is the characters of the cells it owns, with the cells a later leaf owns blanked, so text
/// that is drawn over does not match a locator. The model is geometric: a leaf is assumed to
/// paint every cell of its clip, and a leaf that covers cells without painting them (a
/// `Spacer` that has an extent) still takes them from earlier leaves.
private struct ScreenText {
  let grid: ScreenGrid

  func attribute(to nodes: inout [Projection.Node]) {
    let screen = Rect(column: 0, row: 0, columns: grid.columns, rows: grid.rows.count)
    var owner = Array(
      repeating: Array(repeating: -1, count: grid.columns), count: grid.rows.count)
    var regions: [Int: Rect] = [:]
    for (index, node) in nodes.enumerated() where node.isLeaf {
      guard let region = node.clip.rect.intersection(screen) else {
        continue
      }
      regions[index] = region
      for row in region.rowRange {
        for column in region.columnRange {
          owner[row][column] = index
        }
      }
    }

    for (index, region) in regions {
      var lines: [String] = []
      for row in region.rowRange {
        var line = ""
        for column in region.columnRange where grid.rows[row].indices.contains(column) {
          let gridCell = grid.rows[row][column]
          guard !gridCell.isContinuation else {
            continue
          }
          line.append(owner[row][column] == index ? gridCell.cell.character : " ")
        }
        while line.last == " " {
          line.removeLast()
        }
        lines.append(line)
      }
      while lines.last?.isEmpty == true {
        lines.removeLast()
      }
      while lines.first?.isEmpty == true {
        lines.removeFirst()
      }
      nodes[index].text = lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
  }
}
