import CustomDump
import TesseraTerminalIO
import Testing

@testable import TesseraTerminal

@Test
func `empty passive environment yields conservative unknown capabilities`() {
  expectNoDifference(
    TerminalCapabilityDetector.detect(environment: [:]),
    .conservativeDefault
  )
}

@Test(arguments: modernTerminalCases)
private func `modern terminals keep kitty graphics unknown`(
  _ testCase: ModernTerminalCase
) {
  let capabilities = TerminalCapabilityDetector.detect(environment: testCase.environment)

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .supported,
      focusEvents: .supported,
      mouseTracking: .supported,
      kittyGraphics: .unknown,
      kittyKeyboard: .supported,
      osc8Hyperlinks: .supported,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: testCase.identity,
      isNested: false
    )
  )
}

@Test(arguments: passiveKittyGraphicsStatusCases)
private func `passive detection does not infer kitty graphics from named terminals`(
  _ testCase: PassiveKittyGraphicsStatusCase
) {
  let capabilities = TerminalCapabilityDetector.detect(environment: testCase.environment)

  #expect(capabilities.kittyGraphics == testCase.status)
}

@Test(arguments: nestedTerminalCases)
private func `nested multiplexer hints keep protocol and kitty graphics support unknown`(
  _ testCase: NestedTerminalCase
) {
  let capabilities = TerminalCapabilityDetector.detect(environment: testCase.environment)

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .indexed256,
      identity: testCase.identity,
      isNested: true
    )
  )
}

@Test
func `NO_COLOR wins over true-color environment hints`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: [
      "COLORTERM": "truecolor",
      "NO_COLOR": "1",
      "TERM": "xterm-256color",
    ]
  )

  #expect(capabilities.color == .noColor)
}

@Test(arguments: colorCapabilityCases)
private func `color hints map to the advertised color capability`(
  _ testCase: ColorCapabilityCase
) {
  let capabilities = TerminalCapabilityDetector.detect(environment: testCase.environment)

  #expect(capabilities.color == testCase.color)
}

@Test
func `unknown terminal protocols remain unknown instead of unsupported`() {
  let capabilities = TerminalCapabilityDetector.detect(environment: ["TERM": "vt100"])

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .ansi16,
      identity: .unknown,
      isNested: false
    )
  )
}

@Test
func `contradictory dumb TERM keeps protocol support unknown despite Ghostty identity`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: [
      "TERM": "dumb",
      "TERM_PROGRAM": "Ghostty",
      "TERM_PROGRAM_VERSION": "1.3.2",
    ]
  )

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .ghostty,
        source: .termProgram("Ghostty"),
        version: "1.3.2"
      ),
      isNested: false
    )
  )
}

@Test(arguments: assumedModernTerminalCases)
private func `known terminals keep kitty graphics and keyboard confidence unknown`(
  _ testCase: ModernTerminalCase
) {
  let capabilities = TerminalCapabilityDetector.detect(environment: testCase.environment)

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .supported,
      focusEvents: .supported,
      mouseTracking: .supported,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .supported,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: testCase.identity,
      isNested: false
    )
  )
}

@Test
func `xterm reports kitty graphics unknown`() {
  let capabilities = TerminalCapabilityDetector.detect(environment: ["TERM": "xterm"])

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .supported,
      focusEvents: .supported,
      mouseTracking: .supported,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .ansi16,
      identity: TerminalIdentity(kind: .xterm, source: .term("xterm")),
      isNested: false
    )
  )
}

@Test
func `Apple Terminal reports kitty graphics unknown`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: ["TERM_PROGRAM": "Apple_Terminal"]
  )

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .supported,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .appleTerminal,
        source: .termProgram("Apple_Terminal")
      ),
      isNested: false
    )
  )
}

