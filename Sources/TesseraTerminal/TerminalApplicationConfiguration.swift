import TesseraTerminalANSI
import TesseraTerminalIO

/// Controls whether terminal capabilities are detected before startup.
public enum CapabilityDetectionMode: Equatable, Sendable {
  /// Inspect local hints and send bounded protocol-native probes after startup.
  case active

  /// Do not inspect local capability hints.
  case disabled

  /// Inspect local process-environment hints only.
  case passive
}

/// Controls OSC 52 clipboard write emission.
public enum ClipboardWriteMode: Equatable, Sendable {
  /// Do not emit OSC 52 clipboard writes.
  case disabled

  /// Emit OSC 52 clipboard writes that satisfy the supplied policy.
  case enabled(ClipboardWritePolicy)
}

/// Policy gates for OSC 52 clipboard writes.
public struct ClipboardWritePolicy: Equatable, Sendable {
  /// Conservative enabled preset: 64 KiB raw cap, clipboard-only, no nested passthrough.
  public static let `default` = Self()

  /// Maximum raw payload size before base64 encoding.
  public var maximumPayloadBytes: Int

  /// Clipboard selections the application may write.
  public var allowedTargets: Set<ClipboardTarget>

  /// Whether writes may pass through nested terminal multiplexers.
  public var allowsNestedTerminalPassthrough: Bool

  /// Creates OSC 52 clipboard write policy gates.
  public init(
    maximumPayloadBytes: Int = 64 * 1_024,
    allowedTargets: Set<ClipboardTarget> = [.clipboard],
    allowsNestedTerminalPassthrough: Bool = false
  ) {
    self.maximumPayloadBytes = maximumPayloadBytes
    self.allowedTargets = allowedTargets
    self.allowsNestedTerminalPassthrough = allowsNestedTerminalPassthrough
  }
}

/// Controls the effective color capability used by renderer SGR emission.
public enum ColorCapabilityOverride: Equatable, Sendable {
  /// Use the color capability detected from local terminal hints.
  case detect

  /// Use an application-selected color capability unless user environment disables color.
  case force(ColorCapability)
}

/// Controls session-owned cursor shape and color styling.
public enum CursorStylingPolicy: Equatable, Sendable {
  /// Tessera emits no DECSCUSR/OSC 12/OSC 112 bytes and ignores cursor style requests.
  case disabled

  /// Tessera owns cursor styling. `default` is applied when no focused component or
  /// runtime request overrides it; `.enabled(default: nil)` owns styling for future
  /// dynamic requests but emits nothing at startup.
  case enabled(default: CursorStyle?)
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
  /// Enable Kitty keyboard only after active probes report support.
  case kittyIfAvailable

  /// Always request Kitty keyboard.
  case kittyRequired

  /// Never enable Kitty keyboard; parse legacy input only.
  case legacyOnly
}

/// Controls application mouse tracking.
public enum MouseTrackingMode: Equatable, Sendable {
  /// Enable any-event mouse tracking, including hover motion.
  case anyEvent

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

  /// OSC 52 clipboard write policy.
  public var clipboardWriting: ClipboardWriteMode

  /// Cursor shape and color styling policy.
  public var cursorStyling: CursorStylingPolicy

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

  /// Application override for renderer color degradation policy.
  public var colorCapability: ColorCapabilityOverride

  private var modeSelection: ModeSelection

