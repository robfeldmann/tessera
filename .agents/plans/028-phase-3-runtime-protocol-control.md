---
name: Phase 3 Slice 12 Runtime Protocol Control
description:
  Reconcile active protocol evidence and make selected rendering policies and terminal
  modes adjustable during a live application session.
status: pending
created: 2026-07-09
updated: 2026-07-10
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [ ] **Phase 1 — Lifecycle transaction safety**
  - [ ] 1.1 Make mode writes and emergency cleanup failure-safe
  - [ ] 1.2 Guard startup, teardown, and concurrent mode transitions
- [ ] **Phase 2 — Live capability evidence and Kitty negotiation**
  - [ ] 2.1 Make evidence and effective mode state authoritative at runtime
  - [ ] 2.2 Add bounded single-generation active-probe reconciliation
  - [ ] 2.3 Complete conditional Kitty keyboard negotiation
- [ ] **Phase 3 — Runtime rendering policies**
  - [ ] 3.1 Add runtime color rendering control
  - [ ] 3.2 Add runtime hyperlink rendering control
  - [ ] 3.3 Add runtime synchronized-output control
  - [ ] 3.4 Add opt-in terminfo-database underline compatibility
- [ ] **Phase 4 — Runtime application modes**
  - [ ] 4.1 Centralize requested, effective, and ambiguous mode state
  - [ ] 4.2 Add runtime mouse tracking control
  - [ ] 4.3 Add runtime focus-event control
  - [ ] 4.4 Add runtime Kitty keyboard policy control
- [ ] **Phase 5 — Integrated demo, specification, and validation**
  - [ ] 5.1 Complete the runtime-control demo surfaces
  - [ ] 5.2 Update the specification and affected plans
  - [ ] 5.3 Run focused checks and the complete repository gate

## Overview

This plan completes the live-session policy layer before Phase 4 views depend on it. It
first hardens lifecycle failure and cleanup invariants, then separates detected evidence
from requested policy and effective terminal state. It closes the send-only active-probe
and `.kittyIfAvailable` reconciliation gap, and exposes runtime controls that applications
can offer to users whose output path renders a feature incorrectly. Every production step
lands with focused tests in the same step. Bracketed paste, raw mode, alternate screen,
clipboard policy, and graphics operations do not become runtime settings.

## Implementation review boundaries

This plan is five sequential review units. Implement exactly one numbered phase per pass,
land that phase's production changes and tests together, run its focused checks and the
repository gate before handoff, then stop for review. Continue only after approval. Phase
1 is a prerequisite for Phases 2–4; Phase 5 closes all work.

## Policy precedence and exclusions

- Explicit bracketed-paste, focus-event, and mouse settings remain application
  instructions; active DECRQM evidence is displayed but does not silently override them.
  Unknown terminals commonly ignore these DEC private modes safely.
- `.kittyRequired` is an explicit instruction and enables Kitty keyboard regardless of
  evidence. `.kittyIfAvailable` enables only after positive protocol-native evidence;
  `.legacyOnly` disables it. Terminal identity never influences the result.
- Synchronized output remains an explicit application output policy. DECRQM evidence is
  advisory and displayed separately.
- `NO_COLOR` remains a user-environment constraint that pins effective color output to
  `.noColor`, even when application policy requests a forced color depth.
- Bracketed paste remains startup-only because changing it while the parser is collecting
  an in-flight paste has no settled contract. Raw mode and alternate screen remain fixed
  session ownership. Clipboard policy remains startup-fixed and security-sensitive. Kitty
  Graphics remains query/transmit/delete operations rather than a persistent mode.

## Phase 1 — Lifecycle transaction safety

**Goal**: no partial write, flush error, concurrent setter, startup failure, or teardown
failure can leave an enabled terminal mode outside Tessera's believed/cleanup state.

### Step 1.1 — Make mode writes and emergency cleanup failure-safe

- Files:
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Sources/TesseraTerminalIO/PlatformIO.swift`
  - `Sources/TesseraTerminalIO/CleanupRegistry.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
  - `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`
  - `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift`
- Model lifecycle state explicitly as successfully active modes plus modes that may have
  been enabled or left enabled by a partial write/flush failure. Register
  requested/possibly-active cleanup before the first mutating byte can reach the terminal;
  do not wait for a successful flush to make cleanup aware of the mode.
