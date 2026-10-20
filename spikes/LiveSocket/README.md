# Spike 4 — LiveSocket

Plan 033, Spike 4. A dev-owned run loop over `TerminalSession.withApplicationTerminal`
serves `text`, `tree`, `key`, and `quit` over a Unix-domain NDJSON socket, using public
Tessera API only plus a render mirror.

**Verdict: pass.** Injected input merges ahead of `nextEvent` with public API only, and
the screen is available without touching `TesseraTerminal`. The double render is real and
has sharp edges, so the live runner should add one small package seam (a draw tap, below).

## Hypothesis

A loop that owns the graph and merges real input with control requests into one event
stream can answer `text`/`tree`/`key`/`quit` from a second shell, with an injected key
taking the same `step` path as a typed one, and the spike can name the seam that removes
the double render.

## Layout

```text
Package.swift                        path dependency ../.. (identity follows the folder name)
Sources/LiveSocketKit/
  LiveRunner.swift                   the merged loop (pumps, step, mirror, replies)
  ControlServer.swift                actor: accept, one request per connection, reply routing
  DescriptorEvents.swift             dispatch read source as an AsyncStream (owns the fd)
  ControlClient.swift                blocking `ctl` client, exit codes
  ControlProtocol.swift              request decoding, key names, reply envelopes
  Projection.swift                   `text` rows and `tree` JSON
  CounterApp.swift                   the demo app (list of counters; Tab/arrows)
  POSIXSocket.swift, JSONValue.swift, CLI.swift
Sources/livesocket/main.swift        `livesocket run | ctl | vt-replay`
Tests/LiveSocketKitTests/            35 Swift Testing tests
Scripts/pty-demo.sh                  the end-to-end pty transcript below
```

## How to run

```sh
cd spikes/LiveSocket
swift build && swift test            # 35 tests, ~1.2 s after the first build
Scripts/pty-demo.sh                  # the transcript below, in a real pty via `script`
                                     # (needs jq, nc, python3, script; kills what it starts)

# by hand, two shells
TESSERA_DEBUG_SOCKET=/tmp/tessera-demo.sock swift run livesocket run   # or: run --socket PATH
printf '{"op":"text"}\n' | nc -U /tmp/tessera-demo.sock
swift run livesocket ctl --socket /tmp/tessera-demo.sock '{"op":"key","key":"Tab"}'
```

Protocol: one JSON request line, one JSON reply line, then the server closes. Replies are
`{"ok":true,…}` or `{"ok":false,"error":"…"}` (037 §5). `ctl` prints the reply and exits 0
(`ok:true`), 1 (`ok:false`), 2 (usage), 3 (socket missing, stale, or silent).

| op     | request                          | reply members                                                                                                                                 |
| ------ | -------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `text` | `{"op":"text"}`                  | `rows` (24 strings, trailing blanks trimmed), `text`, `size`, `frame`                                                                         |
| `tree` | `{"op":"tree"}`                  | `nodes` (`id type parent children frame clip measured proposal handlers needsLayout needsRender`), `statistics` (counts only), `requirements` |
| `key`  | `{"op":"key","key":"Shift+Tab"}` | `key`, `frame`, `redrawn`; sent after the step and draw complete                                                                              |
| `quit` | `{"op":"quit"}`                  | `{"ok":true}`; the socket file is unlinked before the reply                                                                                   |

Key names follow Playwright (`Enter`, `ArrowLeft`, `Meta+k`, `F5`, `+`); an unknown name
lists the accepted set.

## Evidence: real pty transcript

`Scripts/pty-demo.sh` runs the built binary under
`script -q /dev/null sh -c 'stty cols 80 rows 24; exec livesocket run --socket …'` (a real
pty; `swift run` in place of the binary behaves the same, checked separately at 100x30
with `TESSERA_DEBUG_SOCKET`). Typed keystrokes are appended to a file that `tail -f` pipes
into `script`'s stdin. The driver is a separate process using `nc -U` and
`livesocket ctl`. Output of the final run, blank screen rows squeezed:

