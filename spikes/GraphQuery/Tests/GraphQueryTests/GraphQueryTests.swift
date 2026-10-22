import Foundation
import GraphQuery
import Tessera
import TesseraTerminalSnapshotSupport
import Testing

private func project(_ demo: Demo, size: TerminalSize? = nil) -> Projection {
  demo.makeSession(size ?? demo.defaultSize).capture()
}

private func resolve(_ locator: String, in projection: Projection) throws -> [Projection.Node] {
  try Locator(parsing: locator).resolve(in: projection).nodes
}

private final class Model {
  var title = "Hello"
  var showsDetail = false
}

// MARK: - Locators

@Suite
struct LocatorTests {
  @Test
  func `text locator returns exactly one node with its frame`() throws {
    let projection = project(.hello)

    let nodes = try resolve(#"text="Hello""#, in: projection)

    #expect(nodes.count == 1)
    let node = try #require(nodes.first)
    #expect(node.type == "Text")
    #expect(node.path == "root/index(0)")
    #expect(node.frame == Projection.Box(column: 0, row: 0, columns: 5, rows: 1))
  }

  @Test
  func `text locator matches a substring and text-exact matches the whole text`() throws {
    let session = GraphSession(size: TerminalSize(columns: 20, rows: 3)) {
      VStack(alignment: .leading) {
        Text("Hello")
        Text("Hello, World")
      }
    }
    let projection = session.capture()

    #expect(try resolve("text=Hello", in: projection).count == 2)
    #expect(try resolve("text-exact=Hello", in: projection).map(\.path) == ["root/index(0)"])
    #expect(try resolve("text=Hello nth=1", in: projection).map(\.path) == ["root/index(1)"])
  }

  @Test
  func `type and nth compose and nth is zero based in tree order`() throws {
    let projection = project(.hello)

    #expect(try resolve("type=Text", in: projection).count == 4)
    let second = try resolve("type=Text nth=1", in: projection)
    #expect(second.map(\.text) == ["Left"])
    #expect(try resolve("type=Text nth=9", in: projection).isEmpty)
    #expect(try resolve("type=Text text=Right", in: projection).map(\.path) == ["root/index(1)/index(2)"])
  }

  @Test
  func `type matches module-free, qualified, and full reflected names`() throws {
    let projection = project(.hello)

    let bare = try resolve("type=VStack", in: projection)
    #expect(bare.map(\.path) == ["root"])
    #expect(try resolve("type=TesseraLayout.VStack", in: projection).map(\.path) == ["root"])
    let full = try #require(bare.first?.typeName)
    #expect(try resolve("type=\"\(full)\"", in: projection).map(\.path) == ["root"])
  }

  @Test
  func `type matches the layout of a layout container such as a frame modifier`() throws {
    let projection = project(.clipped)

    let frames = try resolve("type=_FrameLayout", in: projection)
    #expect(frames.map(\.path) == ["root/index(0)"])
    #expect(frames.first?.type == "_LayoutContainer")
    #expect(frames.first?.layout == "_FrameLayout")
  }

  @Test
  func `id matches identity paths and user identities`() throws {
    let projection = project(.ids)

    let submit = try resolve("id=submit", in: projection)
    #expect(submit.map(\.text) == ["Submit"])
    let path = try #require(submit.first?.path)
    #expect(path == "root/index(0)/explicit(submit)")
    #expect(try resolve("id=\(path)", in: projection).map(\.text) == ["Submit"])
    #expect(try resolve("id=cancel", in: projection).map(\.text) == ["Cancel"])
    #expect(try resolve("id=missing", in: projection).isEmpty)
    #expect(check(projection).isEmpty)
  }

  @Test
  func `id matches keyed ForEach elements and a hidden element has no text`() throws {
    let projection = project(.nestedForEach)

    #expect(try resolve("id=b type=TupleView", in: projection).count == 1)
    #expect(try resolve("id=b type=Text", in: projection).isEmpty)
    #expect(try resolve("text=item", in: projection).map(\.path) == ["root/index(1)/id(b)/index(0)"])
  }

  @Test
  func `a keyed ForEach nested in a stack overlays its items and check says so`() {
    let violations = check(project(.nestedForEach), rules: [.siblingsDisjoint])

    #expect(violations.map(\.node) == ["root/index(1)/id(b)"])
    #expect(violations.first?.related == ["root/index(1)/id(a)"])
  }

  @Test
  func `malformed locators are rejected with the accepted keys`() {
    #expect(throws: LocatorError.unknownKey("color")) { try Locator(parsing: "color=red") }
    #expect(throws: LocatorError.invalidNth("-1")) { try Locator(parsing: "nth=-1") }
    #expect(throws: LocatorError.malformed("Text")) { try Locator(parsing: "Text") }
    #expect(throws: LocatorError.unterminatedQuote(#"text="oops"#)) {
      try Locator(parsing: #"text="oops"#)
    }
    #expect(throws: LocatorError.empty) { try Locator(clauseTexts: []) }
  }

  @Test
  func `argv clauses keep spaces inside unquoted values`() throws {
    let locator = try Locator(clauseTexts: ["type=Text", "text=Hello, World"])

    #expect(locator.clauses == [.type("Text"), .text("Hello, World")])
  }

  @Test
  func `no match replies ok false with per-clause counts and the types present`() throws {
    let projection = project(.hello)

    let reply = try Report.query(Locator(parsing: #"type=Text text="Nope""#), in: projection)

    #expect(reply["ok"] == .bool(false))
    #expect(reply["count"] == .int(0))
    #expect(
      reply["steps"]
        == .array([
          .object(["clause": .string("type=Text"), "remaining": .int(4)]),
          .object(["clause": .string("text=Nope"), "remaining": .int(0)]),
        ])
    )
    #expect(
      reply["typesPresent"]
        == .array(["HStack", "Spacer", "Text", "VStack"].map(JSONValue.string))
    )
  }
}

// MARK: - Text attribution

@Suite
struct TextAttributionTests {
  @Test
  func `wide graphemes attribute without their spacer cells`() throws {
    let projection = project(.wide)

    #expect(try resolve("text=日本語", in: projection).count == 1)
    #expect(try resolve(#"text-exact="日本語 ok""#, in: projection).count == 1)
    #expect(try resolve(#"text="👍 done""#, in: projection).count == 1)
    #expect(projection.screen.rows[0].hasPrefix("日本語 ok"))
  }

