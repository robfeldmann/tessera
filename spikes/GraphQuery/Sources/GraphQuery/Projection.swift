import Foundation
import Tessera
import TesseraTerminalSnapshotSupport

/// A value-only, sorted-key-JSON projection of one completed graph pass plus its screen.
///
/// Everything a locator, diff, or invariant needs is in this value, so all three are pure
/// functions of projections and work on files without a live graph.
public struct Projection: Codable, Equatable, Sendable {
  /// Bump when a field is removed or changes meaning.
  public static let currentVersion = 1

  public var nodes: [Node]
  public var requirements: Requirements
  public var screen: Screen
  public var statistics: Statistics
  public var version: Int

  public init(
    nodes: [Node],
    requirements: Requirements,
    screen: Screen,
    statistics: Statistics,
    version: Int = Projection.currentVersion
  ) {
    self.nodes = nodes
    self.requirements = requirements
    self.screen = screen
    self.statistics = statistics
    self.version = version
  }

  /// Projects `diagnostics` and the screen drawn by the same pass.
  public init(diagnostics: GraphDiagnostics, screen: ScreenSnapshot) {
    let grid = CellGrid(screen)
    var nodes = diagnostics.nodes.map { Node($0, depth: 0) }
    let depths = Self.depths(of: diagnostics.nodes)
    for index in nodes.indices {
      nodes[index].depth = depths[index]
    }
    TextAttribution(grid: grid, nodes: nodes).apply(to: &nodes)
    self.init(
      nodes: nodes,
      requirements: Requirements(
        effective: diagnostics.effectiveTerminalRequirements.map(Self.names),
        requested: Self.names(diagnostics.requestedTerminalRequirements)
      ),
      screen: Screen(
        columns: grid.columns,
        cursor: Box.Point(
          column: screen.cursor.column,
          row: screen.cursor.row
        ),
        rows: grid.rowStrings
      ),
      statistics: Statistics(diagnostics.statistics)
    )
  }

  private static func depths(of nodes: [NodeDiagnostics]) -> [Int] {
    var byPath: [String: Int] = [:]
    return nodes.map { node in
      let depth = node.parentIdentity.map { (byPath[$0.description] ?? -1) + 1 } ?? 0
      byPath[node.identity.description] = depth
      return depth
    }
  }

  private static func names(_ requirements: TerminalRequirements) -> [String] {
    var names: [String] = []
    if requirements.wantsBracketedPaste { names.append("bracketedPaste") }
    if requirements.wantsFocusReporting { names.append("focus") }
    if requirements.wantsKeyboardEnhancement { names.append("keyboard") }
    if requirements.wantsMouse { names.append("mouse") }
    return names
  }
}

// MARK: - Geometry

extension Projection {
  /// A half-open cell rectangle, mirroring `Rect` without depending on its module.
  public struct Box: Codable, Equatable, Sendable {
    public struct Point: Codable, Equatable, Sendable {
      public var column: Int
      public var row: Int

      public init(column: Int, row: Int) {
        self.column = column
        self.row = row
      }
    }

    public var column: Int
    public var columns: Int
    public var row: Int
    public var rows: Int

    public var isEmpty: Bool { columns <= 0 || rows <= 0 }
    public var maxColumn: Int { column + max(columns, 0) }
    public var maxRow: Int { row + max(rows, 0) }

    public init(column: Int, row: Int, columns: Int, rows: Int) {
      self.column = column
      self.row = row
      self.columns = columns
      self.rows = rows
    }

    init(_ rect: Rect) {
      self.init(
        column: rect.origin.column,
        row: rect.origin.row,
        columns: rect.size.columns,
        rows: rect.size.rows
      )
    }

    public func intersection(_ other: Box) -> Box? {
      guard !isEmpty, !other.isEmpty else {
        return nil
      }
      let column = max(self.column, other.column)
      let row = max(self.row, other.row)
      let maxColumn = min(self.maxColumn, other.maxColumn)
      let maxRow = min(self.maxRow, other.maxRow)
      guard column < maxColumn, row < maxRow else {
        return nil
      }
      return Box(column: column, row: row, columns: maxColumn - column, rows: maxRow - row)
    }

    public func contains(_ other: Box) -> Bool {
      other.isEmpty
        || (column <= other.column && row <= other.row && maxColumn >= other.maxColumn
          && maxRow >= other.maxRow)
    }

    /// `x,y WxH`, the notation used by scenario `expect node … frame`.
    public var description: String {
      "\(column),\(row) \(columns)x\(rows)"
    }
  }

  /// A width and height in cells.
  public struct Extent: Codable, Equatable, Sendable {
    public var columns: Int
    public var rows: Int

    public init(columns: Int, rows: Int) {
      self.columns = columns
      self.rows = rows
    }
  }

