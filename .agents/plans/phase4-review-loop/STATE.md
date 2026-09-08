# Execution state

Status: P4.4–P4.8 implementation is complete on the feature branch, with host validation
and review evidence recorded below. Platform graduation remains blocked by the Linux
toolchain mismatch and unavailable Linux/Windows runtime checks. Human visual approval
remains open. PLAN.md stays `in-progress` until those verification gates close.

## Workspace and checkpoint

- The initial timed session and subsequent P4.3 session are historical. The maintainer now
  authorizes continued execution through P4.8, commits, and the final review packet; the
  earlier two-hour implementation boundary does not limit this continuation.
- Destination branch: `phase4-review-loop`, tracking `origin/phase4-review-loop`.
- Destination worktree:
  `/Users/rob/Developer/robfeldmann/tessera/tessera-phase4-review-loop`.
- Origin verified as `robfeldmann/tessera` and fetched before worktree creation.
- Published planning head: `f46a449`; reviewed/source merge base:
  `0697fe28d1accdd2621cdb0d5426a053ed3a2c2d`.
- Original source branch and final restored HEAD: `phase4` at
  `f1061a0224bbbfe01a04d95f74ad660acc40454a`.
- Previous published review-loop checkpoint: `d70acb4`, including code revision
  `87d3284ca2bf677fc3010f467e717312336775d1` and its review packet.
- P4.3 implementation is in the destination only. The first isolated worker clone was
  removed by its runner; its patch was reconstructed in a separate recovery clone and
  reduced against `d70acb4` before integration. No original dirty content was adopted.
- Corrective implementation and capture workers used explicit destination paths. Main owns
  acceptance, final validation, commits, and normal feature-branch publication.
- P4.3 code: `ab272c2`; capture profile correction: `c2e2539`. The following packet commit
  records actual previews and final evidence without changing implementation.
- Read-only continuation verification matched the original HEAD, five dirty-file hashes,
  staged-entry hash, and raw index hash recorded below; no additional source changes
  occurred.
- No PR, merge, force-push, or main-branch push is part of this task.

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

## Initial session verification and artifacts

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

## P4.3 verification and resume

- `just core test`: 710 tests passed. The existing Button phased-key regression now
  supplies explicit Kitty provenance and verifies no action before release.
- `swift test --package-path Examples`: 30 tests passed.
- `swift test --filter PointerTests`: 16 tests passed, covering outside/invalid release,
  disabled ancestor bubbling, replacement and erased same-slot identity, clipping, dynamic
  topmost targets, cancellation, and mixed key sources.
- `swift test --filter TesseraTerminalInputTests`: passed, including associated text
  without explicit event phase and source-aware equality.
- `swift test --package-path Examples --filter ApplicationDriverTests`: two tests passed,
  including initially disabled and stronger configured mouse/keyboard/focus baselines.
- `just quality format`, `just quality lint`, `just quality architecture`, and
  `just docs lint`: passed. Changed Markdown passed `pnpx markdownlint-cli`.
- Real captures from clean code revision `c2e2539628a15e7c56c1fc858cd7e08831dfceea`
  contain 26 Button checkpoints and four layout checkpoints per viewport (40x16 and
  80x24). All four manifests report `sourceDirty: false`. Full bundles at
  `.artifacts/phase4-review-loop/p43-published/` and `p43-published-repeat/` compared
  byte-identical with `diff -rq`: 60 completed checkpoints. Exact saved SVGs and SHA-256
  metadata are linked from REVIEW.md and `artifacts/p43-provenance.json`.
- Live PTY: exact Kitty press/repeat held the count at 3; release advanced to 4. SGR
  primary down held 4 and up advanced to 5. Isolated q exited 0 and cleared the
  reconstructed alternate screen. Separate headless Helium inspection confirmed
  compact/plain held emphasis differs from focused idle and custom/cancellation/removal
  output is legible. The initial headless API attempt unexpectedly attached to relay; it
  was immediately released and reported. Subsequent inspection explicitly spawned an
  isolated headless executable.

The P4.3-only boundary above is historical; the continuation below supersedes its resume
instruction while preserving its evidence and incident record.

