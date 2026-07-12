import TesseraTerminalCore
import TesseraTerminalInput

package struct ActiveCapabilityProbeEvidence: Equatable, Sendable {
  package var kittyGraphics: CapabilityStatus = .unknown
  package var kittyKeyboard: CapabilityStatus = .unknown
  package var privateModes: [Int: PrivateModeState] = [:]
}

package enum ActiveCapabilityProbeCoordinatorError: Error, Equatable, Sendable {
  case alreadyResolved
  case inProgress
}

/// Correlates one serialized generation of terminal capability probes with the session's
/// existing input stream. It observes events without consuming them from public delivery.
package actor ActiveCapabilityProbeCoordinator {
  package typealias Sleep = @Sendable (Duration) async throws -> Void
  package typealias Emit = @Sendable ([UInt8]) async throws -> Void

  private enum GenerationState {
    case idle
    case inProgress
    case resolved(ActiveCapabilityProbeEvidence)
  }

  private enum Round {
    case none
    case privateModes(Set<Int>)
    case kittyKeyboard
    case kittyGraphics(KittyImageID)
  }

  private struct Waiter {
    var continuation: CheckedContinuation<Bool, Never>
    var id: UInt64
    var timeout: Task<Void, Never>
  }

  private static let kittyKeyboardProbeBytes: [UInt8] = [
    0x1B, 0x5B, 0x3F, 0x75, 0x1B, 0x5B, 0x63,
  ]

  private var evidence = ActiveCapabilityProbeEvidence()
  private var generation: GenerationState = .idle
  private var inputIsClosed = false
  private var nextWaiterID: UInt64 = 0
  private var round: Round = .none
  private var roundResponseObserved = false
  private var roundResolved = false
  private var waiter: Waiter?

  package init() {}

  private static func privateModeRequestBytes(_ modes: [Int]) -> [UInt8] {
    modes.flatMap { Array("\u{1B}[?\($0)$p".utf8) }
  }

  private static func kittyGraphicsProbeBytes(id: KittyImageID) -> [UInt8] {
    var bytes = ControlSequence.kittyGraphics(.query(id: id)).bytes
    bytes.append(contentsOf: [0x1B, 0x5B, 0x63])
    return bytes
  }

  package func observe(_ event: InputEvent) {
    switch (round, event) {
    case (.privateModes(let expected), .privateModeStatus(let status))
    where expected.contains(status.mode):
      evidence.privateModes[status.mode] = status.state
      if expected.allSatisfy({ evidence.privateModes[$0] != nil }) {
        resolveRound()
      }

    case (.kittyKeyboard, .kittyKeyboardEnhancementFlags):
      evidence.kittyKeyboard = .supported
      roundResponseObserved = true

    case (.kittyKeyboard, .primaryDeviceAttributes):
      if !roundResponseObserved {
        evidence.kittyKeyboard = .unsupported
      }
      resolveRound()

    case (.kittyGraphics(let expectedID), .kittyGraphicsResponse(let response))
    where response.id == expectedID:
      evidence.kittyGraphics = .supported
      roundResponseObserved = true

    case (.kittyGraphics, .primaryDeviceAttributes):
      if !roundResponseObserved {
        evidence.kittyGraphics = .unsupported
      }
      resolveRound()

    case (.none, _), (.privateModes, _), (.kittyKeyboard, _), (.kittyGraphics, _):
      break
    }
  }

  package func finishInput() {
    inputIsClosed = true
    resolveRound(completed: false)
  }

  package func cachedEvidence() -> ActiveCapabilityProbeEvidence? {
    guard case .resolved(let evidence) = generation else {
      return nil
    }
    return evidence
  }

  package func isInProgress() -> Bool {
    if case .inProgress = generation {
      return true
    }
    return false
  }

  package func reconcile(
    privateModes: [Int],
    kittyImageID: KittyImageID,
    timeout: Duration,
    sleep: @escaping Sleep,
    emit: @escaping Emit
  ) async throws -> ActiveCapabilityProbeEvidence {
    switch generation {
    case .idle:
      generation = .inProgress
    case .inProgress:
      throw ActiveCapabilityProbeCoordinatorError.inProgress
    case .resolved:
      throw ActiveCapabilityProbeCoordinatorError.alreadyResolved
    }

    do {
      round = .privateModes(Set(privateModes))
      roundResolved = privateModes.isEmpty
      try await emit(Self.privateModeRequestBytes(privateModes))
      _ = await waitForRound(timeout: timeout, sleep: sleep)

      try Task.checkCancellation()
      round = .kittyKeyboard
      roundResponseObserved = false
      roundResolved = false
      try await emit(Self.kittyKeyboardProbeBytes)
      let keyboardRoundCompleted = await waitForRound(timeout: timeout, sleep: sleep)

      if keyboardRoundCompleted {
        round = .kittyGraphics(kittyImageID)
        roundResponseObserved = false
        try Task.checkCancellation()
        roundResolved = false
        try await emit(Self.kittyGraphicsProbeBytes(id: kittyImageID))
        _ = await waitForRound(timeout: timeout, sleep: sleep)
      }

      round = .none
      generation = .resolved(evidence)
      try Task.checkCancellation()
      return evidence
    } catch {
      round = .none
      generation = .resolved(evidence)
      cancelWaiter()
      throw error
    }
  }

  private func waitForRound(
    timeout: Duration,
    sleep: @escaping Sleep
  ) async -> Bool {
    if roundResolved {
      return true
    }
    if inputIsClosed {
      return false
    }

    nextWaiterID &+= 1
    let waiterID = nextWaiterID
    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        let timeoutTask = Task {
          do {
            try await sleep(timeout)
            self.timeout(waiterID)
          } catch {
            if !Task.isCancelled {
              self.timeout(waiterID)
            }
          }
        }
        waiter = Waiter(continuation: continuation, id: waiterID, timeout: timeoutTask)
      }
    } onCancel: {
      Task { await self.cancel(waiterID) }
    }
  }

  private func resolveRound(completed: Bool = true) {
    roundResolved = completed
    guard let waiter else {
      return
    }
    self.waiter = nil
    waiter.timeout.cancel()
    waiter.continuation.resume(returning: completed)
  }

  private func timeout(_ waiterID: UInt64) {
    guard waiter?.id == waiterID else {
      return
    }
    resolveRound(completed: false)
  }

  private func cancel(_ waiterID: UInt64) {
    guard waiter?.id == waiterID else {
      return
    }
    resolveRound(completed: false)
  }

  private func cancelWaiter() {
    guard let waiter else {
      return
    }
    self.waiter = nil
    waiter.timeout.cancel()
    waiter.continuation.resume(returning: false)
  }
}
