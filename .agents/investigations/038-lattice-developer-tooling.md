---
name: Lattice developer tooling: designed versus built
date: 2026-10-19
status: resolved
---

# Lattice developer tooling: designed versus built

## Question

Lattice (`~/Developer/robfeldmann/lattice/main`) is a macOS window manager whose owner
wants agents to build, debug, and evaluate it without a screen. Its design pages specify a
large developer-tooling surface. What exactly is proposed, what did P0 build, how do
scenarios act as the behaviour spec, how is JSON and exit-code output shaped for agents,
how are module boundaries enforced, and what did the spikes and decisions teach? What
carries over to Tessera's devtools?

## Outcome

Lattice specifies a complete developer-tooling stack: a virtual platform behind the same
adapter protocol as the real one, a line-oriented scenario language that doubles as test,
bug report and documentation, a structured JSONL log with a daemon trace ring, a `settle`
readiness barrier on a manual clock, a pure invariant checker, a quirk catalogue tied to
evidence rows, trace record and replay, fuzzing, capture, diff, and a control socket with
a `harness.*` method family. Almost all of that is designed; a subset is built.

What P0 (2026-10-17, commits `8778489`, `272c079` and `cda1fb8` on top of the research
commit `7960425`) built is the **in-process** half: a root SwiftPM package with
`LatticeCore`, `LatticeProtocol`, `LatticeLog`, `LatticeVirtual`, `LatticeDaemon`,
`LatticeScenario`, and a `lattice-dev` executable with `run` and `shot`
(`docs/plans/p0.md:15-25`, `docs/log.md:35`). The scenario runner talks to the daemon only
through a `Transport`, and the only transport is in-process
(`Sources/lattice-dev/main.swift:20-27`). There is no socket, no `lattice` CLI, no
`lattice dev` family, no trace replay, no fuzz, no capture, no PNG shots, and no `os_log`
mirror. The gate that did ship is strong: 478 tests, 56 scenarios (11 authored plus a
45-file AeroSpace corpus), an import-boundary test suite and a boundary script, all green
at the closing commit (`docs/plans/p0.md:116`, `:25`).

Two properties matter most for Tessera. First, scenarios are the behaviour specification:
every expectation is evaluated by the client from a daemon snapshot, and the daemon holds
no assertion state (`Sources/LatticeScenario/Runner.swift:7-9`). Second, the agent
interface is deliberately dull: one line of JSON per scenario, exit codes 0/1/2/3 with
fixed meanings, and a human report that is a function of the same data
(`Sources/LatticeScenario/DevCLI.swift:10-12`, `Scenarios/README.md:21-32`). The spikes
were standalone SwiftPM packages under `spikes/`, each with a "proves / does not prove"
README, then migrated mechanically into the root package before any new work
(`docs/plans/p0.md:71`).

## Method

- Read Lattice design pages: `docs/design/devtools.md`, `architecture.md` (§1–§3 read;
  §4–§6 located by heading line only), `roadmap.md` (risk table), `docs/answers.md` §8,
  `docs/decisions/code-conventions-from-tessera.md`, and both Tessera-practice research
  pages as cited by Lattice.
- Read the P0 plan, the log, `Scenarios/README.md`, `Scenarios/aerospace/README.md`, and
  the spike README and manifest.
- Read sources: `Harness.swift`, `Runner.swift`, `Parser.swift`, `DevCLI.swift`,
  `Trace.swift`, `Invariants.swift`, `VirtualPlatform.swift`, `Log.swift`, the
  `lattice-dev` entry point, `QuirkTests.swift`, and
  `scripts/check-package-boundaries.py`.
- Inventory by glob: `Sources/` and `Tests/` target directories, and
  `spikes/*/Package.swift`. Absent by glob: `LatticeCLI`, `latticed`, `LatticeShot`,
  `LatticeConfig`, `LatticeUI`, `LatticeProtocolTests`.
- Not run: no builds, tests, or scenarios were executed in either repo. Every claim below
  is from reading source and docs; "built" means present in source, not observed passing
  this session.

Citation form: `path:line` with paths relative to the Lattice worktree root unless stated.
Tessera paths are relative to `tessera/devtools` where stated.

## Git history

Four commits on `main` (from `git log`): `7960425` research, design and spikes; `8778489`
P0 root package; `272c079` cascade stacks, quirks, traces, settle and verbs; `cda1fb8`
invariant checker, property suite and the AeroSpace corpus. The design pages were written
in one batch on 2026-10-16 from six research pages and three spikes; a critic review found
36 findings, applied on 2026-10-17 (`docs/log.md:7-15`). The floor moved from macOS 15 to
26 that day (`docs/log.md:34`).

Lattice's own log is a useful model of how the project records decisions: each day has
dated bullets that name the document a finding was absorbed into (`docs/log.md:20`,
`:30`).

## The proposed devtools surface

### Principles (designed)

Five principles, stated once (`docs/design/devtools.md:18-22`):

1. The virtual world sits behind the same adapter protocol and IPC as the real one:
   `latticed --harness` is the whole daemon with `VirtualPlatform` and extra `harness.*`
   methods. The alternative rejected is an `isUnitTest` global inside production code
   (`devtools.md:18`).
2. A scenario is a file of commands plus world, time and assertion verbs: "The same file
   is a test, a bug report, and a documentation example" (`devtools.md:19`).
3. Observations are text first: JSONL logs, JSON snapshots, ASCII geometry. Pixels are a
   review aid, never a golden (`devtools.md:20`).