- After an ambiguous lifecycle write failure not already covered by enter, explicitly
  failed apply, graphics cleanup, or disable/exit, use the existing package
  `PlatformIO.discardBufferedOutput()`. A later disable, retry, or teardown must not flush
  the stale suffix of a failed enable/pop/delete operation before recovery bytes.
- On enable/apply failure, preserve successfully completed lifecycle belief and mark the
  ambiguous slot possibly active. Cleanup and exit defensively disable the union of
  active, requested, and possibly-active modes. Kitty push failures must schedule a
  matching pop; failed graphics cleanup must discard its stale suffix before mode teardown
  proceeds.
- On disable/exit failure, retain or reinstall emergency cleanup and retain ambiguous
  belief; clear lifecycle state and cleanup only after successful teardown. Repeated
  cleanup remains idempotent.
- Tests in this same step reuse or extract the existing `CountingOutputWriter` and
  `LifecycleTestDevice`, extending the lifecycle seam only for a partial-positive write.
  Assert retained suffix disposal, pre-write cleanup installation, ambiguous enable/pop
  handling, graphics cleanup failure followed by mode teardown, failed exit retaining
  emergency cleanup, retry, and normal/throwing teardown. Do not rely only on
  `InMemoryTerminalDevice`, whose writes always succeed.
- Acceptance: the existing spec guarantee—safe disable even when enable failed partway—is
  true for startup, runtime apply, and exit on every protocol mode.

### Step 1.2 — Guard startup, teardown, and concurrent mode transitions

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Put `lifecycle.enter`, construction, probes/reconciliation, initial application-mode
  apply, cursor restore, body execution, and exit inside one cleanup transaction. A probe
  or reconciliation error before the application body must still run lifecycle exit; a
  failed exit must leave emergency cleanup installed.
- Split startup into fixed ownership and application intent: acquire raw mode and
  alternate screen first, construct the session/coordinator, resolve bounded active
  evidence when requested, then apply bracketed paste/focus/mouse/Kitty/cursor application
  modes through the runtime reconciler. Passive/disabled detection follows the same apply
  path without the probe wait.
- Prevent actor reentrancy from interleaving lifecycle transactions across `await`. Add a
  cancellation-safe FIFO/single-flight transition gate used by existing `ModeLifecycle`
  enter/apply/exit, `TerminalSession.setCursorStyle(_:)`, and every future mode setter;
  actor isolation alone is insufficient.
- Tests in this same step cover probe failure before body, initial application-mode
  failure, body plus restore/exit failure, concurrent same-slot and unrelated-slot
  requests, cancellation while queued, no lost update, and cleanup retention after every
  failure point.
- Acceptance: lifecycle transitions have one total order, and startup cannot leak fixed or
  application modes when work before the body throws.

## Phase 2 — Live capability evidence and Kitty negotiation

**Goal**: active protocol evidence and effective modes become authoritative live session
state without terminal-name inference, input-event loss, or ambiguous repeated probes.

### Step 2.1 — Make evidence and effective mode state authoritative at runtime

