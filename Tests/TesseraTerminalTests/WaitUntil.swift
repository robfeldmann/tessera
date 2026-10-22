import Testing

/// Suspends until `condition` holds, checking it again after each short pause.
///
/// Tests use this to order work on an observable precondition, such as a waiter count,
/// instead of on scheduler yields. When `timeout` passes first, it records an issue at the
/// caller and returns, so a precondition that never holds fails the test instead of
/// hanging it.
func waitUntil(
  _ description: String,
  timeout: Duration = .seconds(5),
  isolation: isolated (any Actor)? = #isolation,
  sourceLocation: SourceLocation = #_sourceLocation,
  _ condition: () async -> Bool
) async {
  let clock = ContinuousClock()
  let deadline = clock.now.advanced(by: timeout)
  while await !condition() {
    guard clock.now < deadline else {
      Issue.record(
        "Timed out waiting until \(description)", sourceLocation: sourceLocation)
      return
    }
    try? await clock.sleep(for: .milliseconds(1))
  }
}
