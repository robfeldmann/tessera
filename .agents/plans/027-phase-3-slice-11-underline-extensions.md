---
name: Phase 3 Slice 11 Underline Extensions
description:
  Add semantic SGR underline style variants and colored underlines: undercurl and other
  SGR 4:x styles, underline color/reset, renderer diffing, compatibility with the legacy
  underline bit, snapshots, exact byte tests, and documentation.
status: complete
created: 2026-07-07
updated: 2026-07-09
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete. -->

## Progress

- [x] **Phase 1 — Model and clean API**
  - [x] 1.1 Read the Phase 3 protocol context before editing
  - [x] 1.2 Add the underline style value model and remove the boolean underline bit
  - [x] 1.3 Add the underline color model without changing text width or raw payload
        semantics
- [x] **Phase 2 — ANSI encoding and renderer integration**
  - [x] 2.1 Add semantic underline style/color control sequences
  - [x] 2.2 Teach style diffing to transition underline state with targeted SGR resets
  - [x] 2.3 Keep renderer damage tracking sensitive to underline-only changes
- [x] **Phase 3 — Tests, snapshots, docs, and demo visibility**
  - [x] 3.1 Add exact byte and renderer diff tests
  - [x] 3.2 Extend buffer and virtual-terminal snapshot support where the harness exposes
        data
  - [x] 3.3 Update the Phase 3 docs and example surface

## Overview

This plan implemented `docs/Spec.md` Phase 3 Slice 11. Tessera models semantic underline
variants (`4:2` double, `4:3` curly/undercurl, `4:4` dotted, `4:5` dashed) and underline
colors (`58` plus `59` reset) independently from two-state text attributes. The work is
output-only: visible text remains ordinary cells and underline metadata consumes no layout
columns. Session rendering applies an application-selected `UnderlineRenderingPolicy` that
can preserve or collapse variants independently from emitting or omitting underline color.
The extended preset is the default; baseline rendering is explicit.

Before making code changes, future implementers must read these four sources in order:

1. `.agents/plans/015-phase-3-modern-terminal-protocols.md`
2. `docs/Spec.md`'s Phase 3 overview and the inserted `### Slice 11: Underline extensions`
   section
3. this plan file
4. the current implementations of `Style`, `ControlSequence`, and `StyleEncoding` listed
   below, because Phase 3 plans before this one may have changed them

## Non-goals

- Do not implement Sixel, iTerm2 OSC 1337, or any graphics protocol work; those remain out
  of scope for this slice.
- Do not add active terminal probing for underline style or underline color support.
  Applications select the underline rendering policy explicitly.
- Do not parse terminal input for underline styles; Tessera's input parser does not
  receive style state from ordinary terminal output.
- Do not replace foreground/background color APIs, rewrite the broader color model, or add
  theme/palette abstractions.
- Do not make underline metadata affect grapheme width, wrapping, raw payload occupancy,
  opaque cells, or Kitty graphics placement.
- Do not require every terminal snapshot backend to expose underline style/color if the
  backend cannot report it; exact byte tests are authoritative for encoder behavior.

## Contracts

### SGR wire contract

- Single underline remains SGR `4` and reset remains SGR `24`.
- Variant underlines use subparameter SGR forms:
  - `.single` may encode as `4` for compatibility, not `4:1`.
  - `.double` encodes as `4:2`; do not use legacy SGR `21`, which conflicts with bold-off
    semantics in many terminals.
  - `.curly`/undercurl encodes as `4:3`.
  - `.dotted` encodes as `4:4`.
  - `.dashed` encodes as `4:5`.
  - `.none` resets with `24`; prefer `24` over `4:0` for the off transition.
- Underline colors use the extended underline color SGR family:
  - default/reset: `59`
  - 256-color/indexed: `58:5:n`
  - truecolor: `58:2::r:g:b`
  - named 16-color ANSI colors should map to their equivalent palette index `0...15` and
    encode with `58:5:n`; there is no `30...37`/`90...97` shorthand for underline color.
- A full SGR reset (`0`) resets underline style and underline color. Targeted diffs should
  prefer `24` and `59` so renderer transitions do not needlessly drop unrelated
  attributes.

### Public style contract