- Files:
  - `Sources/TesseraTerminal/TerminalCapabilities.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Replace immutable startup snapshots for `capabilities` and `enabledProtocolModes` with
  actor-isolated, `public private(set)` live evidence/effective state. Preserve requested
  application policy separately, including pending unavailable `.kittyIfAvailable` config
  intent and the active cursor style.
- The parser already preserves generic DECRQM. Persist `.privateModeStatus` evidence for
  2004, 1004, 1002, 1003, 1006, and 2026; explicitly exclude 1000 because Tessera has no
  normal-tracking mode/API and Step 4.2 forbids adding it. Derive aggregate fields
  deterministically: direct modes map their own response; mouse is supported only when
  1006 and the queried tracking modes are recognized, unsupported when a required mode is
  explicitly not recognized, and unknown when evidence is missing/ambiguous.
- Define a public runtime report that distinguishes requested policy, positively active
  modes, and possibly-active modes after ambiguous I/O. Startup configuration expresses
  intent; a runtime requested policy commits only after successful lifecycle apply, while
  pending `.kittyIfAvailable` config intent persists until reconciliation. After failure,
  effective/possible state is refreshed from lifecycle belief rather than falsely
  retaining a startup snapshot.
- Refactor `setCursorStyle(_:)` to derive from requested state—not the old effective
  snapshot—so later mouse/focus/Kitty changes cannot resurrect a disabled mode or discard
  unavailable Kitty intent.
- Tests in this same step cover actor-isolated reads, startup resolution,
  requested/effective/possible divergence after partial failure, cursor preservation,
  DECRQM aggregation precedence, and migration of every caller/test that treated
  `capabilities.color` as application output policy.
- Acceptance: public state says what was detected, what the application requested, what
  the lifecycle believes active, and what may need defensive cleanup.

### Step 2.2 — Add bounded single-generation active-probe reconciliation

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/ActiveCapabilityProbeCoordinator.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalInputTests/InputParserTests.swift`
- Add `activeProbeTimeout` to `TerminalApplicationConfiguration` and
  `TerminalApplicationResolution`, defaulting to 250 milliseconds. Provide a
  package-injected deadline/sleep seam so tests advance deterministically without
  wall-clock sleeps.
- Keep `PlatformIO` as the only parser and retain one session input pump. In
  `TerminalSession`'s existing input-pump loop, between receiving one `io.events` event
  and forwarding that same event once to public `events` and once to `nextEvent`, let the
  coordinator observe it. Do not add a second pump or parser. Session teardown/input
  closure cancels waits and resumes every waiter.
- Active startup runs serialized rounds so DA1 is never shared ambiguously:
  1. issue DECRQM requests and collect direct per-mode responses until complete/timeout;
  2. issue Kitty keyboard query plus DA1 and finish on response-before-DA1,
     DA1-before-response, or timeout;
  3. only after a completed keyboard round, issue KGP `a=q` with a unique image ID plus
     DA1 and correlate only the matching response.
- Permit at most one untagged active-probe generation per session. Repeated public query
  APIs return cached evidence or a typed already-resolved/in-progress result rather than
  emitting indistinguishable keyboard/DA1/DECRQM rounds. If a DA1 round times out, retire
  later untagged DA1 rounds for that session so a late response cannot satisfy another
  generation.
- Include KGP in active preparation/emission/state; current send-only startup probing
  omits it. Keep OSC 8 and OSC 52 `.notDetectable`; color remains generic environment
  evidence.
- Existing semantic events—DECRQM `.privateModeStatus`, Kitty keyboard reports, DA1, and
  KGP responses—must continue to be observed. Parser tests remain mandatory regression
  coverage for byte-split Kitty, DA1, KGP, DECRQM including 1006 and 2026, malformed, and
  foreign responses; change parser production only if a missing semantic event is proven.
- Tests in this same step cover serialized round bytes, response/DA1 order, timeout, late
  response quarantine, attempted overlap, one-generation caching, KGP image-ID mismatch,
  DECRQM partial evidence, unrelated input ordering, exact event non-consumption/
  non-duplication, input closure, and no terminal-name inference.
- Acceptance: active detection is bounded and attributable; it cannot hang startup, steal
  input, launch ambiguous overlapping rounds, or manufacture support from identity.

### Step 2.3 — Complete conditional Kitty keyboard negotiation

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Carry requested `KeyboardProtocolMode` through resolution/session. After bounded active
  reconciliation, `.kittyIfAvailable` enables only on positive keyboard evidence;
  unsupported/unknown remains legacy, `.kittyRequired` enables explicitly, and
  `.legacyOnly` disables.
- Apply through the guarded lifecycle reconciler before the application body. Do not write
  push/pop bytes directly or hide failures in detached tasks.
- Tests in this same step prove supported/unsupported/timeout outcomes, exact push/pop
  bytes, explicit-required precedence, requested intent preservation, partial push/pop
  failure, cleanup registration before push, normal/throwing restoration, and
  probe/reconciliation failure cleanup before body.
- Acceptance: `.active` plus `.kittyIfAvailable` completes evidence and effective mode
  selection before the body begins, without leaking Kitty stack state.

## Phase 3 — Runtime rendering policies

