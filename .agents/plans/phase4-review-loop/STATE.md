# Execution state

Status: in progress; live layout and keyboard/Button capture loops verified.

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
- Active unit: semantic metadata and failure retention verified; final code commit and
  handoff checks next.
- Last confirmed push: keyboard/Button increment 3e3e763 to origin/phase4-review-loop.

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

| Capability         | Evidence                                                        | Decision                                                                                                        | Verification                                                                         |
| ------------------ | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Text/layout/style  | `101400448da64a8020cf7678322375ebfea68605`                      | Port Text, StyleEnvironment, Styling, Decoration, Cell/Style and three test files; no Showcase/ScrollView shell | 49 layout tests passed                                                               |
| Small specimens    | `f193135` Gallery Hello/DemoHost patterns                       | Adapt scaffold-free Text/root/session spine into Examples-local support                                         | New real-render test passed at 80x24 and 40x16                                       |
| Session/VT capture | Existing support plus persistent resize                         | Reuse real renderer/encoder, retained VT, shared completed-frame observer                                       | Layout and Button bundles byte-equal across separate runs                            |
| Focus/keys/Button  | f1061a0 selected Core/Layout/Button files and original tests    | Preserve keyboard behavior, remove unnecessary environment unchecked Sendable conformances                      | 30 focus/Button tests, 689 full root tests, two-size real action/result capture pass |
| Pointer            | No Button hit testing/capture/pointer routing found             | Defer; keyboard-only is not P4.3 completion                                                                     | Not implemented                                                                      |
| Viewport           | Existing local ScrollView fixes `8ffffc2`, `9dcc46e`, `5192e7f` | Preserve as later salvage, not initial dependency                                                               | Not integrated                                                                       |

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
- Terminal resize worker used its assigned isolated worktree. Export/docs workers did not:
  see preservation incident below. No further worker writes are authorized.
- Integrated resize as 2a62cd8, exporter as 5d21d35, and narrow adoption docs as 06b6ae7.
  Local source code remains the read-only salvage baseline f1061a0.
- Next: commit the shared specimen/driver/bundle integration, then adopt the smallest
  keyboard/Button closure.

## Source preservation incident

Two workers ignored their assigned absolute worktrees and committed relative paths in the
inherited original phase4 directory. Their commits 9fe5e28 and 49fb05d advanced phase4 and
touched six paths, none of the five original dirty files. Main stopped their writes and
restored exactly those six paths from f1061a0, then restored the source branch ref to
f1061a0224bbbfe01a04d95f74ad660acc40454a using a compare-and-swap update-ref. No reset,
stash, clean, or formatter ran in the original source.

Restoration evidence: original HEAD, four unstaged paths, one untracked path, all five
dirty-file content hashes, and the entire staged-entry listing checksum match the initial
inventory. git diff --cached is empty. The raw index checksum changed from
f9d028c8173c74ccdd5d335cd4c85ccd0bafd7828f9b4d0389eb77b6ec676dfb to
1a846f7da220039c388f8024a293dfb16af7b51eed312099f8e8d3ce9164a765; no original binary-index
backup exists. Its exact staged content is restored, but byte-for-byte index preservation
is NOT claimed. The incident remains visible in the local reflog. Worker changes were
integrated selectively into the feature branch, never published as original phase4
history.

## Checkpoint log

- Styling closure: 49 layout tests; baseline: 29 core tests.
- Live TerminalSession specimen launched through a PTY and exited 0 on q. Live target has
  no test-support dependency.
- Real capture command succeeded: scripts/capture-specimen.sh layout
  .artifacts/phase4-review-loop/normalized-a. The developer-only wrapper supplies Xcode
  test-framework paths and executes the binary directly; the protected swift shim strips
  loader environment variables.
- A second capture to normalized-b compared equal with diff -rq: JSON cells, graph text,
  plain text, manifest and SVG all byte-equal across processes. Graph export reuses the
  existing concise snapshot formatter to omit unstable reflected implementation addresses
  and timings.
- Five Examples capture/export tests and 15 VT support tests passed. A deliberate
  padding(2) mutation produced six intended assertion failures; restoring padding(1)
  restored the passing suite.
- Opened and inspected the actual exported compact SVG in Chromium. Explicit word wrapping
  keeps the compact message readable. Appearance is provisional; cursor outline is a
  diagnostic location marker, not observed cursor visibility or shape.
- Button command: swift run --package-path Examples TesseraLab run button. Real PTY
  launched, received traversal/activation/disable keys, and exited 0 on q.
  scripts/capture-specimen.sh button produced button-a and button-b with byte-equal
  cells/graphs/state/SVG at both sizes; disabled compact SVG opened in Chromium.
- Button pilot checks all 12 semantic checkpoints, exact rendered count row, enabled
  state, repeat/release non-duplication, and forward/backward disabled traversal. Full
  root suite passed 689 tests. Changed-file SwiftLint passed with zero violations.
- Keyboard-only limitation: activation is immediate on press, including enhanced press
  packets; no held-key visual state, pointer hit testing/capture, or blur/removal gesture
  cancellation is claimed. This is NOT completed P4.3 or a graduated Button design.
- Ready-platform probe: limactl lists tessera-linux stopped; no VM started or mount
  changed. Windows Frost doctor failed because the configured CLI is absent and the UTM VM
  is stopped. Platform suites remain unrun; no installation or VM repair attempted.
- Added opt-in automationID annotations independent of reconciliation and FocusID,
  immutable tree-ordered semantic geometry/state, and typed missing/ambiguous selector
  failures. Lookup does not allocate on success; reads do not trigger graph passes. New
  tests prove identity/focus preservation, ambiguity, disabled metadata, and actual Button
  bounds/state at every captured checkpoint.
- Bundle schema 2 adds semantic metadata beside explicitly selected synthetic state.
  Capture errors retain only completed frames and the original error. An intentional
  duplicate-ID mutation exited 1 before any input and wrote failure.json plus one initial
  frame (actionCount=0, focus=none); the mutation was restored and all six specimen tests
  passed.
- Reused the source Gallery's swift-argument-parser 1.8.2 pin
  (6a52f3251125d74daf04fcbd5e6f08a75d074382), Examples-only, to make recoverable CLI
  failures exit cleanly rather than trap. No existing dependency version changed. Live
  --help exits 0; invalid specimen exits 64 with usage. Final documented Button live
  command launched and quit with 0 after traversal/activation input.
- Current full checks: swift test passed 692 tests; swift test --package-path Examples
  passed 28 tests; just quality architecture passed; just quality lint passed; just docs
  lint passed. The resize initializer's stale DocC topic was corrected. Final post-commit
  artifact generation and final source/index-entry verification remain.
