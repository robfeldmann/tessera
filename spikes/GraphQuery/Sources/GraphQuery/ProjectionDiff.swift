/// A field-level difference between two projections, keyed by node identity path.
public struct ProjectionDiff: Codable, Equatable, Sendable {
  public struct Change: Codable, Equatable, Sendable {
    public var after: JSONValue
    public var before: JSONValue
  }

  public struct NodeChange: Codable, Equatable, Sendable {
    public var fields: [String: Change]
    public var path: String
    public var type: String
  }

  public struct NodeSummary: Codable, Equatable, Sendable {
    public var frame: Projection.Box
    public var path: String
    public var type: String
  }

  public struct RowChange: Codable, Equatable, Sendable {
    public var after: String?
    public var before: String?
    public var row: Int
  }

  public struct ScreenChange: Codable, Equatable, Sendable {
    public var cursor: Change?
    public var rows: [RowChange]
    public var size: Change?
  }

  public var added: [NodeSummary]
  public var changed: [NodeChange]
  public var identical: Bool
  public var removed: [NodeSummary]
  public var requirements: [String: Change]
  public var screen: ScreenChange
  public var statistics: [String: Change]

  /// Compares `before` with `after`.
  public init(before: Projection, after: Projection) throws {
    let beforeByPath = Dictionary(before.nodes.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    let afterByPath = Dictionary(after.nodes.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })

    removed = before.nodes.filter { afterByPath[$0.path] == nil }.map(NodeSummary.init)
    added = after.nodes.filter { beforeByPath[$0.path] == nil }.map(NodeSummary.init)
    changed = try after.nodes.compactMap { node in
      guard let old = beforeByPath[node.path], old != node else {
        return nil
      }
      let fields = Self.changes(from: try JSONValue(encoding: old), to: try JSONValue(encoding: node))
      return NodeChange(fields: fields, path: node.path, type: node.type)
    }
    statistics = Self.changes(
      from: try JSONValue(encoding: before.statistics),
      to: try JSONValue(encoding: after.statistics)
    )
    requirements = Self.changes(
      from: try JSONValue(encoding: before.requirements),
      to: try JSONValue(encoding: after.requirements)
    )

    let rowCount = max(before.screen.rows.count, after.screen.rows.count)
    let rowChanges = (0..<rowCount).compactMap { row -> RowChange? in
      let old = before.screen.rows.indices.contains(row) ? before.screen.rows[row] : nil
      let new = after.screen.rows.indices.contains(row) ? after.screen.rows[row] : nil
      return old == new ? nil : RowChange(after: new, before: old, row: row)
    }
    let oldSize = Projection.Extent(columns: before.screen.columns, rows: before.screen.rows.count)
    let newSize = Projection.Extent(columns: after.screen.columns, rows: after.screen.rows.count)
    screen = ScreenChange(
      cursor: before.screen.cursor == after.screen.cursor
        ? nil
        : Change(
          after: try JSONValue(encoding: after.screen.cursor),
          before: try JSONValue(encoding: before.screen.cursor)
        ),
      rows: rowChanges,
      size: oldSize == newSize
        ? nil
        : Change(
          after: try JSONValue(encoding: newSize),
          before: try JSONValue(encoding: oldSize)
        )
    )
    identical =
      added.isEmpty && removed.isEmpty && changed.isEmpty && statistics.isEmpty
      && requirements.isEmpty && rowChanges.isEmpty && screen.cursor == nil
      && screen.size == nil
  }

  /// Keys whose values differ between two JSON objects; nested objects compare whole.
  static func changes(from before: JSONValue, to after: JSONValue) -> [String: Change] {
    guard case .object(let old) = before, case .object(let new) = after else {
      return [:]
    }
    var result: [String: Change] = [:]
    for key in Set(old.keys).union(new.keys) where old[key] != new[key] {
      result[key] = Change(after: new[key] ?? .null, before: old[key] ?? .null)
    }
    return result
  }
}

extension ProjectionDiff.NodeSummary {
  init(_ node: Projection.Node) {
    self.init(frame: node.frame, path: node.path, type: node.type)
  }
}
