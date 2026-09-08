# Execution state

Status: implementation and host verification complete; review packet ready. Visuals remain
provisional, not human-approved. Full P4.3 and Phase 4 completion are not claimed.

## Workspace and checkpoint

- Session start / maximum finish target (UTC): 2026-09-07 22:47 / 2026-09-08 00:47. Start
  was rounded down conservatively. Implementation stopped before the final-check reserve;
  no additional feature is in progress.
- Destination branch: `phase4-review-loop`, tracking `origin/phase4-review-loop`.
- Destination worktree:
  `/Users/rob/Developer/robfeldmann/tessera/tessera-phase4-review-loop`.
- Origin verified as `robfeldmann/tessera` and fetched before worktree creation.
- Published planning head: `f46a449`; reviewed/source merge base:
  `0697fe28d1accdd2621cdb0d5426a053ed3a2c2d`.
- Original source branch and final restored HEAD: `phase4` at
  `f1061a0224bbbfe01a04d95f74ad660acc40454a`.
- Last completed implementation commit and confirmed code push:
  `87d3284ca2bf677fc3010f467e717312336775d1`.
- The following review-packet commit contains this file, REVIEW.md, saved actual
  previews/provenance, and formatter exclusions preserving captured bytes; it changes no
  implementation. Pushes are normal feature-branch pushes, not force-pushes. No PR, merge,
  or main-branch push occurred.
- Active workers: none. Completed worker worktrees were removed without force; the
  implementation worktree remains for review. No feature WIP or fault mutation remains.
- Next step: the P4.3 pointer/gesture boundary described below and in REVIEW.md.

## Source preservation incident and final verification

Two workers ignored their assigned absolute worktrees and used relative paths in the
inherited original `phase4` directory. Their commits `9fe5e28` and `49fb05d` advanced the
original branch and changed six paths: two new exporter/test files and four documentation
files. None was one of the five original dirty files. Main stopped their writes, restored
exactly those six paths from `f1061a0`, and restored the source ref with a
compare-and-swap `git update-ref`. No reset, stash, clean, formatting, or root/Examples
build ran in the original worktree. The incident remains visible in its local reflog.

The six restored paths were:

- .agents/plans/030-phase-4-view-layer-and-showcase.md
- Examples/Sources/SpecimenCaptureSupport/CellImageExporter.swift
- Examples/Tests/SpecimenSupportTests/CellImageExporterTests.swift
- design/showcase.md
- docs/ProjectStatus.md
- docs/Spec.md

Future writable workers need enforced worktree isolation and working directories, not only
prompt instructions. Source audits should remain read-only.

Final checks, using `git --no-optional-locks` for source status/ref inspection, confirm:

- Original branch and HEAD restored exactly.
- The same four unstaged paths and one untracked path as the initial inventory.
- All five dirty-file content hashes below match.
- `git diff --cached` is empty.
- Entire `git ls-files -s` listing SHA-256 remains
  `0c2a4a5d62734b4449f58639f7153fa191d86ba48768c7c4af3c5d17f08fde1e`.

The raw index checksum changed from
`f9d028c8173c74ccdd5d335cd4c85ccd0bafd7828f9b4d0389eb77b6ec676dfb` to
`1a846f7da220039c388f8024a293dfb16af7b51eed312099f8e8d3ce9164a765`. No original
binary-index backup exists. Its exact staged content is restored, but **byte-for-byte
index preservation is not claimed**. The remaining implementation and integration were
performed directly in the destination worktree.

## Dirty-source provenance

No dirty source content was imported. These Git content hashes identify the preserved
inputs:

