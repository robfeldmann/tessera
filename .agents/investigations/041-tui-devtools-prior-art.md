---
name: TUI Devtools Prior Art
date: 2026-10-19
status: resolved
---

# TUI Devtools Prior Art

## Question

Which developer tools do other UI frameworks ship for building, testing, debugging, and
evaluating terminal (and adjacent GUI) apps, and which ideas should Tessera carry over for
agent- and human-facing devtools? For each: what it offers, how tests address elements,
determinism techniques, snapshot formats and review UX, and the live inspection protocol.

## Outcome

Four families matter for Tessera:

1. **Headless drivers with a pilot or harness.** Textual `run_test`/Pilot, oh-my-pi
   `VirtualTerminal` plus `OMP_TUI_DEBUG`, Ink's `ink-testing-library`, Bubble Tea's
   teatest. They run the real app loop without a TTY and expose input injection and frame
   capture.
2. **Emulator-backed snapshots.** tui-test (real emulators), Tessera's Ghostty-backed
   `VirtualTerminal`, VHS. They snapshot what a VT shows, so escape handling is covered.
3. **Live inspection over a socket.** oh-my-pi's NDJSON debug server, Textual's devtools
   websocket console.
4. **Semantic addressing with auto-wait.** Playwright and tui-test locators, Textual
   `DOMQuery`. Tests target text, roles, or structure and re-resolve on every action.

The strongest transferable combination is (2) + (3): a deterministic headless run, a
VT-accurate screen, and a read-only inspection surface keyed by stable identity. Tessera
has (2) (`VirtualTerminal.ghostty`, snapshot strategies). It has no live inspection
surface and no element addressing. The Phase 4 Showcase inspector is specified as a
read-only snapshot consumer (`docs/Spec.md:7437-7441`), the natural seam for one.

## Method and scope

- Local checkouts read: Textual, Ratatui, oh-my-pi, lipgloss, Swift Composable
  Architecture, and Tessera `main` (read-only), all under `~/Developer/`.
- Web sources are cited by URL. Textual's pytest plugin is declared in `pyproject.toml`
  but not installed locally, so it is read from web source, not executed.

## Findings

### 1. Textual (Python)

**Devtools and logging.** `docs/guide/devtools.md` covers `textual run --dev` (`:18`),
`textual serve` (`:62`), live CSS editing (`:101`), `textual console` (`:113`), the
Textual log (`:170`), and the logging handler (`:211`).

- `src/textual/constants.py:110` `TEXTUAL_DEBUG`; `:122` `TEXTUAL_LOG`; `:128`
  `TEXTUAL_DEVTOOLS_PORT` (default 8081).
- `src/textual/app.py:761-771` attaches a `DevtoolsClient`; `:3353` `_init_devtools`.
- Protocol (web: `github.com/Textualize/textual`, `textual_dev/client.py`): a websocket to
  `ws://host:8081/textual-devtools-websocket` carrying msgpack frames
  `{type: client_log, payload: {group, verbosity, timestamp, path, line_number, segments}}`,
  with pickled Rich segments. A bounded queue (`LOG_QUEUE_MAXSIZE=512`) counts spillover.
  Log groups (`src/textual/_log.py`) are filtered with `-x`/`-v`.
- Live CSS reload: `app.py:576-587` `watch_css`, `:782` `css_monitor`;
  `src/textual/file_monitor.py:43` `FileMonitor.check()` is mtime polling.

**DOM inspection.** `DOMNode.tree` (`src/textual/dom.py:969`) renders the widget tree.
`DOMQuery` (`src/textual/css/query.py`) offers `filter`, `exclude`, `first`, `last`,
`only_one`, `set_styles`, `focus`, so styling selectors also address elements in tests.

**Testing and addressing.** `docs/guide/testing.md` covers key presses (`:91`), clicks
(`:105`), click offsets (`:124`), modifiers (`:150`), terminal size (`:159`), pausing
(`:171`), and snapshots (`:186`, `:207`, `:262`).

