/// Retains only completed observations when a later input or presentation fails.
/// The original error remains available; partially rendered graph state is not recaptured.
package struct CaptureFailure: Error, CustomStringConvertible {
  package let step: String
  package let completed: [CapturedCheckpoint]
  package let cause: any Error

  package var description: String {
    "Capture failed at '\(step)' after \(completed.count) completed checkpoints: \(cause)"
  }
}