  /// The size offered to a node; a missing axis was unconstrained.
  public struct Proposal: Codable, Equatable, Sendable {
    public var height: Int?
    public var width: Int?

    public init(height: Int?, width: Int?) {
      self.height = height
      self.width = width
    }
  }
}

// MARK: - Node

extension Projection {
  /// One runtime node as exposed by `NodeDiagnostics`, plus attributed screen text.
  public struct Node: Codable, Equatable, Sendable {
    public var children: [String]
    public var clip: Box
    public var depth: Int
    public var environmentOverrides: [String]
    public var frame: Box
    public var handlerKinds: [String]
    /// For a `_LayoutContainer<Algorithm, …>` (custom `Layout`, `.frame`, `.padding`), the
    /// concise name of `Algorithm`; `nil` for every other node.
    public var layout: String?
    public var measured: Extent?
    public var needsLayout: Bool
    public var needsRender: Bool
    public var parent: String?
    /// Identity path, for example `root/body/index(0)`; unique per node.
    public var path: String
    public var proposal: Proposal?
    public var requirements: [String]
    /// Screen text attributed to this leaf (see `TextAttribution`); `nil` when none.
    public var text: String?
    /// Other leaves whose clip covers a visible cell of this leaf's clip.
    public var textOverlaps: [String]?
    /// Module-free, generic-free type name, for example `Text` or `VStack`.
    public var type: String
    /// The full reflected type name with unstable local-context addresses redacted.
    public var typeName: String

    public var isLeaf: Bool { children.isEmpty }

    init(_ node: NodeDiagnostics, depth: Int) {
      children = node.childIdentities.map(\.description)
      clip = Box(node.clip)
      self.depth = depth
      environmentOverrides = node.environmentOverrides
      frame = Box(node.frame)
      handlerKinds = node.handlerKinds
      layout = TypeName.layoutAlgorithm(of: TypeName.redacted(node.viewType))
      measured = node.measuredSize.map { Extent(columns: $0.columns, rows: $0.rows) }
      needsLayout = node.needsLayout
      needsRender = node.needsRender
      parent = node.parentIdentity?.description
      path = node.identity.description
      proposal = node.proposal.map { Proposal(height: $0.height, width: $0.width) }
      requirements = []
      let requested = node.requestedTerminalRequirements
      if requested.wantsBracketedPaste { requirements.append("bracketedPaste") }
      if requested.wantsFocusReporting { requirements.append("focus") }
      if requested.wantsKeyboardEnhancement { requirements.append("keyboard") }
      if requested.wantsMouse { requirements.append("mouse") }
      type = TypeName.concise(node.viewType)
      typeName = TypeName.redacted(node.viewType)
    }
  }
}

// MARK: - Screen, statistics, requirements

extension Projection {
  /// Terminal features requested by the graph and, when known, granted by the session.
  public struct Requirements: Codable, Equatable, Sendable {
    public var effective: [String]?
    public var requested: [String]
  }

  /// The visible grid as text.
  public struct Screen: Codable, Equatable, Sendable {
    public var columns: Int
    public var cursor: Box.Point
    /// One string per row; the blank spacer cell after a wide grapheme is elided, so a
    /// string index is not a column.
    public var rows: [String]
  }

  /// Pass counters from `GraphStatistics`; durations are excluded because they are not
  /// deterministic.
  public struct Statistics: Codable, Equatable, Sendable {
    public var bodyEvaluations: Int
    public var equatableSkips: Int
    public var focusChanges: Int
    public var invalidationReasons: [String]
    public var leafUpdates: Int
    public var measurements: Int
    public var nodesCreated: Int
    public var nodesDestroyed: Int
    public var nodesUpdated: Int
    public var placements: Int
    public var renderedNodes: Int
    public var terminalRequirementChanges: Int

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
}

// MARK: - Type names

enum TypeName {
  /// `TesseraLayout.VStack<TesseraCore.TupleView<…>>` becomes `VStack`.
  static func concise(_ reflected: String) -> String {
    let base = redacted(reflected).prefix { $0 != "<" }
    let name = base.split(separator: ".").last.map(String.init) ?? String(base)
    return name
  }

  /// Replaces `(unknown context at $…)`, whose address changes per build, with `(local)`.
  static func redacted(_ reflected: String) -> String {
    var result = ""
    var rest = Substring(reflected)
    let marker = "(unknown context at $"
    while let range = rest.range(of: marker) {
      result += rest[..<range.lowerBound]
      result += "(local)"
      let tail = rest[range.upperBound...]
      guard let close = tail.firstIndex(of: ")") else {
        return result
      }
      rest = tail[tail.index(after: close)...]
    }
    result += rest
    return result
  }
}
