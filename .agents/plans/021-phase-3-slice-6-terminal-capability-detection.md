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

Decision for this slice: implement passive, environment-based detection only. Do not
expose an `.active(timeout:)` public mode until active protocol queries are implemented
end to end with bounded I/O, response parsing, and startup-time tests. This avoids
shipping a knob that looks real but does nothing.

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
- Keep protocol support conservative:
  - bracketed paste, focus events, and OSC 8 may be `supported` for known modern terminals
    or `unknown` otherwise
  - mouse tracking is at least `unknown` unless a known terminal hint supports SGR mouse
  - Kitty keyboard is `supported` only for clear Kitty/Ghostty/WezTerm-style hints, and
    `unknown` otherwise
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
- Include `.kittyKeyboard` when `keyboardProtocol == .kittyIfAvailable` and passive hints
  say supported or unknown. Unknown should degrade by trying and relying on harmless
  terminal ignore behavior plus cleanup.
- Include `.kittyKeyboard` when `keyboardProtocol == .kittyRequired`.
- Exclude `.kittyKeyboard` when `keyboardProtocol == .legacyOnly`.
- Keep capability detection advisory. Resolver tests should name every conservative
  assumption.
- Refresh cleanup bytes through `ModeLifecycle` exactly as before; config resolution must
  not bypass lifecycle.

Add tests for:

- default config resolves raw, alt, paste, focus, and Kitty keyboard
- mouse stays disabled by default
- explicit mouse button events add mouse tracking
- legacy-only keyboard excludes Kitty
- disabled paste/focus remove those modes
- disabled capability detection uses conservative unknown capabilities
- passive known unsupported hints do not fail startup
- cleanup bytes still cover every enabled protocol mode

Use snapshot-style resolver dumps for related mode and capability output.

Acceptance:

- Startup mode selection is pure and tested before session integration.
- Session startup still goes through `ModeLifecycle.enter(_:)`.

### Step 2.3 — Expose detected and enabled terminal protocol state

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Expose immutable session inspection values:

```swift
public nonisolated let capabilities: TerminalCapabilities
public nonisolated let enabledProtocolModes: Set<ModeLifecycle.Mode>
```

- If public exposure of `ModeLifecycle.Mode` is too low-level, introduce a small
  `EnabledTerminalProtocols` value instead. Prefer a typed report over a raw byte list.
- The example app uses these values for the capabilities panel.
- Do not let callers mutate lifecycle modes through these inspection values.

Acceptance:

- Apps can inspect what Tessera assumed and enabled.
- Inspection does not leak raw handles or output authority.

## Phase 3 — Example app and validation

**Goal**: reviewers can see the final Phase 3 protocol matrix and run the full demo app.

### Step 3.1 — Add the capabilities panel to `Phase3ProtocolsDemo`

- File: `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`.
- Add panel navigation: `1` paste, `2` focus, `3` mouse, `4` keys, `5` links, `6`
  capabilities.
- Show:
  - detected identity
  - nested terminal status
  - color capability
  - support status for paste, focus, mouse, Kitty keyboard, OSC 8, and synchronized output
  - enabled protocol modes for this session
- Keep the display compact and stable. This panel should be usable as a manual smoke test.

Wireframe:

```text
Phase3ProtocolsDemo — Capabilities                               80x24
q quit · 1 paste · 2 focus · 3 mouse · 4 keys · 5 links · 6 caps

Detected terminal
  identity: Ghostty from TERM_PROGRAM
  nested:   no
  color:    truecolor

Protocol support
  bracketed paste: supported
  focus events:    supported
  SGR mouse:       supported
  Kitty keyboard:  supported
  OSC 8 links:     supported
  sync output:     unknown

Enabled in this session
  raw mode · alt screen · bracketed paste · focus events · mouse · kitty keyboard
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