**Goal**: applications can adjust output during a live session without mutating evidence,
leaving stale cell metadata, or changing a draw transaction halfway through encoding.

### Step 3.1 — Add runtime color rendering control

- Files:
  - `Sources/TesseraTerminal/TerminalCapabilities.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift` only if the effective-color seam
    changes
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift` when renderer API changes
- Preserve passively detected depth in `TerminalCapabilities.color`. Store actor-isolated
  `ColorCapabilityOverride`, separately identified explicit `NO_COLOR` and `TERM=dumb`
  no-color constraints, and separately computed `effectiveColorCapability`; migrate
  resolution/tests that currently overwrite evidence. Preserve current dumb-TERM
  precedence.
- Preserve the existing `ColorCapabilityOverride.force(ColorCapability)` associated-value
  API. `.detect` reuses evidence; `.force(.unknown)` resolves effectively to `.unknown`,
  retaining existing ANSI16-safe renderer resolution. Demo cycling offers only
  noColor/ansi16/indexed256/truecolor.
- Either no-color constraint pins effective output to `.noColor`, even when application
  policy requests a forced color depth. A changed effective depth invalidates and repaints
  an unchanged frame; equal policy or a policy change that remains pinned to the same
  effective depth does not repaint. Draw passes the effective value, never the evidence
  field.
- Define the draw policy commit point after `io.size()` returns and before the synchronous
  frame body/encoding. A setter that runs while size is suspended affects that draw; a
  setter after bytes are encoded affects the next draw and its invalidation remains armed.
- Tests in this same step cover every depth transition, delayed-size actor interleaving,
  unchanged-buffer repaint, equality/no-effective-change no-op, underline-color
  interaction, SGR replay, evidence immutability, separately identified `NO_COLOR` and
  dumb-TERM provenance/precedence, and `.force(.unknown)`.
- Acceptance: users can change color rendering live without falsifying evidence or leaking
  prior SGR state.

### Step 3.2 — Add runtime hyperlink rendering control

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift` or the focused
    Ghostty virtual-terminal test file that can inspect `RenderedCell.hyperlinkURI`
- Make `hyperlinkRendering` actor-isolated `public private(set)` state and add a public
  setter. Apply the same draw commit-point rule as color.
- Enabling/disabling invalidates and repaints unchanged cells so OSC 8 metadata is added
  or removed. Preserve the contract that a frame emits a close sequence. Record the
  current flush-failure risk: `Renderer.invalidate()` clears `currentHyperlink`, so it
  must not forget a possibly delivered open. Before invalidation, solve it through
  retained-suffix delivery before subsequent frame bytes or a conservative close if that
  suffix is discarded; document the closure path.
- Tests in this same step cover both transitions, equal assignment, unchanged visible
  text, Ghostty-observed hyperlink metadata removal/addition, exact close ordering,
  delayed-size interleaving, partial failure after OSC 8 open, retained-suffix retry, and
  invalidation.
- Acceptance: hyperlink output changes live without stale clickable cells, leaked OSC
  state, or hidden text.

### Step 3.3 — Add runtime synchronized-output control

- Files:
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/PlatformIOTests.swift` when retained-output behavior
    changes
- Make `synchronizedOutput` actor-isolated `public private(set)` state and add a public
  setter. Capture it at the same post-size draw commit point; never switch wrappers
  mid-transaction.
- Move both synchronized wrapper boundaries to `TerminalSession.draw` (or make the
  renderer wrapper-free for session draws): enter before `Renderer.encodeFrame`, cursor
  visibility/position after renderer cells/reset, and exit as the final frame byte. Do not
  split boundary ownership. Cursor restoration during session cleanup remains a separate
  operation.
- Do not invalidate cell renderer state solely for this policy. Equal assignment is a
  no-op.
- Tests in this same step assert exact complete wrapper ordering, cursor bytes inside the
  wrapper, delayed-size setter interleaving, no repaint, partial/failed flush
  retained-suffix ordering, retry, and subsequent-frame boundaries.
- Acceptance: synchronized output changes only at a documented frame boundary and cannot
  strand an open wrapper.

### Step 3.4 — Add opt-in terminfo-database underline compatibility

**Goal**: modern default unchanged; applications may opt into an honest terminal-database
downgrade without brand checks.

- Files:
  - `Sources/TesseraTerminalIO/TerminfoDatabase.swift` (new bounded directory-entry
    reader)
  - `Sources/TesseraTerminal/TerminalCapabilities.swift`
  - `Sources/TesseraTerminal/TerminalCapabilityDetector.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Tests/TesseraTerminalIOTests/TerminfoDatabaseTests.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