| Path                                                     | Initial and final content hash             | Disposition                                      |
| -------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------ |
| `.agents/plans/032-view-layer-gallery.md`                | `1e6f75c535812b454cfe2a9a8a44c3654cf1413a` | Read-only historical planning                    |
| `Brewfile`                                               | `374267380bac570df214e21441257282f05802cf` | Unrelated; preserved                             |
| `CHANGELOG.md`                                           | `8625400be32f3e63436700763219331793507206` | Preserved; unrelated entries not copied          |
| `Examples/Sources/TesseraGallery/Gallery.swift`          | `6a7789eaf9b452a6bdccab21eba6d2b0cc9b233c` | Dirty Stacks registration deferred               |
| `Examples/Sources/TesseraGallery/Demos/StacksDemo.swift` | `66e6bfb96178ff169f4c5e3defd5d7a7546662a3` | Untracked playground remains a salvage candidate |

## Capability and salvage ledger

| Capability                 | Provenance / implementation                                                                                | Evidence and disposition                                                                                                                                                             |
| -------------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Text/layout/style          | `101400448da64a8020cf7678322375ebfea68605`, followed by selected `f1061a0` Core/Layout updates             | Preserved implementation/tests; 49 focused layout tests. Standalone ScrollIndicator primitive/tests retained, not the later ScrollView viewport work.                                |
| Direct specimens           | Gallery Hello/DemoHost ideas from `f193135` and `f1061a0`                                                  | Extracted app-owned models and shared graph sequencing without Gallery/Showcase shell, inspector, animation, or global model.                                                        |
| Real capture               | Existing in-memory session, renderer/encoder, Ghostty VT, ScreenSnapshot, concise graph snapshot formatter | Persistent resize, incremental byte ingestion, and immutable completed observations; 32 final checkpoints at two starting sizes.                                                     |
| Focus/keyboard/Button      | Source `6ba369b`, `c34129f`, `08d2501`, `7519623`, and final `f1061a0` closure                             | Thirty focused focus/Button tests; real Enter/Space consequence, repeat/release non-duplication, disabled traversal, forward/backward focus. Other widgets not imported.             |
| Ownership                  | Source framework with unnecessary environment unchecked Sendable conformances removed                      | Models/graphs remain non-Sendable in caller/session isolation. FocusID's immutable constrained erasure has a documented invariant. Frame ownership and architecture gates pass.      |
| Semantics/selectors        | New explicit automation annotation and immutable snapshot                                                  | Identity independent of reconciliation/FocusID; no observation passes or implicit focus change. Missing/ambiguous lookup fails closed. Geometry/state checked against Button frames. |
| Capture failure            | New completed-checkpoint error retention                                                                   | Intentional duplicate-ID run exited 1 before input, retained one initial frame with count 0/no focus, and preserved original cause. Mutation removed.                                |
| CLI behavior               | Source Gallery's exact ArgumentParser 1.8.2 revision `6a52f3251125d74daf04fcbd5e6f08a75d074382`            | Examples-only dependency addition for normal error exits/help. No existing dependency version changed.                                                                               |
| Pointer / held-key visuals | Not present in the salvaged view routing                                                                   | Not implemented or claimed. Immediate keyboard-only Button is not completed P4.3.                                                                                                    |
| Viewport                   | Source fixes `8ffffc2`, `9dcc46e`, `5192e7f`                                                               | Deferred read-only salvage after pointer/gesture work; no ScrollView shell imported.                                                                                                 |

## Driver and export decisions

- The execution pack changes remaining delivery and Showcase acceptance gates, not
  ownership, layout, controlled-state, or deterministic-input contracts.
- Shared driver code remains Examples-local. The app owns its model, root factory,
  bindings, and focus IDs. Each event gets one explicit update and at most one awaited
  presentation when dirty. The driver does not promise async quiescence.
- Live and headless adapters use the same driver in session isolation. Live device
  geometry is authoritative during draw. Capture retains the same VT across frames and
  feeds only newly completed renderer output.
- Capture observation never triggers graph update/layout/render. Semantics and diagnostic
  geometry describe completed layout, not a forced future state. Selectors never choose a
  first ambiguous match or grant mutation/focus authority.
