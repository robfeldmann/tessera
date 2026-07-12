import CustomDump
import Foundation
import TesseraTerminalANSI
import TesseraTerminalIO
import TesseraTerminalInput
import Testing

@testable import TesseraTerminal

@Test
func `empty passive environment keeps protocols unknown`() {
  expectNoDifference(
    TerminalCapabilityDetector.detect(environment: [:]),
    TerminalCapabilities(osc8Hyperlinks: .notDetectable)
  )
}

@Test
func `application underline rendering defaults to extended`() {
  let configuration = TerminalApplicationConfiguration()
  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(configuration.underlineRendering, .extended)
  expectNoDifference(resolution.underlineRendering, .extended)
}

@Test
func `Kitty keyboard flags default conservatively and resolve exact overrides`() {
  let defaultConfiguration = TerminalApplicationConfiguration()
  let requestedFlags: KittyKeyboardFlags = [
    .disambiguateEscapeCodes,
    .reportEventTypes,
    .reportAlternateKeys,
    .reportAllKeysAsEscapeCodes,
    .reportAssociatedText,
  ]
  let overriddenConfiguration = TerminalApplicationConfiguration(
    kittyKeyboardFlags: requestedFlags
  )

  expectNoDifference(defaultConfiguration.kittyKeyboardFlags, .tesseraDefault)
  expectNoDifference(
    defaultConfiguration.resolve(environment: [:]).kittyKeyboardFlags,
    .tesseraDefault
  )
  expectNoDifference(overriddenConfiguration.kittyKeyboardFlags, requestedFlags)
  expectNoDifference(
    overriddenConfiguration.resolve(environment: [:]).kittyKeyboardFlags,
    requestedFlags
  )
}

@Test
func `off terminfo compatibility preserves the modern default`() {
  let configuration = TerminalApplicationConfiguration()
  let capabilities = TerminalCapabilities(
    underlineDeclarations: .init(style: .notDeclared, color: .notDeclared)
  )

  let resolution = configuration.resolve(capabilities: capabilities)

  expectNoDifference(configuration.underlineCompatibility, .off)
  expectNoDifference(resolution.underlineRendering, .extended)
  expectNoDifference(
    resolution.capabilities.underlineDeclarations, capabilities.underlineDeclarations)
}

@Test
func `terminfo compatibility intersects underline axes independently`() {
  let configuration = TerminalApplicationConfiguration(
    underlineRendering: .extended,
    underlineCompatibility: .terminfoDatabase
  )
  let cases: [(TerminfoUnderlineDeclarations, UnderlineRenderingPolicy)] = [
    (
      .init(style: .declared, color: .declared),
      .extended
    ),
    (
      .init(style: .notDeclared, color: .declared),
      .init(style: .singleOnly, color: .emit)
    ),
    (
      .init(style: .declared, color: .notDeclared),
      .init(style: .preserveVariants, color: .omit)
    ),
    (
      .init(style: .notDeclared, color: .notDeclared),
      .baseline
    ),
    (
      .unknown,
      .extended
    ),
  ]

  for (declarations, expected) in cases {
    let capabilities = TerminalCapabilities(underlineDeclarations: declarations)
    let resolution = configuration.resolve(capabilities: capabilities)

    expectNoDifference(resolution.underlineRendering, expected)
    expectNoDifference(resolution.capabilities.underlineDeclarations, declarations)
  }
}

@Test
func `terminfo database evidence drives startup underline resolution`() {
  let environment = ["TERM": "xterm", "TERMINFO": "/terms"]
  let entry = Data([
    0x1A, 0x01,
    0x02, 0x00,
    0x00, 0x00,
    0x00, 0x00,
    0x00, 0x00,
    0x00, 0x00,
    0x78, 0x00,
  ])
  let database = TerminfoDatabase(
    environment: environment,
    readFile: { path in path == "/terms/x/xterm" ? entry : nil },
    systemRoots: []
  )
  let configuration = TerminalApplicationConfiguration(
    underlineCompatibility: .terminfoDatabase
  )

  let resolution = configuration.resolve(
    environment: environment,
    terminfoDatabase: database
  )

  expectNoDifference(
    resolution.capabilities.underlineDeclarations,
    .init(style: .notDeclared, color: .notDeclared)
  )
  expectNoDifference(resolution.underlineRendering, .baseline)
}