4. Time is injected; `wait` advances a manual clock (`devtools.md:21`).
5. `LatticeCore` is pure, so config, initial snapshot and ordered platform inputs
   determine everything it does; a trace of those inputs is a complete bug report
   (`devtools.md:22`).

### Topology (designed)

Three ways to run a scenario through one step executor: a spawned `latticed --harness`
over a Unix socket, an in-process loopback that needs no process, and a transport-parity
test that runs every scenario both ways and requires identical renders (`devtools.md:40`).
The `harness.*` catalogue is a table of ten methods with abridged parameters
(`devtools.md:44-54`). The harness family exists only under `--harness` and answers
`method_not_found` otherwise (`devtools.md:42`).

Architecture adds the process table: `latticed` is the signed bundle's main executable,
the CLI and UI processes are clients, and `latticed --harness` is a second instance on a
separate socket with a scripted world (`architecture.md:40-47`). Isolation follows Tern's
`neutral_env`: a fresh root, own `HOME`, `TMPDIR`, and socket, defaulting to
`/tmp/lattice-dev-<8 hex>` (`devtools.md:52-56`, `architecture.md:52`).

### The `lattice dev` command family (designed)

Eight commands, each with principal flags (`devtools.md:62-71`): `world` (start a harness
daemon, or create real virtual displays in a guest with `--real-displays`), `ctl` (send
one `harness.*` request), `run` (scenario files, `--json`, `--junit`), `shot`, `trace`
(record, dump, replay, info, shrink), `diff` (snapshot, trace or live comparison),
`capture` (sorted-key JSON of keymap, commands, config schema, IPC schema, events, quirks,
DSL, with `--check`), and `fuzz` (random operation sequences checked against invariants,
with shrinking).

Built: only `run` and `shot`, under the name `lattice-dev`, because the CLI's socket
client does not exist until P1 (`docs/plans/p0.md:70`). `DevCLI.usage` lists exactly `run`
and `shot` plus `help` (`Sources/LatticeScenario/DevCLI.swift:64-85`, `:99-108`).

### Flight recorder and replay (designed)

The daemon would keep the last 120 s of platform traffic in a ring. A `RecordingPlatform`
decorator writes three record kinds (`in`, `out`, `res`) to a file; replay answers each
`out` from the recorded `res` and reports divergences (`devtools.md:105-115`). Two
constraints make this possible: `PlatformEvent` is `Codable` and handle-free, and privacy
is by construction (titles hashed, only binding-matched chords, files at mode 0600;
`devtools.md:113`, Decision 6 at `:510`). Built: a `Trace` ring of decisions, not platform
inputs (see the Trace section). `PlatformEvent` being `Codable` and handle-free is built
(`architecture.md:105`, `Sources/LatticeCore/Platform.swift`).

### Scenario grammar (designed, then partly built)

The design gives an EBNF (`devtools.md:137-147`) and a verb table with spike status
(`devtools.md:151-163`), then additions marked `design` or `P0` (`devtools.md:165-180`),
then a quirk table with status and basis (`devtools.md:184-197`). Each quirk row carries
`basis` (`source`, `trial`, or `vm`) and a rule: a quirk may be modelled only with
evidence (`devtools.md:182`, Decision 9 at `:513`).

The built grammar is spelled in `Parser.swift:3-28` and `Scenarios/README.md:38-68`. The
parser is header-binding and fail-fast: `bind` is legal only before the first statement,
an unbound `key` is a parse error at parse time, and the parser stops at the first error
(`Parser.swift:9`, `:35`, `:181-198`). A heredoc is allowed only on `expect render`, and
its tag must be the last bare word (`Parser.swift:128-143`, `:202-244`). `include` is
textual, resolved relative to the including file, with cycle detection that prints the
chain (`Parser.swift:30-33`, `:296-301`).

### Virtual time and settle (designed, built)

Time moves only on `wait`, `tick` and `settle` (`Scenarios/README.md:84-86`). A statement
that acts on the platform gets one reactor turn over the events it produced, so `expect`
never waits (`Sources/LatticeScenario/Runner.swift:12-13`). `settle [max DUR]` advances
the clock tick by tick until a tick produces no platform event and no placement and
nothing is in flight; the default budget is 2000 ms, taken from the `exec.wait` timeout in
the architecture sequence diagram (`Runner.swift:186-188`). A budget that ends first fails
the statement with `still busy after N ms`, and each settle records `elapsed_ms` and
`quiet` (`docs/plans/p0.md:100`, `Scenarios/README.md:56`). The virtual platform itself
reads no clock; anything that takes time takes ticks, and `hasPendingWork` tells the
daemon whether another tick would deliver anything (`VirtualPlatform.swift:7-10`,
`:152-157`).

The `settle` design has a caveat recorded by the P0 author: `settle` needs one quiet tick
after any activity because a placement can make the platform answer on the next, and a
world with nothing in flight answers `(0, quiet)` without ticking (`docs/plans/p0.md:98`).

### Structured log and trace (designed, partly built)

The logging envelope is `ts`, `seq`, `level`, `event`, `src`, with `cid` correlation ids
and `since_cause_us` designed (`devtools.md:364-378`, `:410-420`, `architecture.md:371`).
Built: `LogRecord` with those five reserved keys, sorted-key compact JSON, a `field_`
prefix for colliding user fields, and an `EventLog` that numbers records
(`Sources/LatticeLog/Log.swift:1-17`, `:223-246`, `:262-282`). `LogValue` is a closed JSON
value enum with literal conformances, and the log module knows no geometry types; callers
map frames to objects (`Log.swift:36-44`, `docs/plans/p0.md:81`).