- Bundle schema 2 separates value-free graph/semantic metadata from explicitly listed
  synthetic fixture state. No arbitrary app reflection, network export, or telemetry.
- The fixed truecolor profile and printable-ASCII SVG exporter are deliberate bounds.
  Unsupported glyph/style forms fail. SVG viewer rasterization is not canonical; the
  magenta cursor outline is a coordinate marker, not observed visibility or shape.
- Recoverable CLI failures use the source's pinned ArgumentParser rather than unhandled
  throwing main functions. The live executable has no test-support dependency. The capture
  wrapper supplies macOS test-framework paths only to its developer process and executes
  its binary directly because the protected Swift shim strips loader variables.
- Per user request, the browser relay was released. Further automated image viewing must
  use a separate headless browser and must not steal the user's browser focus.

## Verification and artifacts

- Baseline: `just core doctor`; `just core build-libghostty-vt`; 29 core tests passed. The
  first attempt lacked the per-worktree generated header bridge; preparation fixed it.
- A changed Style initializer exposed stale incremental ABI objects. Destination-only
  `swift package clean` followed by 49 layout tests passed.
- Final `just core test`: 692 tests passed. An additional `swift test` run also passed.
- Final `swift test --package-path Examples`: 28 tests passed, including six
  specimen/export tests with both viewport sizes. AutomationSnapshot tests cover read-only
  observation, renamed IDs/focus preservation, duplicate/missing selectors, and disabled
  role cases.
- `just quality format` ran; formatter changes were inspected. Examples tests were also
  formatted explicitly. `just quality lint`, `just quality architecture`, and
  `just docs lint` passed. The stale resized VirtualTerminal initializer DocC link was
  fixed.
- Both documented live commands launched through PTYs and exited 0 on q. Button received
  traversal/activation/disable input. CLI help exited 0; an invalid specimen exited 64
  cleanly with usage.
- Final captures were produced at clean code commit `87d3284`; all manifests record
  `sourceDirty: false`. `.artifacts/phase4-review-loop/final/` and `final-repeat/`
  compared byte-identically with `diff -rq`, including JSON, graph/text observations,
  manifests, and SVG for all 32 checkpoints. Four actual final SVGs were inspected in
  Chromium.
- Committed previews, a negative failure summary, and SHA-256/source provenance are under
  `artifacts/`. They are candidates, not approved baselines. Full bundles remain local in
  the ignored `.artifacts/` directory.
- Negative proof: padding(2) caused six expected assertion failures; restoration passed.
  Duplicate automation ID failed at selectors before input and retained one complete
  initial frame. A Python assertion confirmed count 0/no focus and one SVG; restoration
  passed. No fault mutation remains.
- Local tooling only: existing Ghostty revision cache, per-worktree SwiftPM output, local
  pnpm dependencies and codespell environment. The temporary generated pnpm lock was
  removed; no toolchain/global configuration change occurred.
- Linux VM was stopped (`limactl list --json`). Windows Frost doctor failed because its
  configured CLI was absent; UTM VM was stopped. No VM boot/reconfiguration or system
  installation was attempted. Linux and Windows suites remain unrun.

## Resume

Read REVIEW.md and inspect the runnable cases before changing code. Next implement the
shared normalized pointer/hit-test/capture and gesture-cancellation boundary, then Button
down/up, release outside, disabled targets, blur/removal cancellation, and honest
phased-key pressed visuals using this driver/capture loop. Do not call the current
keyboard subset completed P4.3. Preserve explicit semantic IDs as metadata, not
reconciliation/focus keys.

Then salvage the existing viewport fixes into a small viewport specimen before starting
TextField's scoped editing/selection work. Keep source `phase4` and its dirty work
read-only; use the preserved hashes above if further salvage is needed. Continue normal
coherent commits and pushes on `phase4-review-loop`, never main. No feature WIP, active
worker, failed gate, or push recovery is awaiting resumption; human review and non-macOS
validation are still outstanding.