- Keep `TerminalApplicationConfiguration.underlineRendering` concrete and default
  `.extended`. Add `UnderlineCompatibilityMode` with `.disabled` (default) and
  `.terminfoDatabase`; it selects initial startup policy only.
  `TerminalSession.setUnderlineRendering(_:)` is an explicit runtime override and is not
  reprojected through the terminfo database.
- Add public inspectable underline declaration evidence with independent style and color
  axes: `declared`, `notDeclared`, and `unknown`. Do not reuse `CapabilityStatus`, whose
  supported/unsupported cases describe protocol-native evidence.
- `.terminfoDatabase` intersects requested policy with evidence per axis. A valid entry
  missing Smulx resolves to `singleOnly`; a valid entry missing Setulc resolves to `omit`.
  A declared axis retains its requested value; an unknown axis leaves the requested value
  unchanged. It never upgrades a requested omitted/single-only axis. `.disabled` uses the
  requested policy unchanged.
- Implement a bounded pure-Swift ncurses directory-tree reader. Search injected
  environment in this precedence: `TERMINFO`, `HOME/.terminfo`, `TERMINFO_DIRS` (an empty
  component means system roots), then documented system roots. Support first-character and
  two-digit hexadecimal subdirectories. Parse legacy and extended-number magics, Boolean
  alignment, extended header/table/name ordering, checked arithmetic, and ncurses limits.
  Ignore or reject hashed databases and unsupported/non-ncurses formats as unknown. Never
  spawn `infocmp`/`tput`, link ncurses, or mutate process-global curses state.
- On Windows, no `TERM`, missing/unreadable/malformed/hashed databases, return unknown
  evidence and leave requested policy unchanged. Do not branch on terminal brand.
- Deterministic tests use injected environment/filesystem and fixture bytes for both
  magics, odd Boolean padding, all four Smulx/Setulc combinations,
  malformed/truncated/oversized/ invalid offsets, search precedence, first-character and
  hex layouts, hashed/unsupported unknown, startup resolution, default-disabled modern
  behavior, terminfo-database mixed-axis downgrade, and runtime explicit override.
- Demo capability and underline panels display declaration evidence separately from
  active-probe evidence and active concrete policy; do not auto-probe.
- Acceptance: `.extended` remains the normal default; `.terminfoDatabase` is explicit
  legacy-compatibility opt-in; `Apple_Terminal` is never named; valid absent declarations
  downgrade safely; unavailable evidence does not dumb down output.

## Phase 4 — Runtime application modes

**Goal**: selected application modes change through one lifecycle-owned transaction.
Bracketed paste remains startup-only.

### Step 4.1 — Centralize requested, effective, and ambiguous mode state

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminalIO/ModeLifecycle.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Add one private session reconciler that derives the full requested application set and
  passes through the non-reentrant lifecycle gate. Preserve active cursor style and
  startup bracketed-paste intent; reject raw/alternate-screen mutation.
- On success, commit requested state and refresh effective/possible state. On failure,
  keep the prior requested application policy, but publish the lifecycle's successfully
  active and possibly-active belief so public state never claims the old snapshot is
  exact.
- Refactor cursor and conditional Kitty changes through this helper. Do not derive desired
  modes from the old effective `enabledProtocolModes`; doing so can resurrect a disabled
  mode or lose unavailable Kitty intent.
- Tests in this same step cover no-op, multi-mode ordering, same-slot concurrent setters,
  unrelated queued setters, cancellation, partial failure/reporting, retry, cursor/Kitty
  intent preservation, fixed-mode rejection, and cleanup.
- Acceptance: every runtime mode setter below shares one serialized state/cleanup
  invariant.

### Step 4.2 — Add runtime mouse tracking control

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Add a public setter for disabled, button-event, and any-event tracking. The effective
  mode changes only through successful lifecycle application.