The daemon's decision trace is a separate layer. The reactor is a pure value, so it
collects `TraceEvent`s and hands them over; `Trace` numbers them through the process's
`EventLog` and keeps the newest in a bounded ring (default 4096) that `records(since:)`
serves (`Sources/LatticeDaemon/Trace.swift:3-7`, `:31-34`, `:66-68`). The wire form
`WireLogRecord` carries `seq`, `event`, and string fields and drops `ts`, `level` and
`src` (`Sources/LatticeProtocol/Harness.swift:19-33`, `docs/plans/p0.md:97`). The event
names that were built are listed in `docs/plans/p0.md:20` (`display_topology`,
`space_change`, `focus_decision`, `placement_mismatch`, `op_applied`, `op_rejected`,
`workspace_changed`, `layout_pass`, `window_classified`, `event_coalesced`, and
reactor-only names).

The scenario runner evaluates `expect log` by asking the daemon for records after a `seq`,
so the runner keeps no log of its own (`Runner.swift:18-20`, `Scenarios/README.md:90`).
`mark` remembers a `seq` and `since` reads only what followed it. `expect log` compares
text, because the wire carries strings (`docs/plans/p0.md:101`).

The `--log FILE` option writes the daemon's own records with virtual timestamps, and each
scenario in a multi-file run is opened by a `scenario_start` record with `seq` 0 so that
the restarted numbering can be told apart (`DevCLI.swift:252-265`, `p0.md:103`).

### Invariants (designed, then built with different ids)

The design lists seven invariants in kebab-case (`tree-wellformed`, `frames-in-display`,
`hidden-is-hidden`, `pin-respected`, `converges`, `restores-on-exit`,
`topology-round-trip`), each with the bug class it catches (`devtools.md:121-129`).

Built: `checkInvariants(world, plan:)` is a pure function that reports
`Violation { rule, detail }` for fifteen snake_case rule ids in a fixed order
(`Sources/LatticeCore/Invariants.swift:3-5`, `:17-30`, `:33-81`). It does not trust its
input: a malformed tree is reported, not walked (`Invariants.swift:7-9`). It takes two
inputs, the world and the plan the platform was last given, so a stale plan is a violation
too (`Invariants.swift:11-14`). The `check` statement and `harness.check` expose it, and a
`check` counts as an expectation (`Scenarios/README.md:59`).

Three of the designed rules are not in `check`: `converges`, `restores-on-exit` and
`topology-round-trip` compare states over time or against platform writes
(`Scenarios/README.md:114`). The design's seven names map onto built rules as recorded in
`docs/plans/p0.md:105`. One design rule is weakened on purpose: `frames-in-display` is
split, because a floating window may overhang its display as long as its centre is inside
(`Invariants.swift:63-65`, `docs/plans/p0.md:106`).

### Quirk catalogue (designed, partly built)

Eight quirk verbs are built: `ax-destroy-missing`, `display-churn`, `display-uuid-change`,
`enhanced-ui-animates`, `readback-stale`, `size-clamp`, `space-reshuffle`, `wake-burst`
(`Tests/LatticeScenarioTests/QuirkTests.swift:49-56`). Each names rows of
`docs/research/macos-quirks.md`, and a test checks that every named row exists in the
catalogue (`QuirkTests.swift:36-47`). A second test checks that every shipped scenario
that arms a quirk names the row in a comment (`QuirkTests.swift:79-93`). Design-only rows
include `park-sliver`, which has a VM basis (`devtools.md:197`), and `mc-hover` and
`ax-slow`, which the language omits (`Scenarios/README.md:156`).

Three table rows did not fit the model: `size-clamp` and `enhanced-ui-animates` are
properties of an app that hold for the platform's lifetime, not one-shot events, and the
clamp's second clause depends on AX write order that belongs to the macOS adapter
(`docs/plans/p0.md:92`).

### Shots and renders (designed, partly built)

The ASCII render is the golden, with one block per display and a grid where `.` is
uncovered, `+ - |` outline a window, and `*` marks the focused window (`devtools.md:88`,
Decision 3 at `:507`). It is built in Core (`Sources/LatticeCore/Render.swift`, per
`docs/plans/p0.md:49`). `lattice-dev shot` prints it (`DevCLI.swift:269-328`). The PNG
renderer `LatticeShot` is designed (`architecture.md:67`) and absent by glob.

### Shell-level developer loop (designed, different tool built)

The design's developer loop is mise tasks (`devtools.md:476-489`). The built loop is a
`Justfile` with `core`, `quality` and `ci` modules (`docs/plans/p0.md:17`, `justfile`
modules `core.just:14-16`, `quality.just:7`, `ci.just:10-13`) and `lefthook.yml` hooks,
with a conventional-commits gate (`lefthook.yml:1-10`). `quality` runs format check, lint,
the boundary script and the architecture tests (`quality.just:7`).

## Designed versus built

Status key: **built** means present in source and covered by a P0 claim; **partial** means
a subset; **designed** means specified in a design page and absent from source; **absent**
means no source or docs say it exists.