  /// Creates a terminal application configuration from protocol intent.
  public init(
    capabilityDetection: CapabilityDetectionMode = .passive,
    enableBracketedPaste: Bool = true,
    enableFocusEvents: Bool = true,
    mouseTracking: MouseTrackingMode = .disabled,
    keyboardProtocol: KeyboardProtocolMode = .kittyIfAvailable,
    hyperlinkRendering: HyperlinkRenderingMode = .enabled,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled,
    colorCapability: ColorCapabilityOverride = .detect,
    clipboardWriting: ClipboardWriteMode = .disabled,
    cursorStyling: CursorStylingPolicy = .disabled
  ) {
    self.capabilityDetection = capabilityDetection
    self.clipboardWriting = clipboardWriting
    self.cursorStyling = cursorStyling
    self.enableBracketedPaste = enableBracketedPaste
    self.enableFocusEvents = enableFocusEvents
    self.hyperlinkRendering = hyperlinkRendering
    self.keyboardProtocol = keyboardProtocol
    self.mouseTracking = mouseTracking
    self.synchronizedOutput = synchronizedOutput
    self.colorCapability = colorCapability
    self.modeSelection = .intent
  }

  /// Creates a terminal application configuration from an exact mode set.
  public init(
    modes: Set<ModeLifecycle.Mode>,
    synchronizedOutput: SynchronizedOutputPolicy = .enabled,
    colorCapability: ColorCapabilityOverride = .detect,
    clipboardWriting: ClipboardWriteMode = .disabled
  ) {
    self.capabilityDetection = .passive
    self.clipboardWriting = clipboardWriting
    self.cursorStyling =
      if let cursorStyle = Self.requestedCursorStyle(in: modes) {
        .enabled(default: cursorStyle)
      } else {
        .disabled
      }
    self.enableBracketedPaste = modes.contains(.bracketedPaste)
    self.enableFocusEvents = modes.contains(.focusEvents)
    self.hyperlinkRendering = .enabled
    self.keyboardProtocol = modes.contains(.kittyKeyboard) ? .kittyRequired : .legacyOnly
    self.mouseTracking =
      switch Self.requestedMouseTracking(in: modes) {
      case .anyEvent:
        .anyEvent
      case .buttonEvents:
        .buttonEvents
      case nil:
        .disabled
      }
    self.synchronizedOutput = synchronizedOutput
    self.modeSelection = .explicit(Self.normalized(modes))
    self.colorCapability = colorCapability
  }

