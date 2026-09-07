---
name: Phase 4 review loop - autonomous execution brief
status: pending
created: 2026-09-07
branch: phase4-review-loop
reviewed-base: 0697fe28d1accdd2621cdb0d5426a053ed3a2c2d
---

# Start here: Phase 4 autonomous implementation

## Mission and authority

The maintainer requested a self-sufficient local implementation session: preserve useful
work from the local `phase4` branch, implement the revised view-layer development loop,
delegate bounded work when useful, and leave coherent commits and review evidence. This is
an instruction to implement, not to return another plan or wait for confirmation.

Work on `phase4-review-loop`, starting from its published planning commit. The branch was
created from `main` at `0697fe28d1accdd2621cdb0d5426a053ed3a2c2d`. At preparation time,
GitHub did not have a `phase4` branch. The important newer implementation may exist only
in the maintainer's local repository and working files. Never mistake old `main` for the
complete implementation, and do not require the maintainer to push `phase4` first.

This brief authorizes scoped implementation and contract-alignment changes on the working
branch. It does not authorize merging to `main`, opening a PR, approving visual baselines,
releasing, rewriting source history, or changing account permissions. Do not publish the
original `phase4` branch wholesale.

Read [PLAN.md](PLAN.md), then the smallest relevant sections of the repository spec,
component contracts, and implementation. These files contain the necessary design context;
no chat transcript or attachment is needed. Read applicable local agent instructions,
`CONTRIBUTING.md`, and `.omp/rules/` before editing. Do not spend the session ingesting
the entire historical specification or rewriting planning documents.

For this branch, PLAN.md replaces plan 030's remaining delivery ordering, Showcase gates,
blanket developer-export prohibition, and human-approval-as-an-implementation-blocker.
Other normative ownership, layout, input, and controlled-state contracts remain binding.
Record narrow engineering decisions when sources disagree. A major unresolved change to
those other contracts is deferred, not silently overridden; continue independent work.

## Session policy

Default budget: 120 minutes from the actual local agent start, unless the operator
supplies another limit. This is an execution budget, not a prediction of achievable scope.
Record actual start time and the finish target in STATE.md. An unspecified subscription
reset time must not be guessed. Quota or host limits can end the session earlier.

Reserve the final 15 minutes for integration, verification, artifact generation, commits,
push, and handoff. Check remaining time at task boundaries. Do not start a substantial new
feature near the finish target. Persist progress throughout so an abrupt cutoff still
leaves useful commits and a current recovery note.

Prefer working, reusable, verified increments over volume. Do not aim to finish all of
Phase 4 in this session or consume usage for its own sake. After completing an increment,
continue to the next eligible priority without asking the maintainer. If further feature
work would jeopardize handoff, strengthen tests, evidence, and documentation instead.

## 1. Protect the source and establish an isolated workspace

First identify the repository, current branch, dirty state, worktrees, and source refs.
Useful read-only inventory commands include:

```sh
git rev-parse --show-toplevel
git status --short
git branch --show-current
git worktree list --porcelain
git show-ref --verify refs/heads/phase4
git log --oneline --decorate -20 phase4
```

A missing ref is an expected condition, not a reason to run the remaining commands
blindly. Verify that the configured remote points to `robfeldmann/tessera`. Do not write
credential- bearing remote URLs or local private paths into committed reports. Fetch the
planning branch without switching, resetting, stashing, formatting, or cleaning the
original tree. Inspect local `phase4` preferentially; use a remote-tracking source only if
no local source exists. Record the exact source SHA and merge base, not just branch names.

Create a separate sibling worktree for the destination branch using Git's worktree
support. Prefer a fresh `tessera-phase4-review-loop` directory. Create the local tracking
branch from `origin/phase4-review-loop` only if it does not already exist. Never use force
options to steal a branch from another worktree. If a clean destination worktree already
exists and is clearly this task's workspace, resume it after inspecting its state.
Otherwise use a unique run-suffixed branch/worktree from the published plan and record the
actual destination.

The source branch and its worktree are read-only inputs. In particular:

- Do not run `reset --hard`, `clean`, automatic stash, checkout/switch, rebase, or
  formatter in the original worktree. Do not move, delete, or amend `phase4`.