| Area                                                                                                                                                          | Designed (where)                                                   | Built in P0 (where)                                                                                                                                                          | Status                      |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| Virtual platform as the obedient twin of the real adapter                                                                                                     | `devtools.md:18`, `architecture.md:105`                            | `VirtualPlatform` actor, `VirtualClock`, quirks (`VirtualPlatform.swift:94`, `:7-10`)                                                                                        | built                       |
| Quirk catalogue with evidence basis                                                                                                                           | `devtools.md:182`, `:184-197`                                      | eight verbs, catalogue-row test (`QuirkTests.swift:36-93`); no `basis` field in the source read                                                                              | partial                     |
| Scenario grammar: world, time, expect                                                                                                                         | `devtools.md:137-163`                                              | `Parser.swift:3-28`, runner (`Runner.swift:199-300`)                                                                                                                         | built                       |
| Scenario additions: `display move/resize`, `space switch`, `window focus/minimize/resize/move`, `app launch/quit/hide`, `session`, `mission-control`, `mouse` | `devtools.md:169-172`                                              | not in grammar (`Scenarios/README.md:156`)                                                                                                                                   | designed                    |
| `include`, `mark`, `settle`, `dump`, `expect log`, `expect hidden`, `check`                                                                                   | `devtools.md:176`, `:177`                                          | all built (`Parser.swift:30-33`, `Runner.swift:186-188`, `Scenarios/README.md:56-66`)                                                                                        | built                       |
| `config <<TOML` heredoc                                                                                                                                       | `devtools.md:175`                                                  | not built; waits for P1 TOML decoder (`docs/plans/p0.md:22`, `Scenarios/README.md:156`)                                                                                      | designed                    |
| `expect frame … tol`, `expect intent`, `expect writes`, `expect workspace`, `expect count`, `expect mode`, `expect result`                                    | `devtools.md:177-180`                                              | `expect log … count N` only; the rest not built (`Scenarios/README.md:156`, `docs/plans/p0.md:116`)                                                                          | partial                     |
| `replay FILE` and trace replay                                                                                                                                | `devtools.md:105-115`, `:176`                                      | not built                                                                                                                                                                    | designed                    |
| Daemon decision trace ring, `harness.log`                                                                                                                     | `architecture.md` §4; `devtools.md:52`                             | `Trace.swift` ring (4096), `records(since:)` (`:34`, `:66-68`)                                                                                                               | built                       |
| Platform-input flight recorder (`in`/`out`/`res`)                                                                                                             | `devtools.md:105-111`                                              | not built                                                                                                                                                                    | designed                    |
| JSONL envelope with `seq`, `ts`, `level`, `event`, `src`                                                                                                      | `devtools.md:364-378`                                              | `Log.swift:223-246`                                                                                                                                                          | built                       |
| `cid` correlation and `since_cause_us`                                                                                                                        | `devtools.md:410-420`                                              | not built; "cid chains and `dur_us` need a platform that writes and times" (`docs/plans/p0.md:97`)                                                                           | designed                    |
| `os_log` mirror, runtime levels with TTL                                                                                                                      | `devtools.md:424`, Decision 10 at `:514`                           | not built (`docs/plans/p0.md:21`)                                                                                                                                            | designed                    |
| Log rotation and `--pretty` renderer                                                                                                                          | `architecture.md:63`, `devtools.md`                                | `FileSink` rotation, `PrettyRenderer` (`docs/plans/p0.md:21`)                                                                                                                | built                       |
| Invariant checker, pure over world plus plan                                                                                                                  | `devtools.md:121-131`                                              | `Invariants.swift:33-98`, fifteen rules                                                                                                                                      | built (renamed, more rules) |
| Invariant `converges`, `restores-on-exit`, `topology-round-trip`                                                                                              | `devtools.md:127-129`                                              | not in `check` (`Scenarios/README.md:114`)                                                                                                                                   | designed                    |
| Property tests over Core                                                                                                                                      | `devtools.md:450` (L0)                                             | `PropertyTests.swift`, 16 committed seeds × 600 steps (`docs/plans/p0.md:116`)                                                                                               | built                       |
| `dev fuzz` with shrinking                                                                                                                                     | `devtools.md:71`, `:83`                                            | not built; `DevCLI.usage` has no `fuzz` (`DevCLI.swift:64-85`)                                                                                                               | designed                    |
| `dev capture` and `--check`                                                                                                                                   | `devtools.md:70`, `:119`, Decision 11 at `:515`                    | not built                                                                                                                                                                    | designed                    |
| `dev diff`                                                                                                                                                    | `devtools.md:69`, `:117`                                           | not built                                                                                                                                                                    | designed                    |
| `dev trace` record, dump, replay, shrink                                                                                                                      | `devtools.md:68`, `:105-115`, `:495-501`                           | not built                                                                                                                                                                    | designed                    |
| Control socket: JSONL, `hello` handshake, 1 MiB frame cap, `harness.sock`                                                                                     | `architecture.md:295-298`                                          | not built; `protocolVersion` declared but no handshake (`docs/plans/p0.md:83`)                                                                                               | designed                    |
| `harness.*` method family                                                                                                                                     | `devtools.md:44-54`; `Harness.swift`                               | nine built (`check`, `clock`, `command`, `log`, `quirk`, `render`, `settle`, `snapshot`, `world`; `Harness.swift:111-133`); `input`, `capture`, `trace.feed`, `shutdown` not | partial                     |
| `lattice` client CLI and `lattice dev` family                                                                                                                 | `architecture.md:70`, `devtools.md:60-71`                          | not built; `lattice-dev` stand-in with `run` and `shot` (`DevCLI.swift:64-85`, `docs/plans/p0.md:70`)                                                                        | partial                     |
| Structured exit codes 0/1/2/3                                                                                                                                 | `devtools.md:73`                                                   | built (`DevCLI.swift:10-12`, `:217`)                                                                                                                                         | built                       |
| `--json` per scenario, one line each                                                                                                                          | `devtools.md:73-83`                                                | built for `run` (`Runner.swift:106-123`, `DevCLI.swift:218`); not for `shot`                                                                                                 | partial                     |
| Transport parity test (in-process vs socket)                                                                                                                  | `devtools.md:40`                                                   | not built; there is no socket transport                                                                                                                                      | designed                    |
| In-process transport with no socket                                                                                                                           | `architecture.md:68`                                               | built (`Sources/lattice-dev/main.swift:20-27`, `DaemonHost.handle`)                                                                                                          | built                       |
| Deterministic bytes and manual clock                                                                                                                          | `devtools.md:58`                                                   | built in part: virtual clock and sorted keys; no seed flag                                                                                                                   | partial                     |
| PNG shots with CoreGraphics                                                                                                                                   | `devtools.md:86`, `architecture.md:67`                             | not built; `LatticeShot` absent                                                                                                                                              | designed                    |
| `LatticeProtocol` DTO boundary                                                                                                                                | `architecture.md:61`                                               | built (`Sources/LatticeProtocol/Harness.swift`, `Snapshot.swift`, `Command.swift`)                                                                                           | built                       |
| `LatticeConfig` (closed TOML schema)                                                                                                                          | `architecture.md:62`                                               | not built; `Command` lives in Protocol because `LatticeConfig` does not exist (`docs/plans/p0.md:76`)                                                                        | designed                    |
| Import-boundary enforcement                                                                                                                                   | `architecture.md:101-110`, `docs/plans/p0.md:17`                   | built: five import tests (`Tests/LatticeArchitectureTests/ImportBoundaryTests.swift:10-68`), boundary script (`scripts/check-package-boundaries.py:20-48`), `just quality`   | built                       |
| AeroSpace-derived scenario corpus                                                                                                                             | `docs/plans/p0.md:24`                                              | 45 scenarios with guide citations (`Scenarios/aerospace/README.md:24-102`)                                                                                                   | built                       |
| Scenario corpus gaps catalogued                                                                                                                               | not designed                                                       | `Scenarios/aerospace/README.md:121-163` lists unexpressible behaviour and gaps                                                                                               | built (docs)                |
| Spikes as standalone packages with "proves / does not prove" READMEs                                                                                          | `spikes/README.md:3`, `spikes/Scenario/README.md:7-15`, `:181-190` | seven spike packages present (glob); later migrated, not deleted (`docs/plans/p0.md:57`)                                                                                     | built                       |
| Developer loop as mise tasks                                                                                                                                  | `devtools.md:476-489`                                              | `Justfile` with `core`, `quality`, `ci` modules (`docs/plans/p0.md:17`)                                                                                                      | different tool              |
| L3 VM harness with Tart and `vdisplay`                                                                                                                        | `devtools.md:453-472`                                              | spike evidence only (`docs/log.md:16`, `:17`)                                                                                                                                | designed                    |
| L4 manual checklists                                                                                                                                          | `devtools.md:454`                                                  | not built                                                                                                                                                                    | designed                    |