  private static func normalized(
    _ modes: Set<ModeLifecycle.Mode>
  ) -> Set<ModeLifecycle.Mode> {
    var normalizedModes = modes.filter { mode in
      switch mode {
      case .mouseTracking, .cursorStyle:
        return false
      case .altScreen, .bracketedPaste, .focusEvents, .kittyKeyboard, .rawMode:
        return true
      }
    }

    if let mouseTracking = requestedMouseTracking(in: modes) {
      normalizedModes.insert(.mouseTracking(mouseTracking))
    }

    if let cursorStyle = requestedCursorStyle(in: modes) {
      normalizedModes.insert(.cursorStyle(cursorStyle))
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
      case .altScreen, .bracketedPaste, .cursorStyle, .focusEvents, .kittyKeyboard,
        .rawMode:
        continue
      }
    }
    return requestedButtonEvents ? .buttonEvents : nil
  }

  /// Selects one requested cursor style deterministically when multiple payloads reach the
  /// configuration. Cursor styles have no broadest-wins superset, so ties are resolved by
  /// a private ordering over shape first, then RGB color components, with nil facets last.
  private static func requestedCursorStyle(
    in modes: Set<ModeLifecycle.Mode>
  ) -> CursorStyle? {
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

  private static func cursorStyleSortValue(
    _ style: CursorStyle
  ) -> (Int, Int, Int, Int) {
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

  package func resolve(environment: [String: String]) -> TerminalApplicationResolution {
    let detectedCapabilities: TerminalCapabilities
    let runsActiveProbes: Bool
    switch capabilityDetection {
    case .active:
      detectedCapabilities = TerminalCapabilityDetector.detect(environment: environment)
        .preparingActiveProbes()
      runsActiveProbes = true
    case .disabled:
      detectedCapabilities = .conservativeDefault
      runsActiveProbes = false
    case .passive:
      detectedCapabilities = TerminalCapabilityDetector.detect(environment: environment)
      runsActiveProbes = false
    }
    return resolve(
      capabilities: detectedCapabilities,
      runsActiveProbes: runsActiveProbes,
      preservesDetectedNoColor: detectedCapabilities.color == .noColor
    )
  }

  package func resolve(
    capabilities: TerminalCapabilities
  ) -> TerminalApplicationResolution {
    resolve(
      capabilities: capabilities,
      runsActiveProbes: false,
      preservesDetectedNoColor: false
    )
  }

  private func resolve(
    capabilities: TerminalCapabilities,
    runsActiveProbes: Bool,
    preservesDetectedNoColor: Bool
  ) -> TerminalApplicationResolution {
    // A no-color signal observed by the environment detector overrides any
    // application `force`. The package `resolve(capabilities:)` entry point
    // passes no such signal, so it trusts the supplied capabilities verbatim.
    var resolvedCapabilities = capabilities
    resolvedCapabilities.color = resolvedColorCapability(
      detected: capabilities.color,
      preservesDetectedNoColor: preservesDetectedNoColor
    )

    let modes =
      switch modeSelection {
      case .explicit(let modes):
        Self.normalized(modes)
      case .intent:
        resolvedIntentModes(capabilities: resolvedCapabilities)
      }

    return TerminalApplicationResolution(
      capabilities: resolvedCapabilities,
      clipboardWriting: clipboardWriting,
      cursorStyling: cursorStyling,
      cursorStyle: Self.requestedCursorStyle(in: modes),
      enabledProtocolModes: modes,
      hyperlinkRendering: hyperlinkRendering,
      modes: modes,
      runsActiveProbes: runsActiveProbes,
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
    switch mouseTracking {
    case .anyEvent:
      modes.insert(.mouseTracking(.anyEvent))
    case .buttonEvents:
      modes.insert(.mouseTracking(.buttonEvents))
    case .disabled:
      break
    }

    switch keyboardProtocol {
    case .kittyIfAvailable where capabilities.kittyKeyboard == .supported:
      modes.insert(.kittyKeyboard)
    case .kittyRequired:
      modes.insert(.kittyKeyboard)
    case .kittyIfAvailable, .legacyOnly:
      break
    }

    if case .enabled(let defaultStyle) = cursorStyling, let defaultStyle {
      if defaultStyle.shape != nil || defaultStyle.color != nil {
        modes.insert(.cursorStyle(defaultStyle))
      }
    }

    return modes
  }

  private func resolvedColorCapability(
    detected: ColorCapability,
    preservesDetectedNoColor: Bool
  ) -> ColorCapability {
    if preservesDetectedNoColor {
      return .noColor
    }

    switch colorCapability {
    case .detect:
      return detected
    case .force(let forced):
      return forced
    }
  }
}

package struct TerminalApplicationResolution: Equatable, Sendable {
  package var capabilities: TerminalCapabilities
  package var clipboardWriting: ClipboardWriteMode
  package var cursorStyling: CursorStylingPolicy
  package var cursorStyle: CursorStyle?
  package var enabledProtocolModes: Set<ModeLifecycle.Mode>
  package var hyperlinkRendering: HyperlinkRenderingMode
  package var modes: Set<ModeLifecycle.Mode>
  package var runsActiveProbes: Bool
  package var synchronizedOutput: SynchronizedOutputPolicy
}

private enum ModeSelection: Equatable, Sendable {
  case explicit(Set<ModeLifecycle.Mode>)
  case intent
}

extension TerminalCapabilities {
  package func preparingActiveProbes() -> Self {
    var capabilities = self
    capabilities.bracketedPaste = .probing
    capabilities.focusEvents = .probing
    capabilities.mouseTracking = .probing
    capabilities.kittyKeyboard = .probing
    capabilities.synchronizedOutput = .probing
    capabilities.osc8Hyperlinks = .notDetectable
    capabilities.osc52Clipboard = .notDetectable
    return capabilities
  }
}
