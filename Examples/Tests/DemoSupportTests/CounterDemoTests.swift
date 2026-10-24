import CustomDump
import InlineSnapshotTesting
import SnapshotTesting
import SnapshotTestingCustomDump
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
      assertInlineSnapshot(of: host.screenRows.joined(separator: "\n"), as: .lines) {
        """
        Counter
        ────────────────────────────────────────────────────────────────────────────────
        Count                                                                          0
        ────────────────────────────────────────────────────────────────────────────────
        + up   - down   0 reset   q quit



















        """
      }
    }
  }

  @Test
  func `the counter renders at mobile in the rows its content needs`() async throws {
    try await Demos.registry().withHeadlessHost("counter", at: .mobile) { host in
      #expect(host.size == TerminalSize(columns: 40, rows: 5))
      assertInlineSnapshot(of: host.screenRows.joined(separator: "\n"), as: .lines) {
        """
        Counter
        ────────────────────────────────────────
        Count                                  0
        ────────────────────────────────────────
        + up   - down   0 reset   q quit
        """
      }
    }
  }

  @Test
  func `plus and minus step the count and zero resets it`() async throws {
    try await Demos.registry().withHeadlessHost("counter", at: .mobile) { host in
      var counts: [String] = []
      try await host.send(plus)
      try await host.send(plus)
      counts.append(host.screenRows[2])
      try await host.send(.key(Key(code: .character("-"))))
      counts.append(host.screenRows[2])
      try await host.send(.key(Key(code: .character("0"))))
      counts.append(host.screenRows[2])
      assertInlineSnapshot(of: counts, as: .customDump) {
        """
        [
          [0]: "Count                                  2",
          [1]: "Count                                  1",
          [2]: "Count                                  0"
        ]
        """
      }
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

    expectNoDifference(names, ["counter", "counter-high", "stack", "workspace"])
  }
}