## Findings

### 1. Scenarios are the behaviour specification and the test harness at once

The runner is the only place assertions are evaluated. It sends `harness.*` and `exec.*`
requests and computes every `expect` from the snapshot the daemon returns, so the daemon
has no assertion state and any transport works (`Runner.swift:7-9`). A failing `expect` is
recorded and the run goes on, so one report lists every failure (`Runner.swift:21-22`,
`:268-277`). The failure report carries the statement, expected and actual values, and the
ASCII render at the moment of failure (`Runner.swift:26-42`, `:127-152`). That render is
what an agent reads to see what went wrong.

Scenarios also document: the 45-file AeroSpace corpus cites `docs/guide.adoc` line ranges
in each file's header and assigns each behaviour to a guide section
(`Scenarios/aerospace/README.md:12-18`). Where Lattice deliberately differs from
AeroSpace, the scenario asserts Lattice's behaviour and names the AeroSpace behaviour it
replaces (`Scenarios/aerospace/README.md:104-119`). A scenario that cannot express a
documented behaviour is not faked: the corpus keeps a separate "not yet expressible" table
with the phase that lands each verb (`Scenarios/aerospace/README.md:121-153`). This is a
good pattern for Tessera: the corpus says what it proves and what it cannot yet say.

Scenario text is versioned in-tree and runs under `just core scenarios` with the glob
`Scenarios/*.scn Scenarios/aerospace/*.scn` (`core.just:14-16`, `ci.just:10-13`). Every
aerospace file ends with `check`, so the invariants hold over each final world
(`Scenarios/aerospace/README.md:18`).

### 2. The virtual platform is obedient, and that limit is written down

`VirtualPlatform` is an actor that implements the same `Platform` protocol as the real
adapter; "the smallest obedient platform" is its own description
(`VirtualPlatform.swift:3-5`). Quirks are opt-in and armed one at a time
(`VirtualPlatform.swift:4`). The README says what this does not prove: nothing about
macOS, no echo of the platform's own writes as move and resize events, focus that flows
one way, one batch per statement, no concurrency, and the unbuilt verbs
(`Scenarios/README.md:151-156`). The design repeats the caveat in its test pyramid: L1
proves wiring "that quirk-handling logic reacts as modelled" and cannot prove "that a
quirk model is faithful to macOS" (`devtools.md:451`).

### 3. Expectations are checked against more than one source