- `src/textual/app.py:2133` `run_test(headless, size=(80,24), message_hook)`. The headless
  driver emits no output, so tests assert on DOM state and the screen.
- `src/textual/pilot.py:76` `press`, `:192` `click(selector, offset, times, modifiers)`,
  `:349` `hover`, `:473` `_wait_for_screen`, `:535` `pause`, `:554`
  `wait_for_scheduled_animations`.
- Widgets are addressed by CSS-like selector; coordinates are a fallback via `offset`.

**Determinism.** `constants.py:104` `TEXTUAL_ANIMATIONS` (`none`|`basic`|`full`; type at
`_types.py:56`); `run_test` fixes the size; `wait_for_scheduled_animations`
(`pilot.py:554`) waits before capture.

**Snapshots.** `app.py:1855` `export_screenshot` records a Rich `Console` and exports SVG.
`src/textual/_doc.py:63-175` `take_svg_screenshot` runs `run_before` -> `pause` -> `press`
-> `wait_for_scheduled_animations` -> `pause` -> export. Its cache is keyed by file hash,
and only when `app_path` is given (`_doc.py:114-118`); `snap_compare` does not use it.

- Suite: `tests/snapshot_tests/test_snapshots.py` (`:77-90`,
  `snap_compare(LAYOUT_EXAMPLES_DIR / ...)`); baselines in
  `tests/snapshot_tests/__snapshots__/test_snapshots/` (448 files as read).
- `pytest-textual-snapshot` (web: `pytest_textual_snapshot.py`):
  `snap_compare(app_or_path, press=(), terminal_size=(80,24), run_before)`;
  `SVGImageExtension` (syrupy) normalizes the random `terminal-<id>` ids;
  `--snapshot-update`; `--snapshot-report` (default `snapshot_report.html`) from a Jinja2
  template with a "show difference" toggle; `TEXTUAL_SNAPSHOT_FILE_OPEN_PREFIX`
  (`code://`, `cursor://`, `pycharm://`) makes report paths editor links.

### 2. Ratatui (Rust)

- `ratatui-core/src/backend/test.rs:32` `TestBackend` (in-memory buffer); `:71` `new`;
  `:84` `with_lines`; `:103` `buffer()`; `:155` `assert_buffer`; `:199`
  `assert_buffer_lines`; `:233` `assert_cursor_position`; `:239` `Display` renders text
  only.
- `ratatui-core/src/buffer/assert.rs:8` `assert_buffer_eq!` prints a per-cell
  expected/actual diff.
- `ratatui-core/src/buffer/buffer.rs:569` `Debug` prints area, content, and styles where
  they change; `:471` `diff()`, `:506` `diff_iter()`; known-input diff tests at
  `:1094-1121`.
- `ratatui-core/src/terminal/render.rs:81` `draw(FnOnce(&mut Frame))`; `:98` diffs against
  `previous_buffer`. `frame.rs:51` `CompletedFrame { buffer, area, count }`.
- No insta or `.snap` files exist in the checkout (zero found). Visual review uses VHS
  tapes (`examples/vhs/*.tape`). `examples/apps/tracing` logs to a file via `RUST_LOG`:
  file-based, not live. `ARCHITECTURE.md` has no test or devtools section.
- Determinism is the fixed-size `TestBackend` plus direct cell assertions.

### 3. oh-my-pi TUI (TypeScript)

The closest existing design: an agent-facing inspection tool wired to a live process.

**Debug server.** `packages/tui/src/debug-server.ts`:

- `:208` `class TuiDebugServer`; NDJSON over a unix socket via `IpcServer`, enabled by
  `OMP_TUI_DEBUG=<path>`; `packages/tui/src/tui.ts:1482-1487` starts it.
