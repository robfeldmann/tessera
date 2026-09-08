import SpecimenCaptureSupport
import Tessera
import Testing

struct ButtonSpecimenTests {
  @Test(arguments: [
    TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 40, rows: 16),
  ])
  func `parser-backed keyboard and pointer scenarios retain semantic state`(
    size: TerminalSize
  ) async throws {
    let checkpoints = try await ButtonCapture.run(size: size)
    let labels = [
      "initial", "focus-add", "legacy-enter", "legacy-space", "kitty-press-only",
      "focus-toggle",
      "phased-press", "phased-repeat", "phased-release", "restore-enabled", "pointer-down",
      "pointer-up", "plain-style", "plain-pointer-down", "plain-pointer-up",
      "restore-compact",
      "outside-down", "outside-up", "focus-loss-down", "focus-loss", "disable-down",
      "disable-during-press", "restore-after-disable", "removal-down",
      "removal-during-press",
      "restore-after-removal",
    ]
    #expect(checkpoints.map(\.label) == labels)

    // Legacy CR/Space and bare CSI-u activate on their press-only report. Explicit
    // press/repeat/release reports wait for release, and pointer cancellation is inert.
    let expectedCounts = [
      0, 0, 1, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    ]
    #expect(checkpoints.map { $0.state["actionCount"] } == expectedCounts.map(String.init))
    #expect(
      checkpoints.map { $0.state["focus"] } == [
        "none", "add", "add", "add", "add", "toggle", "toggle", "toggle", "toggle",
        "toggle",
        "add", "add", "add", "add", "add", "add", "add", "add", "add", "none", "add",
        "none", "none", "add", "none", "none",
      ])
    #expect(
      checkpoints.map { $0.state["addEnabled"] } == [
        "true", "true", "true", "true", "true", "true", "true", "true", "false", "true",
        "true", "true", "true", "true", "true", "true", "true", "true", "true", "true",
        "true", "false", "true", "true", "true", "true",
      ])
    #expect(
      checkpoints.map { $0.state["addPresent"] } == Array(repeating: "true", count: 24)
        + ["false", "true"]
    )
    #expect(
      checkpoints.map { $0.state["addStyle"] } == Array(repeating: "compact", count: 12)
        + ["plain", "plain", "plain"]
        + Array(repeating: "compact", count: 11)
    )

    let pressedLabels: Set<String> = [
      "pointer-down", "plain-pointer-down", "outside-down", "focus-loss-down",
      "disable-down",
      "removal-down",
    ]
    let customPressedLabels: Set<String> = ["phased-press", "phased-repeat"]
    let capturedLabels = pressedLabels
    for checkpoint in checkpoints {
      let addPresent = checkpoint.state["addPresent"] == "true"
      if addPresent {
        let add = try checkpoint.automation.resolve("add")
        #expect(add.isFocused == (checkpoint.state["focus"] == "add"))
        #expect(add.isEnabled == (checkpoint.state["addEnabled"] == "true"))
        #expect(add.activationKeys == (add.isEnabled ? ["enter", "space"] : []))
        #expect(add.isPressed == pressedLabels.contains(checkpoint.label))
        #expect(add.isPointerCaptured == capturedLabels.contains(checkpoint.label))
      } else {
        #expect(checkpoint.label == "removal-during-press")
        #expect(!checkpoint.automation.elements.contains { $0.identifier == "add" })
      }

      let toggle = try checkpoint.automation.resolve("toggle")
      #expect(toggle.isEnabled)
      #expect(toggle.isFocused == (checkpoint.state["focus"] == "toggle"))
      #expect(toggle.isPressed == customPressedLabels.contains(checkpoint.label))
      #expect(toggle.isPointerCaptured == false)
    }

    // The persistent VT capture is deterministic, including state-driven style output.
    #expect(checkpoints == (try await ButtonCapture.run(size: size)))
  }
}
