import TesseraTerminalANSI

/// Coordinates terminal mode ownership for a live terminal session.
public actor ModeLifecycle {
  /// Terminal modes Tessera can acquire for an application session.
  public enum Mode: Hashable, Sendable {
    /// Raw input mode.
    case rawMode

    /// Alternate screen buffer.
    case altScreen

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
    case bracketedPaste
    case focusEvents
    case mouseTracking
    case kittyKeyboard
  }

  private static let acquisitionOrder: [AcquisitionSlot] = [
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking,
    .kittyKeyboard,
  ]

  private let io: PlatformIO
  private var acquisitionStack: [Mode] = []
  private var modes: Set<Mode> = []
  private var requestedModes: Set<Mode> = []

  /// The modes currently believed active by this lifecycle manager.
  public var activeModes: Set<Mode> {
    modes
  }

  /// Creates a lifecycle manager over owned package-internal terminal I/O.
  package init(io: PlatformIO) {
    self.io = io
    CleanupRegistry.installHandlers()
  }

  private static func isSupported(_ mode: Mode) -> Bool {
    switch mode {
    case .rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking,
      .kittyKeyboard:
      true
    }
  }

  private static func mode(for slot: AcquisitionSlot, in modes: Set<Mode>) -> Mode? {
    switch slot {
    case .rawMode:
      modes.contains(.rawMode) ? .rawMode : nil
    case .altScreen:
      modes.contains(.altScreen) ? .altScreen : nil
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
      if case .mouseTracking = mode {
        return false
      }
      return true
    }

    // A set may request both mouse granularities; any-event is a strict superset of
    // button-event tracking, so the broadest requested granularity wins.
    if let mouseTracking = requestedMouseTracking(in: modes) {
      normalizedModes.insert(.mouseTracking(mouseTracking))
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
      case .rawMode, .altScreen, .bracketedPaste, .focusEvents, .kittyKeyboard:
        continue
      }
    }
    return requestedButtonEvents ? .buttonEvents : nil
  }

  private static func slot(for mode: Mode) -> AcquisitionSlot {
    switch mode {
    case .rawMode:
      .rawMode
    case .altScreen:
      .altScreen
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

  /// Enters all requested modes in canonical acquisition order.
  public func enter(_ modes: Set<Mode>) async throws {
    let unsupportedModes = modes.filter { Self.isSupported($0) == false }
    guard unsupportedModes.isEmpty else {
      throw ModeLifecycleError.unsupportedModes(Set(unsupportedModes))
    }

    let normalizedModes = Self.normalized(modes)
    let overlappingModes = normalizedModes.filter { normalizedMode in
      self.modes.contains { activeMode in
        Self.slot(for: activeMode) == Self.slot(for: normalizedMode)
      }
    }
    guard overlappingModes.isEmpty else {
      throw ModeLifecycleError.modesAlreadyActive(Set(overlappingModes))
    }

    requestedModes = normalizedModes
    var acquiredModes: [Mode] = []

    do {
      for slot in Self.acquisitionOrder {
        guard let mode = Self.mode(for: slot, in: normalizedModes) else {
          continue
        }
        try await enable(mode)
        acquiredModes.append(mode)
        acquisitionStack.append(mode)
        self.modes.insert(mode)
      }
      await installCleanup()
    } catch {
      await io.discardBufferedOutput()
      await rollback(acquiredModes)
      await io.clearCleanup()
      requestedModes = []
      throw error
    }
  }

  /// Reconciles active application protocol modes after startup.
  package func apply(applicationModes requestedApplicationModes: Set<Mode>) async throws {
    let normalizedApplicationModes = Self.normalized(requestedApplicationModes)
    let invalidModes = normalizedApplicationModes.filter { mode in
      switch mode {
      case .bracketedPaste, .focusEvents, .mouseTracking, .kittyKeyboard:
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
      case .bracketedPaste, .focusEvents, .mouseTracking, .kittyKeyboard:
        return false
      }
    }
    let desiredModes = fixedModes.union(normalizedApplicationModes)
    let applicationModes = modes.filter { mode in
      switch mode {
      case .bracketedPaste, .focusEvents, .mouseTracking, .kittyKeyboard:
        return true
      case .rawMode, .altScreen:
        return false
      }
    }

    let modesToDisable = applicationModes.subtracting(desiredModes)
    let modesToEnable = normalizedApplicationModes.subtracting(modes)

    do {
      for slot in Self.acquisitionOrder.reversed() {
        guard let mode = Self.mode(for: slot, in: modesToDisable) else {
          continue
        }
        try await disable(mode)
        modes.remove(mode)
        requestedModes.remove(mode)
        acquisitionStack.removeAll { Self.slot(for: $0) == Self.slot(for: mode) }
      }

      for slot in Self.acquisitionOrder {
        guard let mode = Self.mode(for: slot, in: modesToEnable) else {
          continue
        }
        try await enable(mode)
        modes.insert(mode)
        requestedModes.insert(mode)
        acquisitionStack.append(mode)
      }

      requestedModes = fixedModes.union(normalizedApplicationModes)
      await installCleanup()
    } catch {
      await installCleanup()
      throw error
    }
  }

  /// Exits believed/requested modes in reverse acquisition order.
  public func exit() async throws {
    let cleanupModes = modes.union(requestedModes)
    var firstError: (any Error)?

    for slot in Self.acquisitionOrder.reversed() {
      guard let mode = Self.mode(for: slot, in: cleanupModes) else {
        continue
      }
      do {
        try await disable(mode)
      } catch {
        if firstError == nil {
          firstError = error
        }
      }
    }

    acquisitionStack = []
    modes = []
    requestedModes = []
    await io.clearCleanup()

    if let firstError {
      throw firstError
    }
  }

  private func disable(_ mode: Mode) async throws {
    switch mode {
    case .rawMode:
      try await io.disableRawMode()

    case .altScreen:
      try await io.disableAltScreen()

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
      await io.write(ControlSequence.pushKittyKeyboard(.tesseraDefault).bytes)
      try await io.flush()
    }
  }

  private func installCleanup() async {
    var teardownBytes: [UInt8] = []

    if modes.contains(.kittyKeyboard) || requestedModes.contains(.kittyKeyboard) {
      ControlSequence.popKittyKeyboard.encode(into: &teardownBytes)
    }

    // Mouse tracking teardown is broadest-wins on enable but always defensively resets
    // both tracking granularities and SGR encoding.
    if Self.requestedMouseTracking(in: modes.union(requestedModes)) != nil {
      ControlSequence.disableMouseTracking.encode(into: &teardownBytes)
    }

    // DEC private mode 1004: disable focus event reports, `CSI ? 1004 l`.
    if modes.contains(.focusEvents) || requestedModes.contains(.focusEvents) {
      ControlSequence.enableFocusTracking(false).encode(into: &teardownBytes)
    }

    // DEC private mode 2004: disable bracketed paste, `CSI ? 2004 l`.
    if modes.contains(.bracketedPaste) || requestedModes.contains(.bracketedPaste) {
      ControlSequence.enableBracketedPaste(false).encode(into: &teardownBytes)
    }

    // DEC private mode 1049: leave alternate screen, `CSI ? 1049 l`.
    if modes.contains(.altScreen) || requestedModes.contains(.altScreen) {
      ControlSequence.exitAltScreen.encode(into: &teardownBytes)
    }

    // DEC private mode 25: show cursor, `CSI ? 25 h`.
    ControlSequence.cursorVisible(true).encode(into: &teardownBytes)

    await io.installCleanup(teardownBytes: teardownBytes)
  }

  private func rollback(_ acquiredModes: [Mode]) async {
    for mode in acquiredModes.reversed() {
      try? await disable(mode)
      self.modes.remove(mode)
      acquisitionStack.removeAll { $0 == mode }
    }
  }
}

/// Errors thrown by terminal mode lifecycle operations.
public enum ModeLifecycleError: Error, Equatable, Sendable {
  /// The requested modes overlap with modes already active in this lifecycle.
  case modesAlreadyActive(Set<ModeLifecycle.Mode>)

  /// The requested modes are not implemented in this slice.
  case unsupportedModes(Set<ModeLifecycle.Mode>)
}
