/// A cancellation-safe asynchronous FIFO buffer for session event streams.
package actor AsyncEventBuffer<Element: Sendable> {
  private typealias Waiter = (
    id: Int,
    continuation: CheckedContinuation<Element?, any Error>
  )
  package typealias CoalescingPredicate =
    @Sendable (
      _ buffered: Element,
      _ incoming: Element
    ) -> Bool

  /// Waiters cancelled before their continuation was appended.
  ///
  /// `cancelWaiter(id:)` records an ID here only while `next()` for that ID is pending, so
  /// a cancellation that arrives after the waiter already received its element leaves no
  /// entry behind.
  private var cancelledWaiterIDs: Set<Int> = []
  private var elements: [Element] = []
  private var finished = false
  private var nextWaiterID = 0
  private var pendingWaiterIDs: Set<Int> = []
  private var waiters: [Waiter] = []
  private let coalescing: CoalescingPredicate?

  package var waiterCount: Int {
    waiters.count
  }

  /// The number of recorded early cancellations; a test seam for the waiter-ID bookkeeping.
  package var cancelledWaiterCount: Int {
    cancelledWaiterIDs.count
  }

  package init(coalescing: CoalescingPredicate? = nil) {
    self.coalescing = coalescing
  }

  package func finish() {
    guard finished == false else {
      return
    }

    finished = true
    let waiters = waiters
    self.waiters = []
    cancelledWaiterIDs.removeAll()

    for waiter in waiters {
      waiter.continuation.resume(returning: nil)
    }
  }

  package func next() async throws -> Element? {
    if elements.isEmpty == false {
      return elements.removeFirst()
    }

    if finished {
      return nil
    }

    let waiterID = nextWaiterID
    nextWaiterID += 1
    pendingWaiterIDs.insert(waiterID)
    defer {
      pendingWaiterIDs.remove(waiterID)
      cancelledWaiterIDs.remove(waiterID)
    }

    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        if cancelledWaiterIDs.remove(waiterID) != nil {
          continuation.resume(throwing: CancellationError())
        } else {
          waiters.append((id: waiterID, continuation: continuation))
        }
      }
    } onCancel: {
      Task {
        await self.cancelWaiter(id: waiterID)
      }
    }
  }

  package func yield(_ element: Element) {
    guard finished == false else {
      return
    }

    if waiters.isEmpty == false {
      let waiter = waiters.removeFirst()
      waiter.continuation.resume(returning: element)
    } else if shouldCoalesce(elements.last, with: element) {
      elements[elements.index(before: elements.endIndex)] = element
    } else {
      elements.append(element)
    }
  }

  private func shouldCoalesce(_ buffered: Element?, with incoming: Element) -> Bool {
    guard let buffered, let coalescing else {
      return false
    }
    return coalescing(buffered, incoming)
  }

  /// Cancels the read with `id`: a queued waiter resumes by throwing `CancellationError`,
  /// and a pending read that has not queued yet throws when it does. A cancellation for a
  /// read that already returned is ignored. Package-visible as a test seam.
  package func cancelWaiter(id: Int) {
    guard finished == false else {
      return
    }

    if let index = waiters.firstIndex(where: { $0.id == id }) {
      let waiter = waiters.remove(at: index)
      waiter.continuation.resume(throwing: CancellationError())
    } else if pendingWaiterIDs.contains(id) {
      cancelledWaiterIDs.insert(id)
    }
  }
}