The design makes frame assertions read the platform and intent assertions read the model,
because the difference is the bug class (Decision 8, `devtools.md:512`). The built runner
has `expect frame` against the platform and `expect window … on W` against the model
(`Scenarios/README.md:61-62`). `expect intent` was not built (`docs/plans/p0.md:116`).

The same pattern appears in Lattice's invariant design: a pure checker takes the world and
the last plan the platform was given, so a stale plan is caught (`Invariants.swift:11-14`,
`Runner.swift`'s scenario path is not where `check` gets its plan: it is
`Reactor.lastPlan` through `DaemonHost`, `docs/plans/p0.md:108`).

### 4. JSON and exit codes are designed for an agent reading stdout

The contract is in one comment: "Exit codes: 0 success, 1 a statement failed, 2 usage
error, unreadable file or scenario that does not parse, 3 the daemon could not be reached
or answered something unreadable" (`DevCLI.swift:10-12`). The per-file JSON is one line
with a fixed key order, `scenario`, `passed`, `failures` (each with `line`, `verb`,
`expected`, `actual`), then optional `settles` and `dumps` (`Runner.swift:106-123`,
`Scenarios/README.md:25`). A parse error under `--json` is the same shape with `verb`
`parse` (`DevCLI.swift:184-192`). Several files produce one line each and a final
`{"scenarios","passed","failed"}` line (`DevCLI.swift:224-248`). The `shot` command has no
JSON form; it prints the render only (`Scenarios/README.md:29-30`).

The design also states that every `dev` command prints one JSON object on stdout when not
on a terminal, with `--json` and `--pretty` forcing either (`devtools.md:73`). That is a
convention: nothing in source enforces it, because only `run` exists.

Two details are worth carrying over. First, the human report and the JSON report are both
functions of one `ScenarioReport` (`Runner.swift:86-152`), so they cannot disagree.
Second, the runner's output is deterministic by construction: time moves only on `wait`,
`tick` and `settle`, ids come from counters, no dictionary is iterated in hash order, and
the file says "Running a scenario twice gives the same bytes" (`Runner.swift:3-5`).

### 5. Architecture boundaries are enforced twice, in two mechanisms

`Package.swift` declares the targets; the script and the tests enforce what may import
what.

- `scripts/check-package-boundaries.py` reads the package graph from
  `swift package describe` and rejects target edges that are not in
  `ALLOWED_DIRECT_DEPENDENCIES` (`scripts/check-package-boundaries.py:20-30`), with a
  separate allowlist for test targets (`:34-48`). Its final `return 1` is at `:173` (the
  failure path; the branch above it was not read); its JSON-input handling is in
  `load_package_description` (`:127-149`), which I did not read in full.
- `Tests/LatticeArchitectureTests/ImportBoundaryTests.swift` has five tests that read
  source text: `LatticeCore` imports nothing, `LatticeProtocol` only Foundation,
  `LatticeLog` only Foundation, os and Synchronization, `LatticeScenario` never Core,
  Virtual or Daemon, and no AppKit, AppServices, Carbon or CoreGraphics anywhere under
  `Sources` (`ImportBoundaryTests.swift:10-68`).

The architecture page states the rule and the reason: "each enforced by the target graph
rather than by convention" (`architecture.md:101`), with the consequence that Core knows
no wire format and Protocol knows no model (`architecture.md:104`). The test header states
the design intent. The shared `swiftSettings` loop in `Package.swift` applies one settings
set to every target (`Package.swift:155-167`, `docs/plans/p0.md:31`).

One small discrepancy: `architecture.md:63` says `LatticeLog` imports "Foundation, `os`",
but `Log.swift:15` says only Foundation and Synchronization, and `docs/plans/p0.md:81`
records that `os` was dropped as unused. The source is the authority here.

### 6. Decisions are recorded in-line, with what was rejected

`devtools.md:505-527` has 22 numbered decisions. Each states the decision and then the
rejected alternative with the reason, and where a decision was superseded it says so
(Decision 18 is "Superseded by Decision 19", `devtools.md:522`). Examples relevant to
Tessera:

- Decision 3: ASCII render plus model JSON are the goldens; PNG is compared by pixel hash
  and only as a review artefact, because glyph rendering varies by OS release
  (`devtools.md:507`).
- Decision 9: a quirk is modelled only with recorded evidence, because "a fake that
  invents a failure teaches the core the wrong recovery" (`devtools.md:182`, `:513`).
- Decision 2: a manual clock is the default, and real sleeps are rejected because they
  make scenarios slow and flaky (`devtools.md:506`).

Open questions are numbered and dated, and each names the phase that will answer it
(`devtools.md:530-537`, e.g. `:533` "Verify in P1").

### 7. The spikes were standalone packages, then migrated mechanically

`spikes/README.md:3` says each spike is "a standalone Swift package built on the host".
`spikes/Scenario/Package.swift` shows the shape: its own `Package` with
`platforms: [.macOS(.v15)]`, a path dependency on `../LayoutCore`, a library and an
executable, and a comment that says "No third-party dependencies: argument parsing is
hand-rolled so that building needs no network" (`spikes/Scenario/Package.swift:4-12`,
`:14-42`). Each spike README has a "proves" section and a "does not prove" section
(`spikes/Scenario/README.md:7-15`, `:181-190`).

