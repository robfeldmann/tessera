import Foundation

/// Runs scenario files against the applications in an ``ApplicationRegistry``.
///
/// A scenario is a text file; the grammar is `Examples/Scenarios/README.md`. The runner is the
/// Swift entry point to what `tessera run` does on the command line, so an app's tests and its
/// command line run the same scenarios the same way:
///
/// ```swift
/// @Test @MainActor
/// func `the scenarios pass`() async {
///   var registry = ApplicationRegistry()
///   registry.register("browser", viewports: [.desktop]) { Browser() }
///   let reports = await ScenarioRunner(registry: registry).run("Scenarios")
///   #expect(reports.filter { !$0.passed }.isEmpty, "\(reports)")
/// }
/// ```
///
/// Each scenario starts a fresh application and a fresh virtual terminal, so scenarios do not
/// share state. A `shot` statement is checked against its golden file, which lives in a
/// directory named like the scenario file, and a golden that differs or is missing fails the
/// statement unless the runner records.
public struct ScenarioRunner {
  private let registry: ApplicationRegistry
  private let record: Bool

  /// How many times each scenario runs; a run that differs from the first is a failure.
  package var repetitions = 1

  /// Whether each report carries the wall-clock time of its runs.
  package var measuresTime = false

  /// Creates a runner over `registry`.
  ///
  /// - Parameters:
  ///   - registry: The applications scenarios select with their `app` header.
  ///   - record: Whether to write the goldens that `shot` statements compare against, instead
  ///     of failing when one differs or is missing. Recording accepts whatever the run
  ///     produced, so review the files it writes; never record to make a failing run pass.
  public init(registry: ApplicationRegistry, record: Bool = false) {
    self.registry = registry
    self.record = record
  }

  /// What changed between two runs of one scenario, for the `repeat` failure.
  private static func divergence(of run: ScenarioReport, from first: ScenarioReport)
    -> String
  {
    if run.failures.count != first.failures.count {
      return
        "it has \(run.failures.count) failures where run 1 has \(first.failures.count)"
    }
    if let index = first.failures.firstDifference(from: run.failures) {
      return "failure \(index + 1), at line \(run.failures[index].line), differs"
    }
    if run.observations.count != first.observations.count {
      return
        "it saw \(run.observations.count) observations where run 1 saw "
        + "\(first.observations.count)"
    }
    if let index = first.observations.firstDifference(from: run.observations) {
      return "observation \(index + 1), at line \(run.observations[index].line), differs"
    }
    return "the reports differ"
  }

  /// A duration in seconds, to the millisecond.
  private static func seconds(_ duration: Duration) -> Double {
    let components = duration.components
    let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18
    return (seconds * 1_000).rounded() / 1_000
  }

  /// Runs the scenario files at `paths` and returns one report per scenario.
  ///
  /// A path is a `.scn` file, or a directory whose `.scn` files, at any depth, run in sorted
  /// order. A scenario that cannot be parsed reports a `parse` failure instead of running, and
  /// a path that is not a scenario or does not exist reports a `usage` failure, so the result
  /// holds exactly one report for each scenario and each bad path, in order.
  ///
  /// - Parameter paths: Scenario files and directories of them.
  /// - Returns: One report per scenario, in the order the scenarios ran.
  @MainActor
  public func run(_ paths: String...) async -> [ScenarioReport] {
    await run(paths: paths)
  }

  /// The same as ``run(_:)``, for a path list built at run time.
  @MainActor
  package func run(paths: [String]) async -> [ScenarioReport] {
    let known: [String]
    let registryFailure: String?
    do {
      known = try registry.names()
      registryFailure = nil
    } catch {
      known = []
      registryFailure = error.description
    }

    var reports: [ScenarioReport] = []
    for item in ScenarioFiles.discover(paths) {
      switch item {
      case .report(let report):
        reports.append(report)
      case .scenario(let path):
        if let registryFailure {
          reports.append(
            .failure(scenario: path, verb: "harness", message: registryFailure))
        } else {
          reports.append(await runFile(at: path, knownApps: known))
        }
      }
    }
    return reports
  }

  @MainActor
  private func runFile(at path: String, knownApps: [String]) async -> ScenarioReport {
    guard let data = FileManager.default.contents(atPath: path) else {
      return .failure(scenario: path, verb: "harness", message: "cannot read the file")
    }
    guard var source = String(validating: data, as: UTF8.self) else {
      return .failure(
        scenario: path, verb: "usage", message: "the file is not UTF-8 text")
    }
    if source.unicodeScalars.first == "\u{FEFF}" {
      source.unicodeScalars.removeFirst()
    }
    let scenario: Scenario
    do {
      scenario = try ScenarioParser.parse(source, file: path, knownApps: knownApps)
    } catch let error as ScenarioParseError {
      return .parseFailure(error)
    } catch {
      return .failure(scenario: path, verb: "harness", message: "\(error)")
    }

    var reports: [ScenarioReport] = []
    var seconds: [Double] = []
    let clock = ContinuousClock()
    for run in 0..<max(1, repetitions) {
      // Only the first run records. Later runs compare against what it wrote, so a scenario
      // whose output varies fails on the run that differs.
      let goldens = GoldenStore(scenarioPath: path, record: record && run == 0)
      let started = clock.now
      let report = await ScenarioPlayer.run(
        scenario, name: path, registry: registry, goldens: goldens)
      seconds.append(Self.seconds(started.duration(to: clock.now)))
      reports.append(report)
    }
    return combined(reports, seconds: seconds)
  }

  /// The first run's report, with a `repeat` failure for each later run that differs.
  private func combined(_ reports: [ScenarioReport], seconds: [Double]) -> ScenarioReport
  {
    let first = reports[0]
    var failures = first.failures
    for (offset, report) in reports.enumerated().dropFirst()
    where report.comparable != first.comparable {
      failures.append(
        ScenarioFailure(
          line: 0, statement: "--repeat \(reports.count)", verb: "repeat",
          message:
            "run \(offset + 1) of \(reports.count) differs from run 1: "
            + Self.divergence(of: report, from: first)))
    }
    return ScenarioReport(
      scenario: first.scenario,
      failures: failures,
      observations: first.observations,
      recorded: first.recorded,
      seconds: measuresTime ? seconds : []
    )
  }
}