- Update the Mouse panel: `t` cycles actual tracking; existing `m` remains a separately
  labeled logging filter.
- Tests in this same step cover every transition and established exact ordering: enable
  1002 or 1003 followed by 1006; defensive disable 1003, 1002, then 1006. Do not introduce
  1000 without a separate encoder/spec decision. Cover no-op, event volume semantics,
  cleanup, failure state, and cursor/focus/Kitty preservation.
- Acceptance: applications can reduce mouse event volume or enable hover without
  rebuilding the session.

### Step 4.3 — Add runtime focus-event control

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Add a public focus-event setter through the central reconciler. Do not suppress an event
  already parsed before the transition. Update the Focus panel with `f` and
  requested/effective status.
- Tests in this same step cover exact 1004 set/reset, no-op, ordering around
  already-parsed input, preservation of other modes, partial failure, and cleanup.
- Acceptance: focus reporting changes live without event loss or mode-state drift.

### Step 4.4 — Add runtime Kitty keyboard policy control

- Files:
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`
- Add a public setter for `.legacyOnly`, `.kittyIfAvailable`, and `.kittyRequired`.
  Conditional mode consumes cached one-generation evidence; it does not start an ambiguous
  repeated query. The parser continues to accept valid Kitty reports in every mode.
- Preserve push/pop balance through repeated transitions and teardown. Update the Keyboard
  panel with `k`, showing requested policy, evidence, and effective/possible mode
  separately.
- Tests in this same step cover every policy/evidence combination, repeated transitions,
  required precedence, push/pop balance, queued concurrency, partial failure, cleanup, and
  parsing while legacy mode is effective.
- Acceptance: applications can expose a live keyboard setting without corrupting input or
  the Kitty flag stack.

## Phase 5 — Integrated demo, specification, and validation

**Goal**: public contract, demo, lifecycle guarantees, tests, and documentation agree
before umbrella Phase 4 begins.

### Step 5.1 — Complete the runtime-control demo surfaces

- Files:
  - `Examples/Package.swift` declares the `Phase3ProtocolsDemoSupport` library target, the
    executable's by-name dependency, its test target, and adds it to
    `AllTesseraExampleTargetNames` for shared settings.
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
  - `Examples/Tests/Phase3ProtocolsDemoSupportTests/`
- Complete collision-free controls:
  - Capabilities: panel-local `d` cycles detect/truecolor/256/16/no-color and `y` toggles
    synchronized output. Do not offer repeated active-probe refresh because untagged
    responses cannot be safely generation-fenced.
  - Links: panel-local `h` toggles OSC 8 rendering.
  - Mouse: panel-local `t` cycles actual tracking; global `m` remains logging-only and is
    labeled.
  - Focus: panel-local `f` toggles focus reporting.
  - Keyboard: panel-local `k` cycles legacy/if-available/required.
  - Underline/Cursor retain existing `s`/`c` and `s`/`x`; Clip `c` is panel-local.
    Graphics `g`, numeric tabs, `q`, and `m` remain global.
- Display evidence, requested policy, effective state, and possibly-active state
  separately. Capabilities shows detected color apart from override/effective depth and
  displays terminfo-database underline declarations separately from active-probe evidence
  and active concrete policy. Keyboard shows policy, evidence, and effective mode.
  Terminal identity remains diagnostic only.
- Extract pure key-routing/cycle helpers into the support target; test all control
  transitions, panel-local routing, global `g`/`m` behavior, release-event no-op, and
  collisions in the same step. Build the executable as the integration smoke check.
- Keep bracketed paste startup-only, clipboard policy fixed, and graphics operational.
- Acceptance: every planned setting is observable/tested without importing
  executable-private state or using source-text assertions.

### Step 5.2 — Update the specification and affected plans

- Files:
  - `docs/Spec.md`
  - `.agents/plans/015-phase-3-modern-terminal-protocols.md`
  - `.agents/plans/017-phase-3-slice-2-focus-events.md`
  - `.agents/plans/018-phase-3-slice-3-sgr-mouse-tracking.md`
  - `.agents/plans/019-phase-3-slice-4-kitty-keyboard-protocol.md`
  - `.agents/plans/020-phase-3-slice-5-osc-8-hyperlinks.md`
  - `.agents/plans/021-phase-3-slice-6-terminal-capability-detection.md`
  - `.agents/plans/022-phase-3-slice-7-kitty-graphics-protocol.md`
  - `.agents/plans/024-phase-3-slice-8-color-degradation-baseline.md`
  - `.agents/plans/026-phase-3-slice-10-cursor-styling.md`
  - `.agents/plans/027-phase-3-slice-11-underline-extensions.md`
  - `.agents/investigations/015-apple-terminal-underline-corruption.md`
  - `.agents/investigations/016-phase-3-runtime-configurability.md`
- Add the finalized Slice 12 TOC entry and section to `docs/Spec.md`. Cover lifecycle
  ambiguity, cleanup retention, single-generation probes, evidence/policy/effective state,
  app-mode precedence, draw commit points, runtime APIs, demo controls, errors, and
  deliberate exclusions.
- Update the Spec and plan 027 to state that extended underline rendering remains default,
  `.terminfoDatabase` compatibility is explicit opt-in, declaration evidence is advisory,
  runtime setter wins. Correct Step 3.4 and prior-slice language that currently implies
  send-only probes satisfy active reconciliation, capabilities/effective color are one
  value, runtime modes are fixed, or cleanup is safe before partial enable without the new
  lifecycle machinery.
- Update progress/decisions in every affected plan as implementation lands; tests and demo
  behavior stay documented beside the production contract.
- Acceptance: Phase 4 can rely on the spec without reconstructing implementation history.

### Step 5.3 — Run focused checks and the complete repository gate

- Tests are implemented and run with each production step; this closeout does not defer
  test authoring.
- Required focused commands across the plan:

  ```fish
  swift test --filter TesseraTerminalInputTests
  swift test --filter TesseraTerminalIOTests
  swift test --filter TesseraTerminalRenderingTests
  swift test --filter TesseraTerminalTests
  swift test --package-path Examples --filter Phase3ProtocolsDemoSupportTests
  swift build --package-path Examples --product Phase3ProtocolsDemo
  pnpx markdownlint-cli docs/Spec.md .agents/plans/015-phase-3-modern-terminal-protocols.md .agents/plans/028-phase-3-runtime-protocol-control.md
  ```

- Before review, run the repository gate in the required order:

  ```fish
  just quality format
  swift test
  just quality lint
  ```

- Acceptance: focused checks, demo-support tests/build, complete suite, strict lint,
  Markdown lint, lifecycle partial-failure/cleanup tests, and actor-interleaving tests
  pass without wall-clock sleeps. Mark this plan complete only after the gate; if later
  umbrella work remains, return plan 015 to pending rather than completing it.

## References

- `docs/Spec.md` Phase 3 overview and Slices 3–11
- `.agents/plans/015-phase-3-modern-terminal-protocols.md`
- `.agents/plans/017-phase-3-slice-2-focus-events.md`
- `.agents/plans/018-phase-3-slice-3-sgr-mouse-tracking.md`
- `.agents/plans/019-phase-3-slice-4-kitty-keyboard-protocol.md`
- `.agents/plans/020-phase-3-slice-5-osc-8-hyperlinks.md`
- `.agents/plans/021-phase-3-slice-6-terminal-capability-detection.md`
- `.agents/plans/022-phase-3-slice-7-kitty-graphics-protocol.md`
- `.agents/plans/024-phase-3-slice-8-color-degradation-baseline.md`
- `.agents/plans/026-phase-3-slice-10-cursor-styling.md`
- `.agents/plans/027-phase-3-slice-11-underline-extensions.md`
- `.agents/investigations/015-apple-terminal-underline-corruption.md`
- `.agents/investigations/016-phase-3-runtime-configurability.md`
- `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`
- `Sources/TesseraTerminal/TerminalCapabilities.swift`
- `Sources/TesseraTerminal/TerminalSession.swift`
- `Sources/TesseraTerminalIO/ModeLifecycle.swift`
- `Sources/TesseraTerminalIO/PlatformIO.swift`
- `Sources/TesseraTerminalInput/InputParser.swift`
- `Sources/TesseraTerminalRendering/Renderer.swift`
- `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
