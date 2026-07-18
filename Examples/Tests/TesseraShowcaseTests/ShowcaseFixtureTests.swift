import InlineSnapshotTesting
import SnapshotTesting
import Tessera
import TesseraTerminal
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import Testing
@testable import TesseraShowcase

@Suite(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  ),
  .serialized
)
struct ShowcaseFixtureTests {
  @Test
  func `regular fixture dispatches and renders deterministically`() {
    let result = render(.regular)
    assertModel(result.model, fixture: .regular)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase
      Selected: Text
      Diagnostics: ViewGraph ready





















      """
    }
  }

  @Test
  func `standard fixture dispatches and renders deterministically`() {
    let result = render(.standard)
    assertModel(result.model, fixture: .standard)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase
      Selected: Text
      Diagnostics: ViewGraph ready





















      """
    }
  }

  @Test
  func `short standard fixture dispatches and renders deterministically`() {
    let result = render(.standardShort)
    assertModel(result.model, fixture: .standardShort)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase
      Selected: Text
      Diagnostics: ViewGraph ready













      """
    }
  }

  @Test
  func `compact fixture dispatches and renders deterministically`() {
    let result = render(.compact)
    assertModel(result.model, fixture: .compact)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase
      Selected: Text
      Diagnostics: ViewGraph ready













      """
    }
  }

  @Test
  func `guard fixture dispatches and renders deterministically`() {
    let result = render(.guardSize)
    assertModel(result.model, fixture: .guardSize)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Resize to at least 40x12










      """
    }
  }

  private func render(
    _ fixture: ShowcaseFixture
  ) -> (model: ShowcaseModel, snapshot: ScreenSnapshot) {
    let script = ShowcaseScript(events: [
      .paste("fixture"),
      .resize(fixture.size),
    ])
    let model = ShowcaseModel(size: fixture.size)
    model.dispatch(script)
    let graph = model.makeGraph()
    let snapshot = VirtualTerminal.snapshot(size: fixture.size) { frame in
      graph.render(into: frame)
    }
    return (model, snapshot)
  }

  private func assertModel(_ model: ShowcaseModel, fixture: ShowcaseFixture) {
    #expect(model.eventCount == 2)
    #expect(model.lastPaste == "fixture")
    #expect(model.size == fixture.size)
  }
}