@Test
func `KONSOLE_VERSION hint identifies Konsole without protocol confidence`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: ["KONSOLE_VERSION": "23.08.4"]
  )

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .other("Konsole"),
        source: .environmentVariable(name: "KONSOLE_VERSION", value: "23.08.4")
      ),
      isNested: false
    )
  )
}

@Test
func `VTE_VERSION hint identifies VTE without protocol confidence`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: ["VTE_VERSION": "6800"]
  )

  expectNoDifference(
    capabilities,
    TerminalCapabilities(
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .unknown,
      synchronizedOutput: .unknown,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .other("VTE"),
        source: .environmentVariable(name: "VTE_VERSION", value: "6800")
      ),
      isNested: false
    )
  )
}

@Test
func `kitty-if-available intent resolves application modes when support is unknown`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(
    resolution,
    TerminalApplicationResolution(
      capabilities: .conservativeDefault,
      enabledProtocolModes: baseApplicationModes.union([.kittyKeyboard]),
      hyperlinkRendering: .enabled,
      modes: baseApplicationModes.union([.kittyKeyboard]),
      synchronizedOutput: .enabled
    )
  )
}

@Test
func `button-event mouse intent adds mouse tracking mode`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .buttonEvents,
    keyboardProtocol: .legacyOnly,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(
    resolution.modes,
    baseApplicationModes.union([.mouseTracking(.buttonEvents)])
  )
}

@Test
func `legacy keyboard intent excludes kitty keyboard mode`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .legacyOnly,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(environment: ["TERM_PROGRAM": "Kitty"])

  #expect(resolution.modes.contains(.kittyKeyboard) == false)
}

@Test
func `disabled paste and focus intent omits paste and focus modes`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: false,
    enableFocusEvents: false,
    mouseTracking: .disabled,
    keyboardProtocol: .legacyOnly,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(resolution.modes, Set([.rawMode, .altScreen]))
}

@Test
func `disabled capability detection resolves conservative unknown capabilities`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .disabled,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(
    environment: [
      "TERM_PROGRAM": "Ghostty",
      "TERM_PROGRAM_VERSION": "1.3.2",
    ]
  )

  expectNoDifference(resolution.capabilities, .conservativeDefault)
}

@Test
func `dumb terminal marks kitty graphics unsupported`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(environment: ["TERM": "dumb"])

  expectNoDifference(
    resolution.capabilities,
    TerminalCapabilities(
      bracketedPaste: .unsupported,
      focusEvents: .unsupported,
      mouseTracking: .unsupported,
      kittyGraphics: .unsupported,
      kittyKeyboard: .unsupported,
      osc8Hyperlinks: .unsupported,
      synchronizedOutput: .unsupported,
      color: .noColor,
      identity: TerminalIdentity(kind: .dumb, source: .term("dumb")),
      isNested: false
    )
  )
  expectNoDifference(resolution.modes, baseApplicationModes)
}

@Test
func `kitty-required intent requests kitty keyboard with unknown capabilities`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyRequired,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(environment: [:])

  #expect(resolution.modes.contains(.kittyKeyboard))
}

private let baseApplicationModes: Set<ModeLifecycle.Mode> = [
  .altScreen,
  .bracketedPaste,
  .focusEvents,
  .rawMode,
]

private let colorCapabilityCases = [
  ColorCapabilityCase(
    environment: ["COLORTERM": "truecolor"],
    color: .truecolor
  ),
  ColorCapabilityCase(
    environment: ["TERM": "xterm-24bit"],
    color: .truecolor
  ),
  ColorCapabilityCase(
    environment: ["TERM": "xterm-256color"],
    color: .indexed256
  ),
]

private let modernTerminalCases = [
  ModernTerminalCase(
    environment: [
      "TERM_PROGRAM": "Ghostty",
      "TERM_PROGRAM_VERSION": "1.3.2",
    ],
    identity: TerminalIdentity(
      kind: .ghostty,
      source: .termProgram("Ghostty"),
      version: "1.3.2"
    )
  ),
  ModernTerminalCase(
    environment: ["TERM_PROGRAM": "WezTerm"],
    identity: TerminalIdentity(kind: .wezTerm, source: .termProgram("WezTerm"))
  ),
  ModernTerminalCase(
    environment: ["TERM_PROGRAM": "kitty"],
    identity: TerminalIdentity(kind: .kitty, source: .termProgram("kitty"))
  ),
]