  @Test
  func `an overlapped leaf owns only its visible cells and reports its overlaps`() throws {
    let projection = project(.overlap)

    #expect(try resolve("text=AAAAAA", in: projection).isEmpty)
    let visible = try resolve("text=AAA", in: projection)
    #expect(visible.map(\.path) == ["root/index(0)/index(0)"])
    #expect(visible.first?.textOverlaps == ["root/index(0)/index(1)"])
    let reply = try Report.query(Locator(parsing: "text=AAA"), in: projection)
    #expect(reply["ambiguous"] == .bool(true))
  }

  @Test
  func `a later leaf wins ownership of shared cells so text resolves to one node`() throws {
    let projection = project(.overlap)

    let top = try resolve("type=Text text=top", in: projection)
    #expect(top.map(\.path) == ["root/index(1)/index(1)"])
    #expect(try resolve("text=base", in: projection).isEmpty)
    #expect(try resolve("text=e....", in: projection).map(\.path) == ["root/index(1)/index(0)"])
  }

  @Test
  func `text spanning two leaves matches neither`() throws {
    let session = GraphSession(size: TerminalSize(columns: 20, rows: 2)) {
      HStack {
        Text("Hello")
        Text("World")
      }
    }
    let projection = session.capture()

    #expect(projection.screen.rows[0].hasPrefix("HelloWorld"))
    #expect(try resolve("text=HelloWorld", in: projection).isEmpty)
    #expect(try resolve("text=World", in: projection).count == 1)
  }
}

// MARK: - Diff

@Suite
struct DiffTests {
  @Test
  func `diff lists the changed frames after a resize to 40x16`() throws {
    let session = Demo.hello.makeSession(TerminalSize(columns: 80, rows: 24))
    let before = session.capture()
    let after = session.capture(size: TerminalSize(columns: 40, rows: 16))

    let diff = try ProjectionDiff(before: before, after: after)

    #expect(diff.identical == false)
    #expect(diff.added.isEmpty && diff.removed.isEmpty)
    let frames = diff.changed.compactMap { change in
      change.fields["frame"].map { (change.path, $0.before, $0.after) }
    }
    #expect(frames.map(\.0) == ["root", "root/index(1)", "root/index(1)/index(1)", "root/index(1)/index(2)"])
    let right = try #require(diff.changed.first { $0.path == "root/index(1)/index(2)" })
    let moved = try #require(right.fields["frame"])
    #expect(moved.before == .object(["column": .int(75), "columns": .int(5), "row": .int(1), "rows": .int(1)]))
    #expect(moved.after == .object(["column": .int(35), "columns": .int(5), "row": .int(1), "rows": .int(1)]))
    let hello = try #require(diff.changed.first { $0.path == "root/index(0)" })
    #expect(hello.fields.keys.sorted() == ["proposal"])
    #expect(diff.screen.size?.after == .object(["columns": .int(40), "rows": .int(16)]))
    #expect(diff.screen.rows.count == 24)
  }

  @Test
  func `diff reports added and removed nodes by identity path`() throws {
    let model = Model()
    let session = GraphSession(size: TerminalSize(columns: 20, rows: 3)) {
      VStack(alignment: .leading) {
        Text(model.title)
        if model.showsDetail {
          Text("detail")
        }
      }
    }
    let before = session.capture()
    model.showsDetail = true
    session.update()
    let after = session.capture()

    let diff = try ProjectionDiff(before: before, after: after)

    #expect(diff.removed.isEmpty == false || diff.added.isEmpty == false)
    #expect(diff.added.map(\.type).contains("Text"))
    #expect(try ProjectionDiff(before: after, after: before).removed.map(\.path) == diff.added.map(\.path))
  }