@Test
func `terminfo compatibility never upgrades a conservative underline request`() {
  let requested = UnderlineRenderingPolicy(style: .singleOnly, color: .omit)
  let configuration = TerminalApplicationConfiguration(
    underlineRendering: requested,
    underlineCompatibility: .terminfoDatabase
  )
  let capabilities = TerminalCapabilities(
    underlineDeclarations: .init(style: .declared, color: .declared)
  )

  let resolution = configuration.resolve(capabilities: capabilities)

  expectNoDifference(resolution.underlineRendering, requested)
}

@Test
func `terminal identities do not alter configured underline rendering`() {
  let underlineRendering = UnderlineRenderingPolicy(style: .preserveVariants, color: .omit)
  let configuration = TerminalApplicationConfiguration(
    underlineRendering: underlineRendering
  )
  let environments: [[String: String]] = [
    [:],
    ["TERM_PROGRAM": "Apple_Terminal"],
    ["TERM_PROGRAM": "Ghostty"],
  ]

  for environment in environments {
    let resolution = configuration.resolve(environment: environment)

    expectNoDifference(resolution.underlineRendering, underlineRendering)
  }
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
func `NO_COLOR does not overwrite true-color detection evidence`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: [
      "COLORTERM": "truecolor",
      "NO_COLOR": "1",
      "TERM": "xterm-256color",
    ]
  )

  #expect(capabilities.color == .truecolor)
}

@Test
func `dumb-family TERM remains unknown color evidence`() {
  let capabilities = TerminalCapabilityDetector.detect(
    environment: ["TERM": "dumb-300", "TERM_PROGRAM": "Ghostty"]
  )

  #expect(capabilities.color == .unknown)
}

@Test(arguments: colorCapabilityCases)
private func `color hints map to the advertised color capability`(
  _ testCase: ColorCapabilityCase
) {
  let capabilities = TerminalCapabilityDetector.detect(environment: testCase.environment)

  #expect(capabilities.color == testCase.color)
}

@Test
func `color override wins when no environment constraint is present`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.truecolor))

  let resolution = configuration.resolve(environment: [:])
  expectNoDifference(resolution.capabilities.color, .unknown)
  expectNoDifference(resolution.effectiveColorCapability, .truecolor)
}

@Test
func `NO_COLOR records separate provenance and pins forced color output`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.truecolor))

  let resolution = configuration.resolve(
    environment: [
      "COLORTERM": "truecolor",
      "NO_COLOR": "1",
      "TERM": "xterm-256color",
    ]
  )

  expectNoDifference(resolution.capabilities.color, .truecolor)
  expectNoDifference(resolution.hasNoColorEnvironment, true)
  expectNoDifference(resolution.hasDumbTerminal, false)
  expectNoDifference(resolution.effectiveColorCapability, .noColor)
}

@Test
func `dumb TERM records separate provenance and pins forced color output`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.truecolor))

  let resolution = configuration.resolve(environment: ["TERM": "dumb"])

  expectNoDifference(resolution.capabilities.color, .unknown)
  expectNoDifference(resolution.hasNoColorEnvironment, false)
  expectNoDifference(resolution.hasDumbTerminal, true)
  expectNoDifference(resolution.effectiveColorCapability, .noColor)
}

@Test
func `forcing unknown color capability remains unknown`() {
  let configuration = TerminalApplicationConfiguration(colorCapability: .force(.unknown))

  let resolution = configuration.resolve(
    capabilities: TerminalCapabilities(color: .truecolor)
  )

  expectNoDifference(resolution.capabilities.color, .truecolor)
  expectNoDifference(resolution.effectiveColorCapability, .unknown)
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
      kittyGraphics: .probing,
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
func `DECRQM evidence aggregates direct and mouse capabilities deterministically`() {
  var capabilities = TerminalCapabilities()

  capabilities.recordPrivateModeStatus(
    PrivateModeStatus(mode: 2_004, state: .reset)
  )
  capabilities.recordPrivateModeStatus(
    PrivateModeStatus(mode: 1_002, state: .set)
  )
  capabilities.recordPrivateModeStatus(
    PrivateModeStatus(mode: 1_006, state: .permanentlySet)
  )

  expectNoDifference(capabilities.bracketedPaste, .supported)
  expectNoDifference(capabilities.mouseTracking, .unknown)

  capabilities.recordPrivateModeStatus(
    PrivateModeStatus(mode: 1_003, state: .notRecognized)
  )

  expectNoDifference(capabilities.mouseTracking, .unsupported)
  expectNoDifference(
    capabilities.privateModeStates,
    [
      1_002: .set,
      1_003: .notRecognized,
      1_006: .permanentlySet,
      2_004: .reset,
    ]
  )
}

@Test
func `DECRQM normal tracking evidence is explicitly excluded`() {
  var capabilities = TerminalCapabilities()

  capabilities.recordPrivateModeStatus(
    PrivateModeStatus(mode: 1_000, state: .set)
  )

  expectNoDifference(capabilities.privateModeStates, [:])
  expectNoDifference(capabilities.mouseTracking, .unknown)
}

@Test
func `active probe timeout defaults to two hundred fifty milliseconds`() {
  let configuration = TerminalApplicationConfiguration(capabilityDetection: .active)
  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(configuration.activeProbeTimeout, .milliseconds(250))
  expectNoDifference(resolution.activeProbeTimeout, .milliseconds(250))
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
      color: .unknown,
      identity: TerminalIdentity(kind: .dumb, source: .term("dumb")),
      isNested: false
    )
  )
  expectNoDifference(resolution.modes, baseApplicationModes)
  expectNoDifference(resolution.hasDumbTerminal, true)
  expectNoDifference(resolution.effectiveColorCapability, .noColor)
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

