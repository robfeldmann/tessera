# Implementation review packet

Status: runnable layout and keyboard/Button specimens, deterministic real-rendered
capture, explicit semantic selectors, and retained failure checkpoints are implemented.
The full host gates pass. Visuals are provisional; this is not complete P4.3 or complete
Phase 4.

## Open these first

Implementation worktree:
`/Users/rob/Developer/robfeldmann/tessera/tessera-phase4-review-loop`. Branch:
`phase4-review-loop`. Run commands from that directory, not the original `phase4`.

```sh
swift run --package-path Examples TesseraLab run layout
swift run --package-path Examples TesseraLab run button
scripts/capture-specimen.sh layout .artifacts/review/layout
scripts/capture-specimen.sh button .artifacts/review/button
```

Live commands require an interactive terminal. Capture requires neither an interactive
terminal nor GUI permission. The wrapper prepares the pinned Ghostty header bridge and, on
macOS, supplies process-local Xcode test-framework paths before directly launching the
developer capture executable. The live executable does not link test support.

Committed previews are exact copies of generated SVGs, not redraws:

- [Layout, 80x24](artifacts/layout-80x24-initial.svg)
- [Layout, 40x16](artifacts/layout-40x16-initial.svg)
- [Button result, 80x24](artifacts/button-80x24-result.svg)
- [Button disabled, 40x16](artifacts/button-40x16-disabled.svg)
- [Provenance, profile, and SHA-256 checksums](artifacts/provenance.json)
- [Intentional duplicate-selector failure](artifacts/negative-duplicate-failure.json)

Full local bundles remain under `.artifacts/phase4-review-loop/final/`, with independently
repeated bundles under `.artifacts/phase4-review-loop/final-repeat/`. Each contains layout
and button subdirectories for both starting viewports. Across them there are 32 completed
checkpoints, each with styled-cell/semantic/state JSON, sanitized graph text, plain text,
and SVG. Layout traces retain the same VT through initial, changed, resized, and restored
frames. Button traces contain 12 input checkpoints per viewport.

## Revision and source preservation

The clean code revision used for the final captures is
`87d3284ca2bf677fc3010f467e717312336775d1`; all four final manifests report
`sourceDirty: false`. The following review-packet commit changes documentation, saved
artifacts, and their formatter exclusions only. Fresh captures from that later commit will
have its revision in their manifests; compare two fresh runs from the same checkout state
rather than expecting the archived manifest's revision to change.

Origin was verified as `robfeldmann/tessera` and fetched. All implementation commits were
pushed normally to `origin/phase4-review-loop`; no force-push, PR, merge, or main-branch
push was performed.

**Source preservation incident:** two workers ignored their assigned separate worktrees
and committed in the original `phase4`. Their six changed paths were restored from the
original commit, and its branch ref was restored with an expected-old-value check. The
original branch is again at `f1061a0224bbbfe01a04d95f74ad660acc40454a`.

Final verification confirms the original four unstaged paths, one untracked path, all five
original dirty-file hashes, and the entire staged-entry listing match the initial
inventory. `git diff --cached` is empty. No dirty source content was imported. The raw
index file checksum changed, and the incident remains in the local reflog: **byte-for-byte
index preservation is not claimed**. Initial/final checksums, affected paths, and the
restoration boundary are recorded in [STATE.md](STATE.md). No reset, stash, clean,
formatting, or root/Examples build ran in the original worktree. Completed worker
worktrees have been removed; the implementation worktree remains available for review.

## Commit-by-commit review order

Start with the runnable commands, then review this dependency order:

