import SpecimenCaptureSupport
import Tessera
import Testing

struct ButtonSpecimenTests {
  @Test(arguments: [
    TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 40, rows: 16),
  ])
  func `keyboard actions update rendered count once and skip disabled control`(
    size: TerminalSize
  ) async throws {
    let checkpoints = try await ButtonCapture.run(size: size)
    let expectedCounts = [0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3]
    #expect(checkpoints.map { $0.state["actionCount"] } == expectedCounts.map(String.init))
    #expect(
      checkpoints.map { $0.state["focus"] } == [
        "none", "add", "add", "add", "add", "add", "toggle", "toggle", "toggle", "toggle",
        "add", "add",
      ])
    #expect(
      checkpoints.map { $0.state["addEnabled"] } == [
        "true", "true", "true", "true", "true", "true", "true", "false", "false", "true",
        "true", "true",
      ])
    for (checkpoint, count) in zip(checkpoints, expectedCounts) {
      #expect(
        String(checkpoint.screen.cells[3].map(\.character))
          == " Count: \(count)" + String(repeating: " ", count: size.columns - 9))
      let add = try checkpoint.automation.resolve("add")
      #expect(
        add.frame
          == Rect(
            origin: TerminalPosition(column: 1, row: 5),
            size: TerminalSize(columns: 5, rows: 1)
          ))
      #expect(add.isFocused == (checkpoint.state["focus"] == "add"))
      #expect(add.isEnabled == (checkpoint.state["addEnabled"] == "true"))
      #expect(add.activationKeys == (add.isEnabled ? ["enter", "space"] : []))
    }
    #expect(checkpoints == (try await ButtonCapture.run(size: size)))
  }
}
