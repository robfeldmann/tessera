import Tessera
import Testing

@testable import DemoSupport
@testable import TesseraHarness

@MainActor
struct CounterDemoTests {
  private let plus = InputEvent.key(Key(code: .character("+")))

  @Test
  func `the counter renders at desktop`() async throws {
    try await Demos.registry().withHeadlessHost("counter", at: .desktop) { host in
      #expect(host.size == TerminalSize(columns: 80, rows: 24))
      #expect(host.screenRows[0] == "Counter")
      #expect(host.screenRows[2] == "Count" + String(repeating: " ", count: 74) + "0")
      #expect(host.screenRows[4] == "+ up   - down   0 reset   q quit")
    }
  }

  @Test
  func `the counter renders at mobile in the rows its content needs`() async throws {
    try await Demos.registry().withHeadlessHost("counter", at: .mobile) { host in
      #expect(host.size == TerminalSize(columns: 40, rows: 5))
      #expect(host.screenRows.count == 5)
      #expect(host.screenRows[2] == "Count" + String(repeating: " ", count: 34) + "0")
    }
  }

  @Test
  func `plus and minus step the count and zero resets it`() async throws {
    try await Demos.registry().withHeadlessHost("counter", at: .mobile) { host in
      try await host.send(plus)
      try await host.send(plus)
      #expect(host.screenRows[2].hasSuffix("2"))
      try await host.send(.key(Key(code: .character("-"))))
      #expect(host.screenRows[2].hasSuffix("1"))
      try await host.send(.key(Key(code: .character("0"))))
      #expect(host.screenRows[2].hasSuffix("0"))
    }
  }

  @Test
  func `q finishes the demo and other keys do not`() async throws {
    try await Demos.registry().withHeadlessHost("counter", at: .desktop) { host in
      try await host.send(.key(Key(code: .character("x"))))
      try await host.send(.key(Key(code: .character("q"), modifiers: .control)))
      #expect(host.isFinished == false)
      try await host.send(.key(Key(code: .character("q"))))
      #expect(host.isFinished)
    }
  }

  @Test
  func `the fixture starts from its own state`() async throws {
    try await Demos.registry().withHeadlessHost("counter-high", at: .desktop) { host in
      #expect(host.screenRows[2].hasSuffix("12345"))
    }
  }

  @Test
  func `every registered demo renders at every viewport it declares`() async throws {
    let registry = Demos.registry()
    for entry in try registry.checkedEntries() {
      for viewport in entry.viewports {
        try await registry.withHeadlessHost(entry.name, at: viewport) { host in
          let drawn = host.screenRows.contains { !$0.isEmpty }
          #expect(drawn, "\(entry.name) at \(viewport.name)")
        }
      }
    }
  }

  @Test
  func `the demo registry has no duplicate names`() throws {
    let names = try Demos.registry().names()

    #expect(names == ["counter", "counter-high"])
  }
}
