---
name: Tern developer tooling and Ternbook's use of it
date: 2026-10-19
status: resolved
---

# Tern developer tooling and Ternbook's use of it

## Question

What developer tooling does Tern expose for building, observing, and checking a running
app (headless sessions, offscreen shots, the `ctl` control socket, scenario scripts, JSON
state)? How does Ternbook turn that surface into screenshots, reference pages,
keyboard-coverage records, and per-release snapshots? What makes the loop reliable enough
for an agent to run unattended, and what is fragile?

## Outcome

- Four entry points. `tern shot` renders scenario files offscreen, writes a PNG and a
  layout JSON per `shot` line, and exits. `tern serve` keeps a headless session on a
  control endpoint until `quit`. `tern ctl` sends one command, or a file of them, to a
  `serve` session or a window. `tern --control EP` opens a real window that answers the
  same socket.
- One grammar: a scenario is one command per line. The vocabulary is the harness verbs
  (`key`, `click`, `shot`, `wait`, and others, named in `tern help dev` only) plus about
  517 lines of world commands over 83 leading words.
- Protocol: one request, one JSON reply. Success is `{"ok":true,...}`, exit 0. Failure is
  `{"ok":false,"error":"..."}`, exit 1. Most errors are specific (a timeout states its
  duration; an unknown key lists the accepted names). Two gaps: a `dump` selector that
  matches nothing returns `ok:true` with no elements, and a missing socket prints plain
  text with no JSON.
- Determinism: a throwaway config, home, and daemon per run; a fixed shot root; fixed git
  identity and clock; a neutral prompt; readiness barriers (`ready`, `git wait`,
  `expect`); copy-only-if- bytes-differ; and `# render: live` for work that finishes in
  real time. Observed: two `tern shot` runs of one scenario gave byte-identical PNGs and
  layout JSONs (eight files).
- Clock: `stats` reports `now` and `docNow`. `freeze-anims` (named in help only by the
  `thaw` line) stops `docNow` while `now` and the frame count keep moving.
- Ternbook turns observations into data: `capture` (keys, actions, 295 settings, 13
  preference pages, menus, per release under `data/tern/<version>/`), `coverage` (how each
  control is reached, by replaying shots and walking focus), `reference` (generated
  pages), and `shots` (light and dark PNG pairs with numbered labels and crops from
  sidecar TOML). Each takes `--json`, and each keeps going past per-item errors.
- Drift: the installed Tern is 0.9.4 (b9ef74c). The newest snapshot is 0.9.0 (56bd59f).

## Method and boundaries

- `tern --version` reports `tern 0.9.4 (b9ef74c)` (2026-10-19). Ternbook's snapshot and
  Lattice's survey (`~/Developer/robfeldmann/lattice/main/docs/research/tern-devtools.md`)
  describe 0.9.0.
- Checked against Lattice's survey: `tern help dev` is 824 lines; `ready` is at line 91;
  `expect` at 99-100; the world block is 90-811; the 0.9.0 counts in the survey match what
  is recorded there.
- Not run: `tern serve --help` (Lattice's survey records that it starts a server on the
  default socket).
- Probes were isolated. Each `serve` and `shot` run had a temporary `HOME`,
  `TERN_CONFIG_DIR`, and `TERN_DAEMON_SOCKET`, and an explicit `--control` socket under
  `/tmp/tern-probe`. No `ctl` ran without `--control`. No window was opened.
  `/tmp/tern.sock` was never created, and no probe process was left running.
- Citations: `ternbook:` means `~/Developer/robfeldmann/ternbook/main/`. `dev:N` means
  line N of `tern help dev` (0.9.4), saved to `/tmp/tern-help-dev.txt`. Ternbook's own
  rule is to observe Tern only through its interfaces and not to read the binary
  (`ternbook:AGENTS.md:7`,
  `ternbook:docs/decisions/observe-through-tern-interfaces.md:10-18`); this pass kept to
  that rule.

## 1. The surface

`tern help` (0.9.4) lists the developer forms (lines 15-20 of the top-level text):

