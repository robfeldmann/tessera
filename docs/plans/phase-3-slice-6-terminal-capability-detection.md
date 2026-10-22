---
name: Phase 3 Slice 6 Terminal Capability Detection
description:
  Add conservative terminal capability reporting and configuration policy so modern
  protocol enablement degrades gracefully.
status: complete
created: 2026-07-02
updated: 2026-07-07
---

## Progress

- [x] **Phase 1 — Capability model and passive detection**
  - [x] 1.1 Add terminal capability value types
  - [x] 1.2 Add passive environment-based detection tests
- [x] **Phase 2 — Configuration policy and session integration**
  - [x] 2.1 Replace direct default mode policy with explicit protocol knobs
  - [x] 2.2 Resolve startup modes from configuration and capabilities
  - [x] 2.3 Expose detected and enabled terminal protocol state
- [x] **Phase 3 — Example app and validation**
  - [x] 3.1 Add the capabilities panel to `Phase3ProtocolsDemo`
  - [x] 3.2 Run narrow capability, lifecycle, session, renderer, and example checks

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 6. Capabilities are advisory hints, not
truth. A terminal that does not answer a query or advertises an unknown identity must
still start cleanly, draw visible text, parse legacy input, and restore modes on exit.

Historical Slice 6 began with passive, environment-based detection. The current contract
adds `.active` bounded protocol-native probing and runtime reconciliation, but treats both
environment-derived identity and declarations as advisory evidence rather than proof of
protocol support.

## Phase 1 — Capability model and passive detection

**Goal**: Tessera can report what it knows, assumes, or does not know about the
surrounding terminal without changing startup behavior yet.

### Step 1.1 — Add terminal capability value types

- Files:
  - new `Sources/TesseraTerminal/TerminalCapabilities.swift`
  - new `Sources/TesseraTerminal/TerminalCapabilityDetector.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
- Add capability-status values:

```swift
public enum CapabilityStatus: Equatable, Sendable {
  case notDetectable
  case probing
  case supported
  case unsupported
  case unknown
}
```

- Add terminal identity and capability data:

```swift
public struct TerminalCapabilities: Equatable, Sendable {
  public var bracketedPaste: CapabilityStatus
  public var focusEvents: CapabilityStatus
  public var mouseTracking: CapabilityStatus
  public var kittyKeyboard: CapabilityStatus
  public var osc8Hyperlinks: CapabilityStatus
  public var synchronizedOutput: CapabilityStatus
  public var color: ColorCapability
  public var identity: TerminalIdentity
  public var isNested: Bool
}
```

- Add small value types for `TerminalIdentity` and `ColorCapability`.
- Prefer explicit associated values for source strings over raw environment dictionaries.
  Public values should explain what Tessera decided, not leak process environment
  wholesale.
- Include static constructors for `.unknown` or `.conservativeDefault` if that makes tests
  clearer.
- Do not put raw file descriptors, handles, or query closures in public capability values.

Acceptance:

- Capability values are plain `Equatable, Sendable` data.
- Unknown is representable for every protocol.

### Step 1.2 — Add passive environment-based detection tests

- Files:
  - `Sources/TesseraTerminal/TerminalCapabilityDetector.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
- Add a package-visible detector that accepts an explicit environment dictionary. Do not
  read `ProcessInfo.processInfo.environment` directly inside most logic.
- Map obvious hints:
  - `TERM_PROGRAM=Apple_Terminal`, `iTerm.app`, `WezTerm`, `Ghostty`, or known equivalents
    into a `TerminalIdentity` value when present
  - `TERM` prefixes such as `xterm`, `screen`, `tmux`, `wezterm`, `foot`, `kitty`, and
    `ghostty` into conservative identity hints
  - `COLORTERM=truecolor` or `24bit` into true-color support
  - `NO_COLOR` into color disabled or restricted policy input
  - `TMUX` or `STY` into `isNested = true`
- Keep protocol support conservative: environment-derived terminal identity is diagnostic
  metadata, not support evidence. Passive detection leaves queryable protocol status
  `.unknown` until protocol-native evidence is observed; it never marks a protocol
  supported or unsupported merely because of a terminal name.
- Do not fail when environment variables are missing or contradictory.

Add tests for:

- empty environment produces unknown conservative capabilities
- known modern terminal hints
- nested tmux/screen detection
- `NO_COLOR` interaction with color capability
- true-color hints
- unknown terminal remains unknown, not unsupported
- conflicting hints choose the safer result and document the tie-breaker in the test name

Prefer snapshot-style capability dumps for whole capability structs, because reviewers
need to inspect multiple related fields together.

Acceptance:

- Passive detection is deterministic and fully injectable in tests.
- No test depends on the developer machine's actual environment.

## Phase 2 — Configuration policy and session integration

**Goal**: public configuration expresses intent, session startup resolves that intent with
capabilities, and users can inspect what Tessera enabled.

### Step 2.1 — Replace direct default mode policy with explicit protocol knobs

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
- Keep the existing `modes` initializer only if it remains necessary for tests. The
  default app configuration should stop being defined primarily as a raw set of
  `ModeLifecycle.Mode` values.
- Add explicit fields:

```swift
public enum CapabilityDetectionMode: Equatable, Sendable {
  case disabled
  case passive
  case active
}

public enum KeyboardProtocolMode: Equatable, Sendable {
  case legacyOnly
  case kittyIfAvailable
  case kittyRequired
}

public enum MouseTrackingMode: Equatable, Sendable {
  case disabled
  case buttonEvents
}

public enum HyperlinkRenderingMode: Equatable, Sendable {
  case disabled
  case enabled
}
```

