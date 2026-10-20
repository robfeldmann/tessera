/// The one-object-per-command JSON replies of `graphquery`, as sorted-key JSON values.
///
/// Every reply has an `ok` boolean; `ok:false` accompanies exit code 1 (a well-formed
/// request that found nothing or found violations) or 2 (a malformed request).
public enum Report {
  /// The reply to a locator query.
  public static func query(_ locator: Locator, in projection: Projection) throws -> JSONValue {
    let resolution = locator.resolve(in: projection)
    let steps = try JSONValue(encoding: resolution.steps)
    guard !resolution.nodes.isEmpty else {
      let types = Set(projection.nodes.map(\.type)).sorted()
      return .object([
        "count": .int(0),
        "error": .string("no node matches"),
        "locator": .string(locator.description),
        "ok": .bool(false),
        "steps": steps,
        "typesPresent": .array(types.map(JSONValue.string)),
      ])
    }
    let usesText = locator.clauses.contains {
      switch $0 {
      case .text, .textExact: true
      default: false
      }
    }
    let ambiguous = usesText && resolution.nodes.contains { $0.textOverlaps != nil }
    return .object([
      "ambiguous": .bool(ambiguous),
      "count": .int(resolution.nodes.count),
      "locator": .string(locator.description),
      "nodes": try JSONValue(encoding: resolution.nodes),
      "ok": .bool(true),
      "steps": steps,
    ])
  }

  /// The reply to `check`; `ok` is false when any rule produced a violation.
  public static func check(
    _ projection: Projection,
    rules: [Rule],
    options: CheckOptions = CheckOptions()
  ) throws -> JSONValue {
    let violations = GraphQuery.check(projection, rules: rules, options: options)
    return .object([
      "ok": .bool(violations.isEmpty),
      "rules": .array(rules.map { .string($0.rawValue) }),
      "violations": try JSONValue(encoding: violations),
    ])
  }

  /// The reply to `diff`; always `ok:true` when both inputs decoded.
  public static func diff(_ before: Projection, _ after: Projection) throws -> JSONValue {
    var value = try JSONValue(encoding: ProjectionDiff(before: before, after: after))
    guard case .object(var object) = value else {
      return value
    }
    object["ok"] = .bool(true)
    value = .object(object)
    return value
  }

  /// A malformed-request reply.
  public static func failure(_ message: String) -> JSONValue {
    .object(["error": .string(message), "ok": .bool(false)])
  }
}