```text
  tern serve [--control EP] [--out DIR] [ARGS]
                            a headless session on a control endpoint, until `quit`
  tern ctl [--control EP] COMMAND...
  tern ctl [--control EP] --file SCENARIO
  tern ctl COMMAND...          in a Tern pane, a control command (`tern help dev`) for the window
                               showing it, such as css reload after editing Tern's CSS, state or
                               shot NAME (--control EP: a window or serve started with that
                               endpoint)
  tern whoami [--json]         the identity chain of the pane it runs in
```

Outside a pane, `tern whoami` exits 1 with
`not inside a Tern pane (TERN_PANE_SOCKET and TERN_PANE are unset)`. `TERN_WINDOW_SOCKET`,
which `ternbook:AGENTS.md:8` names, appears in neither help text.

`tern help dev` (824 lines) is the only reference for the developer tooling. Its layout:
lines 4-31 launch and harness forms; 33-73 control commands (`ctl`); 75-88 scenario notes;
90-811 world commands; 812-824 environment variables (`STENCIL_LOG`, `STENCIL_LOG_DIR`,
and others).

Subcommand help is incomplete. `tern shot --help` exits 2 with
`set STENCIL_FIXTURE_ROOT to the app crate directory containing goldens, or supply an explicit path`.
`tern bundle --help` exits 2 with `unexpected argument "--help"`. The top-level help
promises that `tern COMMAND --help` shows a command's arguments (top help, lines 19-20).

## 2. Entry points

| Form                                                             | Help      | Observed                                                                                                                                              |
| ---------------------------------------------------------------- | --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `tern shot SCENARIO... --out DIR --flat --size WxH --theme both` | dev:8-14  | Writes `NAME.png` and `NAME.layout.json`, then `NAME-dark.png` and its layout, and exits. `--size 800x600` became `800x600@2`, giving 1600x1200 PNGs. |
| `tern serve --control EP --out DIR`                              | dev:15-16 | Prints `tern: control on <sock>`, then ``tern: serving (`tern ctl quit` stops)``. Stdout is a transcript: `> cmd`, then `< reply`.                    |
| `tern ctl --control EP COMMAND...`                               | dev:17-18 | One JSON object on stdout.                                                                                                                            |
| `tern ctl --control EP --file SCENARIO`                          | dev:19-20 | Echoes `> cmd` and `< {ok}` per line. Only the success path was observed.                                                                             |
| `tern --control EP`                                              | dev:4     | A real window that answers `ctl`. `ternbook window` uses it (`ternbook:src/ternbook/window.py:108-142`). Not run here.                                |

With no server, `ctl` prints plain text and exits 1:

```text
tern: /tmp/tern-probe/nope.sock: No such file or directory (os error 2) (is `tern serve` running?)
```

A clean `quit` removes the socket file (observed: the path was gone after `{"ok":true}`).

## 3. Scenario language

- **Grammar.** One command per line; `#` starts a comment; quoted strings are split the
  way a shell splits them (`ternbook:src/ternbook/shots.py:72-85`). Ternbook passes each
  raw line to `ctl` whole so quoting survives (`shots.py:55-63`), and `ctl_argument`
  escapes payloads for `ctl`'s own splitter (`ternbook:src/ternbook/session.py:72-76`).
- **Verbs.** `dev:75-77` names the harness verbs (size, wait, click, key, type, shot,
  record, swipe, drop, dialog, and others), documented in `crates/window/src/scenario.rs`,
  which is not in this checkout. Their semantics are therefore unverified beyond what
  `ctl` replies show. Observed through `ctl` or scenarios: `ready`, `run`, `expect`,
  `shot`, `key`, `focus`, `resize`, `prefs`, `freeze-anims`, `thaw`, `git open`,
  `git wait`, `files hide`, `close`.
- **Readiness.** `ready` waits for every visible pane's prompt (dev:91). `expect TEXT`
  waits in real time for a grid row (dev:99-100). `files wait` (dev:321), `file wait`
  (dev:347), and `screen wait` (dev:387) each settle one subsystem. A raw `wait N` is real
  milliseconds in Ternbook's live path (`shots.py:297-298`).
- **World domains** (line ranges from `tern help dev`; `account`, `cloud`, `carly`, and
  `plugins` spot-checked at 742, 764, 785, 805):