| Commit                               | Purpose and provenance                                   | Inspect / verification                                                                                                                                                                                                                                                                                 |
| ------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `fde4552`                            | Selective Text/style/decoration salvage from `1014004`   | Existing implementation and three test files; clean rebuild passed 49 layout tests. No Showcase shell.                                                                                                                                                                                                 |
| `2a62cd8`                            | Persistent VT and in-memory device resize                | Retained Ghostty handle, typed invalid geometry, device size without fabricated events; shrink/grow, invalid-size, VT support and IO tests.                                                                                                                                                            |
| `5d21d35`                            | Bounded captured-cell SVG exporter                       | Cell-based output and explicit rejection policy. Standalone worker checking was followed by real integration tests in the next specimen increment.                                                                                                                                                     |
| `06b6ae7`                            | Narrow adoption of the execution pack                    | Spec, plan 030, ProjectStatus, and historical Showcase acceptance/export boundaries. Markup checked; final DocC gate passed.                                                                                                                                                                           |
| `03b8731`                            | Shared driver, direct layout host, real capture command  | Gallery Hello/DemoHost ideas adapted without their shell. Five specimen/export tests, PTY launch/quit, repeat-bundle comparison, and a failing padding mutation. Includes mandated mechanical formatting of planning/example-test files.                                                               |
| `3e3e763`                            | Core/Layout/focus and Button salvage from `f1061a0`      | Includes the standalone ScrollIndicator primitive/tests, not the later ScrollView fixes or other controls. Removes unnecessary environment Sendable escape hatches. Thirty focused tests, 689 root tests, real Button action/result frames, and PTY input/quit passed.                                 |
| `87d3284`                            | Explicit automation observations and failure retention   | IDs independent of structural/focus identity, fail-closed lookup, completed-frame failure artifacts, and non-trapping CLI handling. Reuses Gallery's exact ArgumentParser 1.8.2 pin in Examples only; existing pins unchanged. 692 root tests, 28 Examples tests, lint, architecture, and DocC passed. |
| Review-packet commit after `87d3284` | This packet, final STATE, and actual previews/provenance | No implementation change or baseline approval.                                                                                                                                                                                                                                                         |

## Evidence and quality gates

| Area                   | Actual result / command                                                                                                                                                                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Baseline               | `just core doctor`; `just core build-libghostty-vt`; `swift test --filter TesseraCoreTests`: 29 passed.                                                                                                                                                                 |
| Focused framework      | `swift test --filter TesseraLayoutTests`: 49 passed after destination-only clean rebuild; `swift test --filter 'ButtonTests\|FocusRoutingTests\|FocusAppearanceTests'`: 30 passed; `swift test --filter AutomationSnapshotTests`: 3 tests passed, including role cases. |
| Final root suite       | `just core test`: 692 tests passed. An additional `swift test` run also passed.                                                                                                                                                                                         |
| Final Examples suite   | `swift test --package-path Examples`: 28 tests passed. Six specimen/export tests exercise both viewport sizes.                                                                                                                                                          |
| Format / portable gate | `just quality format`, inspection of formatter changes, and `swift-format format -i --configuration .swift-format -r Examples/Tests`; `just quality lint`: passed.                                                                                                      |
| Architecture           | `just quality architecture`: passed, including nine checker tests and the FrameRegion ownership probe.                                                                                                                                                                  |
| Documentation          | `just docs lint`: passed after repairing the changed VirtualTerminal initializer topic. Changed Markdown passed Prettier and markdownlint.                                                                                                                              |
| Live terminal          | Both documented live commands launched through PTYs and exited 0 on `q`. Button received Tab/Enter, traversal, and disable input. These are terminal-interaction checks, not GUI screenshots of a terminal.                                                             |
| CLI errors             | `swift run --package-path Examples TesseraLab --help`: exit 0. `Examples/.build/debug/TesseraLab run missing`: clean usage error, exit 64, no trap.                                                                                                                     |
| Visual inspection      | All four final previews above were opened and examined in Chromium. The browser relay was then released at the user's request; further automated image viewing must use a separate headless browser and must not steal browser focus.                                   |
| Other platforms        | `limactl list --json` reported the Linux VM stopped. `just windows-frost doctor` failed because its configured Frost CLI was absent; the UTM VM was stopped. No VM was started/reconfigured and no system tools were installed. Linux/Windows suites were not run.      |
| Human approval         | Not granted. Candidate SVGs are not accepted golden baselines.                                                                                                                                                                                                          |

