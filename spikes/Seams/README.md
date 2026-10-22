# Spike 5: Seams

Saved as [`30e4bbf.patch`](30e4bbf.patch) in this directory: commit `30e4bbf`
(`feat(spike): add resize, clock, and probe-ID seams for developer tooling`), written on
branch `devtools-seams-spike` on top of `cb8d143` (the plan 033 draft commit). It applies
cleanly to that base (`git apply --check spikes/Seams/30e4bbf.patch` against `cb8d143`)
and, as of 2026-10-22, to `plan-035` as well. The branch and its worktree are retired once
everything is on `main`; the patch is the record.

## Hypothesis

Three `package`-visible seams make the runtime scriptable and deterministic without new
public API and without changing existing snapshots:

1. `InMemoryTerminalDevice` can deliver `.resize` mid-session.
2. `ViewGraph` reads an injected clock instead of `ContinuousClock()`.
3. `TerminalSession` accepts an injectable Kitty probe image ID.

## How to run

```sh
git apply spikes/Seams/30e4bbf.patch   # on a scratch branch
swift test --filter "injected clock|deterministic clocks|resize delivered|closed input|injected probe"
for t in TesseraTerminalTests TesseraCoreTests TesseraTerminalIOTests TesseraTerminalSnapshotSupportTests TesseraWidgetsTests; do swift test --filter "$t"; done
```

## Result

| Seam                                 | Source lines (+/-)    | Verdict                                         |
| ------------------------------------ | --------------------- | ----------------------------------------------- |
| `ViewGraph` injected clock           | +19 / -10             | pass                                            |
| `TerminalSession` probe image ID     | +7 / -1               | pass (the init seam already existed; see below) |
| `InMemoryTerminalDevice` live resize | +77 / -1 (+5 session) | pass, but over the 40-line budget; see below    |

Tests added: `Tests/TesseraCoreTests/ViewGraphClockTests.swift` (59 lines) and
`Tests/TesseraTerminalTests/TerminalSessionSeamTests.swift` (130 lines).

Observed: all five new tests pass; `TesseraTerminalTests` 142 passed, `TesseraCoreTests`
31, `TesseraTerminalIOTests` 113, `TesseraTerminalSnapshotSupportTests` 15,
`TesseraWidgetsTests` 21. No existing snapshot or test changed. `PlatformIO.swift` and
`TerminalDevice.swift` needed **no change** (public or package): `TerminalDevice` already
has a `sizeChanges` closure and `PlatformIO` already merges it into `events` as `.resize`.

## Diff summary

- `ViewGraph.swift`: `private let now: () -> ContinuousClock.Instant`; the public init
  becomes a `convenience` init that passes `{ .now }` to a new
  `package init(root:size:environment:now:)`. The three `ContinuousClock()` pairs in
  `update`, `layoutIfNeeded`, and `render` use `now()`. `GraphDiagnostics` and
  `GraphStatistics` are untouched: `GraphStatistics` still synthesizes `Equatable` over
  its three `Duration` fields.
- `TerminalSession.swift`: `probeImageID` already was an init parameter (`:232`). The gap
  was that `package static withApplicationTerminal(configuration:io:environment:_:)` never
  forwarded it, so the only path that runs `resolution.runsActiveProbes` always used a
  random ID. Added `probeImageID:` to that static and a shared `randomProbeImageID()`
  default. `probeSleep` is already injectable on the init but not forwarded either; left
  alone.
- `InMemoryTerminalDevice.swift`:
  `package init(size:cellPixelSize:inputBytes:keepsInputOpen:)`,
  `package func deliverResize(to:)`, `package func closeInput()`, plus `sizeChanges` wired
  into `terminalDevice`. The public init delegates with `keepsInputOpen: false`, which
  preserves the old behavior (both streams finish immediately).
- `InMemoryTerminalSession.swift`: `package init(device:)` so a test can wrap an open
  device.

## Findings for the plan

1. **A `sizeChanges` pass-through alone cannot deliver `.resize` through `session.events`
   or `nextEvent()`.** `PlatformIO.events` finishes when `bytes` finishes (and
   `inputStreamsShareLifetime` is false), cancelling the resize task. The in-memory
   device's byte stream finishes immediately, so the session reports `inputClosed` before
   any resize arrives. A live session needs the byte stream held open until
   `closeInput()`. This is what `keepsInputOpen` does, and it is why the device seam is
   larger than budgeted.
2. **`PlatformIO` subscribes to `sizeChanges()` twice** (`PlatformIO.swift:44,47`: the
   public `sizeChanges` stream and the one inside `events`), so the device needs a
   fan-out, not a single stream.
3. **No lock was used.** The seam closures are synchronous, so subscription is registered
   by an unstructured `Task` into the actor. Ordering against `deliverResize` is not
   guaranteed, so the actor replays every delivered size to each new subscriber; delivery
   is therefore race-free but late subscribers see the full history. Repo rule
   `swift-prefer-actors-over-locks` forbids `Mutex`.
4. **`InMemoryTerminalSession.withApplicationTerminal` is public and fixed-shape**, so the
   probe ID cannot be injected through it; probe tests use
   `TerminalSession.withApplicationTerminal(... io:)` directly. A scenario runner in a
   separate package (public API only) can drive resize only if these package seams become
   public or the runner lives in-package. This is the main plan decision: either promote
   `deliverResize`/`closeInput`/`keepsInputOpen` to public test-support API or build the
   runner in-repo.
5. **Injected clock and equality:** `GraphDiagnostics` equality already includes
   durations, so two real-clock graphs never compare equal. With a fixed clock they do
   (tested). `ContinuousClock.Instant` is only constructible from `.now`, so a test clock
   is `origin.advanced(by:)` from a captured `origin`. `ViewGraph` is not `Sendable`, so a
   non-`@Sendable` closure is fine.
6. **Probe test cost:** the private-mode round has no responder in the test device and
   waits out `activeProbeTimeout`; the test uses 100 ms. The graphics query bytes look
   like `ESC _ G i=4242,s=1,v=1,a=q,t=d,f=24;AAAA ESC \ ESC [ c`.
7. **Package access across modules works** for `TesseraTerminalTestSupport` from the test
   targets without `@testable`.

## Proves / Does not prove

Proves: a `.resize` delivered mid-session appears on `session.nextEvent()` and
`session.sizeChanges`, and the next `draw` sees the new size; the injected clock supplies
every pass duration; a chosen probe ID appears in the emitted Kitty query; existing tests
in five targets are unchanged.

Does not prove: that `Application`/widget-level runs react to `.resize` (only
`TerminalSession` was exercised); `SIGWINCH`/live-device behavior; the full repo suite;
that replaying history to late subscribers is the right semantics for a scenario runner
(it may want explicit "since subscription" semantics).

## Verdict

Pass for all three seams, partial on the size budget: the device seam is about 80 lines,
not <40, because holding the input open and fanning out two subscribers is required.

Process note: an early edit-tool call with a relative path landed in `main/`. I reverted
those four files with `git checkout`; `git status` in `main` shows no `Sources` changes
from this spike.
