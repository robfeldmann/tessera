# P4.3 implementation review packet

P4.3's operable Button slice is implemented: phased keyboard activation, primary pointer
routing and cancellation, visible held states, and real-rendered semantic capture. All
host quality gates pass. Visuals remain provisional, not human-approved baselines. This
does not complete Phase 4 or the entire Button catalog.

## Run and inspect

Worktree: `/Users/rob/Developer/robfeldmann/tessera/tessera-phase4-review-loop`. Branch:
`phase4-review-loop`. Run from this directory, not the original `phase4`.

```sh
swift run --package-path Examples TesseraLab run button
scripts/capture-specimen.sh button .artifacts/review/button
```

The live command needs an interactive terminal. Capture needs neither an interactive
terminal nor GUI permission. Its wrapper provides process-local macOS test-framework paths
and directly launches the capture binary; the live host does not link test support.

The Button/result specimen uses app-owned count, enabled state, presence, style selection,
and focus binding. Add uses built-in compact/plain styles; the second control uses a
generic label and a custom style. Capture records 26 checkpoints at each of 40×16 and
80×24 through the same driver, real renderer, and persistent Ghostty VT.

The checkpoints cover legacy Enter/Space, bare CSI-u, explicit Kitty press/repeat/release,
compact/plain pointer down/up, outside release, terminal blur, disablement, and removal.
External enabled/presence/style changes are explicit app-model updates, not simulated user
actions. The selector helper resolves unique, enabled Button metadata and chooses a point
in the current frame/clip intersection. It never assigns focus or invokes an action; the
normal graph route decides whether the event hits and activates.

## Contract and code review order

Start from the previous published packet, `d70acb4`, then review the P4.3 change in this
order:

1. `Key.swift` and `InputParser.swift`: per-event provenance is part of equality. Legacy
   keys and bare CSI-u activate immediately. Only the modifier parameter's explicit
   event-kind field enters phased activation; associated text and alternate key codes do
   not imply a release will arrive.
2. `Responder.swift`, `RuntimeNode.swift`, and `ViewGraph.swift`: normalized pointer
   phases, clipped reverse-paint-order hit testing, click-to-focus, and one capture owner.
   Disabled targets occlude underlays but can bubble to ancestors. New down,
   outside/invalid up, terminal blur, disablement, and removal cancel pending ownership;
   same-slot replacement must not inherit it.
3. `Button.swift`: one node-owned interaction state feeds actions and style configuration.
   Phased presses activate once on matching release; repeats do not activate. Compact and
   plain styles reverse their resolved semantic style while held without changing
   geometry. This emphasis policy is provisional. Custom styles receive the same
   `isPressed` value.
4. `ApplicationDriver.swift`: graph requirements enable mouse, keyboard enhancement, and
   terminal focus reporting without weakening the host's original mode configuration.
5. `ButtonSpecimen.swift`, `ButtonCapture.swift`, and their tests: inspect app state,
   selector-derived input, actual rendered output, and cancellation checkpoints together.

No compatibility equality, forced focus, direct action invocation, or renderer bypass was
introduced. Hover/motion delivery, broad gestures, bordered style, ScrollView, and
TextField are outside this slice. The full mouse API and catalog are not declared
graduated.

## Verification

Current combined evidence:

- `just core test`: 710 tests passed.
- `swift test --package-path Examples`: 30 tests passed.
- `swift test --filter PointerTests`: 16 regressions passed, including disabled ancestor
  bubbling, replacement, erased same-slot replacement, clipping, dynamic topmost changes,
  invalid release, and mixed key sources.
- `swift test --filter TesseraTerminalInputTests`: passed, including explicit provenance
  and associated-text cases.
- `swift test --package-path Examples --filter ApplicationDriverTests`: two baseline-mode
  transition tests passed, covering both initially disabled and stronger configured modes.
- `just quality format`, `just quality lint`, `just quality architecture`, and
  `just docs lint`: passed. Changed Markdown passed `pnpx markdownlint-cli`.

Live PTY verification launched `Examples/.build/debug/TesseraLab run button`. Exact Kitty
`:1` held the count at 3 with reverse styling; `:2` kept 3; `:3` advanced to 4 and
restored focus styling. SGR primary down held 4; primary up advanced to 5. An isolated `q`
exited 0, and the PTY's reconstructed alternate-screen content cleared on teardown.
Initial input also exercised legacy activation; the managed input tool appended Enter
until subsequent sends explicitly set `enter: false`.

Generated SVGs were inspected in a separately spawned headless Helium process using an
isolated temporary profile. Compact/plain held frames visibly differ from focused idle
frames, and custom-style, cancellation, and removal frames were examined. The magenta
cursor outline marks its recorded coordinate, not observed cursor visibility or shape.
SVGs use fixed cell geometry and a generic monospace font; rasterization is not canonical.

The first headless request unexpectedly attached to the browser relay despite not
requesting it. That attachment was immediately released and reported as a tool defect.
Subsequent inspection explicitly spawned the browser executable; no further relay was
used.

Linux and Windows verification remain unrun: the known Linux VM is stopped, Frost's
configured CLI is unavailable, and UTM was stopped. No VM bootstrap or system-tool
installation was attempted. Host checks do not establish those platform combinations.

## Source preservation and review boundary

This continuation targets only the separate implementation worktree. The initial session
had a preservation incident: two workers committed in the original `phase4`; their six
paths and branch ref were restored. Its tracked/dirty file contents and staged-entry
listing matched the initial inventory, but raw index bytes changed. **Byte-for-byte index
preservation is not claimed.** Exact hashes and the restoration boundary remain in
[STATE.md](STATE.md). This history is not erased by the P4.3 work.

The earlier implementation and capture history remains in the branch through `d70acb4`;
archived preview provenance under `artifacts/` describes that earlier revision unless
explicitly labeled P4.3. Publish only normal commits to `origin/phase4-review-loop`; no
force-push, PR, merge, or main-branch push is part of this task.

Human review remains the boundary for accepting Button API/style choices and visual
baselines. P4.4 is the next implementation unit; it is not started here.