P0 then did the migration as its first round, before any new code: "Round 1 moves both
spikes mechanically before any addition, so that every later slice is a diff against
passing tests" (`docs/plans/p0.md:71`). The render goldens had to be byte-identical after
the move (`docs/plans/p0.md:63`). The spike directories were kept as evidence and "nothing
new goes into them" (`docs/plans/p0.md:57`). That is the pattern Tessera's own spikes
could follow: a standalone package with a README that states proofs and non-proofs, then a
mechanical move with byte-identical goldens before the real work.

Seven spike packages exist: `AXWrite`, `AXSys`, `VirtualDisplay`, `ScriptHost`, `AXProbe`,
`Scenario`, `LayoutCore` (glob of `spikes/*/Package.swift`). Five are macOS platform
probes (`AXWrite`, `AXSys`, `VirtualDisplay`, `ScriptHost`, `AXProbe`); `LayoutCore` and
`Scenario` are the portable pair.

### 8. Tessera's practice, as Lattice read it

Lattice mined Tessera's conventions and practice on 2026-10-17 (`docs/log.md:31`). Two
research pages record the rules and what the repo does against them:
`docs/research/tessera-conventions.md` and `docs/research/tessera-practice.md`. The
adopted set is in `docs/decisions/code-conventions-from-tessera.md:14-30`; the rejected
set is `:34-39`.

Items Lattice took from Tessera that bear on devtools:

- Boundary script and allowlist, lint and hooks (from `tessera-practice`, cited there as
  `scripts/check-package-boundaries.py`).
- Import-boundary tests, and compile-fail fixtures for ownership rules.
- Injected clocks and no `Task.yield()` in tests (`tessera-conventions.md` §6, `:125-130`;
  the conventions page also records the divergence between rule and practice).
- Inline snapshots, and "snapshots for structure recorded by the tool"
  (`docs/plans/p0.md:55`).
- Conventional Commits, enforced by `lefthook` (`lefthook.yml:1-10`).

Lattice also records a gap that matters here: Tessera has no property tests
(`tessera-practice.md` §5, `tessera-conventions.md` §6, `:134`, as cited by Lattice).
Lattice added a property suite for the pure core on that basis.

The Tessera phase-zero rule Lattice quotes is "exactly one job: prove the dev loop"
(`tessera-conventions.md` §1, `:21`, citing `Spec.md:182-183` in the Tessera repo). That
is a useful precedent for Tessera's devtools phase.

### 9. Agent-written expectations are a named risk

`docs/design/roadmap.md` has a "what could sink it" table. One row names the risk that
matters most for scenario-driven agent work: "Agent-written expectations are wrong"
(`roadmap.md:187`). The table is in the roadmap rather than the devtools page, so the risk
is an explicit project-level concern, not a footnote. The corpus's answer is that each
expected frame is hand-derived from the AeroSpace arithmetic, "written by hand and then
run" (`Scenarios/aerospace/README.md:15`), and the scenarios never assert a refusal
(`Scenarios/aerospace/README.md:16`).

### 10. The design is ahead of the build, and the build says so

The P0 plan's Outcome lists what was not delivered by design: the TOML config heredoc
(P1), `offViewport` and `algorithm` hidden reasons (no layout emits them),
`expect frame … tol`, `expect intent`, refusal assertions, and the verbs the corpus lists
as inexpressible (`docs/plans/p0.md:116`). The P0 plan's Next step is the author's review
of the interfaces before P1, which would add the socket, CLI and TOML decoder
(`docs/plans/p0.md:27`).

Lattice's `docs/answers.md` §8 says the central tool is the harness daemon and lists the
`lattice dev` family (`answers.md:91`), and the same section describes the flight recorder
and the VM loop in the present tense (`answers.md:107-113`). A reader who does not check
the build state would think those exist. The `answers.md` section is written as a design
answer, so this is a documentation register issue rather than a false claim, but an agent
that reads `answers.md` first could plan against a surface that is not there.

## Lessons and decisions recorded by Lattice

- **Mechanical move first.** P0 round 1 moved the spikes before adding anything, so every
  later slice had a passing baseline (`docs/plans/p0.md:71`).
- **Migration keeps goldens byte-identical.** The render and CLI output had to match the
  spike binary on all seven scenarios (`docs/plans/p0.md:15`).
- **Proof of a guard.** An acceptance item says the architecture tests fail when a
  forbidden import is added, "proved once with a throwaway edit, then reverted"
  (`docs/plans/p0.md:66`).
- **Scenario failures do not stop a run.** One report lists every failure
  (`Runner.swift:21-22`).
- **Unbuilt verbs are listed, not faked.** The corpus says so per behaviour
  (`Scenarios/aerospace/README.md:121-127`).
- **Reject alternatives in writing.** Each decision names what was rejected and why
  (`devtools.md:505-527`).
- **Command type in the wrong module was accepted as a known deviation.** `Command` lives
  in Protocol, not `LatticeConfig`, because `LatticeConfig` does not exist yet
  (`docs/plans/p0.md:76`). The deviation is recorded rather than hidden.
- **Name what is absent.** The P0 plan's "Discoveries" section is long and specific, and
  it names every place the design and the code disagree (`docs/plans/p0.md:75-110`).

## Implications for Tessera devtools

> [INFERENCE] Everything in this section is my reading of Lattice's material for Tessera.
> None of it has been observed in the Tessera repo or in a run.

1. **Carry the scenario-as-spec pattern over, in Swift terms.** A text scenario whose
   `expect` lines are evaluated by the client from a snapshot the runtime returns is the
   piece worth copying. It keeps assertion logic out of the app's runtime and lets one
   runner drive an in-process app and, later, a real one. Tessera's Phase 4 catalog is a
   natural first scenario surface: focus, scroll, mouse and controls can each be a verb.

