# Execution state

Status: in progress; styling salvage verified, direct specimen integration underway.

## Session and workspace

- Start / finish target (UTC): 2026-09-07 22:47 / 2026-09-08 00:47. Start rounded down
  conservatively; final checks begin by 00:32.
- Destination: `phase4-review-loop`, sibling worktree `tessera-phase4-review-loop`.
- Published planning head: `f46a449`; reviewed base and source merge base:
  `0697fe28d1accdd2621cdb0d5426a053ed3a2c2d`.
- Read-only local source: `phase4` at `f1061a0224bbbfe01a04d95f74ad660acc40454a`.
- Origin verified as `robfeldmann/tessera`; fetched before worktree creation.
- Original index has no staged changes; index SHA-256:
  `f9d028c8173c74ccdd5d335cd4c85ccd0bafd7828f9b4d0389eb77b6ec676dfb`.
- Original tracked-entry listing SHA-256:
  `0c2a4a5d62734b4449f58639f7153fa191d86ba48768c7c4af3c5d17f08fde1e`.
- Active unit: shared live/headless layout specimen and completed real-render checkpoints.
- Last confirmed push: none yet.

## Dirty-source provenance

No dirty source has been copied. These Git content hashes identify the read-only inputs:

| Path                                                     | Content hash                               | Decision                                                |
| -------------------------------------------------------- | ------------------------------------------ | ------------------------------------------------------- |
| `.agents/plans/032-view-layer-gallery.md`                | `1e6f75c535812b454cfe2a9a8a44c3654cf1413a` | Deferred historical planning                            |
| `Brewfile`                                               | `374267380bac570df214e21441257282f05802cf` | Unrelated; preserve                                     |
| `CHANGELOG.md`                                           | `8625400be32f3e63436700763219331793507206` | Do not import unrelated entries                         |
| `Examples/Sources/TesseraGallery/Gallery.swift`          | `6a7789eaf9b452a6bdccab21eba6d2b0cc9b233c` | One-line Stacks registration; deferred                  |
| `Examples/Sources/TesseraGallery/Demos/StacksDemo.swift` | `66e6bfb96178ff169f4c5e3defd5d7a7546662a3` | Useful untracked playground; deferred host dependencies |

## Capability and salvage ledger

| Capability         | Evidence                                                        | Decision                                                                                                        | Verification                                       |
| ------------------ | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Text/layout/style  | `101400448da64a8020cf7678322375ebfea68605`                      | Port Text, StyleEnvironment, Styling, Decoration, Cell/Style and three test files; no Showcase/ScrollView shell | 49 layout tests passed                             |
| Small specimens    | `f193135` Gallery Hello/DemoHost patterns                       | Adapt scaffold-free Text/root/session spine into Examples-local support                                         | New real-render test passed at 80x24 and 40x16     |
| Session/VT capture | Existing in-memory session, Ghostty VT, ScreenSnapshot          | Reuse renderer/encoder and persistent VT; add genuine resize seam                                               | Initial/change frames passed; resize worker active |
| Focus/keys/Button  | `6ba369b`, `c34129f`, `08d2501`, `7519623`                      | Select coherent latest Core/Layout/Button closure after evidence loop                                           | Source tests inspected; not integrated             |
| Pointer            | No Button hit testing/capture/pointer routing found             | Defer; keyboard-only is not P4.3 completion                                                                     | Not implemented                                    |
| Viewport           | Existing local ScrollView fixes `8ffffc2`, `9dcc46e`, `5192e7f` | Preserve as later salvage, not initial dependency                                                               | Not integrated                                     |

## Baseline and environment

- `just core doctor` passed. Ghostty revision `ae52f97dcac558735cfa916ea3965f247e5c6e9e`
  reused from the revision-keyed cache.
- First focused baseline lacked the per-worktree generated Ghostty header bridge.
  `just core build-libghostty-vt` prepared it; `swift test --filter TesseraCoreTests` then
  passed 29 tests.
- Swift reports 6.3.3 on this host; no toolchain change made.
- Styling changed a public initializer ABI; an incremental link retained stale callers.
  `swift package clean` in destination only, then
  `swift test --filter TesseraLayoutTests`, passed 49 tests.
- `swift test --package-path Examples --filter LayoutSpecimenTests` passed after fixing
  independently written expected ASCII row width. Exact row/cell assertions remain.
- `pnpm install --ignore-scripts` installed existing pinned local markup tools; no
  dependency versions changed. Generated pnpm lock is disposable, not an adopted
  package-manager migration.
- No source builds, global changes, shared `.build`, VM launches, or new system
  toolchains.

## Decision log

- Execution pack replaces remaining delivery/Showcase gates only;
  ownership/layout/controlled-state contracts remain binding.
- Shared driver remains Examples-local and non-Sendable; model construction and graph work
  remain inside session isolation. No early public runtime abstraction is required.
- Initial exporter accepts printable ASCII and explicitly rejects unsupported
  glyphs/attributes. Styled cells are the portable oracle; new visual treatment is
  provisional, not human-approved.
- Each event has one explicit update, at most one awaited presentation; observations do
  not trigger passes or promise asynchronous quiescence.
- Existing Gallery animation/coalescing/scaffold is intentionally not imported.

## Work in progress and recovery

- Lead owns integration, manifests, driver, STATE/REVIEW, commits, and push.
- Read-only audits `salvage-map` and `capture-seams` completed.
- `vt-resize`: isolated `phase4-review-vt`, terminal support resize plus focused tests.
- `cell-export`: isolated `phase4-review-export`, captured-cell SVG and tests only.
- `adoption-docs`: isolated `phase4-review-docs`, narrow spec/status/Showcase authority
  alignment.
- Next: commit verified styling; complete specimen capture command, integrate
  resize/export, run negative mutation and real launch; then adopt keyboard/Button.

## Checkpoint log

- Created sibling tracking worktree; original branch/index/files remain read-only.
- Styling dependency closure passed focused tests; initial live/headless driver compiled
  and real in-memory frame assertions passed.