- `:299` `#dispatch` ops: `text` (`:302`; last painted viewport, `window_top`, alt-screen,
  cursor); `frame` (`:313`; re-render at live width); `doc`/`tsp` (`:315`, `:322`); `tree`
  (`:326`; `kind`, `id`, `rect`, `focused`, `focusable`, `children`, overlays); `values`
  (`:328`; `debugState()` per `debugId`); `info` (`:330`); `keys` (`:344`,
  `parseKeyTokens` `:152`, `encodeChord` `:116`); `bytes` (`:350`); `paste` (`:354`);
  `mouse` (`:358`, SGR via `mouseSequence` `:181`); `quit` (`:366`).
- Injected input runs through the normal pipeline: `tui.ts:1277` `injectDebugInput`.

**Component contract.** `tui.ts:239` `Component`; `:245` `debugState?()`; `:263`
`describe?(cx): NativeNode | null` (semantic description, Tern Surface Protocol); also
`debugId`, `debugKind`, `debugChildren`, `render(width)`. `:131` `RenderScheduler`; `:138`
`TuiPaint` via `addPaintListener`; `:1211` `synchronizedOutput` (DEC 2026, `:89-91`);
`:1260` `getDebugPaint()`, `:1272` `getDebugDocument()`.

**Tests and determinism.**

- `packages/tui/test/virtual-terminal.ts:90` `VirtualTerminal` wraps `kitty-vt-wasm` (a
  real VT core); `getViewport` (`:274`), `getCellItalic` (`:349`), `getCursor` (`:358`).
- `test/virtual-render-scheduler.ts:12` `FRAME_HORIZON_MS = 40`; `:38`
  `VirtualRenderScheduler` uses a virtual clock.
- `test/debug-server.test.ts:85` "OMP_TUI_DEBUG drives and inspects a live TUI": the
  inspection protocol is also the test harness.
- `alt-frame-row-diff.test.ts` asserts that only changed rows are rewritten, via recorded
  terminal writes (byte-stream level). `test/fixtures/tmux-slow-output.ts` splits writes
  like a backed-up PTY.

**Agent tool.** `.omp/tools/tui.ts` (1381 lines): `start`, `stop`, `list`, `text`,
`screen`, `frame`, `tree`, `values`, `info`, `keys`, `type`, `paste`, `mouse`, `send`,
`resize`, `raw`, `shot`. Runs the app on a Bun PTY with `OMP_TUI_DEBUG`; `shot` rasterizes
PNG via `@napi-rs/canvas` (`:156-218`, `png()` `:403`). Input ops return an
after-screenshot (`:829-846`).

### 4. Bubble Tea, teatest, VHS (Go)

- **teatest** (web: `github.com/charmbracelet/x`, `exp/teatest/v2/teatest.go`):
  `NewTestModel(tb, model, WithInitialTermSize(80,24), WithProgramOptions)` captures
  output to a buffer.
  `WaitFor(tb, r, condition, WithDuration(1s), WithCheckInterval(50ms))` polls the raw
  output stream. `Send`, `Type` (one `KeyPressMsg` per rune), `FinalModel`, `FinalOutput`.
  `RequireEqualOutput` compares escape-bearing goldens via `golden.RequireEqualEscape`,
  updated with `-update`. No element addressing; waits match bytes.
- **VHS** (web: `github.com/charmbracelet/vhs` README): tape DSL. Outputs gif, mp4, webm,
  frames, `.txt`, `.ascii`. `Wait[+Screen][+Line] /regex/` (default timeout 15s),
  `Screenshot`, `Sleep`, `Hide`/`Show`. `Output golden.ascii` is documented for
  integration tests (README ~L972-978). Needs ttyd and ffmpeg. `vhs record` generates a
  tape from a session.

### 5. Ink (React for terminals)

Web: `github.com/vadimdemedes/ink` README and `ink-testing-library`. `render()` returns
`lastFrame()` (plain text), a `frames` array, `stdin.write`, `rerender`, `unmount`. CI
mode writes only the final frame (README ~L3385-3391). Inspection via React DevTools
(`DEV=true`, `npx react-devtools`, ~L3191-3212). `aria-role`/`aria-state`/`aria-label` and
`INK_SCREEN_READER` produce a second text output target (~L3213-3260).

