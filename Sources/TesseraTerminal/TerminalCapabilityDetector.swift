import Foundation

/// Passive detector for advisory terminal capability hints.
package enum TerminalCapabilityDetector {
  private typealias ProtocolStatus = (
    bracketedPaste: CapabilityStatus,
    focusEvents: CapabilityStatus,
    mouseTracking: CapabilityStatus,
    kittyKeyboard: CapabilityStatus,
    osc8Hyperlinks: CapabilityStatus,
    synchronizedOutput: CapabilityStatus
  )
  package static func currentEnvironment() -> [String: String] {
    ProcessInfo.processInfo.environment
  }

  package static func detectCurrentEnvironment() -> TerminalCapabilities {
    detect(environment: currentEnvironment())
  }

  package static func detect(environment: [String: String]) -> TerminalCapabilities {
    let identity = identity(from: environment)
    let isNested = isNestedEnvironment(environment)
    let color = colorCapability(from: environment, identity: identity)
    let status = protocolStatus(
      identity: identity,
      environment: environment,
      isNested: isNested
    )

    return TerminalCapabilities(
      bracketedPaste: status.bracketedPaste,
      focusEvents: status.focusEvents,
      mouseTracking: status.mouseTracking,
      kittyKeyboard: status.kittyKeyboard,
      osc8Hyperlinks: status.osc8Hyperlinks,
      synchronizedOutput: status.synchronizedOutput,
      color: color,
      identity: identity,
      isNested: isNested
    )
  }

  private static func colorCapability(
    from environment: [String: String],
    identity: TerminalIdentity
  ) -> ColorCapability {
    if environment.keys.contains("NO_COLOR") || identity.kind == .dumb {
      return .noColor
    }

    let colorTerm = environmentValue("COLORTERM", in: environment)?.lowercased()
    if colorTerm == "truecolor" || colorTerm == "24bit" {
      return .truecolor
    }

    guard let term = environmentValue("TERM", in: environment)?.lowercased() else {
      return .unknown
    }

    if term.contains("truecolor") || term.contains("24bit") {
      return .truecolor
    }
    if term.contains("256color") {
      return .indexed256
    }

    let isBasicColorTerm =
      term.contains("color") || term.hasPrefix("ansi")
      || term.hasPrefix("vt") || term.hasPrefix("xterm")
    if isBasicColorTerm {
      return .ansi16
    }

    return .unknown
  }

  private static func environmentValue(
    _ name: String,
    in environment: [String: String]
  ) -> String? {
    guard let value = environment[name], !value.isEmpty else {
      return nil
    }
    return value
  }

  private static func identity(from environment: [String: String]) -> TerminalIdentity {
    if let termProgram = environmentValue("TERM_PROGRAM", in: environment) {
      let identity = identityFromTermProgram(
        termProgram,
        version: environmentValue("TERM_PROGRAM_VERSION", in: environment)
      )
      if let identity {
        return identity
      }
    }

    if environmentValue("WT_SESSION", in: environment) != nil {
      return TerminalIdentity(kind: .windowsTerminal, source: .windowsTerminalSession)
    }

    if let term = environmentValue("TERM", in: environment) {
      let kind = identityKindFromTerm(term)
      if let kind {
        return TerminalIdentity(kind: kind, source: .term(term))
      }
    }

    if let version = environmentValue("KONSOLE_VERSION", in: environment) {
      return TerminalIdentity(
        kind: .other("Konsole"),
        source: .environmentVariable(name: "KONSOLE_VERSION", value: version)
      )
    }

    if let version = environmentValue("VTE_VERSION", in: environment) {
      return TerminalIdentity(
        kind: .other("VTE"),
        source: .environmentVariable(name: "VTE_VERSION", value: version)
      )
    }

    return .unknown
  }

  private static func identityFromTermProgram(
    _ termProgram: String,
    version: String?
  ) -> TerminalIdentity? {
    let normalized = termProgram.lowercased()
    let kind: TerminalIdentityKind
    switch normalized {
    case "apple_terminal":
      kind = .appleTerminal
    case "ghostty":
      kind = .ghostty
    case "iterm.app", "iterm2":
      kind = .iTerm2
    case "kitty":
      kind = .kitty
    case "wezterm":
      kind = .wezTerm
    default:
      return nil
    }

    return TerminalIdentity(
      kind: kind,
      source: .termProgram(termProgram),
      version: version
    )
  }

  private static func identityKindFromTerm(_ term: String) -> TerminalIdentityKind? {
    let normalized = term.lowercased()
    if normalized == "dumb" || normalized.hasPrefix("dumb-") {
      return .dumb
    }
    if normalized.contains("ghostty") {
      return .ghostty
    }
    if normalized.contains("kitty") {
      return .kitty
    }
    if normalized.hasPrefix("foot") {
      return .foot
    }
    if normalized.hasPrefix("screen") {
      return .screen
    }
    if normalized.hasPrefix("tmux") {
      return .tmux
    }
    if normalized.hasPrefix("wezterm") {
      return .wezTerm
    }
    if normalized.hasPrefix("xterm") {
      return .xterm
    }
    return nil
  }

  private static func isNestedEnvironment(_ environment: [String: String]) -> Bool {
    let hasNestedVariable =
      environmentValue("TMUX", in: environment) != nil
      || environmentValue("STY", in: environment) != nil
    if hasNestedVariable {
      return true
    }

    guard let term = environmentValue("TERM", in: environment)?.lowercased() else {
      return false
    }
    return term.hasPrefix("screen") || term.hasPrefix("tmux")
  }

  private static func protocolStatus(
    identity: TerminalIdentity,
    environment: [String: String],
    isNested: Bool
  ) -> ProtocolStatus {
    if identity.kind == .dumb {
      return (
        bracketedPaste: .unsupported,
        focusEvents: .unsupported,
        mouseTracking: .unsupported,
        kittyKeyboard: .unsupported,
        osc8Hyperlinks: .unsupported,
        synchronizedOutput: .unsupported
      )
    }

    if isNested || hasContradictoryDumbTerm(identity: identity, environment: environment) {
      return unknownProtocolStatus()
    }

    switch identity.kind {
    case .ghostty, .kitty, .wezTerm:
      return (
        bracketedPaste: .supported,
        focusEvents: .supported,
        mouseTracking: .supported,
        kittyKeyboard: .supported,
        osc8Hyperlinks: .supported,
        synchronizedOutput: .unknown
      )

    case .foot, .iTerm2, .windowsTerminal:
      return (
        bracketedPaste: .supported,
        focusEvents: .supported,
        mouseTracking: .supported,
        kittyKeyboard: .unknown,
        osc8Hyperlinks: .supported,
        synchronizedOutput: .unknown
      )

    case .xterm:
      return (
        bracketedPaste: .supported,
        focusEvents: .supported,
        mouseTracking: .supported,
        kittyKeyboard: .unknown,
        osc8Hyperlinks: .unknown,
        synchronizedOutput: .unknown
      )

    case .appleTerminal:
      return (
        bracketedPaste: .supported,
        focusEvents: .unknown,
        mouseTracking: .unknown,
        kittyKeyboard: .unknown,
        osc8Hyperlinks: .unknown,
        synchronizedOutput: .unknown
      )

    case .dumb, .other, .screen, .tmux, .unknown:
      return unknownProtocolStatus()
    }
  }

  private static func hasContradictoryDumbTerm(
    identity: TerminalIdentity,
    environment: [String: String]
  ) -> Bool {
    guard let term = environmentValue("TERM", in: environment)?.lowercased() else {
      return false
    }
    return (term == "dumb" || term.hasPrefix("dumb-"))
      && identity.kind != .dumb
      && identity.kind != .unknown
  }

  private static func unknownProtocolStatus() -> ProtocolStatus {
    (
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown
    )
  }
}
