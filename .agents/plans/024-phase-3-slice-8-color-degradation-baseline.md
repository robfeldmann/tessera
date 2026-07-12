---
name: Phase 3 Slice 8 Color Degradation Baseline
description:
  Add capability-aware color degradation so Tessera renders truecolor, 256-color, ANSI
  16-color, and no-color output safely from the same semantic styles.
status: complete
created: 2026-07-07
updated: 2026-07-08
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [x] **Phase 1 — Model and policy**
  - [x] 1.1 Move or expose `ColorCapability` where the renderer can depend on it
  - [x] 1.2 Document and test capability policy for truecolor, 256-color, ANSI 16,
        unknown, and no-color
- [x] **Phase 2 — Resolver and palette math**
  - [x] 2.1 Add a pure color resolver with exact capability-level output
  - [x] 2.2 Implement deterministic RGB/indexed degradation math
- [x] **Phase 3 — Renderer integration**
  - [x] 3.1 Thread color capability into `sgrDelta` and full-style encoding
  - [x] 3.2 Pass session capabilities into renderer frames without changing unrelated
        protocols
- [x] **Phase 4 — Tests, docs, and example panel updates**
  - [x] 4.1 Add unit and renderer tests for every policy branch
  - [x] 4.2 Update the Phase 3 demo capabilities/color panel and insert the docs slice
  - [x] 4.3 Run narrow validation commands

## Overview

This plan implements `docs/Spec.md` Phase 3 Slice 8. Tessera already models semantic
colors as `.default`, named ANSI 16 colors, 256-color palette indexes, and 24-bit RGB
values, and passive capability detection already reports `TerminalCapabilities.color`. The
missing piece is the renderer policy that decides which wire color form is safe for the
active terminal.

The renderer must degrade color at the source of SGR emission, not at call sites that
write `Style`. Views should continue to express the best color they mean; the renderer
resolves that semantic color against session capabilities and emits truecolor, indexed
256-color, ANSI 16-color, or no foreground/background color sequence as appropriate.

Before editing, the implementer must read:

1. `.agents/plans/015-phase-3-modern-terminal-protocols.md` for the umbrella Phase 3
   rules.
2. `docs/Spec.md` Phase 3 overview (`## Phase 3: Modern terminal protocols`).
3. The new docs slice titled `### Slice 8: Color degradation baseline`.
4. This plan, including the non-goals and validation commands.

## Non-goals

- Sixel, iTerm2 graphics, or any image color pipeline. Sixel remains out of scope for this
  slice.
- Dithering, contrast correction, theme detection, palette querying, or active color
  probes.
- Changing the public `Style` authoring model or making callers pre-degrade colors.
- Disabling non-color text attributes under `NO_COLOR`; bold, dim, italic, underline,
  reverse, strikethrough, hyperlinks, cursor movement, and raw payload behavior are not
  color output and should keep their existing policies.
- Replacing Tessera's current ECMA-48 named-color SGR form (`31`, `44`, etc.) with
  crossterm's indexed form (`38;5;n`) for already-named ANSI colors.
- Broad demo redesign. The example update is a small status/sample panel addition only.

## Existing code and references

- `Sources/TesseraTerminalANSI/Color.swift` already contains `Color.default`,
  `Color.ansi(_:)`, `Color.indexed(_:)`, and `Color.rgb(_,_,_)`, with
  foreground/background SGR helpers that currently emit the requested color space
  unconditionally.
- `Sources/TesseraTerminalANSI/ANSIColor.swift` maps Tessera's 16 named colors to ECMA-48
  foreground and background SGR parameters.
- `Sources/TesseraTerminal/TerminalCapabilities.swift` defines `ColorCapability` today,
  but `Sources/TesseraTerminalRendering` cannot import `TesseraTerminal` without creating
  a target cycle. The capability type must move to, or be defined in, a dependency shared
  by `TesseraTerminal` and `TesseraTerminalRendering`.
- `Sources/TesseraTerminal/TerminalCapabilityDetector.swift` already maps `NO_COLOR` and
  `TERM=dumb` to `.noColor`, `COLORTERM=truecolor`/`24bit` and `TERM` truecolor hints to
  `.truecolor`, `TERM=*256color*` to `.indexed256`, and basic `TERM` color hints to
  `.ansi16`; missing hints stay `.unknown`.
