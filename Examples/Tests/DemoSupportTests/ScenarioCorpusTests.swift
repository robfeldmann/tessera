import DemoSupport
import TesseraHarness
import Testing

/// The corpus CI runs with `tessera run Examples/Scenarios`, run again here through the Swift
/// entry point an app author's own tests use.
@MainActor
struct ScenarioCorpusTests {
  /// `Examples/Scenarios`, found from this file's own path: three components up (the file,
  /// `DemoSupportTests`, and `Tests`), split at either separator so a Windows path works.
  private static let corpus: String = {
    var parts = #filePath.split(omittingEmptySubsequences: false) { "/\\".contains($0) }
    parts.removeLast(3)
    return (parts + ["Scenarios"]).joined(separator: "/")
  }()

  @Test
  func `every scenario in the corpus passes against its committed goldens`() async {
    let reports = await ScenarioRunner(registry: Demos.registry()).run(Self.corpus)

    let failed = reports.filter { !$0.passed }
    #expect(failed.isEmpty, "\(failed.map(\.description).joined(separator: "\n"))")
    #expect(reports.count >= 5)
  }

  @Test
  func `two runs of the corpus produce the same bytes`() async {
    let runner = ScenarioRunner(registry: Demos.registry())

    let first = await runner.run(Self.corpus).map(\.json)
    let second = await runner.run(Self.corpus).map(\.json)

    #expect(first == second)
    #expect(!first.isEmpty)
  }
}