- Add `public enum UnderlineStyle: Equatable, Sendable` in `TesseraTerminalANSI` (a
  focused file such as `Sources/TesseraTerminalANSI/UnderlineStyle.swift`), beside the
  existing `Color`/`ANSIColor` wire types. It must live in `TesseraTerminalANSI`, not
  `TesseraTerminalBuffer`: `ControlSequence.setUnderlineStyle(_:)` is defined in
  `TesseraTerminalANSI`, and `TesseraTerminalBuffer` already depends on
  `TesseraTerminalANSI` (never the reverse), so defining the enum in the buffer target
  would force a dependency cycle. `Style` (in `TesseraTerminalBuffer`) reuses it directly
  through its existing `import TesseraTerminalANSI`. The supported cases are:

  ```swift
  public enum UnderlineStyle: Equatable, Sendable {
    case none
    case single
    case double
    case curly
    case dotted
    case dashed
  }
  ```

- Extend `Style` with:

  ```swift
  public var underlineStyle: UnderlineStyle
  public var underlineColor: Color
  ```

  Defaults: `underlineStyle: .none`, `underlineColor: .default`.

- Do not preserve a boolean `TextAttributes.underline` compatibility bridge. This API has
  not shipped, so prefer the clean model:
  - remove the underline bit from `TextAttributes` if it still exists;
  - update all demos, tests, and internal call sites from `.underline` to
    `underlineStyle: .single`;
  - make `style.underlineStyle` the single source of truth for whether text is underlined.
- `underlineColor != .default` does not imply underline is enabled. It is styling state
  that becomes visible only when `underlineStyle != .none`.

### Rendering and degradation contract

- `Style` equality must include underline style and underline color so `BufferDiff`
  catches underline-only changes automatically through existing `Cell` equality.
- Renderer state must track underline style and underline color as SGR state, independent
  of OSC 8 hyperlink state and foreground/background color state.
- When transitioning from a custom underline color to `.default`, emit `59` even if the
  new style also disables underline. This prevents stale underline colors from leaking
  into a later default-colored underline.
- When transitioning from any underline style to `.none`, emit `24`.
- When transitioning between non-`.none` underline styles, emit the target style (`4`,
  `4:2`, `4:3`, `4:4`, or `4:5`) without a full `0` reset unless some other attribute
  transition already requires a reset.
- Under `.extended`, Tessera preserves the semantic style and color SGR. Under
  `.baseline`, Tessera maps every non-`.none` style to `.single` and omits underline
  color, emitting only SGR `4`/`24`. Custom policies can control the style and color axes
  independently.
- `TerminalSession.setUnderlineRendering(_:)` may change the application policy at
  runtime. A changed policy invalidates renderer state so the next draw repaints under the
  new projection; assigning the active policy is a no-op.

### Compatibility evidence contract

- `.terminfoDatabase` is an explicit startup compatibility opt-in. Its valid `Smulx` and
  `Setulc` declarations may project the configured underline policy; `.disabled` leaves
  the `.extended` default unchanged.
- Terminfo declarations, terminal identity, and missing declaration data are advisory
  evidence, not proof of support. Unknown, malformed, truncated, or absent declarations
  must not silently downgrade modern underline output.
- `TerminalSession.setUnderlineRendering(_:)` is the runtime override. Once called, its
  explicit policy takes precedence over the startup terminfo projection and invalidates
  the renderer when the projected output changes.

## Phase 1 — Model and clean API

**Goal**: buffers can carry underline style and underline color metadata through the clean
underline API.

### Step 1.1 — Read the Phase 3 protocol context before editing