- `Sources/TesseraTerminalRendering/StyleEncoding.swift` is the central SGR delta encoder;
  integrating there keeps damage rendering, full repaints, and adjacent-style elision on
  one path.
- Ratatui reference: `~/Developer/ratatui/ratatui/main/ratatui-core/src/style/color.rs`
  keeps semantic `Color::Rgb`/`Color::Indexed` variants and documents that truecolor
  output can misrender on unsupported terminals; `ratatui-crossterm/src/lib.rs` converts
  Ratatui colors to crossterm colors at backend emission time.
- Crossterm reference: `style::available_color_count()` uses `COLORTERM`/`TERM` hints,
  `Colored` honors `NO_COLOR` by emitting no color parameters, and crossterm's `Color`
  supports named, ANSI-value, and RGB forms. Tessera should borrow the
  environment/no-color posture, but keep Tessera's own capability data model and SGR
  encoding conventions.

## Phase 1 — Model and policy

**Goal**: the renderer can receive a terminal color capability without layering
violations, and the policy is explicit enough that every fallback is testable.

### Step 1.1 — Move or expose `ColorCapability` where rendering can use it

- Files:
  - `Sources/TesseraTerminal/TerminalCapabilities.swift`
  - new or updated `Sources/TesseraTerminalANSI/ColorCapability.swift`
  - `Sources/TesseraTerminal/TerminalCapabilityDetector.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
- Move `ColorCapability` from `TesseraTerminal` into `TesseraTerminalANSI` beside
  `Color.swift`, or otherwise place it in a lower-level module already depended on by both
  `TesseraTerminal` and `TesseraTerminalRendering`. Prefer `TesseraTerminalANSI` because
  the type controls SGR color encoding policy and the rendering target already imports
  ANSI.
- Do not create a second renderer-only capability enum. The same public value must flow
  from detection/session state into renderer encoding.
- If tests or files need the moved type explicitly, add `import TesseraTerminalANSI`
  rather than reintroducing a parallel alias in `TesseraTerminal`.
- Preserve the current cases and meanings:

  ```swift
  public enum ColorCapability: Equatable, Sendable {
    case ansi16
    case indexed256
    case noColor
    case truecolor
    case unknown
  }
  ```

- Keep `TerminalCapabilities.color` defaulting to `.unknown` and
  `TerminalCapabilities.conservativeDefault.color == .unknown`.

Acceptance:

- `TerminalCapabilities` and `TerminalCapabilityDetector` still expose one shared
  `ColorCapability` type.
- `TesseraTerminalRendering` can name `ColorCapability` without importing
  `TesseraTerminal`.
- No production code duplicates the capability enum or maps between two identical enums.

### Step 1.2 — Lock the rendering policy in tests before renderer rewiring

- Files:
  - new focused tests in `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or
    `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
- Define the policy as:
  - `.truecolor`: emit requested `.rgb` as `38/48;2;r;g;b`; requested `.indexed` and
    `.ansi` may remain in their original narrower forms because truecolor terminals also
    accept them.
  - `.indexed256`: emit requested `.rgb` as nearest xterm 256-color index; keep requested
    `.indexed`; keep requested `.ansi` as ECMA-48 named-color SGR.
  - `.ansi16`: emit requested `.rgb` and non-ANSI `.indexed` values as nearest
    `ANSIColor`; map `.indexed(0...15)` to the corresponding `ANSIColor`; keep requested
    `.ansi`.
  - `.unknown`: treat as `.ansi16`, not `.noColor`. Unknown terminals should receive only
    the safest standardized color level, while still showing intentionally colored
    warnings, focus state, and examples when basic color works.
  - `.noColor`: resolve every foreground/background color to `.default` and emit no
    non-default foreground/background SGR. Attribute SGR and OSC 8 policy are unaffected.
- Keep `.default` as `.default` under every capability.
- Add capability detector tests only where policy depends on detector inputs:
  - `NO_COLOR` wins over `COLORTERM=truecolor` and `TERM=xterm-256color` (already present;
    keep it passing).
  - `TERM=dumb` resolves `.noColor`.
  - missing environment remains `.unknown` so the renderer's unknown policy is exercised
    separately.

Acceptance:

- The intended capability ladder is visible in test names before or alongside the encoder
  refactor.
- `NO_COLOR` and `TERM=dumb` are policy inputs to `.noColor`; missing or unknown hints are
  not silently treated as no-color.

## Phase 2 — Resolver and palette math

**Goal**: color degradation is pure, deterministic, allocation-free in the common renderer
path, and independent of damage tracking.

### Step 2.1 — Add a pure color resolver

- Files:
  - `Sources/TesseraTerminalANSI/Color.swift`
  - `Sources/TesseraTerminalANSI/ANSIColor.swift`
  - new or updated tests in `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or a
    focused `ColorResolutionTests.swift` in the same target