- Add configuration fields:
  - `capabilityDetection`
  - `enableBracketedPaste`
  - `enableFocusEvents`
  - `mouseTracking`
  - `keyboardProtocol`
  - `hyperlinkRendering`
  - existing `synchronizedOutput`
- Defaults:
  - `capabilityDetection: .passive`
  - `enableBracketedPaste: true`
  - `enableFocusEvents: true`
  - `mouseTracking: .disabled`
  - `keyboardProtocol: .kittyIfAvailable`
  - `hyperlinkRendering: .enabled`
  - `synchronizedOutput: .enabled`
- `kittyRequired` may fail startup only if mode enablement fails locally. It must not fail
  just because passive detection returns unknown unless the policy explicitly chooses that
  behavior and tests name it.

Acceptance:

- Public configuration reads like app intent, not raw terminal byte modes.
- Existing tests and examples are migrated to the new initializer or an explicit low-level
  test initializer.

### Step 2.2 — Resolve startup modes from configuration and capabilities

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Add a pure resolver that returns:
  - requested `ModeLifecycle.Mode` set
  - resolved `TerminalCapabilities`
  - enabled protocol report for user inspection
- Always include `.rawMode` and `.altScreen` for application terminal sessions.
- Include `.bracketedPaste` when `enableBracketedPaste` is true.
- Include `.focusEvents` when `enableFocusEvents` is true.
- Include `.mouseTracking` only when `mouseTracking == .buttonEvents`.
- Include `.kittyKeyboard` for `.kittyIfAvailable` only after positive, protocol-native
  Kitty keyboard evidence. Unknown, missing, or advisory identity/declaration evidence
  leaves the requested policy pending and Kitty keyboard disabled.
- Include `.kittyKeyboard` when `keyboardProtocol == .kittyRequired`.
- Exclude `.kittyKeyboard` when `keyboardProtocol == .legacyOnly`.
- Keep capability detection advisory. Resolver tests should name every conservative
  assumption.
- Refresh cleanup bytes through `ModeLifecycle` exactly as before; config resolution must
  not bypass lifecycle.

Add tests for:

- default config resolves raw, alternate screen, bracketed paste, and focus; conditional
  Kitty keyboard remains pending until positive protocol-native evidence
- mouse stays disabled by default
- explicit mouse button events add mouse tracking
- legacy-only keyboard excludes Kitty
- disabled paste/focus remove those modes
- disabled capability detection uses conservative unknown capabilities
- passive identity hints do not imply protocol support or cause startup failure
- cleanup bytes cover every requested, active, or possibly-active protocol mode

Use snapshot-style resolver dumps for related mode and capability output.

Acceptance:

- Startup mode selection is pure and tested before session integration.
- Session startup still goes through `ModeLifecycle.enter(_:)`.

### Step 2.3 — Expose detected and enabled terminal protocol state

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Expose actor-isolated live session inspection values:

```swift
public private(set) var capabilities: TerminalCapabilities
public private(set) var enabledProtocolModes: Set<ModeLifecycle.Mode>
public private(set) var possiblyActiveProtocolModes: Set<ModeLifecycle.Mode>
public var protocolModeReport: TerminalProtocolModeReport { get }
```

- `capabilities` records detected evidence; requested policy and effective/possibly-active
  lifecycle state remain separate. If public exposure of `ModeLifecycle.Mode` is too
  low-level, expose an equivalent typed report rather than raw bytes.
- The example app uses this live report for the capabilities panel.
- Inspection is read-only to callers and does not leak raw handles or output authority.

Acceptance:

- Apps can inspect advisory evidence, requested policy, effective modes, and modes that
  may require defensive cleanup.
- Inspection does not grant output authority.

## Phase 3 — Example app and validation

**Goal**: reviewers can see the final Phase 3 protocol matrix and run the full demo app.

### Step 3.1 — Add the capabilities panel to `Phase3ProtocolsDemo`

- File: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Add panel navigation: `1` paste, `2` focus, `3` mouse, `4` keys, `5` links, `6`
  capabilities.
- Show:
  - detected identity, labeled diagnostic
  - nested terminal status
  - detected and effective color capability
  - live protocol evidence for paste, focus, mouse, Kitty keyboard, OSC 8, and
    synchronized output, without deriving support from identity
  - requested, effective, and possibly-active protocol modes for this session
- Keep the display compact and stable. This panel should be usable as a manual smoke test.

Wireframe:

```text
Phase3ProtocolsDemo — Capabilities                               80x24
q quit · g graphics · m mouse log · d/y/h/t/f/k/s/c/x live controls

Detected terminal
  identity: Ghostty from TERM_PROGRAM (diagnostic)
  nested:   no
  color:    detected truecolor · effective truecolor

Protocol evidence
  bracketed paste: unknown
  focus events:    unknown
  SGR mouse:       unknown
  Kitty keyboard:  probing
  OSC 8 links:     not detectable
  sync output:     unknown

Session state
  requested: bracketed paste · focus events · kitty if available
  effective: raw mode · alt screen · bracketed paste · focus events
  possibly active: none
```

Acceptance:

- The panel renders even when every capability is unknown.
- The panel reports policy and capability state without performing active terminal
  queries.

### Step 3.2 — Run narrow capability, lifecycle, session, renderer, and example checks

Run:

```fish
swift test --filter TesseraTerminalTests
swift test --filter TesseraTerminalIOTests
swift test --filter TesseraTerminalRenderingTests
swift build --package-path Examples --product Phase3ProtocolsDemo
just quality changed
```

Then manually smoke the example in an interactive terminal:

```fish
just core example Phase3ProtocolsDemo
```

Acceptance:

- Capability detection, configuration resolution, session integration, and renderer policy
  checks pass.
- The example app has all six Phase 3 panels.
- Startup succeeds when capabilities are unknown.