- Files to read before any code edit:
  - `.agents/plans/015-phase-3-modern-terminal-protocols.md`
  - `docs/Spec.md` Phase 3 overview plus `### Slice 11: Underline extensions`
  - `.agents/plans/027-phase-3-slice-11-underline-extensions.md`
  - `Sources/TesseraTerminalBuffer/Style.swift`
  - `Sources/TesseraTerminalANSI/Color.swift`
  - `Sources/TesseraTerminalANSI/ANSIColor.swift`
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Sources/TesseraTerminalRendering/StyleEncoding.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift`
- Confirm the current source still matches the assumptions in this plan: `Style` contains
  foreground/background/attributes/hyperlink, `TextAttributes` may still contain
  `.underline`, `Color` has `.default`/`.ansi`/`.indexed`/`.rgb`, and `sgrDelta` currently
  resets when attributes are removed.

Acceptance:

- The implementation starts from the current file contents, not stale line numbers or this
  plan's sketches.
- Any prior Phase 3 slices that changed the same symbols are accounted for before editing.

### Step 1.2 — Add the underline style value model and remove the boolean bit

- Files:
  - `Sources/TesseraTerminalANSI/UnderlineStyle.swift` (new; the enum's home)
  - `Sources/TesseraTerminalBuffer/Style.swift`
  - `Tests/TesseraTerminalBufferTests/BufferTests.swift` or a focused new style test file
    in the same target
  - `Sources/TesseraTerminalTestSupport/BufferSnapshotting.swift`
- Add `UnderlineStyle` in `TesseraTerminalANSI` with the cases from the public style
  contract. `Style` sees it through its existing `import TesseraTerminalANSI`.
- Add `Style.underlineStyle` with default `.none`. Insert the parameter in the initializer
  where it reads naturally with current style fields.
- Remove `TextAttributes.underline` if it exists. Update every in-repo caller to express a
  single underline with `underlineStyle: .single`.
- Do not add `effectiveUnderlineStyle` compatibility logic that maps a boolean bit to
  `.single`; `style.underlineStyle` is the single source of truth.
- Add tests proving:
  - `Style(underlineStyle: .single)` renders single underline;
  - `Style(underlineStyle: .curly)` renders curly underline;
  - default `Style()` has `underlineStyle == .none`;
  - old in-repo `.attributes.contains(.underline)` checks or `.underline` construction no
    longer exist.
- Update buffer snapshots so non-default style metadata includes readable underline
  tokens, for example `underline=curly` or `underline=double`.

Acceptance:

- `TextAttributes` no longer carries underline state; single underline is expressed by
  `Style.underlineStyle == .single`.
- Call sites can express all six underline style cases without raw ANSI bytes.
- Buffer equality and snapshot output visibly distinguish underline style changes.

### Step 1.3 — Add the underline color model without changing layout semantics

- Files:
  - `Sources/TesseraTerminalBuffer/Style.swift`
  - `Sources/TesseraTerminalANSI/Color.swift`
  - `Sources/TesseraTerminalANSI/ANSIColor.swift`
  - `Sources/TesseraTerminalTestSupport/BufferSnapshotting.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
  - `Tests/TesseraTerminalBufferTests/BufferTests.swift` or the focused style test file
    from Step 1.2
- Add `Style.underlineColor: Color` with default `.default`.
- Add `Color.underlineSGRParameters` or an equivalently named internal/package helper:
  - `.default` -> `[59]`
  - `.indexed(index)` -> `[58, 5, Int(index)]`
  - `.rgb(r, g, b)` -> `[58, 2, Int(r), Int(g), Int(b)]`
  - `.ansi(color)` -> `[58, 5, color.ansiPaletteIndex]`
- Add `ANSIColor.ansiPaletteIndex` as an internal/package helper with the conventional
  mapping: black 0, red 1, green 2, yellow 3, blue 4, magenta 5, cyan 6, white 7,
  brightBlack 8, brightRed 9, brightGreen 10, brightYellow 11, brightBlue 12,
  brightMagenta 13, brightCyan 14, brightWhite 15.
- Snapshot non-default underline colors as `ul=indexed(196)`, `ul=rgb(1,2,3)`, or
  `ul=ansi(red)`/`ul=indexed(1)`; choose one format and keep it stable.
- Do not make underline color affect cell width, grapheme clustering, raw payload declared
  width, or opaque-cell behavior.

Acceptance:

- The same `Color` type can be reused for underline colors without changing foreground or
  background behavior.
- `Color.default` means underline color reset (`59`) in underline-color context, not SGR
  `39` or `49`.
- A style that differs only by underline color is unequal and causes normal damage
  diffing.

## Phase 2 — ANSI encoding and renderer integration

**Goal**: semantic underline style/color state encodes to exact SGR bytes and renderer
diffs transition state without broad, avoidable resets.

### Step 2.1 — Add semantic underline style/color control sequences

