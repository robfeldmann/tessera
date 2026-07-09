import CustomDump
import TesseraTerminalANSI
import TesseraTerminalIO
import Testing

@testable import TesseraTerminal

@Test
func `empty passive environment keeps protocols unknown`() {
  expectNoDifference(
    TerminalCapabilityDetector.detect(environment: [:]),
    TerminalCapabilities(osc8Hyperlinks: .notDetectable)
  )
}

@Test(arguments: namedTerminalProtocolCases)
private func `passive named terminals do not infer active protocol support`(
  _ testCase: NamedTerminalProtocolCase
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
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .unknown,
      color: testCase.color,
      identity: testCase.identity,
      isNested: false
    )
  )
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
      osc8Hyperlinks: .notDetectable,
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

@Test
func `dumb-family TERM suppresses color regardless of TERM_PROGRAM`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: ["TERM": "dumb-300", "TERM_PROGRAM": "Ghostty"]
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
func `color override wins when environment does not disable color`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.truecolor))

  let resolution = configuration.resolve(environment: [:])
  expectNoDifference(resolution.capabilities.color, .truecolor)
}

@Test
func `NO_COLOR environment wins over color override`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.truecolor))

  let resolution = configuration.resolve(
    environment: [
      "COLORTERM": "truecolor",
      "NO_COLOR": "1",
      "TERM": "xterm-256color",
    ]
  )

  expectNoDifference(resolution.capabilities.color, .noColor)
}

@Test
func `dumb TERM wins over color override`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.truecolor))

  let resolution = configuration.resolve(environment: ["TERM": "dumb"])

  expectNoDifference(resolution.capabilities.color, .noColor)
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
      osc8Hyperlinks: .notDetectable,
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
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .unknown,
      color: .noColor,
      identity: TerminalIdentity(
        kind: .ghostty,
        source: .termProgram("Ghostty"),
        version: "1.3.2"
      ),
      isNested: false
    )
  )
}

@Test
func `kitty-if-available intent omits kitty keyboard when support is unknown`() {
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
    resolution.capabilities,
    TerminalCapabilities(osc8Hyperlinks: .notDetectable)
  )
  expectNoDifference(resolution.enabledProtocolModes, baseApplicationModes)
  expectNoDifference(resolution.hyperlinkRendering, .enabled)
  expectNoDifference(resolution.modes, baseApplicationModes)
  expectNoDifference(resolution.runsActiveProbes, false)
  expectNoDifference(resolution.synchronizedOutput, .enabled)
}

@Test(arguments: kittyIfAvailableCapabilityCases)
private func `kitty-if-available intent only enables kitty keyboard for active support`(
  _ testCase: KittyIfAvailableCapabilityCase
) {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .passive,
    enableBracketedPaste: true,
    enableFocusEvents: true,
    mouseTracking: .disabled,
    keyboardProtocol: .kittyIfAvailable,
    hyperlinkRendering: .enabled,
    synchronizedOutput: .enabled
  )

  let resolution = configuration.resolve(
    capabilities: TerminalCapabilities(kittyKeyboard: testCase.status)
  )

  #expect(resolution.modes.contains(.kittyKeyboard) == testCase.enablesKittyKeyboard)
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
func `active detection marks protocols probing before support`() {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: .active,
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

  expectNoDifference(
    resolution.capabilities,
    TerminalCapabilities(
      bracketedPaste: .probing,
      focusEvents: .probing,
      mouseTracking: .probing,
      kittyGraphics: .unknown,
      kittyKeyboard: .probing,
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .probing,
      color: .unknown,
      identity: TerminalIdentity(
        kind: .ghostty,
        source: .termProgram("Ghostty"),
        version: "1.3.2"
      ),
      isNested: false
    )
  )
  expectNoDifference(resolution.modes, baseApplicationModes)
  expectNoDifference(resolution.runsActiveProbes, true)
}