  @Test
  func `diff of a projection with itself is identical`() throws {
    let projection = project(.hello)

    #expect(try ProjectionDiff(before: projection, after: projection).identical)
  }
}

// MARK: - Invariants

@Suite
struct InvariantTests {
  @Test
  func `check flags overlapping siblings under a custom layout but not under ZStack`() {
    let violations = check(project(.overlap), rules: [.siblingsDisjoint])

    #expect(violations.map(\.node) == ["root/index(0)/index(1)"])
    #expect(violations.first?.related == ["root/index(0)/index(0)"])
    #expect(violations.first?.severity == .error)
  }

  @Test
  func `check flags a clipped Text with its visible text`() throws {
    let violations = check(project(.clipped), rules: [.frameInsideClip])

    let violation = try #require(violations.first)
    #expect(violations.count == 1)
    #expect(violation.severity == .warning)
    #expect(violation.detail == #"frame 0,0 25x1 is clipped to 0,0 8x1 (visible text "This lin")"#)
  }

  @Test
  func `check flags a Text measured wider than its proposal`() {
    let violations = check(project(.clipped), rules: [.measuredWithinProposal])

    #expect(violations.map(\.node) == ["root/index(0)/index(0)"])
  }

  @Test
  func `check is clean for a well-formed layout at both sizes`() {
    let session = Demo.hello.makeSession(TerminalSize(columns: 80, rows: 24))

    #expect(check(session.capture()).isEmpty)
    #expect(check(session.capture(size: TerminalSize(columns: 40, rows: 16))).isEmpty)
  }

  @Test
  func `frame-inside-clip exempts content under a scrolling container`() {
    let projection = project(.scroll)

    #expect(check(projection, rules: [.frameInsideClip]).isEmpty)
    var strict = CheckOptions()
    strict.scrollingContainers = []
    #expect(check(projection, rules: [.frameInsideClip], options: strict).count == 2)
  }

  @Test
  func `no-dirty-after-pass flags every node of a graph that never rendered`() {
    let session = Demo.hello.makeSession(TerminalSize(columns: 80, rows: 24))
    let unrendered = Projection(diagnostics: session.graph.diagnostics, screen: .empty)

    let violations = check(unrendered, rules: [.noDirtyAfterPass])

    #expect(violations.count == unrendered.nodes.count)
    #expect(check(session.capture(), rules: [.noDirtyAfterPass]).isEmpty)
  }

  @Test
  func `unknown rule ids are rejected with the accepted ids`() throws {
    #expect(throws: RuleError.unknown("nope")) { try Rule.parse("nope") }
    #expect(try Rule.parse("siblings-disjoint") == .siblingsDisjoint)
  }
}

// MARK: - Identity and determinism

@Suite
struct IdentityTests {
  @Test
  func `identity paths and fields are stable across update on an unchanged tree`() throws {
    let session = Demo.hello.makeSession(TerminalSize(columns: 80, rows: 24))
    let first = session.capture()

    session.update()
    let second = session.capture()

    #expect(second.nodes.map(\.path) == first.nodes.map(\.path))
    let diff = try ProjectionDiff(before: first, after: second)
    #expect(diff.added.isEmpty && diff.removed.isEmpty && diff.changed.isEmpty)
    #expect(diff.screen.rows.isEmpty)
    #expect(second.statistics.invalidationReasons.contains("updateRequested"))
  }

  @Test
  func `identity paths survive a text change but a conditional flip rekeys its subtree`() throws {
    let model = Model()
    let session = GraphSession(size: TerminalSize(columns: 20, rows: 3)) {
      VStack(alignment: .leading) {
        Text(model.title)
        if model.showsDetail {
          Text("detail")
        } else {
          Text("none")
        }
      }
    }
    let first = session.capture()

    model.title = "Hello again"
    session.update()
    let renamed = session.capture()
    #expect(renamed.nodes.map(\.path) == first.nodes.map(\.path))
    #expect(try resolve(#"text="Hello again""#, in: renamed).map(\.path) == ["root/index(0)"])

    model.showsDetail = true
    session.update()
    let flipped = session.capture()
    let firstConditional = Set(first.nodes.map(\.path).filter { $0.contains("branch(") })
    let flippedConditional = Set(flipped.nodes.map(\.path).filter { $0.contains("branch(") })
    #expect(!firstConditional.isEmpty)
    #expect(firstConditional.isDisjoint(with: flippedConditional))
  }

  @Test
  func `projection JSON is byte-stable across independent sessions and has no timings`() throws {
    let first = try JSONValue(encoding: project(.hello)).compactString()
    let second = try JSONValue(encoding: project(.hello)).compactString()

    #expect(first == second)
    #expect(!first.contains("Duration") && !first.contains("duration"))
  }

  @Test
  func `projection survives a JSON round trip`() throws {
    let projection = project(.overlap)

    let data = try JSONEncoder().encode(projection)
    let decoded = try JSONDecoder().decode(Projection.self, from: data)

    #expect(decoded == projection)
  }

  @Test
  func `local type names are redacted so they stay stable across builds`() {
    let projection = project(.hello)

    #expect(projection.nodes.allSatisfy { !$0.typeName.contains("unknown context at $") })
  }
}
