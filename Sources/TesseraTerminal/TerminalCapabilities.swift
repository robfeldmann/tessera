import TesseraTerminalANSI
import TesseraTerminalIO
import TesseraTerminalInput

/// Advisory support status for a terminal protocol or feature.
public enum CapabilityStatus: Equatable, Sendable {
  /// Tessera knows there is no standard active probe for this capability.
  case notDetectable

  /// Tessera has sent an active probe and has not yet observed a conclusive response.
  case probing

  /// Tessera observed protocol-native evidence that the capability works.
  case supported

  /// Tessera has no reliable protocol-native evidence for this capability.
  case unknown

  /// Tessera observed protocol-native evidence that the capability is unavailable.
  case unsupported
}

/// Passive identity hint for the terminal or multiplexer around Tessera.
public struct TerminalIdentity: Equatable, Sendable {
  /// No known terminal identity.
  public static var unknown: Self {
    Self()
  }

  /// The terminal kind inferred from local hints.
  public var kind: TerminalIdentityKind

  /// The hint that produced `kind`.
  public var source: TerminalIdentitySource

  /// A version string when the source provides one.
  public var version: String?

  /// Creates a terminal identity hint.
  public init(
    kind: TerminalIdentityKind = .unknown,
    source: TerminalIdentitySource = .none,
    version: String? = nil
  ) {
    self.kind = kind
    self.source = source
    self.version = version
  }
}

/// Known terminal identity categories Tessera can infer passively.
public enum TerminalIdentityKind: Equatable, Sendable {
  case appleTerminal
  case dumb
  case foot
  case ghostty
  case iTerm2
  case kitty
  case other(String)
  case screen
  case tmux
  case unknown
  case wezTerm
  case windowsTerminal
  case xterm
}

/// The local hint that produced a terminal identity.
public enum TerminalIdentitySource: Equatable, Sendable {
  case environmentVariable(name: String, value: String)
  case none
  case term(String)
  case termProgram(String)
  case windowsTerminalSession
}

/// Conservative, inspectable terminal capability hints.
public struct TerminalCapabilities: Equatable, Sendable {
  /// Conservative unknown capabilities used when detection is disabled or unavailable.
  public static var conservativeDefault: Self {
    Self()
  }

  /// Conservative unknown capabilities used when detection is disabled or unavailable.
  public static var unknown: Self {
    conservativeDefault
  }

  /// Bracketed paste advisory support.
  public var bracketedPaste: CapabilityStatus

  /// Focus event advisory support.
  public var focusEvents: CapabilityStatus

  /// Mouse tracking advisory support.
  public var mouseTracking: CapabilityStatus

  /// Kitty Graphics Protocol advisory support.
  public var kittyGraphics: CapabilityStatus

  /// Kitty keyboard advisory support.
  public var kittyKeyboard: CapabilityStatus

  /// OSC 8 hyperlink advisory support.
  public var osc8Hyperlinks: CapabilityStatus

  /// OSC 52 clipboard advisory support.
  public var osc52Clipboard: CapabilityStatus

  /// DEC synchronized output advisory support.
  public var synchronizedOutput: CapabilityStatus

  /// Terminfo-database declarations for extended underline style and color output.
  ///
  /// These declarations are advisory compatibility metadata, not protocol support proof.
  public var underlineDeclarations: TerminfoUnderlineDeclarations
  /// Protocol-native DECRQM evidence keyed by DEC private mode number.
  ///
  /// Tessera records only the modes it queries for application protocol support. A
  /// recognized set/reset state proves that the mode is queryable; it does not override
  /// explicit application policy.
  public var privateModeStates: [Int: PrivateModeState]

  /// Terminal color advisory support.
  public var color: ColorCapability

  /// Best passive terminal identity hint.
  public var identity: TerminalIdentity

  /// Whether local hints indicate a nested multiplexer environment.
  public var isNested: Bool

  /// Creates terminal capability hints.
  public init(
    bracketedPaste: CapabilityStatus = .unknown,
    focusEvents: CapabilityStatus = .unknown,
    mouseTracking: CapabilityStatus = .unknown,
    kittyGraphics: CapabilityStatus = .unknown,
    kittyKeyboard: CapabilityStatus = .unknown,
    osc8Hyperlinks: CapabilityStatus = .unknown,
    osc52Clipboard: CapabilityStatus = .notDetectable,
    synchronizedOutput: CapabilityStatus = .unknown,
    underlineDeclarations: TerminfoUnderlineDeclarations = .unknown,
    privateModeStates: [Int: PrivateModeState] = [:],
    color: ColorCapability = .unknown,
    identity: TerminalIdentity = .unknown,
    isNested: Bool = false
  ) {
    self.bracketedPaste = bracketedPaste
    self.focusEvents = focusEvents
    self.mouseTracking = mouseTracking
    self.kittyGraphics = kittyGraphics
    self.kittyKeyboard = kittyKeyboard
    self.osc8Hyperlinks = osc8Hyperlinks
    self.osc52Clipboard = osc52Clipboard
    self.synchronizedOutput = synchronizedOutput
    self.underlineDeclarations = underlineDeclarations
    self.privateModeStates = privateModeStates
    self.color = color
    self.identity = identity
    self.isNested = isNested
  }
}

extension TerminalCapabilities {
  private static let probedPrivateModeNumbers: Set<Int> = [
    1_002, 1_003, 1_004, 1_006, 2_004, 2_026,
  ]

  private static func capabilityStatus(
    for requiredModes: [Int],
    in evidence: [Int: PrivateModeState]
  ) -> CapabilityStatus {
    if requiredModes.contains(where: { evidence[$0] == .notRecognized }) {
      return .unsupported
    }
    guard requiredModes.allSatisfy({ evidence[$0] != nil }) else {
      return .unknown
    }
    return .supported
  }

  package mutating func recordPrivateModeStatus(_ status: PrivateModeStatus) {
    guard Self.probedPrivateModeNumbers.contains(status.mode) else {
      return
    }
    privateModeStates[status.mode] = status.state
    reconcilePrivateModeCapabilities()
  }

  package mutating func applyActiveProbeEvidence(
    _ evidence: ActiveCapabilityProbeEvidence
  ) {
    for (mode, state) in evidence.privateModes {
      recordPrivateModeStatus(PrivateModeStatus(mode: mode, state: state))
    }
    kittyGraphics = evidence.kittyGraphics
    kittyKeyboard = evidence.kittyKeyboard
    reconcilePrivateModeCapabilities()
  }

  private mutating func reconcilePrivateModeCapabilities() {
    bracketedPaste = Self.capabilityStatus(for: [2_004], in: privateModeStates)
    focusEvents = Self.capabilityStatus(for: [1_004], in: privateModeStates)
    mouseTracking = Self.capabilityStatus(
      for: [1_002, 1_003, 1_006],
      in: privateModeStates
    )
    synchronizedOutput = Self.capabilityStatus(for: [2_026], in: privateModeStates)
  }
}