- Resolve semantic `Color` to a narrower **`Color`**, not a new parallel type. Add:

  ```swift
  extension Color {
    /// The representable form of this color under `capability`, still a `Color`.
    /// `.default` is preserved under every capability.
    package func resolved(for capability: ColorCapability) -> Color
  }
  ```

  Do not introduce a `ResolvedColor` enum: its cases would be identical to `Color`
  (`default`/`ansi`/`indexed`/`rgb`), so a second type only adds a boundary conversion
  with no invariant `Color` cannot already express. Every degraded result — `.rgb` →
  `.indexed`, `.rgb`/`.indexed` → `.ansi`, any color → `.default` — is a legal `Color`, so
  resolution is closed over `Color`.

- Do not add `foregroundSGRParameters(for:)` / `backgroundSGRParameters(for:)`.
  `ControlSequence.setForeground(_:)` already emits bytes from
  `Color.foregroundSGRParameters` (see `ControlSequence.swift`), so resolving to a
  narrower `Color` first and feeding the existing `setForeground`/`setBackground` cases
  reuses the one byte-generation path with zero new SGR encoding: one resolver, one
  encoder, no drift.
- `resolved(for:)` must be pure and allocation-free (a `switch` returning a `Color`); it
  performs no byte encoding and builds no per-cell lookup tables.

Acceptance:

- Resolution can be tested without constructing a `Buffer` or `Renderer`.
- Existing exact byte tests for named ANSI, indexed, and RGB encoding still pass for the
  default/truecolor path.

### Step 2.2 — Implement deterministic degradation math

- Files:
  - `Sources/TesseraTerminalANSI/Color.swift`
  - `Sources/TesseraTerminalANSI/ANSIColor.swift`
  - tests from Step 2.1
- Add constant palette data for:
  - ANSI 16 canonical RGB approximations. Pin the **xterm default palette** explicitly so
    tests are reproducible rather than palette-dependent guesses: `black 000000`,
    `red cd0000`, `green 00cd00`, `yellow cdcd00`, `blue 0000ee`, `magenta cd00cd`,
    `cyan 00cdcd`, `white e5e5e5`, `brightBlack 7f7f7f`, `brightRed ff0000`,
    `brightGreen 00ff00`, `brightYellow ffff00`, `brightBlue 5c5cff`,
    `brightMagenta ff00ff`, `brightCyan 00ffff`, `brightWhite ffffff`. Real terminals
    theme these, so ANSI-16 fallback is an explicit best-effort hue match against this
    reference table, tie-broken deterministically — not a promise about on-screen pixels.
  - xterm 256-color palette entries for indexes 16...231 (6x6x6 cube with components
    `[0, 95, 135, 175, 215, 255]`) and 232...255 (grayscale ramp `8 + 10 * n`).
- RGB → indexed256:
  - search only indexes 16...255. Exclude system indexes 0...15: those slots are
    user/theme configurable, so including them would make output depend on terminal
    configuration and break deterministic snapshots.
  - choose the nearest entry by squared Euclidean distance in sRGB byte space; no floating
    point is necessary.
  - tie-break by the lower palette index for deterministic snapshots.
  - Exact colors in the cube or grayscale ramp must map to their exact indexes.