2. **Use the cell grid as the golden, as Lattice uses ASCII.** Lattice's decision that
   ASCII is the golden and pixels are only a review aid (`devtools.md:507`) maps onto
   Tessera's cell grid. Tessera already has a Ghostty-based snapshot harness
   (`tessera/devtools` investigations 002, 003, 006), so the question is less whether to
   snapshot and more which grid form the scenario `expect render` compares against.

3. **Write the "proves / does not prove" list for every layer.** Lattice's test pyramid
   has a "cannot prove" column for each layer (`devtools.md:448-454`) and its spike
   READMEs have proof sections (`spikes/Scenario/README.md:7-15`, `:181-190`). For a
   terminal framework, the obvious gap is the difference between Tessera's cell model and
   real terminals; Tessera should say that in the same place it claims rendering is
   correct.

4. **Make the invariant checker a pure function and a verb.**
   `checkInvariants(world, plan)` is pure, reports named rules, and is also a scenario
   statement (`Invariants.swift:93-98`, `Scenarios/README.md:59`). For Tessera, the
   analogue is a pure check over the view tree plus the last render: focus path resolves,
   exactly one focused control, scroll offsets within content, no view outside its
   container. The rule ids should be stable and cited by failures.

5. **Catalogue platform quirks with evidence and test the catalogue.** Lattice's
   `QuirkTests` checks that every quirk names rows that exist and every scenario that uses
   one cites its row (`QuirkTests.swift:36-93`). Tessera already keeps terminal-specific
   behaviour in investigations (`015-apple-terminal-underline-corruption.md`,
   `018-ghostty-all-keys-omitted-modifier.md`, `019-ghostty-graphics-erase-ordering.md`).
   A quirk catalogue that scenarios cite, with a test that the citation resolves, would
   turn those notes into executable constraints.

6. **Put the same JSON contract on every command.** One JSON line per scenario, fixed key
   order, exit codes 0/1/2/3 with fixed meanings, and a `parse` failure shaped like a
   failure (`DevCLI.swift:10-12`, `:184-192`). Agents can parse this without reading
   prose. Do it before the second command exists, because retrofitting is what Lattice's
   `dev` family has not yet had to do.

7. **Keep a pure core and make its inputs recordable.** Lattice's strongest bug-report
   idea is that a pure core plus an ordered input trace is a complete bug report
   (`devtools.md:22`). For Tessera, the equivalent is recording the input events and the
   state transitions of the runtime loop, then replaying them. That only works if the
   events are handle-free values, which Lattice enforced for `PlatformEvent`
   (`architecture.md:105`).

8. **Use an in-process transport first and keep a second transport for the real process.**
   Lattice's `DaemonHost.handle` lets `swift test` run scenarios with no socket
   (`main.swift:20-27`), and the design adds a transport-parity test to prove the two
   agree (`devtools.md:40`). The parity test is designed and not built, so it is an idea
   to copy with its status, not a result.

9. **Spike as standalone packages, then migrate with goldens unchanged.** Lattice's
   pattern (`spikes/README.md:3`, `docs/plans/p0.md:71`) is cheap and worth copying. Each
   Tessera spike gets its own package and a proof/non-proof README, and the first
   migration round must keep existing snapshot goldens byte-identical before new work.

10. **Enforce import boundaries with a script and with tests that read source text.**
    Lattice uses both an allowlist script over the package graph and five source-text
    tests (`ImportBoundaryTests.swift:10-68`). Tessera already has a boundary script and
    `ImportBoundaryTests` (per Lattice's reading of Tessera), so the transferable part is
    the allowlist of test-target dependencies, which Lattice keeps separate
    (`check-package-boundaries.py:34-48`).

Pitfalls, each with its Lattice evidence:

- **Design-first documents drift from the build.** `answers.md` and `devtools.md` describe
  the surface in the present tense (`answers.md:91-113`), and `devtools.md` names `mise`
  tasks while the build uses `just` (`devtools.md:476`, `docs/plans/p0.md:17`). Mark every
  design row with its status, as Lattice's tables do, and keep the status column current.
- **Two counts of the same thing.** The design lists seven invariants
  (`devtools.md:121-129`); the build has fifteen (`Invariants.swift:33-81`). The mapping
  lives in a plan's Discoveries section (`docs/plans/p0.md:105`), not in the design. Keep
  one owner for each catalogue.
- **An obedient fake gives false confidence.** The virtual platform only proves the
  decision logic (`Scenarios/README.md:151`). For Tessera, a headless harness proves the
  view layer's decisions and the terminal's cell output, not a real terminal's byte
  handling. Name that gap in the first scenario README.
- **Agent-written expectations are the weakest link.** Lattice ranks this as a sink risk
  (`roadmap.md:187`). Mitigate by deriving each expected value by hand from the spec
  before the run, and by never asserting a refusal
  (`Scenarios/aerospace/README.md:15-16`).
- **The socket and the replay were the most expensive designed items and are still not
  built.** Lattice's flight recorder, replay and fuzz (`devtools.md:105-115`, `:83`)
  depend on a transport and a recorder that P0 did not build. For Tessera, do not promise
  replay in phase one; promise the in-process scenario runner and the stable JSON contract
  first.
- **Scenario corpora grow faster than their gap lists.** The AeroSpace corpus has a gap
  table because the authors kept one (`Scenarios/aerospace/README.md:121-163`). Keep a
  "not yet expressible" table from the first scenario, not after the corpus reaches forty
  files.
