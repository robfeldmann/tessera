import TesseraTerminalANSI

/// Serializes lifecycle transactions across suspension points.
package actor ModeLifecycleTransitionGate {
  private var isHeld = false
  private var nextWaiterID: UInt64 = 0
  private var waiters: [(id: UInt64, continuation: CheckedContinuation<Bool, Never>)] = []

  package init() {}

  package func acquire() async -> Bool {
    guard !Task.isCancelled else {
      return false
    }
    guard isHeld else {
      isHeld = true
      return true
    }

    nextWaiterID &+= 1
    let waiterID = nextWaiterID
    return await withTaskCancellationHandler(
      operation: {
        await withCheckedContinuation { continuation in
          guard !Task.isCancelled else {
            continuation.resume(returning: false)
            return
          }
          waiters.append((waiterID, continuation))
        }
      },
      onCancel: {
        Task {
          await self.cancel(waiterID)
        }
      }
    )
  }

  package func release() {
    guard !waiters.isEmpty else {
      isHeld = false
      return
    }
    let waiter = waiters.removeFirst()
    waiter.continuation.resume(returning: true)
  }

  private func cancel(_ waiterID: UInt64) {
    guard let index = waiters.firstIndex(where: { $0.id == waiterID }) else {
      return
    }
    let waiter = waiters.remove(at: index)
    waiter.continuation.resume(returning: false)
  }
}