| Domain                                   | Lines            | Examples                                                        |
| ---------------------------------------- | ---------------- | --------------------------------------------------------------- |
| Readiness                                | 90-101           | `ready`, `git-read`, `link-read`, `run`, `expect`, `completing` |
| Panes, tabs, sessions                    | 102-132, 169-206 | `split`, `focus`, `tab`, `palette`, `session`, `move-pane`      |
| Style, fonts                             | 114-131, 162-178 | `font`, `theme`, `style`, `layout`, `decorations`               |
| Alerts, park, melt                       | 133-168          | `alert`, `inbox`, `peek`, `park`, `gpu-hang`                    |
| Remote hosts                             | 207-239          | `remote` link states, identity, setup, rtt                      |
| Preferences, phone                       | 240-259          | `prefs [page]`, `prefs search`, `phone`                         |
| Media, pip                               | 260-294          | `surface-play`, `feed`, `browser`, `pip`                        |
| Files, file blocks                       | 295-357          | `files`, `file open`, `file wait`                               |
| Git, screen, procs                       | 358-427          | `git open fixture`, `git select`, `screen click`                |
| SQLite, notebook, board, canvas, profile | 428-741          | block command families                                          |
| Account, update, cloud                   | 742-771          | `account`, `update`, `cloud` states                             |
| Carly, plugins                           | 772-811          | `carly tool <name> <args>`, `carly lua <code>`, `plugins run`   |

- **Corpus.** `scenarios/git/` has 19 files and 346 command lines. First words: `git` 132,
  `key` 92, `shot` 48, `close` 20, `focus` 19, `wait` 15, `files` 15, `type` 4, `run` 1.
  Nine files carry `# render: live`.
- **Example.** `scenarios/git/task-push.txt` is `# render: live`, then `git open fixture`,
  `git wait`, `focus left`, `close`, `files hide`, fourteen `key Tab` lines,
  `shot task-push-focused`, `key Space`, `wait 2500`, `git wait`, and
  `shot task-push-done`. Its sidecar crops the shots to the toolbar
  (`scenarios/git/task-push.shots.toml:3`):
  `crop = ['button\.gb-tb-branch$', { match = 'div\.gb-tb-root>div\.gb-grp$', nth = 1 }]`.
- **Setup.** `<name>.setup.sh` runs under `/bin/sh -eu` with a fixed git identity and no
  user git config (`shots.py:176-207`). `scenarios/git/states.setup.sh:5-17` builds a
  merge conflict, which the scenario then opens with `git open <dir>`.
- **Prelude.** Every screenshot scenario runs `ready` and then
  `run "PROMPT='%1~ %# ' && clear"`, so the prompt shows no user or host name
  (`shots.py:36-42`).

## 4. Determinism

Mechanisms, with sources:

1. Empty config and home, rebuilt per run (`ternbook:src/ternbook/session.py:50-69`).
   Headless `serve` ignores settings files, so settings changes there are ephemeral
   (`docs/decisions/isolated-defaults.md:12`).
2. Fixed shot root `/tmp/ternbook-shot`, mode 0700, refused if it is a symlink or another
   user's (`shots.py:34`, `:153-169`). Dialogs show the working directory, so the path
   must not vary.
3. Fixed size 1280x800 (`shots.py:32`).
4. Fixed git identity and date, including commits Tern makes (`session.py:39-47`).
5. Readiness barriers, not sleeps, where Tern exposes one (`dev:91-101`).
6. Byte-stable output: `place()` copies only when bytes differ (`shots.py:143-150`).
7. Both themes in one run; the live dark pass calls `appearance:dark` first
   (`shots.py:288-289`).
8. Live rendering for real-time work. Ternbook's README says `tern shot` runs "offscreen
   on its own clock", so a scenario that waits for git needs `# render: live`
   (`ternbook:README.md:51`; `shots.py:264-300`).

Observed on this Mac:

- Two `tern shot` runs of one scenario, both themes, gave identical SHA-256 digests for
  all eight files (PNG and layout JSON per shot per theme). This is repeatability on one
  machine only.
- Two shots in one scenario (before and after `key Tab`) gave identical layout JSONs apart
  from the shot name. The Tab did not move focus (section 7).
