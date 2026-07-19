import InlineSnapshotTesting
import SnapshotTesting
import Tessera
import TesseraTerminal
import TesseraTerminalTestSupport
import Testing
@testable import TesseraShowcase

@Suite(.serialized)
struct ShowcaseTerminalSessionTests {
  @Test
  func `Showcase draws through an in-memory terminal session`() async throws {
    let size = TerminalSize(columns: 20, rows: 6)
    let initialSize = ShowcaseFixture.standard.size
    #expect(size.columns < initialSize.columns)
    #expect(size.rows < initialSize.rows)
    let session = InMemoryTerminalSession(size: size)
    let configuration = TerminalApplicationConfiguration(
      modes: [.rawMode, .altScreen],
      synchronizedOutput: .disabled,
      colorCapability: .force(.noColor)
    )
    let renderedSize = try await session.withApplicationTerminal(
      configuration: configuration
    ) { terminal in
      let model = ShowcaseModel(size: initialSize)
      let graph = model.makeGraph()
      try await TesseraShowcase.render(model, graph: graph, to: terminal)
      return model.size
    }

    #expect(renderedSize == size)
    let output = try #require(
      String(bytes: await session.bytes, encoding: .utf8)
    ).debugDescription
    #expect(Array((await session.events).suffix(2)) == [.exitAltScreen, .exitRawMode])
    assertInlineSnapshot(
      of: output,
      as: .lines
    ) {
      #"""
      "\u{1B}[?1049h\u{1B}[2J\u{1B}[1;1H\u{1B}[0mResize to at least 2\u{1B}[2;1H                    \u{1B}[3;1H                    \u{1B}[4;1H                    \u{1B}[5;1H                    \u{1B}[6;1H                    \u{1B}[0m\u{1B}[?25l\u{1B}[?25h\u{1B}_Ga=d,d=A\u{1B}\\\u{1B}[?1049l"
      """#
    }
  }
}
