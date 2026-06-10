/// A cancellation-safe asynchronous FIFO buffer for session event streams.
package actor AsyncEventBuffer<Element: Sendable> {
  private typealias Waiter = (
    id: Int,
    continuation: CheckedContinuation<Element?, any Error>
  )

  private var cancelledWaiterIDs: Set<Int> = []
  private var elements: [Element] = []
  private var finished = false
  private var nextWaiterID = 0
  private var waiters: [Waiter] = []

  package var waiterCount: Int {
    waiters.count
  }

  package init() {}

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
    defer {
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
    } else {
      elements.append(element)
    }
  }

  private func cancelWaiter(id: Int) {
    guard finished == false else {
      return
    }

    if let index = waiters.firstIndex(where: { $0.id == id }) {
      let waiter = waiters.remove(at: index)
      waiter.continuation.resume(throwing: CancellationError())
    } else {
      cancelledWaiterIDs.insert(id)
    }
  }
}
