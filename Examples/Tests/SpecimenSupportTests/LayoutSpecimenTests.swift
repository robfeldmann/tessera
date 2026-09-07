import SpecimenCaptureSupport
import Tessera
import Testing

struct LayoutSpecimenTests {
  @Test(arguments: [
    TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 40, rows: 16),
  ])
  func `completed frames retain layout and erase replaced content`(size: TerminalSize)
    async throws
  {
    let checkpoints = try await LayoutCapture.run(size: size)
    let initial = try #require(checkpoints.first)
    let changed = try #require(checkpoints.dropFirst().first)
    #expect(initial.screen.cells[1].count == size.columns)
    #expect(
      initial.screen.cells[1].map(\.character).map(String.init).joined()
        == " Hello, Tessera" + String(repeating: " ", count: size.columns - 15))
    #expect(
      changed.screen.cells[3].map(\.character).map(String.init).joined()
        == " Changed." + String(repeating: " ", count: size.columns - 9))
    #expect(initial.screen.cells[1][1].bold)
    #expect(initial.sequence == 1)
    #expect(changed.sequence == 2)
    #expect(checkpoints == (try await LayoutCapture.run(size: size)))
  }
}