private let nestedTerminalCases = [
  NestedTerminalCase(
    environment: [
      "TERM": "tmux-256color",
      "TMUX": "/private/tmp/tmux-501/default,123,0",
    ],
    identity: TerminalIdentity(kind: .tmux, source: .term("tmux-256color"))
  ),
  NestedTerminalCase(
    environment: [
      "STY": "1234.pts-0.host",
      "TERM": "screen-256color",
    ],
    identity: TerminalIdentity(kind: .screen, source: .term("screen-256color"))
  ),
]

private let assumedModernTerminalCases = [
  ModernTerminalCase(
    environment: ["WT_SESSION": "abc123"],
    identity: TerminalIdentity(kind: .windowsTerminal, source: .windowsTerminalSession)
  ),
  ModernTerminalCase(
    environment: ["TERM_PROGRAM": "iTerm.app"],
    identity: TerminalIdentity(kind: .iTerm2, source: .termProgram("iTerm.app"))
  ),
  ModernTerminalCase(
    environment: ["TERM": "foot"],
    identity: TerminalIdentity(kind: .foot, source: .term("foot"))
  ),
]

private let passiveKittyGraphicsStatusCases = [
  PassiveKittyGraphicsStatusCase(
    name: "Ghostty TERM_PROGRAM",
    environment: ["TERM_PROGRAM": "Ghostty"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "Ghostty TERM",
    environment: ["TERM": "ghostty"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "kitty TERM_PROGRAM",
    environment: ["TERM_PROGRAM": "kitty"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "kitty TERM",
    environment: ["TERM": "xterm-kitty"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "WezTerm TERM_PROGRAM",
    environment: ["TERM_PROGRAM": "WezTerm"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "WezTerm TERM",
    environment: ["TERM": "wezterm"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "iTerm2 TERM_PROGRAM",
    environment: ["TERM_PROGRAM": "iTerm.app"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "Windows Terminal",
    environment: ["WT_SESSION": "abc123"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "foot TERM",
    environment: ["TERM": "foot"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "xterm TERM",
    environment: ["TERM": "xterm"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "Apple Terminal TERM_PROGRAM",
    environment: ["TERM_PROGRAM": "Apple_Terminal"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "Konsole VERSION",
    environment: ["KONSOLE_VERSION": "23.08.4"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "VTE VERSION",
    environment: ["VTE_VERSION": "6800"],
    status: .unknown
  ),
  PassiveKittyGraphicsStatusCase(
    name: "dumb TERM",
    environment: ["TERM": "dumb"],
    status: .unsupported
  ),
  PassiveKittyGraphicsStatusCase(
    name: "dumb-prefixed TERM",
    environment: ["TERM": "dumb-ansi"],
    status: .unsupported
  ),
]

private struct PassiveKittyGraphicsStatusCase: CustomStringConvertible, Sendable {
  let name: String
  let environment: [String: String]
  let status: CapabilityStatus

  var description: String {
    name
  }
}

private struct ColorCapabilityCase: CustomStringConvertible, Sendable {
  let environment: [String: String]
  let color: ColorCapability

  var description: String {
    String(describing: color)
  }
}

private struct ModernTerminalCase: CustomStringConvertible, Sendable {
  let environment: [String: String]
  let identity: TerminalIdentity

  var description: String {
    String(describing: identity.kind)
  }
}

private struct NestedTerminalCase: CustomStringConvertible, Sendable {
  let environment: [String: String]
  let identity: TerminalIdentity

  var description: String {
    String(describing: identity.kind)
  }
}