@Test
func `default intent and exact modes keep cursor styling disabled`() {
  let defaultResolution =
    TerminalApplicationConfiguration.default.resolve(environment: [:])
  let exactConfiguration = TerminalApplicationConfiguration(modes: baseApplicationModes)
  let exactResolution = exactConfiguration.resolve(environment: [:])

  expectNoDifference(TerminalApplicationConfiguration.default.cursorStyling, .disabled)
  expectNoDifference(defaultResolution.cursorStyling, .disabled)
  expectNoDifference(defaultResolution.cursorStyle, nil)
  #expect(!containsCursorStyle(defaultResolution.modes))
  expectNoDifference(exactConfiguration.cursorStyling, .disabled)
  expectNoDifference(exactResolution.cursorStyling, .disabled)
  expectNoDifference(exactResolution.cursorStyle, nil)
  #expect(!containsCursorStyle(exactResolution.modes))
}

@Test
func `enabled cursor styling without default is carried without cursor mode`() {
  let configuration = TerminalApplicationConfiguration(
    cursorStyling: .enabled(default: nil)
  )

  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(resolution.cursorStyling, .enabled(default: nil))
  expectNoDifference(resolution.cursorStyle, nil)
  #expect(!containsCursorStyle(resolution.modes))
}

@Test
func `shape-only cursor styling default resolves one cursor style mode`() {
  let cursorStyle = CursorStyle(shape: .steadyBar)
  let configuration = TerminalApplicationConfiguration(
    cursorStyling: .enabled(default: cursorStyle)
  )

  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(resolution.cursorStyling, .enabled(default: cursorStyle))
  expectNoDifference(resolution.cursorStyle, cursorStyle)
  expectNoDifference(cursorStyles(in: resolution.modes), [cursorStyle])
}

@Test
func `color-only cursor styling default resolves one cursor style mode`() {
  let cursorStyle = CursorStyle(color: CursorColor(red: 0x12, green: 0x34, blue: 0x56))
  let configuration = TerminalApplicationConfiguration(
    cursorStyling: .enabled(default: cursorStyle)
  )

  let resolution = configuration.resolve(environment: [:])

  expectNoDifference(resolution.cursorStyling, .enabled(default: cursorStyle))
  expectNoDifference(resolution.cursorStyle, cursorStyle)
  expectNoDifference(cursorStyles(in: resolution.modes), [cursorStyle])
}

@Test
func `exact modes round trip cursor styling policy`() {
  let cursorStyle = CursorStyle(
    shape: .steadyBlock,
    color: CursorColor(red: 0xAA, green: 0xBB, blue: 0xCC)
  )
  let styledConfiguration = TerminalApplicationConfiguration(
    modes: baseApplicationModes.union([.cursorStyle(cursorStyle)])
  )
  let unstyledConfiguration = TerminalApplicationConfiguration(modes: baseApplicationModes)

  expectNoDifference(styledConfiguration.cursorStyling, .enabled(default: cursorStyle))
  expectNoDifference(cursorStyles(in: styledConfiguration.modes), [cursorStyle])
  expectNoDifference(unstyledConfiguration.cursorStyling, .disabled)
  #expect(!containsCursorStyle(unstyledConfiguration.modes))
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

private func containsCursorStyle(_ modes: Set<ModeLifecycle.Mode>) -> Bool {
  modes.contains { mode in
    if case .cursorStyle = mode {
      return true
    }
    return false
  }
}

private func cursorStyles(in modes: Set<ModeLifecycle.Mode>) -> [CursorStyle] {
  modes.compactMap { mode in
    if case .cursorStyle(let style) = mode {
      return style
    }
    return nil
  }
}

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
