/// Coordinates terminal mode ownership for a live terminal session.
public actor ModeLifecycle {
  /// Terminal modes Tessera can acquire for an application session.
  public enum Mode: Hashable, Sendable {
    /// Raw input mode.
    case rawMode

    /// Alternate screen buffer.
    case altScreen

    /// Mouse tracking. Deferred to Phase 3.
    case mouseTracking

    /// Bracketed paste. Deferred to Phase 3.
    case bracketedPaste

    /// Focus events. Deferred to Phase 3.
    case focusEvents

    /// Kitty keyboard protocol. Deferred to Phase 3.
    case kittyKeyboard
  }

  private static let acquisitionOrder: [Mode] = [.rawMode, .altScreen]
  private static let supportedModes: Set<Mode> = Set(acquisitionOrder)

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
  }

  /// Enters all requested modes in canonical acquisition order.
  public func enter(_ modes: Set<Mode>) async throws {
    let unsupportedModes = modes.subtracting(Self.supportedModes)
    guard unsupportedModes.isEmpty else {
      throw ModeLifecycleError.unsupportedModes(unsupportedModes)
    }

    let overlappingModes = self.modes.intersection(modes)
    guard overlappingModes.isEmpty else {
      throw ModeLifecycleError.modesAlreadyActive(overlappingModes)
    }

    requestedModes = modes
    var acquiredModes: [Mode] = []

    do {
      for mode in Self.acquisitionOrder where modes.contains(mode) {
        try await enable(mode)
        acquiredModes.append(mode)
        acquisitionStack.append(mode)
        self.modes.insert(mode)
      }
    } catch {
      await rollback(acquiredModes)
      requestedModes = []
      throw error
    }
  }

  /// Exits believed/requested modes in reverse acquisition order.
  public func exit() async throws {
    let cleanupModes = modes.union(requestedModes)
    var firstError: (any Error)?

    for mode in Self.acquisitionOrder.reversed() where cleanupModes.contains(mode) {
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

    case .mouseTracking, .bracketedPaste, .focusEvents, .kittyKeyboard:
      throw ModeLifecycleError.unsupportedModes([mode])
    }
  }

  private func enable(_ mode: Mode) async throws {
    switch mode {
    case .rawMode:
      try await io.enableRawMode()

    case .altScreen:
      try await io.enableAltScreen()

    case .mouseTracking, .bracketedPaste, .focusEvents, .kittyKeyboard:
      throw ModeLifecycleError.unsupportedModes([mode])
    }
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