### 6. Microsoft tui-test

Web: `github.com/microsoft/tui-test` README and `bindings/js/README.md`.

- Rust engine with CLI and Python, JS, Go, Rust bindings; backends alacritty (default),
  ghostty, rio, xtermjs. Tests run against real emulators.
- Locators: `getByText` (regex, full scrollback, whitespace, `after`/`before` anchors,
  `match unique|first|last|nth`); `getByStyle` (fg, bg, bold); `getByLink` (OSC 8);
  composition `and`, `or`, `filter has|hasNot`. Locators "resolve against latest terminal
  screen before every read or action."
- Waits: `wait idle` (screen stopped changing), `command`, `exit`, `ready`.
- Snapshots: `expect snapshot NAME [-u] [--include-style] [--include-title]`;
  `expect text --not`.
- Artifacts: `screenshot text|SVG|PNG`; `record` APNG/GIF/MP4/cast; `trace on|on-failure`
  writes `trace.html`, `trace.json`, `timeline.json`. `agent-context` JSON schema, `skill`
  command, daemon sessions. Default JS size 80x30.

### 7. SwiftUI and TCA (GUI analogs)

- **`#Preview`** (Apple: `developer.apple.com/documentation/swiftui/previews-in-xcode`,
  found via search; direct fetch returned 404): one view rendered in isolation with fixed
  data.
- **`Self._printChanges()`** (Hacking with Swift,
  `hackingwithswift.com/quick-start/swiftui/how-to-find-which-data-change-is-causing-a-swiftui-view-to-update`):
  called in `body` in debug builds to print which property caused re-evaluation. Stack
  Overflow (`stackoverflow.com/questions/69859370`) says it is a private, undocumented
  API.
- **TCA `_printChanges`** (local checkout): `Reducer._printChanges(printer)` wraps a
  reducer in `_PrintChangesReducer`
  (`Sources/ComposableArchitecture/Reducer/Reducers/DebugReducer.swift:16`) and prints the
  action plus a `customDump` diff of old vs new state, or "(No state changes)".
  DEBUG-only.

### 8. Flutter and React DevTools

- **Flutter** (web: `docs.flutter.dev/tools/devtools/inspector`): select-widget mode (tap
  device, node selected in tree); implementation-widget and guideline overlays; baselines;
  repaint highlighting; slow animations (timeDilation 5x). Per-node constraints and size;
  a flex explorer flags constraint violations and overflow stripes. Property edits apply
  live and revert on hot reload.
- **React** (web: `react.dev/learn/react-developer-tools`): browser extension or
  `react-devtools` npm package, connected via `<script src="http://localhost:8097">`.
  Component tree with editable props and state; the same shape as oh-my-pi's `tree` and
  `values` ops.

### 9. Playwright (browser)

Web: `playwright.dev/docs/locators`, `/actionability`, `/trace-viewer-intro`,
`/test-snapshots`, `/codegen`.

- Locators: `getByRole` first; then `getByText` (whitespace-normalized), `getByLabel`,
  `getByPlaceholder`, `getByAltText`, `getByTitle`, `getByTestId`. Locators are lazy and
  re-resolve on each action.
- Actionability: Visible, Stable (same box on two frames), Receives Events (hit-target),
  Enabled, Editable; `TimeoutError` on failure; `force` skips checks. Auto-retrying
  `expect(locator)`.
- Snapshots: `toHaveScreenshot` with per-platform goldens, pixelmatch threshold 0.2,
  `maxDiffPixels`, `stylePath` to hide volatile elements; text `toMatchSnapshot`;
  `--update-snapshots` needs review. Screenshots vary by host.
- Codegen: `npx playwright codegen <url>` records actions and picks role/text/testid
  locators, improving them "to make it resilient" on ambiguity; "Pick locator" mode;
  `--save-storage` / `--load-storage`; `page.pause()` opens codegen mid-test.