- Inspect staged and unstaged diffs and relevant untracked source files. The latest useful
  code may not be committed. Read only task-related files; do not sweep credentials,
  private data, caches, ignored files, or symlinks outside the repository into the
  salvage.
- Port only reviewed code and associated tests into the destination. Preserve the original
  index and files byte-for-byte. Source provenance for uncommitted work is a scoped path
  and local content hash, not an invented commit SHA. Keep raw dirty-work patches local.
- A new worktree shares Git objects, not the source's uncommitted changes. Do not
  interpret their absence in the destination as absence of work to salvage.

If `phase4` cannot be found, record that limitation and implement the review-loop skeleton
from the available baseline. Do not wait for the maintainer and do not claim salvage.

## 2. Audit narrowly and salvage by dependency

Create STATE.md immediately from its supplied template. Inventory only the capabilities
needed for the next increments: Text/layout/style, diagnostics and terminal test support,
existing small examples, focus/key routing, Button, pointer support, and viewport
behavior. Classify each as present with evidence, present without evidence, incomplete, or
absent. Do not infer correctness from plan checkboxes or file names.

Compare `main`/destination with `phase4` using history, diffs, tests, and actual public
APIs. Preserve useful primitives, shared Flex/SplitView geometry, routing, tests, and the
newer small examples. Avoid importing the old Showcase shell just because it appears in
the same history. Working code is not obsolete merely because the new sequence describes
it later.

Prefer `git cherry-pick -x` for a clean, self-contained implementation commit. For a mixed
commit, port the smallest coherent dependency closure, including tests and required
package entries, and record source SHAs and paths in the commit body and salvage ledger.
Combine interdependent source changes when needed for a buildable commit; do not preserve
broken intermediate commits just to maximize commit count. Do not cherry-pick merge
commits with an arbitrary mainline or merge all of `phase4` by default.

When a conflict takes more than a small bounded investigation, defer that unit and
continue an independent one. Never settle conflicts with blanket ours/theirs or import old
planning files over this execution pack. Keep original author/provenance metadata where
applicable.

Run a small baseline check early in the isolated destination. Record pre-existing failures
separately from regressions. Do not run builds in a dirty source worktree to establish its
baseline; inspect existing evidence or use a separate disposable source worktree if
useful.

## 3. Execute the priority queue

The order below is a dependency queue, not a quota of mandatory features. Existing working
capabilities can satisfy a dependency after verification; never reimplement them to follow
the numbering. Prefer the nearest complete loop over importing every salvageable file.

### A. Get one existing specimen out of the Showcase

Extract or reuse one tiny Text/layout specimen with an app-owned root factory and direct
launch. Put reusable example definitions in an Examples-local support target so its live
executable and tests exercise the same code. No new in-app catalog or configuration UI.
Import only the source capabilities necessary to make that specimen work.

Acceptance: it builds, launches through the actual TerminalSession host, and has a focused
regression test. Interactive launch may be marked unverified when a terminal is
unavailable, but a compile must not be described as having used the application.

### B. Produce a real, deterministic review bundle

Wrap the existing in-memory session, renderer/encoder, VirtualTerminal, and graph
snapshots. Share application driving decisions between live and headless runs. Add
explicit initial render and resize checkpoints, styled-cell output, sanitized structural
diagnostics, and one faithful visual export from captured cells. Start with only the
features the specimen actually needs; describe exporter limitations. Do not build a new
terminal emulator.

Use 80x24 and 40x16 and a multi-frame resize/change case. Keep VT state across frames. An
observation reads a completed checkpoint; it must not trigger graph passes itself. Provide
a direct command that regenerates the bundle without manual TUI navigation. Commands in
PLAN.md are illustrative; record the actual implemented invocations in REVIEW.md.

Acceptance: repeat runs have equal normalized semantic/cell/structural output;
noncanonical timestamps and durations are not part of equality. Open an actual exported
image using the agent's image-viewing tool when available. A viewable SVG may be the first
artifact, but convert/open it with an available renderer before claiming visual review.
Record limitations rather than installing an unapproved toolchain to get a screenshot.

### C. Exercise the nearest real interaction

If useful routing/Button code exists in `phase4`, adopt it rather than rebuilding it. Add
an action/result specimen and drive actual graph input. Establish keyboard activation,
explicit focus traversal, disabled behavior, and action-count assertions. Add basic
pointer phases, outside release, and cancellation only when the common seams are
understood.

