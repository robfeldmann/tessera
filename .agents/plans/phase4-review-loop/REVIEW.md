# Implementation review packet

Status: template only. No local implementation, tests, screenshots, or terminal checks
have been performed by this planning change. Fill this file from actual evidence at
handoff.

## Open these first

Record the exact checkout/branch, direct launch command, headless replay/capture command,
and readable artifact paths. Do not leave illustrative command names here after execution.
State which command works without interactive terminal or GUI permission.

## Revision and source preservation

Record the code revision used to generate evidence, any dirty marker, source `phase4` SHA,
relevant uncommitted-source provenance, actual destination, and confirmed push result.
Report whether the original branch/index/working files remained unchanged.

## Commit-by-commit review order

| Commit                 | Purpose / source provenance | What to inspect          | Checks actually run |
| ---------------------- | --------------------------- | ------------------------ | ------------------- |
| Pending implementation | No code changes yet         | Execution brief and plan | Not run             |

List coherent code changes in dependency order. Include deferred or partial work locations
without representing those as integrated or tested.

## Evidence and quality gates

| Area                               | Result  | Exact command / artifact / limitation |
| ---------------------------------- | ------- | ------------------------------------- |
| Focused framework tests            | Not run | Pending                               |
| Example package build/tests        | Not run | Pending                               |
| Deterministic multi-frame capture  | Not run | Pending                               |
| Image opened and visually examined | Not run | Pending                               |
| Interactive / PTY smoke            | Not run | Pending                               |
| Full repository quality gate       | Not run | Pending                               |
| Applicable DocC checks             | Not run | Pending                               |
| Other platforms/emulators          | Not run | Pending                               |
| Human visual approval              | Pending | Agent cannot grant this               |

Separate pre-existing failures from introduced regressions. A skipped or unavailable check
is not passed. Mention the negative verification used to show a new test detects its
defect.

## Visual and API critique

State the specimen's task, what the actual images show, treatment of hierarchy/alignment,
focus/disabled/pressed states where implemented, compact behavior, color fallbacks, and
any exporter limitations. Record whether feedback was revised after inspection. No taste
score.

Explain app-code friction, internal access used by examples, and helpers that may hide
complexity. List candidate baseline changes separately from approved existing baselines.

## Remaining work and review decisions

Distinguish implemented, behavior-tested, visually reviewed, real-terminal-checked, and
human-approved. Identify the smallest next implementation step and decisions for the
maintainer. Include exact recovery/push instructions if a tool or credential blocked them.