- Clock, from `ctl stats` in one session (`docNow` is the document clock; `now` is app
  time):

```text
A  now 1050.0  docNow 1050.0  frozen false  frames 127
B  now 2647.9  docNow 2647.9                       (about 1.6 s later)
   freeze-anims -> {"ok":true}
C  now 3199.3  docNow 2647.9  frozen true   frames 133
D  now 4811.4  docNow 2647.9  frozen true   frames 137   (+1.6 s)
   thaw -> {"ok":true}
E  now 5339.5  docNow 3176.0  frozen false  frames 139
```

While frozen, frames still render and `now` advances, but `docNow` holds still. After
`thaw`, `docNow` jumped to 3176.0 rather than resuming from 2647.9. The cause was not
investigated.

Not established: whether offscreen `tern shot` freezes `docNow`, since the clock cannot be
queried in that mode.

## 5. Control socket: replies and errors

**Envelope.** Ternbook parses the single JSON reply. If parsing fails, the stderr text
becomes the error; if `ok` is not truthy, `error` is raised
(`ternbook:src/ternbook/session.py:103-123`). A `ctl` call has a 30-second limit
(`session.py:33`), and the socket must appear within 20 seconds (`session.py:32`).

**Observed errors**, each sent to a live headless session:

```text
> expect text-that-never-shows-zz
< {"ok":false,"error":"timed out after 20s"}                 exit 1, after 20.04 s
> key NoSuchKey
< {"ok":false,"error":"unknown key `NoSuchKey` (Playwright names: Meta+k, Escape, ArrowLeft, F1, [, …)"}
> bogus-command
< {"ok":false,"error":"unknown command \"bogus-command\""}   exit 1
> dump zz-no-match
< {"ok":true,"header":{...},"elements":[]}                   exit 0
```

`expect` times out on Tern's side before Ternbook's 30-second limit, so a missing text is
reported by Tern. The `key` error names the accepted vocabulary. The empty `dump` is a
silent no-match.

**Reply shapes** (each has `ok`):

- `state`: `tabs`, `focused` (with id, label, cwd, git, running, busy), `panes`,
  `palette`, `sessions`, `theme_dark` (`titanium`), `theme_light` (`light`), `layout`
  (`tiles`), `tab_orientation`, `status_bar`, `pane_headers`, `density`, and more.
  Ternbook reads only `carly.last_tool` (`session.py:139-144`).
- `stats`: `now`, `docNow`, `frozen`, `frames`, `nodes`, `viewport` ([w, h, scale]),
  `pointer`, `cursor`, `animating` (`elements`, `caret`, `nextTimer`).
- `tree [SEL]`: nested `{tag, id|class, rect, children}`; the help says it lists "text,
  values and focus" for matches (`dev:36-37`).
- `dump [SEL]`: every element's path, box, and computed geometry (`dev:33-35`).
- `a11y`: nested `{id, role, name, bounds, actions, states, children}`.
- `shot`: `{"ok":true,"png","layout","elements":580,"size":[2560,1600]}`, in device
  pixels.
- Layout JSON: `scenario`, `shot`, `page`, `viewport` ({width, height,
  deviceScaleFactor}), `theme`, `htmlClass`, and `elements`. Each element has a CSS-like
  `path` (such as `div#carly.tn-carly`), `nth`, `rect`, `visible`, and computed style. The
  580 elements include hidden ones, with `visible` set to false.

**Logs.** `serve` writes its stdout transcript to `serve.log` in the session root
(`session.py:211-212`), and `wait_for_socket` includes that log's text when the process
exits (`session.py:158-160`). `STENCIL_LOG=debug` with `STENCIL_LOG_DIR` also writes
`tern-serve.log` to that directory and echoes debug lines to stderr. One short debug
session produced 227,380 lines.

## 6. Screenshot pipeline

1. **Render.** `shots` runs each scenario through `tern shot --theme both` in a fresh root
   (`shots.py:210-252`), or, for `# render: live`, through `serve` once per theme
   (`shots.py:264-300`).
2. **Pair.** `NAME.png` and `NAME-dark.png` pair by stem (`shots.py:129-140`). A scenario
   with no `shot` line is an error (`shots.py:333-334`).