- indexed256 → ansi16:
  - indexes 0...15 map by table to Tessera `ANSIColor` values: `0 black`, `1 red`,
    `2 green`, `3 yellow`, `4 blue`, `5 magenta`, `6 cyan`, `7 white`, `8 brightBlack`,
    `9 brightRed`, `10 brightGreen`, `11 brightYellow`, `12 brightBlue`,
    `13 brightMagenta`, `14 brightCyan`, `15 brightWhite`.
  - indexes 16...255 first expand to canonical xterm RGB, then map to nearest ANSI 16.
- RGB → ansi16 maps directly to nearest ANSI 16 by the same squared-distance function.
- Keep foreground and background symmetric; do not special-case backgrounds unless a test
  proves a foreground/background bug.
- Add tests for edge colors and visually important fallbacks. Compute every expected value
  from the pinned tables above; do not assert intuited names. The pinned xterm palette has
  deliberate asymmetries the tests must encode: pure `rgb(255,0,0)` → `brightRed` and
  `rgb(0,255,0)` → `brightGreen` (both exact), but pure `rgb(0,0,255)` → `blue`, because
  xterm `brightBlue` is `5c5cff` and sits farther from pure blue than `blue` `0000ee`.
  - exact RGB red/green/blue/white/black to the ANSI 16 values that fall out of the table
  - grayscale RGB values map to the nearest of
    `black`/`brightBlack`/`white`/`brightWhite`, with expected values documented in the
    test
  - RGB colors exactly on xterm cube entries map to exact 256 indexes
  - RGB colors near the grayscale ramp choose grayscale indexes when closer than the cube
  - indexed 0...15 degrade to the documented ANSI mapping
  - indexed 196 (`rgb(255,0,0)`) degrades to `brightRed`; indexed 21 (`rgb(0,0,255)`)
    degrades to `blue`, not `brightBlue`
  - `.default` survives every capability

Acceptance:

- The resolver does not depend on terminal identity names; it depends only on
  `ColorCapability`.
- Tie-breakers are deterministic and documented by tests.
- No fallback path emits invalid SGR parameters.

## Phase 3 — Renderer integration

**Goal**: every rendered frame uses the same capability-aware color resolver while
preserving existing damage, hyperlink, raw payload, synchronized-output, and cursor
behavior.

### Step 3.1 — Thread color capability through SGR delta encoding

