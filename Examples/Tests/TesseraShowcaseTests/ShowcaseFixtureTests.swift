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
      Tessera Showcase                                                                                                 regular
      ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
      Catalog                 │Playground                                                            │Inspector
      > Text                  │Selected: Text                                                        │node: selected
      Overview                │                                                                      │proposal: 120x24
      Primitives              │Text specimen                                                         │frame: absolute
        Divider               │Hello, Tessera                                                        │clip: parent
        Frame                 │Unicode: café 你 好                                                     │state: app-owned
        Padding               │                                                                      │render: ready
        Spacer                │[Button placeholder]                                                  │
      Layout                  │[Toggle placeholder: off]                                             │
        HStack                │                                                                      │
        VStack                │Layout diagnostics remain                                             │
        ZStack                │visible through the Inspector.                                        │
        SplitView             │                                                                      │
      Scrolling               │                                                                      │
        ScrollView            │                                                                      │
      Diagnostics             │                                                                      │
        ViewGraph             │                                                                      │
        Frames                │                                                                      │
        Clips                 │                                                                      │
        Proposals             │                                                                      │


      """
    }
  }

  @Test
  func `standard fixture dispatches and renders deterministically`() {
    let result = render(.standard)
    assertModel(result.model, fixture: .standard)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                                                         regular
      ────────────────────────────────────────────────────────────────────────────────
      Catalog                 │Playground
      > Text                  │Selected: Text
      Overview                │
      Primitives              │Text specimen
        Divider               │Hello, Tessera
        Frame                 │Unicode: café 你 好
        Padding               │
        Spacer                │[Button placeholder]
      Layout                  │[Toggle placeholder: off]
        HStack                │
        VStack                │Layout diagnostics remain
        ZStack                │visible through the Inspector.
        SplitView             │
      Scrolling               │
        ScrollView            │
      Diagnostics             │
        ViewGraph             │
        Frames                │
        Clips                 │
        Proposals             │


      """
    }
  }

  @Test
  func `short standard fixture dispatches and renders deterministically`() {
    let result = render(.standardShort)
    assertModel(result.model, fixture: .standardShort)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                                                         regular
      ────────────────────────────────────────────────────────────────────────────────
      Catalog                 │Playground
      > Text                  │Selected: Text
      Overview                │
      Primitives              │Text specimen
        Divider               │Hello, Tessera
        Frame                 │Unicode: café 你 好
        Padding               │
        Spacer                │[Button placeholder]
      Layout                  │[Toggle placeholder: off]
        HStack                │
        VStack                │Layout diagnostics remain
        ZStack                │visible through the Inspector.
        SplitView             │
      Scrolling               │
      """
    }
  }

  @Test
  func `compact fixture dispatches and renders deterministically`() {
    let result = render(.compact)
    assertModel(result.model, fixture: .compact)
    assertInlineSnapshot(of: result.snapshot, as: .terminalText(trim: .trailing)) {
      """
      Tessera Showcase                 compact
      ────────────────────────────────────────
      Catalog
      > Text
      Overview
      Primitives
        Divider
        Frame
        Padding
        Spacer
      Layout
        HStack
        VStack
        ZStack
        SplitView
      Scrolling
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
