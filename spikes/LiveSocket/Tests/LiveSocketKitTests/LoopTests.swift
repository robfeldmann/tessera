import Foundation
import Testing
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport

@testable import LiveSocketKit

@Test
func `text returns the screen the terminal received`() async throws {
  let run = try await LoopRun.start()

  let reply = try await run.text()
  #expect(reply["ok"] == .bool(true))
  let rows = try #require(
    { () -> [String]? in
      guard case .array(let values) = reply["rows"] else { return nil }
      return values.compactMap(\.stringValue)
    }()
  )
  #expect(rows.count == 24)
  #expect(rows[0] == "LiveSocket counter")
  #expect(rows[3] == "> Alpha  0")
  #expect(rows[6] == "  你好 wide  0")
  // The mirror render and the bytes the session actually wrote produce the same screen.
  #expect(rows == (await run.terminalRows()))

  try await run.quit()
}

@Test
func `an injected key changes the next text reply`() async throws {
  let run = try await LoopRun.start()

  let key = try await run.key("Tab")
  #expect(key["ok"] == .bool(true))
  #expect(key["redrawn"] == .bool(true))
  #expect(key["frame"] == .int(2))

  let text = try #require(try await run.text()["text"]?.stringValue)
  #expect(text.contains("\n  Alpha  0\n> Beta  0\n"))
  #expect(text.contains("selected Beta  total 0  events 1  last key Tab"))
  #expect(await run.terminalRows()[4] == "> Beta  0")

  _ = try await run.key("ArrowRight")
  #expect(try await run.text()["text"]?.stringValue?.contains("> Beta  1") == true)

  try await run.quit()
}

@Test
func `typed input and injected keys take the same step path`() async throws {
  // 0x09 is a real Tab delivered through the terminal's input parser.
  let run = try await LoopRun.start(inputBytes: [0x09])

  let afterTyped = try await run.waitForText { $0.contains("events 1") }
  #expect(afterTyped.contains("selected Beta  total 0  events 1  last key Tab"))

  _ = try await run.key("Tab")
  let afterInjected = try #require(try await run.text()["text"]?.stringValue)
  #expect(afterInjected.contains("selected Gamma  total 0  events 2  last key Tab"))

  try await run.quit()
}

@Test
func `quit replies ok removes the socket and ends the loop`() async throws {
  let run = try await LoopRun.start()
  #expect(TestSocket.exists(run.path))

  let reply = try await TestSocket.reply(#"{"op":"quit"}"#, to: run.path)
  #expect(reply == .object(["ok": .bool(true)]))
  // Removal precedes the reply, so the path is already gone when the client sees `ok`.
  #expect(!TestSocket.exists(run.path))
  try await run.task.value
}

@Test
func `the q key quits through the same path whether injected or typed`() async throws {
  let injected = try await LoopRun.start()
  let reply = try await injected.key("q")
  #expect(reply["ok"] == .bool(true))
  #expect(!TestSocket.exists(injected.path))
  try await injected.task.value

  let typed = try await LoopRun.start(inputBytes: Array("q".utf8), waitForSocket: false)
  try await typed.task.value
  #expect(!TestSocket.exists(typed.path))
}

@Test
func `a loop that sees its input close exits and removes the socket by default`() async throws {
  let run = try await LoopRun.start(exitWhenInputCloses: true, waitForSocket: false)
  try await run.task.value
  #expect(!TestSocket.exists(run.path))
}

@Test
func `without a socket path the loop opens no endpoint and still handles typed input`() async throws {
  // Tab then q, typed: the endpoint is opt-in, so nothing is bound and nothing is left behind.
  let session = InMemoryTerminalSession(
    size: TerminalSize(columns: 80, rows: 24),
    inputBytes: Array("\tq".utf8)
  )
  try await session.withApplicationTerminal { terminal in
    try await LiveRunner.loop(
      app: CounterApp(),
      options: LiveRunner.Options(socketPath: nil),
      terminal: terminal
    )
  }
  let output = String(decoding: await session.bytes, as: UTF8.self)
  #expect(output.contains("> Beta  0"))
}

@Test
func `reading the screen leaves the graph projection unchanged`() async throws {
  let run = try await LoopRun.start()
  _ = try await run.key("Tab")

  let before = try await TestSocket.reply(#"{"op":"tree"}"#, to: run.path)
  _ = try await run.text()
  _ = try await run.text()
  let after = try await TestSocket.reply(#"{"op":"tree"}"#, to: run.path)
  #expect(before == after)

  try await run.quit()
}

@Test
func `tree lists nodes with identity type and frame`() async throws {
  let run = try await LoopRun.start()

  let tree = try await TestSocket.reply(#"{"op":"tree"}"#, to: run.path)
  guard case .array(let nodes) = tree["nodes"] else {
    Issue.record("missing nodes")
    try await run.quit()
    return
  }
  #expect(nodes.count == 12)
  #expect(nodes[0]["id"] == .string("root"))
  let rows = nodes.compactMap { $0["frame"]?["row"] }.count
  #expect(rows == nodes.count)
  let alpha = nodes.first { $0["frame"]?["row"] == .int(3) && $0["id"]?.stringValue?.hasSuffix("index(3)") == true }
  #expect(alpha?["frame"]?["columns"] == .int(10))

  try await run.quit()
}

@Test
func `bad requests get ok false replies and the loop keeps running`() async throws {
  let run = try await LoopRun.start()

  let unknownOp = try await TestSocket.reply(#"{"op":"grid"}"#, to: run.path)
  #expect(unknownOp["ok"] == .bool(false))
  let notJSON = try await TestSocket.reply("hello", to: run.path)
  #expect(notJSON["ok"] == .bool(false))
  let badKey = try await TestSocket.reply(#"{"op":"key","key":"Hyper"}"#, to: run.path)
  #expect(badKey["ok"] == .bool(false))

  #expect(try await run.text()["ok"] == .bool(true))
  try await run.quit()
}

@Test
func `the render mirror costs well under a frame budget at 80x24`() async throws {
  let app = CounterApp()
  let clock = ContinuousClock()
  let iterations = 50
  let elapsed = clock.measure {
    for _ in 0..<iterations {
      _ = VirtualTerminal.snapshot(size: TerminalSize(columns: 80, rows: 24)) { frame in
        app.graph.render(into: frame)
      }
    }
  }
  let perCall = elapsed / iterations
  print("mirror snapshot at 80x24: \(perCall) per call (debug build, \(iterations) calls)")
  #expect(perCall < .milliseconds(100))
}