- Files:
  - `Sources/TesseraTerminalRendering/StyleEncoding.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
- Update `sgrDelta(from:to:into:)` and `encodeFullStyle(_:into:)` to accept a color
  capability, for example:

  ```swift
  package func sgrDelta(
    from oldStyle: Style?,
    to newStyle: Style,
    colorCapability: ColorCapability,
    into bytes: inout [UInt8]
  )
  ```

- Resolve `oldStyle`/`newStyle` foreground and background to their `Color.resolved(for:)`
  form once at the top of `sgrDelta`, then run the existing delta logic against the
  resolved colors. All three comparison sites must key off the resolved color or redundant
  SGR leaks through:
  - the early-out equality guard (currently `sgrAttributes`),
  - `requiresReset` (its `foreground == .default` / `background == .default` tests: under
    `.noColor` every color resolves to `.default`, so a raw-color test would spuriously
    force a reset + full repaint), and
  - the per-field `oldStyle.foreground != newStyle.foreground` guards. If two semantic
    colors resolve to the same color under the active capability, no color SGR is emitted
    between them.
- Preserve damage tracking semantics: `BufferDiff` should still see raw `Style` equality
  so changing a semantic color repaints the cell. The SGR delta may then emit no color
  bytes if the two colors resolve identically under the active capability, but it must
  still emit the cell content so the terminal state is correct after damage.
- Under `.noColor`, if old/new foreground or background differs only in color, do not emit
  foreground/background SGR. If an attribute is added/removed, emit the existing attribute
  SGR exactly as today.
- Keep final frame reset (`SGR 0`) in place. Resetting all attributes at frame end is not
  a colorized output choice; it is renderer state cleanup.

Acceptance:

- One style encoding path handles both full repaint and damage repaint.
- `.noColor` removes foreground/background color sequences but does not remove text,
  attributes, hyperlinks, cursor movement, synchronized-output wrappers, or final cleanup.
- Damage rendering still repaints semantic color changes even when the resolved color is
  the same under the active capability.

### Step 3.2 — Pass session color capability into renderer frames

- Files:
  - `Sources/TesseraTerminalRendering/Renderer.swift`
  - `Sources/TesseraTerminal/TerminalSession.swift`
  - `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift` only if a resolution
    field is needed for clarity
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
- Add a `colorCapability: ColorCapability` parameter to `Renderer.encodeFrame(...)` with
  **no default**. Production output must make a deliberate choice; a defaulted parameter
  would let `TerminalSession.draw` silently emit truecolor to a `.noColor` terminal by
  omission. Default `.truecolor` only on the static
  `Renderer.render`/`render(previous:current:)` test helpers, so existing direct renderer
  byte tests keep covering exact ANSI/RGB output unless they opt into degradation.
- Have `TerminalSession.draw` pass actor-isolated `effectiveColorCapability` into
  `renderer.encodeFrame`; `TerminalCapabilities.color` remains detected advisory metadata
  and is not itself the live rendering policy.
- Do not add a new terminal mode or lifecycle step. Color degradation is renderer policy,
  not a protocol enable sequence.
- Do not make `NO_COLOR` a renderer environment read. The detector records environment
  evidence; tests inject capabilities and user constraints rather than read the developer
  machine's environment.
- Add an application-level `ColorCapabilityOverride` intent, defaulting to `.detect`.
  `TerminalSession.setColorCapability(_:)` changes that live policy. It derives a separate
  effective renderer capability from detected metadata and user constraints, invalidating
  the renderer only when that effective capability changes.
- `NO_COLOR` and `TERM=dumb` pin the effective result to `.noColor`; otherwise an explicit
  application override wins over detected capability metadata. Surface both detected and
  effective values distinctly so callers cannot mistake evidence for policy.

Acceptance:

- Live sessions use detected/injected color capability automatically.
- Direct renderer tests can opt into `.indexed256`, `.ansi16`, `.unknown`, and `.noColor`
  without constructing `TerminalSession`.
- Capability detection remains advisory and never fails startup because color is unknown.

## Phase 4 — Tests, docs, and example panel updates

**Goal**: reviewers can verify policy from tests, docs, and the Phase 3 demo without
running broad suites.

### Step 4.1 — Add renderer and session tests

- Files:
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererVisualEquivalenceTests.swift` if a visual
    fallback check is useful
  - `Tests/TesseraTerminalTests/TerminalSessionTests.swift`
  - `Tests/TesseraTerminalTests/TerminalCapabilityTests.swift`
- Add exact byte renderer tests for:
  - `.rgb(255, 0, 0)` foreground under `.truecolor` emits `38;2;255;0;0`.
  - same RGB foreground under `.indexed256` emits the expected nearest `38;5;<index>`.
  - same RGB foreground under `.ansi16` and `.unknown` emits the expected named-color SGR.
  - same RGB foreground under `.noColor` emits no foreground SGR while still writing text.
  - background uses `48` equivalents for truecolor/indexed and named background SGR for
    ANSI 16.
  - adjacent cells whose semantic colors degrade to the same color do not emit redundant
    color SGR between them.
  - attribute-only changes still emit under `.noColor`.
  - hyperlink rendering and color no-color policy compose: links can still open/close
    while foreground/background color is suppressed.
- Add session-level tests that create/inject a configuration/environment with `NO_COLOR`
  or explicit `.noColor` capabilities and assert `TerminalSession.draw` passes no-color
  policy through to renderer output. Use existing package seams/stubs; do not read the
  real process environment.
- Keep existing capability detector tests for `NO_COLOR`, `TERM=dumb`, `truecolor`, and
  `256color` passing. Add missing cases if any branch is uncovered.

Acceptance:

- Unit tests cover the pure resolver and byte-level renderer output.
- Session tests prove the detected capability reaches real draw output.
- Existing hyperlink, raw payload, opaque cell, synchronized output, and style-delta tests
  are updated only where their expected color bytes intentionally change.

### Step 4.2 — Update docs slice and Phase 3 demo panel

- Files:
  - `docs/Spec.md`
  - `Examples/Sources/Phase3ProtocolsDemo/Phase3ProtocolsDemo.swift`
- Insert the docs section titled `### Slice 8: Color degradation baseline` after Slice 7
  in `docs/Spec.md`. Use the draft supplied with this plan review and keep Sixel
  explicitly out of scope.
