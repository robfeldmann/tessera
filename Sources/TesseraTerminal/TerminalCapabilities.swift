import TesseraTerminalANSI

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
    self.color = color
    self.identity = identity
    self.isNested = isNested
  }
}
