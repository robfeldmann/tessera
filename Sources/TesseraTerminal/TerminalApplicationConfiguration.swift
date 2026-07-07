import TesseraTerminalANSI
import TesseraTerminalIO

/// Controls whether terminal capabilities are detected before startup.
public enum CapabilityDetectionMode: Equatable, Sendable {
  /// Do not inspect local capability hints.
  case disabled

  /// Inspect local process-environment hints only.
  case passive
}

/// Controls OSC 8 hyperlink rendering.
public enum HyperlinkRenderingMode: Equatable, Sendable {
  /// Do not encode OSC 8 hyperlink sequences.
  case disabled

  /// Encode OSC 8 hyperlink sequences when frame styles contain hyperlink metadata.
  case enabled
}

/// Controls keyboard protocol enablement.
public enum KeyboardProtocolMode: Equatable, Sendable {
  /// Enable Kitty keyboard when passive hints say supported or unknown.
  case kittyIfAvailable

  /// Always request Kitty keyboard.
  case kittyRequired

  /// Never enable Kitty keyboard; parse legacy input only.
  case legacyOnly
}

/// Controls application mouse tracking.
public enum MouseTrackingMode: Equatable, Sendable {
  /// Enable button-event mouse tracking.
  case buttonEvents

  /// Do not enable mouse tracking.
  case disabled
}

/// Configuration for a scoped live terminal application session.
public struct TerminalApplicationConfiguration: Equatable, Sendable {
  /// The default terminal application configuration.
  public static var `default`: Self {
    Self()
  }

  /// Terminal modes to acquire for the session.
  ///
  /// This low-level view remains for tests and protocol demos that need exact mode sets.
  /// Intent-level configuration should prefer the explicit protocol fields below.
  public var modes: Set<ModeLifecycle.Mode> {
    get {
      switch modeSelection {
      case .explicit(let modes):
        return Self.normalized(modes)
      case .intent:
        return resolvedIntentModes(capabilities: .conservativeDefault)
      }
    }
    set {
      modeSelection = .explicit(Self.normalized(newValue))
    }
  }

  /// Whether capability detection runs before startup.
  public var capabilityDetection: CapabilityDetectionMode

  /// Whether bracketed paste mode should be enabled.
  public var enableBracketedPaste: Bool

  /// Whether focus events should be enabled.
  public var enableFocusEvents: Bool

  /// OSC 8 hyperlink rendering policy.
  public var hyperlinkRendering: HyperlinkRenderingMode

  /// Keyboard protocol policy.
  public var keyboardProtocol: KeyboardProtocolMode

  /// Mouse tracking policy.
  public var mouseTracking: MouseTrackingMode

  /// Whether draw transactions should use DEC synchronized output wrappers.
  public var synchronizedOutput: SynchronizedOutputPolicy

  private var modeSelection: ModeSelection

  /// Creates a terminal application configuration from protocol intent.
  public init(
    capabilityDetection: CapabilityDetectionMode = .passive,
    enableBracketedPaste: Bool = true,
    enableFocusEvents: Bool = true,
    mouseTracking: MouseTrackingMode = .disabled,
    keyboardProtocol: KeyboardProtocolMode = .kittyIfAvailable,
    hyperlinkRendering: HyperlinkRenderingMode = .enabled,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled
  ) {
    self.capabilityDetection = capabilityDetection
    self.enableBracketedPaste = enableBracketedPaste
    self.enableFocusEvents = enableFocusEvents
    self.hyperlinkRendering = hyperlinkRendering
    self.keyboardProtocol = keyboardProtocol
    self.mouseTracking = mouseTracking
    self.synchronizedOutput = synchronizedOutput
    self.modeSelection = .intent
  }

  /// Creates a terminal application configuration from an exact mode set.
  public init(
    modes: Set<ModeLifecycle.Mode>,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled
  ) {
    self.capabilityDetection = .passive
    self.enableBracketedPaste = modes.contains(.bracketedPaste)
    self.enableFocusEvents = modes.contains(.focusEvents)
    self.hyperlinkRendering = .enabled
    self.keyboardProtocol = modes.contains(.kittyKeyboard) ? .kittyRequired : .legacyOnly
    self.mouseTracking =
      Self.requestedMouseTracking(in: modes) == nil ? .disabled : .buttonEvents
    self.synchronizedOutput = synchronizedOutput
    self.modeSelection = .explicit(Self.normalized(modes))
  }

  private static func normalized(
    _ modes: Set<ModeLifecycle.Mode>
  ) -> Set<ModeLifecycle.Mode> {
    var normalizedModes = modes.filter { mode in
      if case .mouseTracking = mode {
        return false
      }
      return true
    }

    if let mouseTracking = requestedMouseTracking(in: modes) {
      normalizedModes.insert(.mouseTracking(mouseTracking))
    }
    return normalizedModes
  }

  private static func requestedMouseTracking(
    in modes: Set<ModeLifecycle.Mode>
  ) -> MouseTracking? {
    var requestedButtonEvents = false
    for mode in modes {
      switch mode {
      case .mouseTracking(.anyEvent):
        return .anyEvent
      case .mouseTracking(.buttonEvents):
        requestedButtonEvents = true
      case .altScreen, .bracketedPaste, .focusEvents, .kittyKeyboard, .rawMode:
        continue
      }
    }
    return requestedButtonEvents ? .buttonEvents : nil
  }

  package func resolve(environment: [String: String]) -> TerminalApplicationResolution {
    let capabilities: TerminalCapabilities =
      switch capabilityDetection {
      case .disabled:
        .conservativeDefault
      case .passive:
        TerminalCapabilityDetector.detect(environment: environment)
      }
    let modes =
      switch modeSelection {
      case .explicit(let modes):
        Self.normalized(modes)
      case .intent:
        resolvedIntentModes(capabilities: capabilities)
      }

    return TerminalApplicationResolution(
      capabilities: capabilities,
      enabledProtocolModes: modes,
      hyperlinkRendering: hyperlinkRendering,
      modes: modes,
      synchronizedOutput: synchronizedOutput
    )
  }

  private func resolvedIntentModes(
    capabilities: TerminalCapabilities
  ) -> Set<ModeLifecycle.Mode> {
    var modes: Set<ModeLifecycle.Mode> = [.rawMode, .altScreen]

    if enableBracketedPaste {
      modes.insert(.bracketedPaste)
    }
    if enableFocusEvents {
      modes.insert(.focusEvents)
    }
    if mouseTracking == .buttonEvents {
      modes.insert(.mouseTracking(.buttonEvents))
    }

    switch keyboardProtocol {
    case .kittyIfAvailable where capabilities.kittyKeyboard != .unsupported:
      modes.insert(.kittyKeyboard)
    case .kittyRequired:
      modes.insert(.kittyKeyboard)
    case .kittyIfAvailable, .legacyOnly:
      break
    }

    return modes
  }
}

package struct TerminalApplicationResolution: Equatable, Sendable {
  package var capabilities: TerminalCapabilities
  package var enabledProtocolModes: Set<ModeLifecycle.Mode>
  package var hyperlinkRendering: HyperlinkRenderingMode
  package var modes: Set<ModeLifecycle.Mode>
  package var synchronizedOutput: SynchronizedOutputPolicy
}

private enum ModeSelection: Equatable, Sendable {
  case explicit(Set<ModeLifecycle.Mode>)
  case intent
}