- Files:
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Sources/TesseraTerminalANSI/Color.swift`
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
- Replace `case setUnderline(Bool)` with the semantic cases; do not keep it as a parallel
  alias. Its only non-test caller is `StyleEncoding`, which this slice rewrites, and the
  other boolean SGR toggles (`setBold`, `setItalic`, etc.) stay `Bool` because they are
  genuinely two-state — underline is the one attribute that graduates to a value type, so
  a lingering `setUnderline(Bool)` would be a redundant second spelling of
  `setUnderlineStyle(.single)`/`.none`.
  - Add `case setUnderlineStyle(UnderlineStyle)`. `UnderlineStyle` lives in
    `TesseraTerminalANSI` per the public style contract, so `ControlSequence` references
    it directly with no dependency cycle.
  - Add `case setUnderlineColor(Color)`.
- Encode the new style/color cases per the SGR wire contract. Note that the existing
  `ANSIByteEncoding.appendSGR([Int])` joins parameters with `;`, so it cannot emit the
  colon subparameter forms (`4:2`, `4:3`, `4:4`, `4:5`). Add a colon-aware emit path (or
  emit the style token as a preformatted parameter) so `.setUnderlineStyle(.curly)`
  produces `4:3`, never `4;3`. The `58`/`59` underline-color forms use colon subparameters
  (`58:5:n`, `58:2::r:g:b`) via the colon-aware emit path; only `59` reuses `appendSGR`.
- Add exact byte tests:
  - `.setUnderlineStyle(.single)` -> `ESC[4m`
  - `.setUnderlineStyle(.double)` -> `ESC[4:2m`
  - `.setUnderlineStyle(.curly)` -> `ESC[4:3m`
  - `.setUnderlineStyle(.dotted)` -> `ESC[4:4m`
  - `.setUnderlineStyle(.dashed)` -> `ESC[4:5m`
  - `.setUnderlineStyle(.none)` -> `ESC[24m`
  - `.setUnderlineColor(.default)` -> `ESC[59m`
  - `.setUnderlineColor(.indexed(196))` -> `ESC[58:5:196m`
  - `.setUnderlineColor(.rgb(1, 2, 3))` -> `ESC[58:2::1:2:3m`
  - `.setUnderlineColor(.ansi(.red))` -> `ESC[58:5:1m`

Acceptance:

- Underline variants and underline colors can be emitted through semantic
  `ControlSequence` cases; users do not need `RawTerminalPayload` for this feature.
- Exact byte tests pin colon subparameters for `4:x`, `58:5`, and `58:2`, plus plain `59`.

### Step 2.2 — Teach style diffing to transition underline state with targeted SGR resets

- Files:
  - `Sources/TesseraTerminalRendering/StyleEncoding.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift` if renderer state needs a new cached
    style projection
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
- Extend the style projection currently named `SGRAttributes` so equality includes:
  - foreground
  - background
  - non-underline attributes
  - effective underline style
  - underline color
- Refactor `requiresReset(from:to:)` so underline removal and underline-color reset do not
  force a full `ControlSequence.resetAttributes` by themselves. Targeted sequences exist:
  `24` for underline style off and `59` for underline color reset.
- Preserve existing reset behavior for attributes that still lack a safe local removal
  path in current code, such as the broad reset used when non-underline attributes are
  removed, unless the implementation chooses to improve those paths with tests.
- Diff order should be deterministic and safe. Recommended order:
  1. foreground/background changes
  2. underline color changes (`58...` or `59`)
  3. non-underline added attributes
  4. underline style change (`24`, `4`, `4:2`, `4:3`, `4:4`, `4:5`)

  If a full reset is required for another reason, emit `0` first and then replay the full
  target style, including underline style and non-default underline color.

- Ensure `encodeFullStyle` includes non-default underline color and effective underline
  style. It should not emit `59` on a clean full-style replay immediately after `0`.

Acceptance:

- Moving from `.curly` to `.none` emits `24`, not an unavoidable `0`, when no other state
  needs reset.
- Moving from `.curly` red underline to `.curly` default underline emits `59` and keeps
  the underline style active.
- Moving from custom underline color to default while disabling underline emits both `59`
  and `24` in a deterministic order, preventing color leakage into later underlines.
- Full-reset paths replay underline style/color correctly after `0`.

### Step 2.3 — Keep renderer damage tracking sensitive to underline-only changes

- Files:
  - `Sources/TesseraTerminalBuffer/Cell.swift` only if `Style` equality no longer suffices
  - `Sources/TesseraTerminalRendering/BufferDiff.swift`
  - `Tests/TesseraTerminalRenderingTests/BufferDiffTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
- Confirm that `Cell: Equatable` includes `style` and `BufferDiff` already sees underline
  style/color changes as damage.
- Add tests showing a previous/current buffer with identical graphemes but different
  underline style or underline color repaints the changed cell.
- Add renderer byte tests for style-only damage:
  - plain -> curly underline emits cursor move, reset/full style, `4:3`, text/blank, final
    reset
  - single -> dashed emits targeted `4:5`
  - indexed underline color -> RGB underline color emits targeted `58:2::...`
  - custom underline color -> default no underline emits `59` and `24`
- Keep hyperlink deltas independent. Underline changes must not spuriously open/close OSC
  8 hyperlinks, and hyperlink-only changes must not spuriously reset underline state.

Acceptance:

- Underline-only style changes are damaged and rendered.
- Renderer output remains deterministic and minimal enough for exact byte tests.
- OSC 8 hyperlink handling and SGR underline handling remain separate state machines.

## Phase 3 — Tests, snapshots, docs, and demo visibility

**Goal**: prove the behavior at the byte, buffer, and virtual-terminal levels that are
observable in Tessera's harness, then document the feature.

### Step 3.1 — Add exact byte and renderer diff tests

- Files:
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
  - `Tests/TesseraTerminalRenderingTests/BufferDiffTests.swift`
  - `Tests/TesseraTerminalBufferTests/BufferTests.swift` or focused style tests
- Add the exact encoder byte tests listed in Step 2.1.
- Add renderer exact byte tests listed in Step 2.3.
- Add buffer/diff tests proving underline style and underline color participate in
  equality and damage.
- Prefer focused Swift Testing tests over broad snapshots when asserting exact bytes.

Acceptance:

- Tests fail if `4:3` is accidentally emitted as `4;3`, if `58` resets with `39`/`49`, or
  if `24`/`59` are omitted from targeted reset paths.
- Tests fail if a style-only underline change is skipped by damage tracking.

### Step 3.2 — Extend buffer and virtual-terminal snapshot support where the harness exposes data

- Files:
  - `Sources/TesseraTerminalTestSupport/BufferSnapshotting.swift`
  - `Sources/TesseraTerminalSnapshotSupport/RenderedCell.swift`
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+ghosttyUnavailable.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`
- Buffer snapshots must include underline style and underline color metadata for
  non-default styles.
- The Ghostty bridge currently reads `GhosttyStyle.underline` and
  `GhosttyStyle.underline_color`. If the C bridge exposes enough information, extend
  `RenderedCell` with:

  ```swift
  public let underlineStyle: UnderlineStyle
  public let underlineColor: RenderedColor
  ```

  or a snapshot-support-local mirror type if importing buffer style into snapshot support
  creates an undesirable dependency.

- If Ghostty exposes only boolean underline through the available C surface, keep
  `RenderedCell.underline: Bool` as the portable field and document in tests that exact
  bytes, not virtual-terminal style inspection, prove variant/color encoding.
- Add or update terminal debug snapshots so underlined cells still show readable metadata.
  Include variant/color only when the harness can observe them.

Acceptance:

- Snapshot support never lies: it reports underline style/color only if the backend
  actually exposed those fields.
- Existing snapshots keep working, and new snapshots make non-default underline state
  readable when available.

### Step 3.3 — Update the Phase 3 docs and example surface

- Files:
  - `docs/Spec.md`
  - an existing Phase 3 terminal protocol demo file if one exists in `Examples/`,
    `Sources/`, or another example target by the time this plan is executed
- Insert the finalized `### Slice 11: Underline extensions` section after Slice 10 in
  `docs/Spec.md` once slices 8-10 exist, or after Slice 7 if the umbrella plan still lists
  this as the next post-7 addition. Keep the title exactly
  `### Slice 11: Underline extensions`.
- Update the Phase 3 demo panel, if present, to render a short, text-only matrix:
  - single default underline
  - curly/undercurl underline
  - dotted/dashed underline
  - colored underline using indexed and RGB colors
- Do not add a demo-only terminal probe. The demo should explicitly use and display the
  extended application rendering policy while describing the baseline alternative.
- On the Underline panel, `s` toggles variant preservation/single-only rendering and `c`
  toggles underline color emission/omission. The panel displays both active axes.
- Keep Sixel out of the docs and demo for this slice.

Acceptance:

- Docs explain the clean underline API, SGR bytes, `24`/`59` resets, independent
  style/color output decisions, the extended/baseline presets, and runtime policy
  mutation.
- Any example remains text-only, displays its active output policy, and supports
  independent style/color toggles.

## Test/validation commands

Run only these narrow commands for this slice; do not run formatters or project-wide test
suites as part of plan execution unless a reviewer explicitly asks for broader validation.

```bash
swift test --filter TesseraTerminalANSITests
swift test --filter TesseraTerminalBufferTests
swift test --filter TesseraTerminalRenderingTests
swift test --filter TesseraTerminalSnapshotSupportTests
```

If a Phase 3 demo executable exists and this slice updates it, run the narrow launch/smoke
command already used by the adjacent Phase 3 slice plans for that demo. Do not invent a
new project-wide validation command.

## Acceptance criteria

- `Style` exposes underline style and underline color with default values that preserve
  the old visual default of no underline.
- `TextAttributes` no longer carries underline state; single underline is modeled as
  `UnderlineStyle.single`.
- Semantic `ControlSequence` APIs emit `4`, `24`, `4:2`, `4:3`, `4:4`, `4:5`, `58:5`,
  `58:2`, and `59` exactly as specified.
- Renderer diffing treats underline style and underline color as real style state and
  emits targeted `24`/`59` resets where possible.
- Buffer diffing repaints cells whose only change is underline style or underline color.
- Buffer snapshots and virtual-terminal/debug snapshots represent underline metadata as
  far as the harness can observe it.
- Docs include the finalized `### Slice 11: Underline extensions` text and keep Sixel out
  of scope.
- Extended rendering is the application default, baseline rendering remains explicitly
  selectable at startup or runtime, terminal identity does not alter policy, and no active
  probe is required.

## References

- `docs/Spec.md` Phase 3 overview and the new `### Slice 11: Underline extensions`
  section.
- `.agents/plans/015-phase-3-modern-terminal-protocols.md` for the umbrella Phase 3
  contracts.
- Existing Tessera style/renderer files:
  - `Sources/TesseraTerminalBuffer/Style.swift`
  - `Sources/TesseraTerminalANSI/ControlSequence.swift`
  - `Sources/TesseraTerminalANSI/Color.swift`
  - `Sources/TesseraTerminalRendering/StyleEncoding.swift`
  - `Sources/TesseraTerminalRendering/Renderer.swift`
- Existing Tessera test surfaces:
  - `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererTests.swift`
  - `Tests/TesseraTerminalRenderingTests/BufferDiffTests.swift`
  - `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift`
  - `Sources/TesseraTerminalTestSupport/BufferSnapshotting.swift`
  - `Sources/TesseraTerminalSnapshotSupport/RenderedCell.swift`
  - `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift`
- Ratatui local references:
  - `~/Developer/ratatui/ratatui/main/ratatui-core/src/style.rs` stores optional
    `underline_color`, documents that underline color uses non-standard SGR `58`/`59`, and
    notes that text must also be underlined.
  - `~/Developer/ratatui/ratatui/main/ratatui-crossterm/src/lib.rs` tracks underline color
    as renderer state and resets it at draw end when the `underline-color` feature is
    enabled.
  - `~/Developer/ratatui/ratatui/main/ratatui-crossterm/src/lib.rs` maps crossterm
    `DoubleUnderlined`, `Undercurled`, `Underdotted`, and `Underdashed` attributes back to
    Ratatui's boolean `Modifier::UNDERLINED`, which is a compatibility model Tessera
    should improve on by preserving the variant.
- Crossterm references used for wire behavior:
  - `crossterm::style::Attribute` documents `DoubleUnderlined`, `Undercurled`,
    `Underdotted`, `Underdashed`, and `NoUnderline`.
  - Crossterm source encodes underline variants as `4:<n>` for those attributes and
    `SetUnderlineColor` through the underline color SGR family.