### 10. Tessera today (read-only, `~/Developer/robfeldmann/tessera/main`)

**Snapshot harness.**

- `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift:11`
  `VirtualTerminal.ghostty(cols:rows:)`; `VirtualTerminal+ghosttyUnavailable.swift:52`
  `ghosttyOrUnavailable`.
- `Sources/TesseraTerminalTestSupport/VirtualTerminalSnapshotting.swift`: `:16`
  `terminalDebugDump`, `:23` `terminalText(trim:)`, `:32` `terminalStyledGrid(trim:)`;
  links-grid variant in the DocC (`Terminal-Snapshot-Strategies`).
- Usage: `Tests/TesseraTerminalRenderingTests/RendererSnapshotTests.swift:25` (text),
  `:53` (styled, `trim: .none`), `:77` (debug dump).
- History: `.agents/investigations/003-ghostty-vt-snapshot-harness-closeout.md`
  (libghostty-vt pin, `ghostty_render_state_*` use, macOS and Lima Linux validation).
- Spec guidance: `docs/Spec.md:546-548` prefers focused regions, semantic state, or golden
  fixtures over full-screen byte snapshots. `:1432-1469` compares to Ratatui's
  `TestBackend`; `:1500-1502` plans ~60 golden-byte tests plus VT round-trips;
  `:7521-7522` plans reconciler `dump()` goldens and `statistics`.

**Inspection.**

- `docs/Spec.md:7437-7441`: the Showcase inspector reads an immutable snapshot only; it
  cannot mutate the graph, retain a `RenderRegion`, change focus, or trigger a pass.
  `:7550-7551` forbids serialization, persistence, logging, telemetry, and remote
  transport. A live socket would be a new decision against this contract.
- A grep of `Sources/` and `docs/` for `OMP_TUI_DEBUG`, debug socket, devtools, and
  inspector matched only Spec and investigation text. No runtime inspection surface exists
  in code.
- `DevTools/README.md` documents a `Linux VM Tests` Xcode wrapper around
  `just linux test`: a test-runner shim, not a runtime inspector.
- Addressing: tests use text rows, styled grid, and cursor. No element addressing; the
  view layer is Phase 4.

### 11. Comparison table

Legend: Y present; P partial or indirect; N absent. "text" = text-only snapshot.

