import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import Testing

struct AutomationSnapshotTests {
  @Test
  func
    `renaming automation preserves structural identity and focus without implicit passes`()
    throws
  {
    var identifier = "before"
    let focusID = FocusID("control")
    let graph = ViewGraph(
      root: {
        Text("Private text is not metadata")
          .focusable(focusID)
          .automationID(identifier, role: .button)
      },
      size: TerminalSize(columns: 40, rows: 16)
    )
    let beforeLayout = graph.diagnostics.statistics
    _ = graph.automationSnapshot
    #expect(graph.needsLayout)
    #expect(graph.diagnostics.statistics == beforeLayout)

    graph.focus.focus(focusID)
    graph.layoutIfNeeded()
    let before = try graph.automationSnapshot.resolve("before")
    let completedStatistics = graph.diagnostics.statistics
    #expect(before.isFocused)
    #expect(try graph.automationSnapshot.resolve("before") == before)
    #expect(graph.diagnostics.statistics == completedStatistics)

    identifier = "after"
    graph.update()
    graph.layoutIfNeeded()
    let after = try graph.automationSnapshot.resolve("after")
    #expect(after.nodeIdentity == before.nodeIdentity)
    #expect(after.frame == before.frame)
    #expect(after.isFocused)
    #expect(graph.focus.focused == focusID)
  }

  @Test
  func `missing and ambiguous selectors never choose an arbitrary candidate`() throws {
    let graph = ViewGraph(
      root: {
        VStack {
          Text("First").automationID("duplicate", role: .text)
          Text("Second").automationID("duplicate", role: .text)
        }
      },
      size: TerminalSize(columns: 40, rows: 16)
    )
    graph.layoutIfNeeded()
    let snapshot = graph.automationSnapshot
    #expect(
      throws: AutomationSnapshot.LookupError.missing(
        identifier: "absent", available: ["duplicate", "duplicate"]
      )
    ) { try snapshot.resolve("absent") }
    #expect(
      throws: AutomationSnapshot.LookupError.ambiguous(
        identifier: "duplicate", candidates: snapshot.elements
      )
    ) { try snapshot.resolve("duplicate") }
    #expect(snapshot.elements.map(\.frame.origin.row) == [0, 1])
  }

  @Test(arguments: AutomationRole.allCases)
  func `disabled annotations expose no activation keys`(role: AutomationRole) throws {
    let graph = ViewGraph(
      root: { Text("Fixture").automationID("surface", role: role).disabled() },
      size: TerminalSize(columns: 40, rows: 16)
    )
    graph.layoutIfNeeded()
    let element = try graph.automationSnapshot.resolve("surface")
    #expect(!element.isEnabled)
    #expect(element.activationKeys.isEmpty)
  }
}