3. **Label and crop.** `<name>.shots.toml` gives each shot labels and a crop
   (`labels.py:93-113`). A label is a regex over each element's `path`, with `nth` for
   repeats; the first visible match wins (`labels.py:142-160`). A crop is the union of
   matched elements, padded 12 CSS pixels and clamped to the viewport
   (`labels.py:185-196`). Labels are drawn on the whole window before cropping, so a label
   outside the crop is an error (`labels.py:20-25`).
4. **Place.** Files go to `docs/book/attachments/<chapter>/NAME-light.png` and
   `NAME-dark.png`, copied only when bytes differ (`shots.py:350-351`;
   `ternbook:docs/decisions/light-and-dark-screenshots.md`). The `--json` output lists
   each placed file with a `changed` flag (`cli.py:616-621`).
5. **Fail per shot.** A shot whose labels or crop match nothing keeps its old files; other
   shots in the scenario still place (`shots.py:343-349`).

Decision records give the reasons. Light and dark variants are embedded as consecutive
images with GitHub theme fragments (`ternbook:AGENTS.md:18`). Crops are used because a
full 2560x1600 window shrinks to about 0.7 of its text size in the book column, and a
524x1532 crop at 2x is 69 KB against 287 KB
(`docs/decisions/cropped-screenshots.md:10-16`). Pillow is the one exception to the
standard-library rule, for labels (`docs/decisions/labeled-screenshots.md:8-14`).

## 7. Semantic queries: labels, focus, reachability

**Labels** are regexes over CSS-like paths, not stable IDs. They are cheap, and they break
when a class is renamed. The error names the shot and the match count
(`labels.py:158-160`).

**Focus** is reported by `a11y` and by the focus flag in `tree`. In the probe, a lone
shell pane showed a `MultilineTextInput` labelled "Terminal input" as focused. `key Tab`
left focus there, and so did `focus next`, which had only that one pane to move among.

**Reachability** is `coverage`. For each `shot NAME`, a fresh headless session replays the
scenario to that shot (`coverage.py:850-870`). From the shot's focus, and from each
landmark key the chapter's reference TOML names, it presses Tab and Shift+Tab one at a
time until focus returns to where the walk began or stops moving. A terminal pane swallows
Tab, and the walk records where it stalled (`coverage.py:1-12`). The driver presses keys
with `ctl key` and reads focus with `ctl a11y` (`coverage.py:635-651`). Wherever a walk
lands on a list, grid, tab bar, or menu, arrow keys are pressed through it
(`coverage.py:818-846`). A radio group's arrows leave the group, so it is probed once,
after the walks, in a fresh session (`coverage.py:1-12`, `:888`).

- Each control keeps its shortest route and a level, best first: `shortcut`, `palette`,
  `landmark` (within `REACH = 3` presses), `bindable`, `tab_only`, `unreachable`
  (`coverage.py:89-93`).
- A control only a right click opens is `unreachable`, with reason "in a context menu only
  a right click opens" (`coverage.py:91`, `:208`).
- A walk that loops or stalls records why. The limits are `STALL = 3`, `MAX_TABS = 80`,
  and `MAX_ARROWS = 40` (`coverage.py:84-87`).

Recorded output: `data/tern/0.9.0/coverage/git.json` covers 28 screens, with levels
`tab_only` 328, `landmark` 171, `shortcut` 52, `unreachable` 40, `palette` 8, and no
`bindable` (Lattice survey's counts, checked against the file). On the `changes` screen, a
Tab walk recorded
`{"from":"start","keys":"Tab","presses":45,"stopped":"looped at Improve this message with AI"}`.

**Capture** is the other half of the record. `CAPTURE_LUA` reads `cx.actions:keys()`,
`cx.actions:list()`, and each setting's `describe` (`capture.py:22-37`). Pages are read
with the viewport at 1400x60000 so that every row is on screen (`capture.py:228-240`).
Each setting is tied to its row by perturbation: flip one setting, reopen the page, and
record the one row that changed (`capture.py:116-225`). The `flip` field records `row`
199, `flipped` 76, `no-alternate` 15, and `refused` 5 (`capture.py:182-185`). The menu bar
comes from `ctl menus` (`capture.py:258-262`).

## 8. Isolation

- The environment is built from scratch (`session.py:50-69`): `HOME` and `TMPDIR` under
  the session root, an empty `.zshrc`, `TERN_CONFIG_DIR`, and `TERN_DAEMON_SOCKET`, so
  each session has its own daemon. Isolated defaults observed: `titanium` dark, `light`
  light, layout `tiles`, no status bar.
- `ternbook window` runs a real, separate Tern with its own config, home, and daemon, in a
  profile at `$XDG_STATE_HOME/ternbook/window` (`ternbook:src/ternbook/window.py:41-45`).
  It is reset on each launch except for the closed beta's sign-in (`window.py:55-82`;
  `docs/decisions/isolated-window.md:10-12`).
