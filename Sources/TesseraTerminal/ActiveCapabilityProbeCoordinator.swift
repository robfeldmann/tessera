import TesseraTerminalCore
import TesseraTerminalIO
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

/// Which colors a color round asks the terminal for.
package enum ColorQueryScope: Equatable, Sendable {
  /// The default foreground (OSC 10), the default background (OSC 11), and ANSI slots 0
  /// through 15 (OSC 4).
  case all

  /// Only the default background (OSC 11), which `NO_COLOR` sessions still need for the
  /// color scheme.
  case backgroundOnly
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
    case colors
  }

  private struct Waiter {
    var continuation: CheckedContinuation<Bool, Never>
    var id: UInt64
    var timeout: Task<Void, Never>
  }

  private static let kittyKeyboardProbeBytes: [UInt8] = [
    0x1B, 0x5B, 0x3F, 0x75, 0x1B, 0x5B, 0x63,
  ]

  private var colorRerunQueued = false
  private var evidence = ActiveCapabilityProbeEvidence()
  private var generation: GenerationState = .idle
  private var generationColorRoundStarted = false
  private var inputIsClosed = false
  private var isClosed = false
  private var nextWaiterID: UInt64 = 0
  /// DA1 queries written (or attempted) whose reply has not been observed. Every round
  /// ends with one, the terminal answers them in order, and a round that timed out or a
  /// generation or color re-run that was cancelled or failed leaves its own in flight, so
  /// only the reply that brings this to zero can be the current round's sentinel.
  private var pendingSentinels = 0
  private var round: Round = .none
  private let roundGate = ModeLifecycleTransitionGate()
  private var roundResponseObserved = false
  private var roundResolved = false
  private var waiter: Waiter?

  package init() {}

  /// The mode requests followed by one DA1 sentinel, which a terminal answers after every
  /// reply it will give. An empty request asks nothing, so it needs no sentinel.
  private static func privateModeRequestBytes(_ modes: [Int]) -> [UInt8] {
    guard !modes.isEmpty else {
      return []
    }
    return modes.flatMap { Array("\u{1B}[?\($0)$p".utf8) } + [0x1B, 0x5B, 0x63]
  }

  private static func kittyGraphicsProbeBytes(id: KittyImageID) -> [UInt8] {
    var bytes = ControlSequence.kittyGraphics(.query(id: id)).bytes
    bytes.append(contentsOf: [0x1B, 0x5B, 0x63])
    return bytes
  }

  /// The bytes of one color round: one query per requested color, then the round's single
  /// DA1, which a terminal answers after every reply it will send.
  package static func colorQueryBytes(scope: ColorQueryScope) -> [UInt8] {
    var bytes: [UInt8] = []
    func appendQuery(_ query: String) {
      bytes.append(contentsOf: Array("\u{1B}]\(query);?\u{1B}\\".utf8))
    }
    switch scope {
    case .all:
      appendQuery("10")
      appendQuery("11")
      for slot in TerminalColorReport.slotRange {
        appendQuery("4;\(slot)")
      }
    case .backgroundOnly:
      appendQuery("11")
    }
    bytes.append(contentsOf: [0x1B, 0x5B, 0x63])
    return bytes
  }

  package func observe(_ event: InputEvent) {
    if case .primaryDeviceAttributes = event {
      pendingSentinels = max(pendingSentinels - 1, 0)
      guard pendingSentinels == 0 else {
        // An earlier round's reply (a timed-out round's, or an abandoned attempt's): it
        // precedes every reply to the current round.
        return
      }
    }

    switch (round, event) {
    case (.privateModes(let expected), .privateModeStatus(let status))
    where expected.contains(status.mode):
      evidence.privateModes[status.mode] = status.state

    case (.privateModes, .primaryDeviceAttributes):
      // DA1 ends the round. A mode with no reply by now stays unknown: an unanswered
      // DECRQM is not a conclusive "unsupported".
      resolveRound()

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

    case (.colors, .primaryDeviceAttributes):
      resolveRound()

    case (.none, _), (.privateModes, _), (.kittyKeyboard, _), (.kittyGraphics, _),
      (.colors, _):
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

  /// Runs the generation: DECRQM, Kitty keyboard, Kitty graphics, then the color round.
  ///
  /// The color round is the generation's last round and ends at its own DA1 or at
  /// `timeout`. Color replies are not evidence here; the session applies each one as it
  /// arrives, so a reply after the round ended is still applied.
  package func reconcile(
    privateModes: [Int],
    kittyImageID: KittyImageID,
    colorScope: ColorQueryScope,
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
    guard await roundGate.acquire() else {
      generation = .idle
      throw CancellationError()
    }

    do {
      round = .privateModes(Set(privateModes))
      roundResolved = privateModes.isEmpty
      try await emitCountingSentinel(
        Self.privateModeRequestBytes(privateModes), emit: emit)
      let modesRoundCompleted = await waitForRound(timeout: timeout, sleep: sleep)

      // A DA1 round that timed out may still have its DA1 in flight, so later rounds
      // retire: a late reply could otherwise satisfy their sentinel.
      var keyboardRoundCompleted = false
      if modesRoundCompleted {
        try Task.checkCancellation()
        round = .kittyKeyboard
        roundResponseObserved = false
        roundResolved = false
        try await emitCountingSentinel(Self.kittyKeyboardProbeBytes, emit: emit)
        keyboardRoundCompleted = await waitForRound(timeout: timeout, sleep: sleep)
      }

      if keyboardRoundCompleted {
        round = .kittyGraphics(kittyImageID)
        roundResponseObserved = false
        try Task.checkCancellation()
        roundResolved = false
        try await emitCountingSentinel(
          Self.kittyGraphicsProbeBytes(id: kittyImageID), emit: emit)
        _ = await waitForRound(timeout: timeout, sleep: sleep)
      }

      try Task.checkCancellation()
      generationColorRoundStarted = true
      try await performColorRound(
        scope: colorScope,
        timeout: timeout,
        sleep: sleep,
        emit: emit
      )

      round = .none
      try Task.checkCancellation()
      generation = .resolved(evidence)
      generationColorRoundStarted = false
      await roundGate.release()
      return evidence
    } catch {
      // Cancellation and emit failures mean the terminal was never fully asked, so a later
      // reconcile retries from scratch, keeping `pendingSentinels` so the retry waits past
      // the DA1 replies this attempt left in flight. Timeouts do not reach here; they
      // resolve permanently.
      round = .none
      evidence = ActiveCapabilityProbeEvidence()
      generation = .idle
      generationColorRoundStarted = false
      cancelWaiter()
      await roundGate.release()
      throw error
    }
  }

  /// Asks the terminal for its colors again, after the generation has resolved.
  ///
  /// A color-scheme notification or a resume calls this; unlike every other probe, the
  /// color round is not cached. Rounds run one at a time. A request that arrives while
  /// another is already queued adds nothing, because the queued round has not asked yet
  /// and will see the newest colors. A request that arrives before the generation's own
  /// color round has asked is covered the same way, and one for a session that never ran
  /// the generation, or after `close()`, does nothing.
  package func rerunColorRound(
    scope: ColorQueryScope,
    timeout: Duration,
    sleep: @escaping Sleep,
    emit: @escaping Emit
  ) async throws {
    guard !isClosed, !colorRerunQueued else {
      return
    }
    switch generation {
    case .idle:
      return
    case .inProgress where !generationColorRoundStarted:
      return
    case .inProgress, .resolved:
      break
    }

    colorRerunQueued = true
    guard await roundGate.acquire() else {
      colorRerunQueued = false
      throw CancellationError()
    }
    colorRerunQueued = false

    do {
      if !isClosed, case .resolved = generation {
        try await performColorRound(
          scope: scope, timeout: timeout, sleep: sleep, emit: emit)
      }
      await roundGate.release()
    } catch {
      round = .none
      cancelWaiter()
      await roundGate.release()
      throw error
    }
  }

  /// Ends any round in flight and stops later color rounds from asking.
  package func close() {
    isClosed = true
    resolveRound(completed: false)
  }

  private func performColorRound(
    scope: ColorQueryScope,
    timeout: Duration,
    sleep: @escaping Sleep,
    emit: @escaping Emit
  ) async throws {
    round = .colors
    roundResolved = false
    try await emitCountingSentinel(Self.colorQueryBytes(scope: scope), emit: emit)
    _ = await waitForRound(timeout: timeout, sleep: sleep)
    round = .none
  }

  /// Writes one round's request, counting its DA1 first, because a write that throws
  /// part-way may still have sent it, and an uncounted DA1 would let its reply end a later
  /// round early. The count never heals: a DA1 that is counted but never answered (dropped
  /// buffered output, a reply the parser rejects, input lost across a suspend) leaves it
  /// one too high for the session, so every later round ends by timeout, a generation
  /// still to run caches Kitty keyboard and graphics as unknown, and each color re-run
  /// waits out its timeout. An empty request asks nothing and sends no DA1.
  private func emitCountingSentinel(_ bytes: [UInt8], emit: Emit) async throws {
    if !bytes.isEmpty {
      pendingSentinels += 1
    }
    try await emit(bytes)
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