The final deterministic check actually run was:

```sh
scripts/capture-specimen.sh layout .artifacts/phase4-review-loop/final/layout
scripts/capture-specimen.sh button .artifacts/phase4-review-loop/final/button
scripts/capture-specimen.sh layout .artifacts/phase4-review-loop/final-repeat/layout
scripts/capture-specimen.sh button .artifacts/phase4-review-loop/final-repeat/button
diff -rq .artifacts/phase4-review-loop/final .artifacts/phase4-review-loop/final-repeat
```

The comparison exited 0 with no differences across all artifacts. A temporary `padding(2)`
mutation produced six intended assertion failures; restoring `padding(1)` restored passing
tests. A temporary duplicate `add` automation annotation exited 1 at `selectors`, before
input, and retained one completed initial frame with count 0 and no focus. Its original
error and candidate geometry are in the linked failure JSON. The mutation was restored.
The negative bundle's provenance correctly records a dirty pre-commit source state; it is
not a final candidate baseline.

## Visual and API critique

The layout specimen isolates hierarchy, wrapping, and replacement/resize cleanup: a cyan
bold title, one body paragraph, and a dim exit hint with one-cell padding. At 40 columns,
the paragraph wraps instead of clipping. At 80 columns, the unused space is deliberate;
this is a specimen, not an application dashboard.

The Button specimen makes the consequence visible above its controls. Focused brackets and
label use the existing focus treatment; the disabled Add control is dim while Enable Add
remains focusable. Exact count rows, focus/disabled state, and semantic bounds are checked
at every checkpoint. There is no held-key visual or pointer behavior to review.

SVGs use actual VT-reconstructed cells with fixed 10x20 geometry, explicit palette
choices, and a generic monospace font. Rasterization depends on the viewer, so these are
not canonical pixel baselines. The magenta outline marks only the recorded cursor
coordinate; it does not claim observed cursor visibility or shape. Non-ASCII graphemes,
hyperlinks, ragged rows, and unsupported style forms fail rather than being silently
simplified. These specimens use a fixed truecolor profile; light/default-palette,
NO_COLOR, wide-glyph, and enhanced-keyboard visual combinations remain untested here.

App authors own their model, root factory, bindings, and explicit focus IDs. The shared
Examples-local driver owns graph sequencing and optional unhandled Tab traversal; both
hosts use it in the session's isolation domain. It does not observe state implicitly, wait
for arbitrary async work, force selector targets into focus, or expose terminal handles.
Capture support is deliberately separate from the live target. The wrapper's Xcode
test-framework environment is real tooling friction, not a public application requirement.
Root factories and direct public view APIs are visible in the small specimen files; no
Showcase chrome or inspector was imported.

## Remaining work and review decisions

Implemented, behavior-tested, visually examined, and PTY-checked are recorded separately
above; none implies human approval. Review the public metadata shape, caller-declared
roles, immediate keyboard activation policy, and candidate styling before graduating any
component contract.

The next bounded implementation step is the P4.3 pointer/gesture boundary: add the shared
normalized pointer/hit-test/capture route, then exercise Button down/up, release outside,
disabled targets, blur/removal cancellation, and correct phased-key pressed visuals using
the same driver and checkpoint loop. Do not label the current keyboard subset completed
P4.3. Typed selectors currently resolve/read metadata; there is no click-by-selector or
implicit focus-changing pilot API.

After that, salvage the existing local ScrollView viewport fixes and a small viewport
specimen before beginning TextField's scoped editing/selection work. Local dirty
StacksDemo/Gallery registration and the remaining source widgets remain read-only salvage
candidates, not lost or silently imported work. The capability/provenance ledger and exact
source fingerprints are in STATE.md. No push recovery is required; continue in the
implementation worktree, commit coherent verified units, and push normally to
`origin/phase4-review-loop`.