- Headless cannot show native menus, first-run prompts, the Dock, or permission prompts
  (`docs/decisions/isolated-defaults.md:14`). Ternbook marks those facts as needing a real
  window.
- Guardrail: no `ctl` without `--control`, and nothing through `TERN_WINDOW_SOCKET`
  (`ternbook:AGENTS.md:8`).
- Socket access control is not documented. Peer-credential checks were not investigated.

## 9. Ternbook commands, JSON, and errors

| Command     | Does                                                                | Source           |
| ----------- | ------------------------------------------------------------------- | ---------------- |
| `doctor`    | Reads `tern --version` and the snapshot; exits 1 if Tern is missing | `cli.py:140-195` |
| `capture`   | Writes `data/tern/<version>/` from an isolated session              | `cli.py:198-240` |
| `coverage`  | Writes `data/tern/<version>/coverage/<chapter>.json`                | `cli.py:357-467` |
| `reference` | Generates chapter pages from the snapshot                           | `cli.py:470-544` |
| `shots`     | Renders, labels, crops, and places light and dark PNGs              | `cli.py:547-626` |
| `feedback`  | Lists feedback items and the pages citing them                      | `cli.py:292-340` |
| `window`    | Opens the isolated window and prints its socket                     | `cli.py:243-289` |

`--json` output: `shots` gives `placed` and `errors`; `coverage` gives `chapters` and
`errors`; `reference` gives `pages` and `errors` (`cli.py:453`, `:535`, `:623-625`). Each
error is `{"scenario","shot","error"}`, built by `_failure_records` (`cli.py:83-91`).

Errors keep going, are collected, and make the command exit 1 (`ternbook:README.md:55`).
One nuance matters for scripts: `_report_failures` also runs in `--json` mode, so a caller
gets JSON on stdout and a plain-text block on stderr, with exit 1 (`cli.py:94-105`,
`:626`). Read the exit code, not just the JSON. A scenario with no shots is an error
(`shots.py:333-334`), so an empty render cannot pass.

The loop has caught real problems. Tern 0.9 scrolled a diff when a hunk's buttons were
focused, so coverage saw three same-named buttons and called them unreachable. The
2026-10-16 entry in `docs/log.md` records the fix, which matches repeated controls by
where they moved (commit `49c36fc`).

## 10. Update loop, drift, and feedback

- Update loop (`ternbook:README.md:39-47`): `doctor`, `capture`, `coverage`, `reference`,
  `shots`, `git diff --stat`, then `feedback --stage filed` to find pages to recheck.
- Snapshots are per release and overwritten on re-capture, so `git diff` shows what moved
  (`src/ternbook/capture.py:1-6`). `data/tern/` holds 0.8.3, 0.8.4, and 0.9.0.
- Drift now: installed 0.9.4, newest snapshot 0.9.0. No capture for 0.9.4 was run here.
- Five feedback items exist under `docs/feedback/`. Each opens with a paste-ready
  Submission section (`ternbook:AGENTS.md:16`). One, `git-context-menus-keyboard`, records
  confirmation "in a real window", meaning the isolated-window path.

## 11. Open questions

From Lattice's list, updated:

1. Does offscreen `tern shot` freeze `docNow`? Open. Freezing was observed in serve mode
   only.
2. Shapes of `dump`, `tree`, `a11y`, `state`, and `stats`: resolved (section 5).
3. How do `key`, `click`, and the other harness verbs behave in shot and serve mode,
   beyond the `ctl` replies observed? Open; `crates/window/src/scenario.rs` is not in this
   checkout.
