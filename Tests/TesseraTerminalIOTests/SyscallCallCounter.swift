import Synchronization

/// Counts calls made by syscall stubs that may run on a thread other than the test's.
final class SyscallCallCounter: Sendable {
  private let storage = Atomic<Int>(0)

  /// The number of calls recorded so far.
  var value: Int {
    storage.load(ordering: .acquiring)
  }

  /// Records one call and returns how many calls came before it.
  @discardableResult
  func increment() -> Int {
    storage.add(1, ordering: .acquiringAndReleasing).oldValue
  }
}