## P4.4–P4.8 final implementation state

Implementation commits are `9119ef3` and `5a22022`. Final code revision:
`5a22022150df0676a5d0f8b6d69c7bd77743a91e`. The subsequent packet commit contains
review evidence, not implementation changes.

- P4.4: controlled ScrollView offsets, focus reveal, nested-boundary consumption, hover,
  motion requirements, and terminal-blur clearing are implemented and exercised.
- P4.5: controlled grapheme-safe TextField editing, selection, commit/paste, submission,
  hardware cursor, Toggle, Stepper, and Picker are integrated in the settings editor.
- P4.6: Section, keyed List, Grid, and Table are implemented. The final Section reserves
  header/spacing before proposing content height and clamps extreme spacing safely.
  The actual multiline collection/Grid overlap was reproduced in captured output and
  fixed; the regression covers that composition rather than only a fixed-height List.
- P4.7: adjacent-pair SplitView input, constraints, collapse/capture lifecycle, and
  controlled regular/compact NavigationSplitView composition are integrated.
- P4.8 implementation: eight direct specimens share one live/replay driver and registry.
  Settings demonstrates plain app ownership; records demonstrates explicit reducer-style
  ownership, including retained pane sizing. No automatic observation was introduced.
  Public DocC, catalog status, spec, ProjectStatus, and changelog were updated.

### Final verification

- `swift test --filter CollectionsTests`: 9 passed.
- `swift test --package-path Examples --filter SpecimenRegistryTests`: 5 passed.
- `just core test`: 786 passed; `swift test --package-path Examples`: 37 passed.
- `just quality format`, `just quality lint`, `just quality architecture`, and
  `just docs lint`: passed after the final source edit. Changed Markdown passed
  `pnpx markdownlint-cli`. Formatting changes and the final scoped diff were inspected.
- All eight `TesseraLab run <id>` commands launched in PTYs and exited 0 on q. Settings
  accepted q as field text, replaced its selection with bracketed paste `Grace`, and
  showed `Submitted: 1`; Tab then q exited and cleared the alternate screen. The final
  records app changed to Waypoint through Tab, Tab, Enter and exited 0.
- Final capture roots `.artifacts/phase4-review-loop/p48-published/` and
  `p48-published-repeat/` compare byte-identically with `diff -rq`: 232 checkpoints
  across 16 manifests. Every manifest records the final code revision and
  `sourceDirty: false`. Saved previews and checksums are linked from REVIEW.md.
- Actual images were inspected using explicitly spawned, isolated headless Helium, not
  the browser relay. Final collection and record images were opened after the final
  source commit; seven unchanged previews matched the already inspected SVGs exactly.
- Release benchmark: 200 keyed leaves at 200x50, seven samples per scenario. Median wall
  durations were 2.577 ms initial, 1.330 ms forced unchanged presentation, 1.357 ms visible
  one-leaf update, and 1.870 ms resize to 180x45. Counters were deterministic. The
  unchanged forced draw emitted 10 control bytes, not zero; the changed leaf emitted 25.
  Results and machine/configuration context are saved with the review artifacts.

### Unclosed verification and review boundary

`just linux build` **failed**: the installed Swift 6.3.2 static SDK cannot be imported by
Swift 6.3.3. `swift sdk list`, `swiftly list`, and local Toolchains directories found
no matching installed compiler. No replacement compiler/SDK was installed.

Linux runtime tests remain unrun: the known VM is stopped and the packet forbids VM
bootstrap. Windows runtime tests remain unrun: the configured Frost CLI is unavailable
and no running usable UTM guest was available. Host success does not certify either
platform. Matching-toolchain Linux compilation and Linux/Windows runtime checks remain
required for full graduation; PLAN.md is intentionally not marked complete.

Human API/style and visual-baseline approval remains open. Broad gestures, IME pre-edit,
cross-view text selection, and the catalog's explicitly deferred surfaces were not added.
No PR, merge, main push, release, or baseline approval was performed. Continue only in the
destination worktree. Read-only source verification still matches the original HEAD,
five dirty-file hashes, staged-entry listing, and post-incident raw index hash above.
