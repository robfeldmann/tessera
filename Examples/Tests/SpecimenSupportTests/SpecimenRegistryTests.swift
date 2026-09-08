import SpecimenCaptureSupport
import SpecimenSupport
import Tessera
import Testing

struct SpecimenRegistryTests {
  @Test
  func `every registered specimen resolves to an app-owned session`() {
    #expect(SpecimenRegistry.all == SpecimenID.allCases)
    #expect(SpecimenID.allCases.count == 8)
    for id in SpecimenID.allCases {
      let session = SpecimenRegistry.make(id, size: TerminalSize(columns: 40, rows: 16))
      #expect(session.state().isEmpty == false)
    }
  }

  @Test
  func `unknown host selections are rejected before terminal setup`() {
    #expect(SpecimenRegistry.id("unknown") == nil)
    #expect(SpecimenRegistry.id("settings") == .settings)
    #expect(SpecimenRegistry.id("records") == .records)
  }

  @Test
  func `settings replay retains parser-boundary traces and model transitions`()
    async throws
  {
    let checkpoints = try await RegisteredCapture.run(
      id: .settings, size: TerminalSize(columns: 40, rows: 16))
    #expect(checkpoints.count >= 5)
    #expect(checkpoints.allSatisfy { !$0.inputTrace.isEmpty })
    #expect(checkpoints.contains { $0.inputTrace.contains("bytes=09") })
    #expect(checkpoints.contains { $0.state["submissions"] == "1" })
    #expect(checkpoints.map(\.sequence) == checkpoints.map(\.sequence).sorted())
    #expect(
      checkpoints
        == (try await RegisteredCapture.run(
          id: .settings, size: TerminalSize(columns: 40, rows: 16))))
  }

  @Test
  func `reducer record selection and divider resize remain app-owned`()
    async throws
  {
    for size in [
      TerminalSize(columns: 40, rows: 16), TerminalSize(columns: 80, rows: 24),
    ] {
      let checkpoints = try await RegisteredCapture.run(id: .records, size: size)
      let opened = try #require(checkpoints.first { $0.label == "open-record-2" })
      let dragged = try #require(checkpoints.first { $0.label == "divider-drag" })
      let released = try #require(checkpoints.first { $0.label == "divider-up" })
      let pointer = try #require(checkpoints.first { $0.label == "pointer-up" })
      #expect(opened.state["selectedID"] == "2")
      #expect(dragged.state["paneIdeals"] == "36,40")
      #expect(released.state["paneIdeals"] == dragged.state["paneIdeals"])
      #expect(pointer.state["selectedID"] == "2")
      #expect(checkpoints == (try await RegisteredCapture.run(id: .records, size: size)))
    }
  }

  @Test
  func `viewport replay reveals the nested action and moves its child offset`()
    async throws
  {
    for size in [
      TerminalSize(columns: 40, rows: 16), TerminalSize(columns: 80, rows: 24),
    ] {
      let checkpoints = try await RegisteredCapture.run(id: .viewport, size: size)
      let firstDown = checkpoints.first { $0.label == "inner-down-1" }
      let boundary = checkpoints.first { $0.label == "boundary-bubble" }
      let revealed = checkpoints.first { $0.label == "focus-inner-action" }
      let activated = checkpoints.first { $0.label == "pointer-up" }
      #expect(firstDown?.state["innerOffset"] == "0,1")
      #expect(boundary?.state["innerOffset"] == "0,6")
      #expect(boundary?.state["outerOffset"] != "0,0")
      #expect(revealed?.state["innerOffset"] == "0,6")
      #expect(revealed?.state["focus"]?.contains("inner-action") == true)
      #expect(activated?.state["actionCount"] == "1")
    }
  }
}