A keyboard-only increment is worth committing but is not a completed P4.3 milestone. Never
implement pilot clicks by calling action closures or forcing focus/scroll state. Do not
claim pointer support from a synthetic action-counter mutation.

### D. Continue only after the evidence loop works

Next choices are better regression coverage, completing Button pointer/cancellation
states, missing visual primitives, then the viewport. Follow PLAN.md for later sequencing.
Do not start TextField, all controls, broad text selection, navigation, or a large
exporter before A/B are usable. If source code already provides later features, retain
useful verified work without making it a prerequisite for the immediate review loop.

A successful small result is A/B plus clear source preservation and reviewable history.
More interaction coverage is additional progress, not permission to skip the evidence
loop. A documentation-only outcome is not the target unless execution is genuinely
blocked.

## 4. Delegate without fragmenting the architecture

Use the lead model for the source/target comparison, Swift ownership/isolation decisions,
shared driver interfaces, event semantics, integration, and final review. Use cheaper
available models for bounded inventory, fixture extraction after interfaces are agreed,
mechanical test matrices, markup, and independent regression review.

Discover the local harness's actual subagent and model capabilities. Do not invent model
names, pricing, APIs, permissions, or a hidden ability to spawn workers. If lower-cost
selection is unavailable, reduce delegation or execute serially. Do not install a new
agent system or wait for the maintainer. Token cost and subscription quota are not assumed
equal.

Start with two concurrent workers when useful; this is a starting point, not a cap. The
maintainer explicitly permits more. Scale up for independent, well-scoped tasks when
additional workers improve throughput, and scale down when integration overhead, build
contention, resource pressure, or the remaining budget makes more workers
counterproductive. No additional maintainer approval is needed for worker count within the
harness's actual permissions and limits. Keep the coordinator-owned integration and write
isolation below. Before each task, provide:

```text
Goal and done condition:
Base commit and relevant source/target paths:
Allowed write paths (or read-only):
Contract and invariants to preserve:
Required tests/artifacts:
Return: changed files/commit, actual commands and results, caveats, next dependency.
No recursive delegation or changes outside the assigned scope.
```

Give workers separate worktrees when they write. The coordinator alone integrates and
pushes the destination branch and edits shared manifests, the driver seam, and the ledger.
Workers do not commit into the integration branch or share a dirty index. Do not run
concurrent SwiftPM builds against one build directory. Reuse the documented revision-keyed
Ghostty cache; do not copy/symlink another worktree's `.build` directory or clean shared
caches. A read-only audit can run in parallel with initial setup. Parallel implementation
starts only after the relevant interface is agreed.

Independently inspect worker diffs and rerun integration checks. A worker's success
summary is not evidence that its code composes with the rest of the branch.

## 5. Use defaults instead of blocking questions

| Situation                                        | Default action                                                                                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| No approved new visual reference                 | Use existing tokens and the simplest component contract; label new appearance provisional and continue.                                     |
| Design document has an unresolved future feature | Specify only the current capability and tests; explicitly defer the rest. Do not mark the entire component complete.                        |
| Noncritical API naming choice                    | Follow surrounding public conventions; record the reversible decision and continue.                                                         |
| Ownership/isolation conflict                     | Keep the proven safe seam; defer the risky convenience API and implement independent coverage.                                              |
| Source salvage conflict                          | Preserve the source, document the conflict, and port an independent coherent unit.                                                          |
| Missing subagent or cheaper model                | Run serially with the available model.                                                                                                      |
| No GUI/computer-use permission                   | Run headless and image-file review where possible; mark real-terminal visual review unperformed.                                            |
| Missing image viewing                            | Still produce actual image/cell artifacts; mark visual review unperformed, not passed.                                                      |
| Missing source branch                            | Use the known baseline and record salvage unavailable.                                                                                      |
| Missing build dependency or broken environment   | Use repo doctor/setup and existing caches; timebox diagnosis, then do independently verifiable work.                                        |
| Existing failing tests                           | Establish relevance, record baseline, fix a scoped cause or continue elsewhere; never delete coverage to get green.                         |
| Network, authentication, or push failure         | Preserve local commits and exact recovery commands; no repeated login attempts or escalation.                                               |
| New snapshot needed                              | Add independently reasoned behavioral expectations and separately identified candidate visual evidence. Never self-approve human baselines. |
| Unclear major scope decision                     | Choose the smaller reversible implementation; leave a decision note and continue.                                                           |