| Capability           | Textual                   | Ratatui                      | oh-my-pi TUI               | Bubble Tea (teatest/VHS) | Ink              | tui-test                   | Tessera today               | Playwright                        |
| -------------------- | ------------------------- | ---------------------------- | -------------------------- | ------------------------ | ---------------- | -------------------------- | --------------------------- | --------------------------------- |
| Headless run, no TTY | Y `run_test`              | Y `TestBackend`              | Y `VirtualTerminal`        | Y teatest                | Y `render`       | Y real emulator            | Y `VirtualTerminal`         | Y                                 |
| Real VT emulation    | N                         | N buffer model               | Y kitty-vt-wasm            | P VHS real TTY           | N                | Y                          | Y libghostty-vt             | Y                                 |
| Element addressing   | Y CSS selectors           | N cells                      | P `debugId`, `tree`        | N regex/bytes            | N text           | Y text/style/link          | N rows/cursor               | Y role/text/testid                |
| Auto-wait            | P `pause`, animations     | N                            | N                          | P `WaitFor` polls        | N                | Y `wait idle`              | N                           | Y actionability                   |
| Key input            | Y `press`                 | N                            | Y `keys`                   | Y `Send`/`Type`          | Y `stdin.write`  | Y                          | N                           | Y                                 |
| Mouse input          | Y `click`/`hover`         | N                            | Y SGR                      | P messages               | N                | Y                          | N                           | Y                                 |
| Snapshot format      | SVG                       | text `Display`               | PNG tool, text             | escape golden, `.ascii`  | text             | text, SVG, PNG             | text, styled grid, dump     | PNG, text                         |
| Styles in snapshot   | Y (SVG)                   | P (`Debug`)                  | Y cell attrs               | Y escape bytes           | N default        | opt-in `--include-style`   | Y styled grid               | Y PNG                             |
| Review UX            | HTML report, editor links | per-cell `assert_buffer_eq!` | `shot` image               | golden `diff`            | none             | `expect snapshot -u`       | inline snapshot diff        | HTML report, `--update-snapshots` |
| Animation off        | Y `TEXTUAL_ANIMATIONS`    | n/a                          | N                          | N                        | N                | N                          | n/a                         | Y `stylePath`                     |
| Virtual clock        | N                         | N                            | Y `VirtualRenderScheduler` | N                        | N                | N                          | N                           | N                                 |
| Live inspection      | Y websocket console       | N                            | Y NDJSON socket            | N                        | P React DevTools | Y `trace.json`, daemon     | N by design (snapshot only) | P trace viewer                    |
| Tree / state dump    | Y `DOMNode.tree`          | N                            | Y `tree`, `values`         | N                        | P                | P trace                    | P `dump()` planned          | Y a11y tree                       |
| Agent-facing surface | N                         | N                            | Y `.omp/tools/tui.ts`      | N                        | N                | Y `agent-context`, `skill` | N                           | N                                 |
| Recording            | N                         | N                            | N                          | Y VHS                    | N                | Y APNG/GIF/MP4/cast        | N                           | Y video                           |
| Codegen / record     | N                         | N                            | N                          | Y `vhs record`           | N                | Y `record`                 | N                           | Y `codegen`                       |
| Trace / timeline     | N                         | N                            | Y `tsp` frames             | N                        | N                | Y `timeline.json`          | N                           | Y trace viewer                    |
| Logs to devtools     | Y `TextualHandler`        | N `RUST_LOG`                 | N                          | N                        | N                | N                          | N                           | N                                 |
| Live style reload    | Y `watch_css`             | N                            | N                          | N                        | N                | N                          | N                           | N                                 |
| State-change diff    | N                         | N                            | N                          | N                        | N                | N                          | N                           | N                                 |
| Semantic description | N                         | N                            | Y `describe?`              | N                        | N                | N                          | N                           | Y a11y tree                       |

A per-event state-change diff exists only as TCA's `customDump` (Section 7) and SwiftUI's
debug-only `_printChanges`. No surveyed TUI offers one.

## Implications for Tessera devtools

_Inference, not observed fact. Each idea is grounded in a finding above; the judgments are
mine._

1. **Build the live inspection surface as a read-only, request-scoped protocol.** oh-my-pi
   routes injected input through the normal pipeline (`tui.ts:1277`) and exposes
   `text`/`tree`/`values` over NDJSON (`debug-server.ts:208`). Tessera's Spec forbids
   mutation and remote transport for the inspector (`docs/Spec.md:7437-7441`,
   `:7550-7551`). A compatible design reads only the immutable snapshot and sends input
   through the existing session. Lifting the remote-transport prohibition is an owner
   decision.
2. **Use the Ghostty `VirtualTerminal` as ground truth for every devtools output.**
   oh-my-pi (`virtual-terminal.ts:90`) and tui-test read the screen from a real VT.
   Tessera has this (`VirtualTerminal+Ghostty.swift:11`). Any `text` or `shot` op should
   build on it, so escape bugs that a cell model hides still show.
3. **Give every element a stable identity and a `tree` op with an explicit describe
   hook.** oh-my-pi's `debugId`/`debugKind`/`debugState`/`describe?` (`tui.ts:239-263`)
   let an agent address "the Submit button" rather than row 12; Textual's `DOMQuery` does
   the same with selectors. Tessera's reconciler already has identity paths
   (`docs/Spec.md:7521-7522`), so exposing them with requirement and geometry fields
   (`:7437-7441`) is the cheapest route to element addressing.