- Update the Phase 3 overview slice list and table of contents if the surrounding spec
  maintains one for Phase 3 slices.
- In `Phase3ProtocolsDemo`, add a small color degradation panel or extend the existing
  capabilities panel with:
  - detected `capabilities.color`
  - selected `effectiveColorCapability`, distinct from detected metadata
  - the effective fallback ladder (`truecolor → 256 → 16 → no-color`)
  - sample swatches/text written as RGB, indexed, ANSI 16, and default colors so reviewers
    can see degradation under `NO_COLOR`, `TERM=dumb`, and ordinary terminals
  - a plain-text note that `NO_COLOR` suppresses foreground/background color only;
    attributes and links remain protocol-specific
- Keep demo navigation compact. If adding a new panel, update `DemoPanel`, key handling,
  header navigation, minimum terminal size, and tests/snapshots that assert demo strings.
  If extending the capabilities panel is simpler, prefer that over another navigation
  item.

Acceptance:

- The spec documents behavior before Phase 4 view work depends on it.
- The demo makes current color policy inspectable without new terminal protocols or active
  probes.

### Step 4.3 — Run narrow validation commands

- Run only narrow commands for touched targets; do not run formatters, linters, broad
  builds, or whole-package tests for this slice unless a reviewer explicitly requests
  them.
- Suggested commands after implementation:

  ```bash
  swift test --filter TesseraTerminalANSITests
  swift test --filter TesseraTerminalRenderingTests
  swift test --filter TesseraTerminalTests/TerminalCapabilityTests
  swift test --filter TesseraTerminalTests/TerminalSessionTests
  swift run --package-path Examples Phase3ProtocolsDemo
  ```

  The example command is an interactive smoke check; run it only in an interactive
  terminal or use the existing example attach workflow if that is the project convention.

Acceptance:

- Narrow tests pass for ANSI color resolution, renderer integration, capability detection,
  and session draw wiring.
- Manual/demo verification confirms `NO_COLOR=1` or `.noColor` suppresses foreground and
  background colors while preserving readable text.

## Acceptance criteria

- `ColorCapability` is available to both `TesseraTerminal` and `TesseraTerminalRendering`
  without cycles or duplicate enums.
- The renderer implements this policy exactly: `truecolor` keeps RGB, `indexed256`
  degrades RGB to xterm 256, `ansi16` degrades RGB and high indexed colors to named ANSI,
  `unknown` uses the ANSI 16 fallback, and `noColor` suppresses foreground/background
  color.
- `NO_COLOR` and `TERM=dumb` select `.noColor` through the detector; missing or
  unrecognized hints remain `.unknown` and therefore render ANSI 16 fallback, not
  no-color.
- Degradation math is deterministic, tested, and independent of terminal identity strings.
- Full repaint and damage repaint use the same color resolver.
- No-color output still emits text, non-color attributes, hyperlinks when enabled, cursor
  movement, raw payloads, synchronized-output wrappers, and final reset/cleanup.
- The Phase 3 demo exposes the detected color capability and a visible fallback sample.
- Sixel remains out of scope.

## References

- `docs/Spec.md` — `## Phase 3: Modern terminal protocols` and the new Slice 8 section.
- `.agents/plans/015-phase-3-modern-terminal-protocols.md` — umbrella Phase 3 plan.
- `Sources/TesseraTerminalANSI/Color.swift`
- `Sources/TesseraTerminalANSI/ANSIColor.swift`
- `Sources/TesseraTerminal/TerminalCapabilities.swift`
- `Sources/TesseraTerminal/TerminalCapabilityDetector.swift`
- `Sources/TesseraTerminalRendering/StyleEncoding.swift`
- `Sources/TesseraTerminalRendering/Renderer.swift`
- `~/Developer/ratatui/ratatui/main/ratatui-core/src/style/color.rs`
- `~/Developer/ratatui/ratatui/main/ratatui-crossterm/src/lib.rs`
- Crossterm `style.rs`, `style/types/color.rs`, and `style/types/colored.rs` sources read
  from `https://raw.githubusercontent.com/crossterm-rs/crossterm/master/` during planning.