4. Does `TERN_WINDOW_SOCKET` exist? Open. It appears only in Ternbook's AGENTS file, not
   in help.
5. Is `ctl` authenticated beyond socket file permissions? Open.
6. `--help` for `shot` and `bundle` exits 2 (section 1). `serve --help` was not re-run. A
   candidate for `docs/feedback/`.
7. Does `serve` honor `STENCIL_LOG`? Resolved: yes (section 5).
8. Does `quit` remove the socket? Resolved: yes (section 2).

New: does `--file` stop at the first failed reply (only success was observed)? What
happens when two `serve` processes share a daemon socket (not tested)?

## Implications for Tessera devtools

[INFERENCE] The points below are design reasoning drawn from the observations above.
Tessera itself was not inspected for this section.

Worth carrying over:

- **Scenario as the unit of truth.** One text file, one command per line, shell quoting,
  and `#` comments. The same file can drive an offscreen render, a live session, and a
  replay. Ternbook keeps raw lines whole so that quoting survives the trip.
- **Two headless modes, one grammar.** A cheap offscreen renderer that exits, and a
  long-lived session with a control socket. Tern's split keeps common cases cheap and
  real-time cases live.
- **Replies as one JSON object with `ok`.** Failures should name the cause and the valid
  vocabulary, as Tern's unknown-key error does. Queries that match nothing should fail,
  not return an empty list.
- **Barriers over sleeps.** `ready`, `git wait`, and `expect` with a stated timeout. Keep
  raw waits for the rare case with no barrier, and label them as such.
- **Separate clocks.** Tern splits app time from document time and freezes only the
  second. A Tessera capture clock should freeze animation and timer time while leaving
  wall time alone, and it should define what happens on resume (Tern's `docNow` jump is
  the cautionary case).
- **Layout data beside every image.** Path, rect, visibility, and style per element make
  labels and crops data-driven. For Tessera, the equivalent is the view tree and cell
  grid. Phase 4's focus, scroll, and collections can then be checked as fields and rects:
  a focused node, or a clipped scroll region.
- **Copy only when bytes differ.** Fixed size, fixed root paths, and fixed identity for
  anything that writes into the scene (commits, dates, prompts).
- **Reachability as a walk.** Tab and Shift+Tab walks, arrows through containers, shortest
  route per control with a level, and a recorded stop reason on loops. Mark pointer-only
  controls as keyboard-unreachable instead of hiding them.
- **Per-version snapshots, diffed.** Keys, actions, settings, and pages per release,
  written with sorted keys, so `git diff` shows drift. Generated pages should say they are
  generated.
- **Isolation by construction.** A fresh config, home, daemon, and socket per run. A
  separate real window for what headless cannot show, with a note saying which facts only
  that window verifies.

Pitfalls seen here:

- **Focused terminal input swallows Tab.** In a lone shell pane, focus stayed put.
  Tessera's focus model needs an explicit escape, or reachability walks stall as
  Ternbook's did (`coverage.py:7-8`).
- **Silent no-match and plain-text failures.** An empty `dump` is `ok:true`, and a missing
  socket is plain text. A harness that reads only JSON misses both.
- **Two outputs for one failure.** `--json` still writes the error block to stderr and
  exits 1.
- **Debug logs are large.** One debug session wrote 227,380 lines. Default to warnings and
  let a flag raise the level.
- **Help that promises more than it prints.** `shot --help` and `bundle --help` exit 2,
  while the top-level help promises per-command help. Agents read help first, so it needs
  real text.
- **Regex labels drift.** A class rename breaks a label, and the error only says nothing
  matched. Stable IDs survive refactors but need discipline in the tree.
- **Snapshot lag.** The binary is 0.9.4 and the snapshot is 0.9.0. A loop run only on
  request drifts silently. Check the version on every run.
- **Determinism checked on one machine.** Identity held for two runs on one Mac. Fonts,
  GPU adapter, and scale were not varied. Pin them in tests and say which goldens depend
  on them.
- **Permissions cannot be isolated by environment.** Accessibility and screen-recording
  grants belong to the app bundle, so a real window is still needed for those checks.