```text
$ ls -l /tmp/livesocket-demo.sock
srw-------@ 1 rob  wheel  0 Oct 19 23:45 /tmp/livesocket-demo.sock

$ printf '{"op":"text"}\n' | nc -U /tmp/livesocket-demo.sock | jq -r .text
LiveSocket counter
Tab/Down next  Shift+Tab/Up prev  +/- change  q quit

> Alpha  0
  Beta  0
  Gamma  0
  你好 wide  0

selected Alpha  total 0  events 0  last key none

$ printf '{"op":"key","key":"Tab"}\n' | nc -U /tmp/livesocket-demo.sock
{"frame":2,"key":"Tab","ok":true,"redrawn":true}

$ printf '{"op":"text"}' | nc -U /tmp/livesocket-demo.sock | jq -r .text     # no trailing newline
…
  Alpha  0
> Beta  0
…
selected Beta  total 0  events 1  last key Tab

$ printf '\t' >> keys   # a REAL Tab typed into the pty
  Alpha  0
  Beta  0
> Gamma  0                      <- real Tab took the same path (events 2)

$ livesocket ctl ... Shift+Tab, then ArrowRight twice
{"frame":4,"key":"Shift+Tab","ok":true,"redrawn":true}
{"frame":6,"key":"ArrowRight","ok":true,"redrawn":true}
  Alpha  0
> Beta  2

$ livesocket ctl ... '{"op":"key","key":"Hyper"}'      # unknown key
{"error":"unknown key \"Hyper\" (names: ArrowDown, …, a single character; prefix with Shift+, Ctrl+, Alt+, Meta+ or Super+)","ok":false}
exit=1

$ livesocket ctl ... '{"op":"tree"}' | jq -c '.nodes[] | {id,frame}'      # list rows
{"id":"root/body/index(0)/index(3)","frame":{"column":0,"columns":10,"row":3,"rows":1}}
{"id":"root/body/index(0)/index(4)","frame":{"column":0,"columns":9,"row":4,"rows":1}}
…

$ latency: 100 sequential 'text' round trips through the ctl client (one process each)
real	0m0.814s                      <- ~8 ms per request including process spawn

$ a client that disconnects before reading its reply must not hurt the app (SIGPIPE)
{"ok":true,"frame":6}

$ parity: bytes the pty received, replayed through a fresh Ghostty VT, vs the text reply
IDENTICAL: socket text == pty-rendered text (24 rows)

$ livesocket ctl ... '{"op":"quit"}'; ls -l /tmp/livesocket-demo.sock
{"ok":true}
exit=0
ls: /tmp/livesocket-demo.sock: No such file or directory
script exited

$ livesocket ctl ... '{"op":"text"}'   # socket is gone
{"error":"no socket at /tmp/livesocket-demo.sock; start the app with TESSERA_DEBUG_SOCKET=/tmp/livesocket-demo.sock","ok":false}
exit=3

$ second run: quit with a REAL q keystroke
ls: /tmp/livesocket-demo.sock: No such file or directory
script exited

$ kill -9 leaves a stale socket; ctl says so (exit 3) and the next launch replaces it
srw-------@ 1 rob  wheel  0 Oct 19 23:45 /tmp/livesocket-demo.sock
{"error":"cannot connect to /tmp/livesocket-demo.sock: Connection refused (stale socket file?)","ok":false}
exit=3
{"ok":true,"frame":1}
{"ok":true}
```

The parity step is the strongest check on the mirror: `script`'s stdout (every byte the
app wrote to the pty) goes through `livesocket vt-replay`, a fresh Ghostty VT, and the
result equals the `text` reply row for row. `swift test` repeats that comparison
headlessly (`text returns the screen the terminal received`) against
`InMemoryTerminalSession` bytes.

## Proves / Does not prove

**Proves**

- A loop written against public API owns the graph, merges real and injected input, and
  serves read-only queries between steps. An injected key and a typed key reach the same
  `LoopContext.step` (`typed input and injected keys take the same step path`).
- `text` from a render mirror (`VirtualTerminal.snapshot(size:draw:)` over the same
  `ViewGraph`) equals what the terminal received, at 80x24 in a real pty and in-memory.
- The envelope, exit codes, `quit` removing the socket (before the reply), a missing
  socket (exit 3, JSON), a stale socket (exit 3 from `ctl`; replaced on the next launch),
  a hostile client disconnecting mid-reply, and a 40-connection burst all behave.
- The server needs no lock and no blocked thread (actor + dispatch read sources).

**Does not prove**