4. **Adopt locators that re-resolve per action and auto-wait for screen idle.** Playwright
   (actionability, auto-retrying `expect`) and tui-test (`getByText` anchors, `match nth`,
   `wait idle`) both re-resolve against the latest screen. Tessera's helpers address rows
   and cursor only (`VirtualTerminalSnapshotting.swift:16-32`). A locator layer over the
   styled grid (text + style + link) is the next step; wait-for-idle is a determinism
   tool.
5. **Make style an explicit, opt-in assertion axis; keep text as the readable default.**
   Ink, tui-test (`--include-style`), and Ratatui's `Display` default to text. Tessera
   already has three strategies (`VirtualTerminalSnapshotting.swift:16-32`). Require the
   styled grid where color is the contract, and reserve the debug dump for diagnosis.
   Textual's 448 SVG baselines show the review cost of whole-screen styled snapshots.
6. **Add a per-event state-change diff.** No surveyed TUI does this. TCA prints action
   plus `customDump` diff (`DebugReducer.swift:16`). A Tessera op reporting which
   element's state, focus, or geometry changed per input event, sourced from the
   reconciler's `statistics` and `dump()` (`docs/Spec.md:7521-7522`), would answer "why
   did this redraw" and "why did focus move" without a debugger. Keep it DEBUG-only.
7. **Use an injected clock and a fixed frame horizon for every devtools-driven run.**
   oh-my-pi's `VirtualRenderScheduler` with `FRAME_HORIZON_MS=40`
   (`virtual-render-scheduler.ts:12`) and Textual's `TEXTUAL_ANIMATIONS=none`
   (`constants.py:104`) are the determinism levers. Phase 4 focus, scroll, and animation
   will need the same, or agent-driven runs will flake. The Spec names no clock
   abstraction yet.
8. **Make snapshot failures human-reviewable and agent-readable.** Textual's HTML report
   with difference toggle and editor links, Ratatui's per-cell diff, and tui-test's
   `trace.json`/`timeline.json` are the models. A Tessera failure should show cell-level
   expected/actual, and an agent bundle should carry screen text, styled grid, debug dump,
   and the last N input events as one JSON file.
9. **Make the agent tool a thin wrapper over the protocol the tests use.** oh-my-pi's
   `debug-server.test.ts:85` drives the same live TUI the agent tool does, so the paths
   cannot drift. tui-test's `agent-context` and `skill` are the second model. Avoid a
   separate agent-only harness.

Pitfalls:

- **Non-portable transport.** oh-my-pi's protocol is a Bun unix socket and `shot` needs a
  native canvas. Tessera validates on macOS, a Linux Lima VM, and Windows
  (`docs/WindowsFrostVM.md`). Any socket needs a Windows story or a per-platform gate.
- **Pickled, version-coupled transport.** textual-dev pickles Rich segments over the
  websocket (`textual_dev/client.py`). Use a versioned, plain-data schema.
- **Cache keyed too narrowly.** Textual's `_doc.py` cache uses only the file hash when
  `app_path` is set (`_doc.py:114-118`), so a changed dependency can serve a stale
  screenshot. Key any Tessera screenshot cache on the full build input.
- **Text-only assertions hide style regressions.** Ink, Ratatui `Display`, and tui-test's
  default all miss color changes. The styled grid exists for this; never let the text
  strategy be the only one on styling work.
- **Full-screen baselines churn.** Textual's baseline set changes with any shared style.
  Prefer region-scoped or semantic snapshots, as `docs/Spec.md:546-548` already directs.
- **Escape churn in byte goldens.** teatest goldens change when byte output changes even
  when the screen does not. Keep byte goldens at the encoder layer
  (`docs/Spec.md:1500-1502`) and assert screen state at the screen layer.
- **Live mutation in the inspector.** Flutter's inspector edits apply live. The Spec
  forbids mutation (`docs/Spec.md:7437-7441`); keep that, and if live edits are ever
  wanted, make them a separate, explicit, reversible op.