Do not ask routine clarification questions or stop after presenting a plan. Continue
through eligible work. Do not bypass tool permission prompts or safety controls: defer the
blocked operation and continue within permissions. Stop only when the budget/host requires
it, no safe useful work remains, or the remaining action requires unavailable authority.

## 6. Verification, commits, and persistence

Use current repository commands, inspected in the destination after salvage. The reviewed
baseline documents `just core doctor`, `just core build`, `just core test`,
`just quality changed`, `just quality format`, `just quality lint`, and `just docs lint`.
Read CONTRIBUTING.md and current justfiles for their actual prerequisites. Reuse the
pinned Ghostty build/cache and local tools. Do not update dependencies, install system
toolchains, start VMs, or change global configuration to make this session larger.

Run the narrowest test first; verify new example targets/tests through Examples' actual
package, not only the root package. Before declaring a review-ready handoff, run the
normal repository gate: format, full core tests, lint, and applicable DocC checks.
Formatting occurs only in the isolated destination; inspect incidental diffs. If budget or
environment prevents the full gate, report precise omissions and label the branch
partial/not review-ready. Never disable hooks, weaken CI, hide failing tests, or claim
unrun platform coverage.

Tests use explicit events, render checkpoints, bounded drains, and injected clocks when
needed. No sleeps or Task.yield-based correctness. Add at least one meaningful negative
verification that a new test detects the intended defect, then remove the deliberate
fault. Keep traces bounded and never invoke a second app behavior path just for the tests.

Make a commit for each coherent tested unit; do not save everything for the end. Use
Conventional Commits, following the existing changelog policy. Suitable boundaries
include:

```text
refactor(examples): extract a directly runnable layout specimen
feat(test-support): add deterministic view presentation checkpoints
feat(devtools): export specimen review bundles
feat(examples): add scripted button interaction evidence
test(widgets): cover disabled activation and outside release
docs: record implementation evidence and remaining review decisions
```

These are examples, not required commit counts or permission to claim unfinished features.
Each commit body explains why, source provenance when salvaged, verification performed,
and limitations. Keep unrelated changes separate; do not squash the session into one giant
commit. Do not rewrite already published commits. Review `git diff --check`, staged paths,
and secrets/artifact exposure before committing. Stage explicit paths, not unrelated work.

Update STATE.md at each meaningful increment with the source map, decisions, current unit,
completed checks, and the next exact action. Push completed commits normally to this
feature branch after useful checkpoints. No force pushes, main pushes, automatic PR, or
merge. If Git/credentials cannot complete a push noninteractively, continue locally and
report it.

Store generated bulk artifacts in a scoped ignored local directory such as
`.artifacts/phase4-review-loop/<run-id>/`. Record the actual absolute location in the
local handoff, but use sanitized/repository-relative paths in committed reports. Do not
commit raw terminal traces, credentials, personal data, font files, caches, or all
generated output. A small clearly labeled synthetic review sample may be committed if
repository policy allows it; reproducible generation commands are mandatory either way.

## 7. Close out without depending on another message

During the final reserved interval, stop assigning new feature work. Integrate completed
worker changes, run the applicable checks, regenerate evidence at the final code revision,
and fill REVIEW.md. Keep incomplete worker work off the integration branch; preserve
useful partial work in its own clearly identified worktree or local patch, without
altering the maintainer's source. Do not erase partial work merely to report a clean tree.

Record actual source SHA, destination code SHA, dirty-state provenance, branch/worktree,
commit-by-commit review order, implemented commands, artifact paths, test outcomes, and
known omissions. Use the last code commit for evidence identity; a later
documentation-only handoff commit can reference it without a circular self-hash.
Distinguish implemented, behavior-tested, visually reviewed, real-terminal-checked, and
human-approved.

Make the final handoff commit and attempt a normal push. Confirm the destination status,
remote result, and original source state. Stop only processes launched by this session; do
not kill other agents, builds, terminals, or user applications. Leave a resumable next
action.

The final user-facing report starts with what to run/open and which commits to review,
followed by what actually passed and what remains provisional. No "everything works"
unless the evidence supports it. No need to wait for a response after completing the
handoff.