- Anything about `grid`, `shot`, `stats`, `type`, `mouse`, `resize`, or `tree [SEL]`
  locators; style fidelity (`.terminalStyledGrid`) through the mirror; kitty graphics.
- Focus or `graph.dispatch`: `ViewGraph.dispatch` is still a stub returning `.ignored`
  (the plan's gap 1), so keys reach the app only through the app-owned model.
- Windows, Linux, tmux or other multiplexers. The code has `#if canImport(Darwin)`
  branches for `SO_NOSIGPIPE`/`getpeereid` and Linux equivalents (`MSG_NOSIGNAL`,
  `SO_PEERCRED`); only the macOS branch was compiled and run.
- Resize delivered mid-session over the socket (no `resize` op; the in-memory device emits
  no `.resize`, which is Spike 5's `sizeChanges` seam).
- Performance with a real demo or large graph; numbers below are the counter app only.

## Findings for the plan

### The seam, named

1. **Input merge: no seam needed.** `TerminalSession.nextEvent()` is actor-isolated and
   cancellation-aware, so a `Task.detached` pump
   (`while true { sink.yield(.terminal(try await terminal.nextEvent())) }`) feeds the same
   `AsyncStream<Message>` the control requests use. The loop never awaits the terminal
   directly, so injected input is "merged ahead of `nextEvent`" by construction.
   (`terminal.events` is also public and nonisolated but uncoalesced and not
   backpressured; `nextEvent` keeps mouse-move coalescing.) Optional convenience seam for
   apps that call `nextEvent()` themselves:
   `package func inject(_ event: InputEvent) async` on `TerminalSession` calling the two
   `yield`s at `TerminalSession.swift:279-280`. The plan does not need it: queries have to
   run inside the loop's isolation anyway.
2. **Screen: add a draw tap.** With public API the only route to the screen is a second
   `graph.render(into:)` into `VirtualTerminal.snapshot(size:draw:)` on demand (3.5 ms per
   call at 80x24, debug build, VT allocation included). It matched the pty exactly, but:
   - it re-runs `ViewGraph.render`, which resets `renderedNodes`/`renderDuration`, records
     `.renderRequested`, and clears the dirty flags; a mirror between `update()` and the
     real draw makes the loop skip that draw (`MirrorTests`). Safe here only because a
     step runs `update` and `draw` back to back before any query is read;
   - `VirtualTerminal.snapshot(size:draw:)` discards `Frame.setCursorPosition`, so the
     cursor is lost (the spike omits `cursor` from `text`);
   - it renders with `Renderer.render(buffer)` defaults (truecolor, extended underlines,
     hyperlinks on), not the session's `effectiveColorCapability`, hyperlink, or underline
     policy, so `grid`/`shot` styles could differ from what the terminal received;
   - it needs a width oracle for wide glyphs: the Ghostty spacer cell is a plain blank in
     `RenderedCell` and `terminalCellWidth` is `package`. The spike skips the cell after a
     coarse CJK/emoji range test (`Projection.rows`) and renders `你好` correctly, but a
     real harness must use `terminalCellWidth`.

   **Exact seam:** in `TerminalSession.draw` (`TerminalSession.swift:593-650`), where
   `lastDrawnBuffer = buffer` is assigned after a successful flush (line 642), also keep
   the frame's cursor and a sequence number and expose them package-readable:

   ```swift
   package struct DrawnFrame: Sendable { var buffer: Buffer; var cursor: TerminalPosition?; var sequence: Int }
   package private(set) var lastDrawn: DrawnFrame?
   ```

   Roughly 8 lines, no hook, no Sendable closure: the loop reads
   `await terminal.lastDrawn` right after `draw` (or on a query) and feeds
   `Renderer.render(buffer)` to a persistent `VirtualTerminal.ghostty`. If byte-exact
   styles matter, also tee `bytes` before `io.write(bytes)` (`TerminalSession.swift:639`)
   through `package var outputTap: (@Sendable ([UInt8]) -> Void)?`; that mirrors color
   policy and kitty output as well. `lastDrawn` alone covers `text`, `tree`, and `shot`
   text/grid.

3. **Terminal size before the first draw.** `PlatformIO.size()` is package; there is no
   public `TerminalSession.size`. The Showcase draws first and reads `frame.size`; this
   spike does the same. A `package var size: TerminalSize { get async }` (or the Driver
   starting from an initial `.resize`) removes the placeholder-size first frame.

### API surprises (all public-API; none blocked the spike)

- **Path-dependency identity is the folder name.** `.product(name:package:)` needs
  `"devtools"` in this worktree and `"main"` in the main checkout; `"tessera"` fails with
  `unknown package 'tessera'`. `Package.swift` derives it from `#filePath`. Spikes 1–3 and
  the A.3 copy-migration should do the same (or the plan should state it).
- **`terminal.draw`'s closure is not `Sendable`.** It compiles only from inside the
  session actor's isolation. A local nested `async` func in the `isolated` body lost
  isolation (`#IsolatedConformances` warning, then a sending error). Keep loop state in a
  non-Sendable class whose methods take `terminal: isolated TerminalSession`
  (`LoopContext`). The plan's `Driver` should be shaped this way.
- **`ForEach` children share one frame inside a `VStack`.** `tree` showed four keyed rows
  all at `row 3`; only the last painted. The demo uses explicit rows. Not a spike issue,
  but it is the kind of bug `tree` finds immediately, and a point for Phase B's
  `siblings-disjoint` invariant (which the plan exempts only for `ZStack` and overlays).
- **`tree` types are unreadable for locators.** `viewType` is the full generic name
  (`TesseraCore.TupleView<Pack{TesseraLayout.VStack<…>}>`); identity components are
  `index(3)`, `id(Beta)`, `body`. The `type=Text` locator needs the projection to
  normalise to the unqualified, non-generic head and the plan should decide whether
  `body`/`TupleView` wrappers appear in the projection.
- **The input stream's second consumer.** `TerminalSession` yields every event to both
  `events` (unbounded `AsyncStream`) and the `nextEvent` buffer. Apps that use only
  `nextEvent()`, including the Showcase and this spike, never drain `events`, so it grows
  for the session's lifetime (small per event; pre-existing).
- **`InMemoryTerminalSession` input closes at once.** `nextEvent` then throws, so a
  long-lived headless loop needs `exitWhenInputCloses: false` (spike option) or a Spike 5
  input stream that stays open. A real pty closing stdin should exit (the default).
- **macOS `nc -U` half-closes** on stdin EOF, so a request without a trailing newline
  works (the plan's pass-criterion example) and, because the server closes after one
  reply, `nc` exits without `-N`.
- **macOS refuses, not queues, when the listen backlog is full**, and `ECONNREFUSED` is
  also how a stale socket looks. The backlog is `SOMAXCONN`; a burst of 20 connects with
  the earlier backlog of 8 was refused mid-burst once (not repeated since).
- **`sockaddr_un.sun_path` is 104 bytes on macOS (103 usable).** Worktree paths under
  `.build` can exceed it; the error names the limit (`a path longer than … reported`).
  `TESSERA_DEBUG_SOCKET` should default under `/tmp`, not `$TMPDIR` plus a long name.
- **`script` quirks for the plan's smoke scripts:** a fifo on stdin fails with
  `tcgetattr/ ioctl: Operation not supported on socket` (use `tail -f` on a file or a
  plain pipe); `script -q FILE` buffers the typescript, so capture `script`'s stdout
  instead; run it in the background, never in the foreground of a non-interactive tool
  shell (a foreground `timeout script` hung the shell; [INFERENCE] job-control stop on the
  tty).

### Recommended changes to the plan

- Phase F: say the runner merges `nextEvent()` with a control stream (public API) and that
  the only `TesseraTerminal` change is `lastDrawn` (plus optionally `size` and an
  `outputTap`), replacing "draw tap seam" with that exact shape. Add `size` to the gap
  list.
- Phase F: `quit` unlinks before replying; `ctl` exit 3 covers missing, stale, and silent
  sockets; one request per connection (server closes) so `nc -U` works without flags.
- Record that queries run between steps, so a mirror/`lastDrawn` read is always consistent
  with the last completed draw; never read the graph from another isolation domain.
- Spike 1/2/3 and Phase A.3: derive the package identity from the folder name.
- `tree` needs a short `type` and a decision on wrapper nodes before locators are built.

## Concurrency notes

Written under the repo's "prefer actors over locks" rule: no `Mutex`, `NSLock`, semaphore,
or serial-queue lock anywhere; no thread blocks on I/O.

- **One owner of the app.** `LiveRunner.loop` runs inside `isolated TerminalSession`.
  `LoopContext` holds the app, graph, frame counter, and drawn size, and is touched only
  from that body. Control requests are answered between steps (never during one), so
  `text`/`tree` always see a completed frame.
- **Two pumps, one stream.** `Task.detached` pumps forward `nextEvent()` results and
  `ControlServer.requests` into one `AsyncStream<Message>`. A pump failure becomes
  `.inputEnded`; the loop cancels both pumps on exit.
- **`ControlServer` is an actor.** It owns the accept task, per-connection tasks, the
  pending-reply table (`CheckedContinuation` per request id, so a double reply or a reply
  after the timeout is a no-op), and its own timeouts (5 s for the app, 10 s idle read, 5
  s write). The server never touches the app; it only yields `ControlRequest` values and
  the owner calls `reply(id, line)`.
- **No blocking I/O.** Descriptors are non-blocking. `DescriptorEvents` wraps a dispatch
  read source as `AsyncStream<Void>` (`bufferingNewest(1)`, drain until `EAGAIN`) and owns
  the descriptor: it is closed in the source's cancel handler, the one safe place. A write
  that hits `EAGAIN` backs off with `Task.sleep`.
- **Shutdown order.** `quit`: `stopListening()` (unlink, stop accepting) → `reply(ok)` →
  loop exits → `shutdown()` fails any unanswered requests (`app is shutting down`),
  cancels connections still waiting for a request, and awaits in-flight reply writes, so
  the process cannot exit before the `quit` reply is written.
- **The blocking client is only in `ctl`.** Tests call it through `DispatchQueue.global`;
  calling it from `Task.detached` starved the cooperative pool and deadlocked the server
  under test (40 parallel clients).
- Swift 6 language mode, no warnings in the spike target, no `@unchecked Sendable` in the
  spike (`DescriptorEvents` holds a `DispatchSourceRead`, which is `Sendable` in this
  SDK).

## Security notes

- **Opt-in.** No endpoint exists unless `--socket PATH` or `TESSERA_DEBUG_SOCKET` is set
  (`without a socket path the loop opens no endpoint…`). Release builds of a real app
  should compile the endpoint out or require the env var; nothing here is on by default.
- **File permissions.** The socket is created under `umask 077` and `chmod 0600`; a
  missing parent directory is created `0700`. An existing parent must be owned by the user
  with no group/other write, or sticky (`/tmp`); anything else is refused.
- **Peer check.** Every accepted connection is checked with `getpeereid` (`SO_PEERCRED` on
  Linux); other users are dropped silently, whatever the file mode.
- **No clobbering.** A path that exists is removed only if it is a socket owned by the
  user and a probe `connect` is refused (stale). A live socket, a regular file, or another
  user's socket makes startup fail with a message.
- **Bounds.** Requests over 1 MiB, more than 8 live connections, idle reads over 10 s, and
  replies stalled over 5 s are cut off; a client vanishing mid-reply cannot raise SIGPIPE
  (`SO_NOSIGPIPE`; `MSG_NOSIGNAL` on Linux).
- **Read/write surface.** `key` injects input as the user would; `tree`/`text` expose the
  screen. That is full control of the app for any process running as the same user, so the
  endpoint is a dev tool, never a production feature. Unlike oh-my-pi's debug server there
  is no `paste`/`mouse`/raw-bytes op yet; adding them widens this surface.
- **Residual risks.** `kill -9` leaves the socket file (handled on next start and by
  `ctl`'s exit 3). The `umask` swap around `bind` is process-wide for microseconds.
  Another process running as the same user can connect; there is no token.

## Numbers

| What                                      | Value                                                        |
| ----------------------------------------- | ------------------------------------------------------------ |
| Source lines (library + CLI)              | ~1,370 (`ControlServer` 327, `LiveRunner` 191, rest smaller) |
| Tests                                     | 35, all green three runs in a row, ~1.2 s                    |
| `ctl` round trip (process spawn included) | ~8 ms (100 requests in 0.81 s)                               |
| Mirror snapshot at 80x24 (debug)          | ~3.5 ms per call                                             |
| Replies at 80x24                          | `text` 517 bytes; `tree` 4,922 bytes (12 nodes)              |