/// Coordinates terminal mode ownership for a live terminal session.
public actor ModeLifecycle {
  /// Terminal modes Tessera can acquire for an application session.
  public enum Mode: Hashable, Sendable {
    /// Raw input mode.
    case rawMode

    /// Alternate screen buffer.
    case altScreen

    /// Session-owned cursor shape and color styling.
    case cursorStyle(CursorStyle)

    /// Bracketed paste.
    case bracketedPaste

    /// Focus events.
    case focusEvents

    /// Mouse tracking.
    case mouseTracking(MouseTracking)

    /// Kitty keyboard protocol.
    case kittyKeyboard
  }

  private enum AcquisitionSlot: Sendable {
    case rawMode
    case altScreen
    case cursorStyle
    case bracketedPaste
    case focusEvents
    case mouseTracking
    case kittyKeyboard
  }

  private static let acquisitionOrder: [AcquisitionSlot] = [
    .rawMode,
    .altScreen,
    .cursorStyle,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking,
    .kittyKeyboard,
  ]

  private let io: PlatformIO
  private let kittyKeyboardFlags: KittyKeyboardFlags
  private let transitionGate = ModeLifecycleTransitionGate()
  private var acquisitionStack: [Mode] = []
  private var modes: Set<Mode> = []
  private var possiblyActiveModes: Set<Mode> = []
  private var requestedModes: Set<Mode> = []

  /// The modes currently believed active by this lifecycle manager.
  public var activeModes: Set<Mode> {
    modes
  }

  /// Modes that may have changed terminal state before an I/O failure was reported.
  public var modesPossiblyActive: Set<Mode> {
    possiblyActiveModes
  }

  package var possiblyActiveModesForTesting: Set<Mode> {
    possiblyActiveModes
  }

  private var cleanupModes: Set<Mode> {
    modes.union(requestedModes).union(possiblyActiveModes)
  }

  /// Creates a lifecycle manager over owned package-internal terminal I/O.
  package init(
    io: PlatformIO,
    kittyKeyboardFlags: KittyKeyboardFlags = .tesseraDefault
  ) {
    self.io = io
    self.kittyKeyboardFlags = kittyKeyboardFlags
    io.installCleanupHandlers()
  }

  private static func isSupported(_ mode: Mode) -> Bool {
    switch mode {
    case .rawMode, .altScreen, .cursorStyle, .bracketedPaste, .focusEvents,
      .mouseTracking, .kittyKeyboard:
      true
    }
  }

  private static func mode(for slot: AcquisitionSlot, in modes: Set<Mode>) -> Mode? {
    switch slot {
    case .rawMode:
      modes.contains(.rawMode) ? .rawMode : nil
    case .altScreen:
      modes.contains(.altScreen) ? .altScreen : nil
    case .cursorStyle:
      requestedCursorStyle(in: modes).map(Mode.cursorStyle)
    case .bracketedPaste:
      modes.contains(.bracketedPaste) ? .bracketedPaste : nil
    case .focusEvents:
      modes.contains(.focusEvents) ? .focusEvents : nil
    case .mouseTracking:
      requestedMouseTracking(in: modes).map(Mode.mouseTracking)
    case .kittyKeyboard:
      modes.contains(.kittyKeyboard) ? .kittyKeyboard : nil
    }
  }

  private static func normalized(_ modes: Set<Mode>) -> Set<Mode> {
    var normalizedModes = modes.filter { mode in
      switch mode {
      case .mouseTracking, .cursorStyle:
        return false
      case .rawMode, .altScreen, .bracketedPaste, .focusEvents, .kittyKeyboard:
        return true
      }
    }

    // A set may request both mouse granularities; any-event is a strict superset of
    // button-event tracking, so the broadest requested granularity wins.
    if let mouseTracking = requestedMouseTracking(in: modes) {
      normalizedModes.insert(.mouseTracking(mouseTracking))
    }

    if let cursorStyle = requestedCursorStyle(in: modes) {
      normalizedModes.insert(.cursorStyle(cursorStyle))
    }
    return normalizedModes
  }

  private static func requestedMouseTracking(in modes: Set<Mode>) -> MouseTracking? {
    var requestedButtonEvents = false
    for mode in modes {
      switch mode {
      case .mouseTracking(.anyEvent):
        return .anyEvent
      case .mouseTracking(.buttonEvents):
        requestedButtonEvents = true
      case .rawMode, .altScreen, .cursorStyle, .bracketedPaste, .focusEvents,
        .kittyKeyboard:
        continue
      }
    }
    return requestedButtonEvents ? .buttonEvents : nil
  }

  /// Selects one requested cursor style deterministically when multiple payloads reach the
  /// lifecycle. Cursor styles have no broadest-wins superset, so ties are resolved by a
  /// private ordering over shape first, then RGB color components, with nil facets last.
  private static func requestedCursorStyle(in modes: Set<Mode>) -> CursorStyle? {
    var requestedStyle: CursorStyle?
    for mode in modes {
      switch mode {
      case .cursorStyle(let style) where style.shape != nil || style.color != nil:
        guard let currentStyle = requestedStyle else {
          requestedStyle = style
          continue
        }
        if cursorStyleSortValue(style) < cursorStyleSortValue(currentStyle) {
          requestedStyle = style
        }
      case .cursorStyle:
        continue
      case .rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking,
        .kittyKeyboard:
        continue
      }
    }
    return requestedStyle
  }

  private static func cursorStyleFacets(in modes: Set<Mode>) -> (
    hasShape: Bool, hasColor: Bool
  ) {
    var hasShape = false
    var hasColor = false
    for mode in modes {
      guard case .cursorStyle(let style) = mode else {
        continue
      }
      hasShape = hasShape || style.shape != nil
      hasColor = hasColor || style.color != nil
    }
    return (hasShape, hasColor)
  }

  private static func cursorStyleSortValue(_ style: CursorStyle) -> (Int, Int, Int, Int) {
    let color = style.color
    return (
      style.shape.map(cursorShapeSortValue) ?? .max,
      color.map { Int($0.red) } ?? .max,
      color.map { Int($0.green) } ?? .max,
      color.map { Int($0.blue) } ?? .max
    )
  }

  private static func cursorShapeSortValue(_ shape: CursorShape) -> Int {
    switch shape {
    case .defaultUserShape:
      0
    case .blinkingBlock:
      1
    case .steadyBlock:
      2
    case .blinkingUnderline:
      3
    case .steadyUnderline:
      4
    case .blinkingBar:
      5
    case .steadyBar:
      6
    }
  }

  private static func slot(for mode: Mode) -> AcquisitionSlot {
    switch mode {
    case .rawMode:
      .rawMode
    case .altScreen:
      .altScreen
    case .cursorStyle:
      .cursorStyle
    case .bracketedPaste:
      .bracketedPaste
    case .focusEvents:
      .focusEvents
    case .mouseTracking:
      .mouseTracking
    case .kittyKeyboard:
      .kittyKeyboard
    }
  }

  private static func teardownMode(
    for slot: AcquisitionSlot,
    in modes: Set<Mode>
  ) -> Mode? {
    guard slot == .cursorStyle else {
      return mode(for: slot, in: modes)
    }
    let facets = cursorStyleFacets(in: modes)
    guard facets.hasShape || facets.hasColor else {
      return nil
    }
    return .cursorStyle(
      CursorStyle(
        shape: facets.hasShape ? .defaultUserShape : nil,
        color: facets.hasColor ? CursorColor(red: 0, green: 0, blue: 0) : nil
      )
    )
  }

  /// Enters all requested modes in canonical acquisition order.
  public func enter(_ modes: Set<Mode>) async throws {
    try await beginTransition()
    do {
      try await performEnter(modes)
      await endTransition()
    } catch {
      await endTransition()
      throw error
    }
  }

  /// Reconciles active application protocol modes after startup.
  package func apply(applicationModes requestedApplicationModes: Set<Mode>) async throws {
    try await beginTransition()
    do {
      try await performApply(applicationModes: requestedApplicationModes)
      await endTransition()
    } catch {
      await endTransition()
      throw error
    }
  }

  /// Exits believed/requested modes in reverse acquisition order.
  public func exit() async throws {
    try await beginTransition()
    do {
      try await performExit()
      await endTransition()
    } catch {
      await endTransition()
      throw error
    }
  }

  private func beginTransition() async throws {
    guard await transitionGate.acquire() else {
      throw CancellationError()
    }
    do {
      try Task.checkCancellation()
    } catch {
      await transitionGate.release()
      throw error
    }
  }

  private func endTransition() async {
    await transitionGate.release()
  }

  private func performEnter(_ requested: Set<Mode>) async throws {
    let unsupportedModes = requested.filter { Self.isSupported($0) == false }
    guard unsupportedModes.isEmpty else {
      throw ModeLifecycleError.unsupportedModes(Set(unsupportedModes))
    }

    let normalizedModes = Self.normalized(requested)
    let occupiedModes = modes.union(possiblyActiveModes)
    let overlappingModes = normalizedModes.filter { normalizedMode in
      occupiedModes.contains { occupiedMode in
        Self.slot(for: occupiedMode) == Self.slot(for: normalizedMode)
      }
    }
    guard overlappingModes.isEmpty else {
      throw ModeLifecycleError.modesAlreadyActive(Set(overlappingModes))
    }

    requestedModes.formUnion(normalizedModes)
    await installCleanup()

    for slot in Self.acquisitionOrder {
      guard let mode = Self.mode(for: slot, in: normalizedModes) else {
        continue
      }
      try Task.checkCancellation()
      possiblyActiveModes.insert(mode)
      await installCleanup()
      do {
        try await enable(mode)
      } catch {
        await io.discardBufferedOutput()
        throw error
      }
      removePossiblyActiveMode(for: slot)
      acquisitionStack.append(mode)
      modes.insert(mode)
    }
    await installCleanup()
  }

  private func performApply(
    applicationModes requestedApplicationModes: Set<Mode>
  ) async throws {
    let normalizedApplicationModes = Self.normalized(requestedApplicationModes)
    let invalidModes = normalizedApplicationModes.filter { mode in
      switch mode {
      case .cursorStyle, .bracketedPaste, .focusEvents, .mouseTracking,
        .kittyKeyboard:
        return false
      case .rawMode, .altScreen:
        return true
      }
    }
    guard invalidModes.isEmpty else {
      throw ModeLifecycleError.unsupportedModes(Set(invalidModes))
    }

    let fixedModes = modes.filter { mode in
      switch mode {
      case .rawMode, .altScreen:
        return true
      case .cursorStyle, .bracketedPaste, .focusEvents, .mouseTracking,
        .kittyKeyboard:
        return false
      }
    }
    let desiredModes = fixedModes.union(normalizedApplicationModes)
    let applicationModes = modes.filter { mode in
      switch mode {
      case .cursorStyle, .bracketedPaste, .focusEvents, .mouseTracking,
        .kittyKeyboard:
        return true
      case .rawMode, .altScreen:
        return false
      }
    }

    let modesToDisable = applicationModes.subtracting(desiredModes)
    let modesToEnable = normalizedApplicationModes.subtracting(modes)
    requestedModes = desiredModes
    await installCleanup()

    for slot in Self.acquisitionOrder.reversed() {
      guard let mode = Self.mode(for: slot, in: modesToDisable) else {
        continue
      }
      try Task.checkCancellation()
      possiblyActiveModes.insert(mode)
      await installCleanup()
      do {
        try await disable(mode)
      } catch {
        await io.discardBufferedOutput()
        throw error
      }
      removeActiveMode(for: slot)
      removePossiblyActiveMode(for: slot)
      acquisitionStack.removeAll { Self.slot(for: $0) == slot }
    }

    for slot in Self.acquisitionOrder {
      guard let mode = Self.mode(for: slot, in: modesToEnable) else {
        continue
      }
      try Task.checkCancellation()
      possiblyActiveModes.insert(mode)
      await installCleanup()
      do {
        try await enable(mode)
      } catch {
        await io.discardBufferedOutput()
        throw error
      }
      removePossiblyActiveMode(for: slot)
      modes.insert(mode)
      acquisitionStack.append(mode)
    }

    requestedModes = desiredModes
    await installCleanup()
  }

  private func performExit() async throws {
    await installCleanup()

    // Unconditional Kitty Graphics cleanup, before any mode is torn down. Harmless on
    // unsupported terminals and safer than leaving images after alternate-screen exit.
    await io.write(ControlSequence.kittyGraphics(.delete(.all)).bytes)
    do {
      try await io.flush()
    } catch {
      // Never let a retained graphics-cleanup suffix precede recovery output.
      await io.discardBufferedOutput()
    }

    let teardownModes = self.cleanupModes
    var firstError: (any Error)?

    for slot in Self.acquisitionOrder.reversed() {
      guard let mode = Self.teardownMode(for: slot, in: teardownModes) else {
        continue
      }
      possiblyActiveModes.insert(mode)
      await installCleanup()
      do {
        try await disable(mode)
      } catch {
        await io.discardBufferedOutput()
        if firstError == nil {
          firstError = error
        }
        continue
      }
      removeAllModes(for: slot)
    }

    if cleanupModes.isEmpty {
      await io.clearCleanup()
    } else {
      await installCleanup()
    }

    if let firstError {
      throw firstError
    }
  }

  private func removeActiveMode(for slot: AcquisitionSlot) {
    modes = modes.filter { Self.slot(for: $0) != slot }
  }

  private func removePossiblyActiveMode(for slot: AcquisitionSlot) {
    possiblyActiveModes = possiblyActiveModes.filter { Self.slot(for: $0) != slot }
  }

  private func removeAllModes(for slot: AcquisitionSlot) {
    removeActiveMode(for: slot)
    removePossiblyActiveMode(for: slot)
    requestedModes = requestedModes.filter { Self.slot(for: $0) != slot }
    acquisitionStack.removeAll { Self.slot(for: $0) == slot }
  }

  private func disable(_ mode: Mode) async throws {
    switch mode {
    case .rawMode:
      try await io.disableRawMode()

    case .altScreen:
      try await io.disableAltScreen()

    case .cursorStyle(let style):
      var bytes: [UInt8] = []
      if style.shape != nil {
        ControlSequence.setCursorShape(.defaultUserShape).encode(into: &bytes)
      }
      if style.color != nil {
        ControlSequence.resetCursorColor.encode(into: &bytes)
      }
      await io.write(bytes)
      try await io.flush()

    case .bracketedPaste:
      await io.write(ControlSequence.enableBracketedPaste(false).bytes)
      try await io.flush()

    case .focusEvents:
      await io.write(ControlSequence.enableFocusTracking(false).bytes)
      try await io.flush()

    case .mouseTracking:
      await io.write(ControlSequence.disableMouseTracking.bytes)
      try await io.flush()

    case .kittyKeyboard:
      await io.write(ControlSequence.popKittyKeyboard.bytes)
      try await io.flush()
    }
  }

  private func enable(_ mode: Mode) async throws {
    switch mode {
    case .rawMode:
      try await io.enableRawMode()

    case .altScreen:
      try await io.enableAltScreen()

    case .cursorStyle(let style):
      var bytes: [UInt8] = []
      if let shape = style.shape {
        ControlSequence.setCursorShape(shape).encode(into: &bytes)
      }
      if let color = style.color {
        ControlSequence.setCursorColor(color).encode(into: &bytes)
      }
      await io.write(bytes)
      try await io.flush()

    case .bracketedPaste:
      await io.write(ControlSequence.enableBracketedPaste(true).bytes)
      try await io.flush()

    case .focusEvents:
      await io.write(ControlSequence.enableFocusTracking(true).bytes)
      try await io.flush()

    case .mouseTracking(let granularity):
      await io.write(ControlSequence.enableMouseTracking(granularity).bytes)
      try await io.flush()

    case .kittyKeyboard:
      await io.write(ControlSequence.pushKittyKeyboard(kittyKeyboardFlags).bytes)
      try await io.flush()
    }
  }

  private func installCleanup() async {
    let cleanupModes = self.cleanupModes
    var teardownBytes: [UInt8] = []
    // Unconditional Kitty Graphics cleanup: harmless APC noise on terminals that never
    // saw a KGP command, and defense-in-depth for terminals that do not clear alt-screen
    // images on their own. Must precede leaving the alternate screen.
    ControlSequence.kittyGraphics(.delete(.all)).encode(into: &teardownBytes)

    if cleanupModes.contains(.kittyKeyboard) {
      ControlSequence.popKittyKeyboard.encode(into: &teardownBytes)
    }

    // Mouse tracking teardown is broadest-wins on enable but always defensively resets
    // both tracking granularities and SGR encoding.
    if Self.requestedMouseTracking(in: cleanupModes) != nil {
      ControlSequence.disableMouseTracking.encode(into: &teardownBytes)
    }

    // DEC private mode 1004: disable focus event reports, `CSI ? 1004 l`.
    if cleanupModes.contains(.focusEvents) {
      ControlSequence.enableFocusTracking(false).encode(into: &teardownBytes)
    }

    // DEC private mode 2004: disable bracketed paste, `CSI ? 2004 l`.
    if cleanupModes.contains(.bracketedPaste) {
      ControlSequence.enableBracketedPaste(false).encode(into: &teardownBytes)
    }

    let cursorStyleFacets = Self.cursorStyleFacets(in: cleanupModes)
    if cursorStyleFacets.hasShape {
      ControlSequence.setCursorShape(.defaultUserShape).encode(into: &teardownBytes)
    }
    if cursorStyleFacets.hasColor {
      ControlSequence.resetCursorColor.encode(into: &teardownBytes)
    }

    // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
    if cleanupModes.contains(.altScreen) {
      ControlSequence.exitAltScreen.encode(into: &teardownBytes)
    }

    // DEC private mode 25: show cursor, `CSI ? 25 h`.
    ControlSequence.cursorVisible(true).encode(into: &teardownBytes)

    await io.installCleanup(teardownBytes: teardownBytes)
  }
}

/// Errors thrown by terminal mode lifecycle operations.
public enum ModeLifecycleError: Error, Equatable, Sendable {
  /// The requested modes overlap with modes already active in this lifecycle.
  case modesAlreadyActive(Set<ModeLifecycle.Mode>)

  /// The requested modes are unsupported by this lifecycle.
  case unsupportedModes(Set<ModeLifecycle.Mode>)
}