@Test
func `dumb terminal keeps active protocol support unknown and OSC 8 not-detectable`() {
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
      bracketedPaste: .unknown,
      focusEvents: .unknown,
      mouseTracking: .unknown,
      kittyGraphics: .unknown,
      kittyKeyboard: .unknown,
      osc8Hyperlinks: .notDetectable,
      synchronizedOutput: .unknown,
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

@Test(arguments: osc52ClipboardDetectionCases)
private func `OSC 52 clipboard support is not inferred from identity or active probes`(
  _ testCase: OSC52ClipboardDetectionCase
) {
  let configuration = TerminalApplicationConfiguration(
    capabilityDetection: testCase.capabilityDetection
  )

  let resolution = configuration.resolve(environment: testCase.environment)

  expectNoDifference(resolution.capabilities.osc52Clipboard, .notDetectable)
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

private let namedTerminalProtocolCases = [
  NamedTerminalProtocolCase(
    name: "Ghostty",
    environment: [
      "TERM_PROGRAM": "Ghostty",
      "TERM_PROGRAM_VERSION": "1.3.2",
    ],
    identity: TerminalIdentity(
      kind: .ghostty,
      source: .termProgram("Ghostty"),
      version: "1.3.2"
    ),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "kitty",
    environment: ["TERM_PROGRAM": "kitty"],
    identity: TerminalIdentity(kind: .kitty, source: .termProgram("kitty")),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "WezTerm",
    environment: ["TERM_PROGRAM": "WezTerm"],
    identity: TerminalIdentity(kind: .wezTerm, source: .termProgram("WezTerm")),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "Apple Terminal",
    environment: ["TERM_PROGRAM": "Apple_Terminal"],
    identity: TerminalIdentity(
      kind: .appleTerminal,
      source: .termProgram("Apple_Terminal")
    ),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "Windows Terminal",
    environment: ["WT_SESSION": "abc123"],
    identity: TerminalIdentity(kind: .windowsTerminal, source: .windowsTerminalSession),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "iTerm2",
    environment: ["TERM_PROGRAM": "iTerm.app"],
    identity: TerminalIdentity(kind: .iTerm2, source: .termProgram("iTerm.app")),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "foot",
    environment: ["TERM": "foot"],
    identity: TerminalIdentity(kind: .foot, source: .term("foot")),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "xterm",
    environment: ["TERM": "xterm"],
    identity: TerminalIdentity(kind: .xterm, source: .term("xterm")),
    color: .ansi16
  ),
  NamedTerminalProtocolCase(
    name: "Konsole",
    environment: ["KONSOLE_VERSION": "23.08.4"],
    identity: TerminalIdentity(
      kind: .other("Konsole"),
      source: .environmentVariable(name: "KONSOLE_VERSION", value: "23.08.4")
    ),
    color: .unknown
  ),
  NamedTerminalProtocolCase(
    name: "VTE",
    environment: ["VTE_VERSION": "6800"],
    identity: TerminalIdentity(
      kind: .other("VTE"),
      source: .environmentVariable(name: "VTE_VERSION", value: "6800")
    ),
    color: .unknown
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

private let kittyIfAvailableCapabilityCases = [
  KittyIfAvailableCapabilityCase(status: .supported, enablesKittyKeyboard: true),
  KittyIfAvailableCapabilityCase(status: .unknown, enablesKittyKeyboard: false),
  KittyIfAvailableCapabilityCase(status: .probing, enablesKittyKeyboard: false),
  KittyIfAvailableCapabilityCase(status: .unsupported, enablesKittyKeyboard: false),
  KittyIfAvailableCapabilityCase(status: .notDetectable, enablesKittyKeyboard: false),
]

private let osc52ClipboardDetectionCases =
  namedTerminalProtocolCases.flatMap { terminalCase in
    [
      OSC52ClipboardDetectionCase(
        name: "\(terminalCase.name) passive",
        environment: terminalCase.environment,
        capabilityDetection: .passive
      ),
      OSC52ClipboardDetectionCase(
        name: "\(terminalCase.name) active",
        environment: terminalCase.environment,
        capabilityDetection: .active
      ),
    ]
  }
  + [
    OSC52ClipboardDetectionCase(
      name: "unknown passive",
      environment: [:],
      capabilityDetection: .passive
    ),
    OSC52ClipboardDetectionCase(
      name: "unknown active",
      environment: [:],
      capabilityDetection: .active
    ),
  ]

private struct OSC52ClipboardDetectionCase: CustomStringConvertible, Sendable {
  let name: String
  let environment: [String: String]
  let capabilityDetection: CapabilityDetectionMode

  var description: String {
    name
  }
}

private struct NamedTerminalProtocolCase: CustomStringConvertible, Sendable {
  let name: String
  let environment: [String: String]
  let identity: TerminalIdentity
  let color: ColorCapability

  var description: String {
    name
  }
}

private struct KittyIfAvailableCapabilityCase: CustomStringConvertible, Sendable {
  let status: CapabilityStatus
  let enablesKittyKeyboard: Bool

  var description: String {
    "\(status)"
  }
}

private struct ColorCapabilityCase: CustomStringConvertible, Sendable {
  let environment: [String: String]
  let color: ColorCapability

  var description: String {
    String(describing: color)
  }
}

private struct NestedTerminalCase: CustomStringConvertible, Sendable {
  let environment: [String: String]
  let identity: TerminalIdentity

  var description: String {
    String(describing: identity.kind)
  }
}
