import Testing

/// Waits until `condition` holds, and records an issue instead of hanging when `timeout`
/// passes first.
///
/// Use it only for state that offers no signal, such as a gate's waiter count.
func waitUntil(
  _ description: String,
  timeout: Duration = .seconds(5),
  sourceLocation: SourceLocation = #_sourceLocation,
  _ condition: () async -> Bool
) async {
  let clock = ContinuousClock()
  let deadline = clock.now.advanced(by: timeout)
  while await condition() == false {
    guard clock.now < deadline else {
      Issue.record(
        "Timed out waiting until \(description)",
        sourceLocation: sourceLocation
      )
      return
    }
    try? await clock.sleep(for: .milliseconds(1))
  }
}
