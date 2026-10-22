---
type: spec
description: "Slice 3: mode lifecycle + real PlatformIO + signal handling"
---

# Slice 3: mode lifecycle + real PlatformIO + signal handling

This slice is where Tessera grows up. Phase 1's "main function turns alt screen on, hopes nothing goes wrong" grows into a real lifecycle manager that **guarantees** the terminal is restored no matter how the program exits — clean exit, thrown error, `Ctrl-C`, `SIGTERM`, `SIGHUP` from a disconnected ssh session, panic, anything. The promise is: _if Tessera ever touches the terminal, Tessera puts it back._

This is the load-bearing reliability commitment of the whole library. Get this wrong and every user has to know how to type `reset` in a broken terminal. Get it right and Tessera disappears.

## The three problems this slice solves

1. **Mode lifecycle.** Raw mode and alt screen aren't booleans you flip; they're nested state with strict ordering. Enter raw mode _then_ alt screen; exit alt screen _then_ raw mode. Doing it in the wrong order leaves the terminal subtly broken. We need a type that enforces this.

2. **Async I/O.** Phase 1's "blocking `read(2)` in a `Task`" is fine for a walking skeleton but doesn't compose with the rest of an async program. We need `bytes` as an `AsyncSequence<UInt8>` and `write(_:)` as an async function — both backed by non-blocking I/O with proper cancellation.

3. **Catastrophic-exit recovery.** Swift's `defer` runs on normal scope exit and thrown errors. It does _not_ run on signal-induced termination. `SIGINT`, `SIGTERM`, `SIGHUP`, `SIGQUIT` will kill the process with the terminal still in raw mode unless we install handlers.

Each problem has a tidy solution; the work is in getting them to compose.

## The `ModeLifecycle` type

> [!note] Ratatui References
>
> - Ratatui's `init` module (`ratatui/src/init.rs`) provides `try_init` (line 397) and `try_restore` (line 554) which encode the enter/exit ordering: `enable_raw_mode` → `EnterAlternateScreen` on enter, `disable_raw_mode` → `LeaveAlternateScreen` on exit.
> - The crossterm pieces underneath are the same mode primitives Tessera will encode or implement directly: raw mode delegates through `crossterm` `src/terminal.rs`, lines 122–130; alternate screen writes `CSI ? 1049 h/l` in `crossterm` `src/terminal.rs`, lines 218–262.
> - The `run` function (`ratatui/src/init.rs`, line 318) wraps a closure with setup and guaranteed cleanup — the closest Rust analogue to Tessera's `enter`/`exit` contract.
> - Unlike Tessera's all-or-nothing set semantics, Ratatui's `try_init` enables modes sequentially without rollback; a failure midway leaves the terminal partially modified. Tessera's `ModeLifecycle.enter` improves on this by rolling back on partial failure.

This is the user-facing entry point. The shape:

```swift
public actor ModeLifecycle {
    public enum Mode: Sendable {
        case rawMode
        case altScreen
        case mouseTracking                  // Phase 3
        case bracketedPaste                 // Phase 3
        case focusEvents                    // Phase 3
        case kittyKeyboard                  // Phase 3
    }

    public init(io: PlatformIO)

    public func enter(_ modes: Set<Mode>) async throws
    public func exit() async throws

    public var activeModes: Set<Mode> { get async }
}
```

A few load-bearing properties of this design:

- **Modes are entered as a set, all-or-nothing.** Either every requested mode is active or none are. If entering alt screen succeeds but enabling mouse tracking fails, the lifecycle rolls back the alt screen before throwing. This is critical — partial states are how terminals end up broken.

- **`enter` is idempotent-ish.** Calling `enter` twice with overlapping mode sets is an error, not a no-op. Tessera applications enter modes once at startup; if you find yourself wanting to call `enter` mid-run, something is wrong with your design. (The exception is Phase 3's `mouseTracking`, which you may legitimately toggle. We'll handle that when we get there.)

- **`exit` always works.** Even if state tracking gets confused, `exit` emits the disable sequence for every mode it _believes_ might be active _and_ the mode it _requested_ be active. Over-cleaning is fine; under-cleaning is what causes broken terminals. We bias hard toward over-cleaning.

- **It's an actor, not a struct.** Mode state is shared mutable state by definition (the terminal is the state). Wrapping it in an actor gets Swift 6's strict concurrency happy and serializes mode transitions, which is exactly the semantics you want.

## The teardown discipline (the spicy part)

> [!note] Ratatui References
>
> - Ratatui installs a panic hook via `set_panic_hook()` (`ratatui/src/init.rs`, line 566) that calls `restore()` before delegating to the previous hook. This covers panics but not signal-induced termination — Tessera's layered approach (defer + signal handlers + atexit) goes further.
> - The `Terminal` struct implements `Drop` (`ratatui-core/src/terminal.rs`, line 473) to restore cursor visibility on scope exit, analogous to Tessera's `defer` layer.
> - Ratatui's `restore()` (`ratatui/src/init.rs`, line 524) and `try_restore()` (line 554) perform the actual teardown (`disable_raw_mode` → `LeaveAlternateScreen`). Tessera's signal handler must replicate this logic using only signal-safe syscalls.

`defer` is not enough. Here's the layered approach:

**Layer 1: Swift `defer` for normal and thrown exits.**

```swift
let configuration = TerminalApplicationConfiguration.default
try await TerminalSession.withApplicationTerminal(configuration: configuration) { terminal in
    try await terminal.runApplicationBody()
}
```

Do not make unstructured cleanup the primary guarantee. A `defer { Task { ... } }` helper is acceptable only as a last-ditch internal fallback because the task can race process exit. The public API should be scoped: load application terminal configuration, enter the configured lifecycle modes, run the awaited body, then perform structured async cleanup before returning or rethrowing.

**Layer 2: signal handlers for SIGINT, SIGTERM, SIGHUP, SIGQUIT.**

The handler does the _bare minimum_ to restore the terminal, then re-raises the signal so the process dies with the right exit status. This means: write the mode-exit byte sequences directly to stdout using `write(2)`, then `signal(sig, SIG_DFL); raise(sig)`.

Critical constraint: **signal handlers run in a _very_ restricted context.** No Swift runtime, no `String` allocation, no async, no actor hops. Just `write(2)` of a pre-computed byte buffer of disable sequences. The bytes are computed at `lifecycle.enter` time and stored in a global atomic pointer; the handler reads the pointer and writes the bytes.

This is the only place in Tessera that touches a global. It's unavoidable — POSIX signal handlers are inherently global. Containing the ugliness to one file is the best you can do.

**Layer 3: `atexit` as a backstop.**

`atexit` is called on normal process exit _and_ on `exit()` calls but _not_ on signals. Used as belt-and-braces for the case where the program calls `Foundation.exit()` directly (bypassing `defer`). Same restricted-context constraints as signal handlers: just write pre-computed bytes.

**Layer 4: documented escape hatch.**

For users whose programs _do_ die without running our handlers (segfault, `kill -9`, power outage), Tessera documents the per-platform terminal-recovery incantation prominently. You can't catch every failure mode; you can make recovery a one-command operation. Tessera is a library, not a CLI, so it does **not** ship a `tessera-reset` executable — an executable has no coherent distribution path to either end users (who never know Tessera exists) or app developers (who already have the platform command), and `swift run`-ing a binary is worse than typing the command. Instead: on POSIX, `reset` (or `stty sane`); on Windows, which has no native equivalent, a PowerShell one-liner that emits RIS (`ESC c`), e.g. `[Console]::Write([char]27 + 'c')`.

## The real `PlatformIO`

> [!note] Ratatui References
>
> - The `Backend` trait (`ratatui-core/src/backend.rs`, line 157) defines the contract for terminal I/O: `draw`, `flush`, `size`, `window_size`, cursor ops. Tessera's `PlatformIO` combines this with input — Ratatui splits input into the crossterm event system.
> - `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160) wraps a `Write` and implements `Backend`. Its `flush` (line 358) delegates to `self.writer.flush()` — analogous to Tessera's explicit `flush()` after buffered writes.
> - `Backend::size()` (`ratatui-core/src/backend.rs`, line 315) and `Backend::window_size()` (line 322) map to `terminal::size()` in crossterm, ultimately `TIOCGWINSZ`. Tessera's `PlatformIO.size()` and `sizeChanges` stream serve the same purpose.
> - `WindowSize` (`ratatui-core/src/backend.rs`, line 139) carries both character dimensions (`columns_rows: Size`) and pixel dimensions (`pixels: Size`). Tessera's `TerminalSize` starts with just columns/rows.
> - Input events in Ratatui use `crossterm::event::poll()` and `event::read()` (see `examples/apps/demo/src/crossterm.rs`, lines 57, 62). Tessera replaces this with a non-blocking `AsyncStream<[UInt8]>` backed by `poll` + `read(2)`.

Phase 1's `PlatformIO` was intentionally thin. Slice 3 is where it gains the full terminal I/O API.

```swift
package actor PlatformIO {
    package init(handles: consuming PlatformHandles) throws

    // Output: package only. Public arbitrary writes make it possible to write
    // outside a render transaction. `write` buffers; `flush` performs the actual syscall.
    package func write(_ bytes: [UInt8])
    package func write(_ bytes: ArraySlice<UInt8>)
    package func flush() async throws

    // Input. Chunked rather than per-byte; an empty chunk is an input-idle
    // notification used internally for ESC-timeout handling.
    package nonisolated var bytes: AsyncStream<[UInt8]> { get }

    // Terminal queries
    package func size() async throws -> TerminalSize
    package nonisolated var sizeChanges: AsyncStream<TerminalSize> { get }

    // Mode primitives (called by ModeLifecycle/TerminalSession, not directly by users)
    package func enableRawMode() async throws
    package func disableRawMode() async throws
    package func savedTermios() async -> termios?  // POSIX only; for the signal handler
}

// `FileDescriptor` is swift-system's noncopyable wrapper.
package struct PlatformHandles: ~Copyable {
    package let stdin: FileDescriptor
    package let stdout: FileDescriptor
    // Windows console handles live behind equivalent noncopyable wrappers on Windows.
}
```

The public facade should be `TerminalSession`, not `PlatformIO`. `PlatformIO` is the owned low-level capability; `TerminalSession.draw { frame in ... }` is the operation users get. Public code must not be able to write arbitrary bytes to a live terminal, flush output, read raw file descriptors, or construct platform handles.

`TerminalSession` is the live-terminal capability users receive from the scoped application entry point:

```swift
public actor TerminalSession {
    public static func withApplicationTerminal<R>(
        configuration: TerminalApplicationConfiguration,
        _ body: (isolated TerminalSession) async throws -> sending R
    ) async throws -> sending R

    public func draw<R>(
        _ body: (borrowing Frame) throws -> sending R
    ) async throws -> sending R

    public func nextEvent() async throws -> InputEvent
}
```

`TerminalOutput` remains internal/package-level. It is the only owner allowed to flush bytes to stdout/stderr/Windows console; renderers and mode lifecycle code reach it through scoped package APIs, not public byte-writing APIs.

Design notes:

- **Writes are buffered, with explicit `flush`.** Each `write` appends to an internal buffer; `flush` issues the actual `write(2)` syscall(s). The renderer in slice 4 will compose a whole frame, then flush once — one syscall per frame is the target. Per-`encode(into:)` syscalls would be catastrophic for performance.

- **`bytes` is an `AsyncStream`, not an `AsyncSequence` protocol.** Concrete type, single owner, no generic gymnastics. Created in `init`, lives for the lifetime of the `PlatformIO`. The producer is a detached task doing non-blocking `read(2)` calls with `EAGAIN` handling and a self-pipe for cancellation.

- **`sizeChanges` is driven by SIGWINCH.** Same global-atomic + signal-handler trick as the teardown: handler sets a flag, a polling task in `PlatformIO` notices, queries the new size via `TIOCGWINSZ`, yields to the stream.

- **No Windows yet.** All of the above is POSIX-specific. Slice 3 is POSIX-only; Windows is a separate slice later in Phase 2. Conditional compilation guards the Windows-incompatible bits; on Windows, `PlatformIO.init()` throws `.unsupportedPlatform` for now.

## The non-blocking read loop

> [!note] Ratatui References
>
> - Ratatui delegates input to crossterm's event system: `crossterm::event::poll(timeout)` followed by `event::read()` (`examples/apps/demo/src/crossterm.rs`, lines 57, 62). Crossterm internally uses `poll`/`epoll`/`kqueue` depending on platform — Tessera re-implements this directly with POSIX `poll` for full control.
> - The crossterm event loop is synchronous and blocking within `poll`'s timeout. Tessera's `AsyncStream<[UInt8]>` approach is async-native, yielding byte chunks via an `AsyncStreamContinuation` from the input loop.
> - Crossterm's cancellation is implicit (the `poll` timeout bounds the block). Tessera uses an explicit self-pipe trick so cancellation returns immediately without waiting for the timeout.

This is the one place where the implementation details genuinely matter, because getting it wrong leads to either CPU-spinning or dropped keystrokes. The shape:

```swift
// Inside PlatformIO, a detached Task started in init():
private func inputLoop() async {
    let fd = STDIN_FILENO
    // Set O_NONBLOCK once at startup.

    var buffer = [UInt8](repeating: 0, count: 256)

    while !Task.isCancelled {
        // poll() on stdin + self-pipe-for-cancellation, with timeout
        let readable = await poll(fds: [stdin, cancelPipe], timeoutMs: 100)

        guard readable.contains(stdin) else { continue }

        let n = read(fd, &buffer, buffer.count)
        if n > 0 {
            for i in 0..<n {
                bytesContinuation.yield(buffer[i])
            }
        } else if n == -1 && errno == EAGAIN {
            continue  // shouldn't happen after poll, but defensive
        } else if n == 0 {
            // EOF; finish the stream
            bytesContinuation.finish()
            return
        }
        // Other errors: log and continue, or finish — TBD.
    }
}
```

Three details worth pinning down here:

1. **`poll` over `select`.** `poll` has saner FD-set semantics and is fine on macOS/Linux. `epoll`/`kqueue` would be lower-overhead but the difference is irrelevant for one or two FDs.
2. **A 100ms `poll` timeout.** Lets the loop check `Task.isCancelled` periodically without busy-waiting. 100ms is a totally arbitrary number; it just needs to be small enough that cancellation feels responsive and large enough that we're not waking up constantly. Tune later if profiling cares.
3. **The self-pipe for cancellation.** Standard POSIX trick: a pipe whose write end is touched when we want `poll` to return immediately. Otherwise cancellation has to wait for the timeout. Worth implementing properly.

## The `Cleanup` registration mechanism

> [!note] Ratatui References
>
> - Ratatui's `set_panic_hook()` (`ratatui/src/init.rs`, line 566) captures the cleanup logic in a closure via `std::panic::take_hook` / `set_hook`. Tessera's `CleanupRegistry` uses a global atomic pointer instead, because POSIX signal handlers cannot invoke Swift closures or the Swift runtime.
> - Ratatui's `restore()` (`ratatui/src/init.rs`, line 524) calls `try_restore()` (line 554) which runs `disable_raw_mode()` then `LeaveAlternateScreen`. Tessera's `performEmergencyCleanup` must replicate this with only `tcsetattr` + `write(2)` — no crossterm library calls, no allocation.
> - The `Terminal::drop` impl (`ratatui-core/src/terminal.rs`, line 473) restores cursor visibility as a best-effort cleanup. Tessera has no equivalent in its signal handler; cursor state is restored as part of the broader termios restoration.

To support layer 2 (signal handlers) and layer 3 (`atexit`), `ModeLifecycle` needs to publish the current "if we die right now, what bytes should we emit" to a global location. Sketch:

```swift
// Internal to TesseraTerminal.
internal enum CleanupRegistry {
    internal static let current = AtomicReference<CleanupState?>(nil)

    internal struct CleanupState {
        internal let teardownBytes: [UInt8]  // pre-encoded mode-exit sequences
        internal let savedTermios: termios   // for tcsetattr restoration
    }

    internal static func install(_ state: CleanupState)
    internal static func clear()
    internal static func performEmergencyCleanup()  // called from signal handler
}
```

`performEmergencyCleanup` is the signal-safe function: it reads the atomic pointer, calls `tcsetattr` to restore termios, calls `write(2)` with the teardown bytes. No allocation, no Swift runtime calls, no async. Just syscalls.

This is the single ugliest file in the library. It deserves a long doc comment explaining what's safe to do in a signal handler context and why.

## Definition of done for slice 3

1. `ModeLifecycle` actor with `enter`/`exit`/`activeModes` for `rawMode` and `altScreen`. (Other modes deferred to Phase 3.)
2. Real internal `PlatformIO` actor: buffered writes, `AsyncStream<[UInt8]>` input, `size()` query, `sizeChanges` stream, and noncopyable platform handles.
3. Signal handlers installed for SIGINT, SIGTERM, SIGHUP, SIGQUIT that restore the terminal and re-raise.
4. `atexit` backstop installed.
5. Documented per-platform terminal-recovery commands (POSIX `reset`/`stty sane`) — no shipped executable; Tessera is a library, not a CLI.
6. Public `TerminalSession.withApplicationTerminal(configuration:)` entry point that owns structured setup/teardown and exposes no arbitrary live-terminal write API.
7. The Phase 1 walking skeleton is rewritten to use `ModeLifecycle`, `TerminalSession`, and the real `PlatformIO`. Manually verifying: `Ctrl-C` mid-run leaves the terminal sane. Sending `SIGTERM` from another shell leaves the terminal sane. Closing the terminal tab while the program runs leaves... nothing, because the terminal is gone, but the process exits cleanly.
8. Tests:
   - Unit test for `ModeLifecycle`'s rollback: inject a `PlatformIO` that fails on the second mode-enable, assert that the first mode is rolled back.
   - Unit test for the buffered-write semantics: many writes, one flush, one underlying syscall (use a mock `PlatformIO` for this).
   - Snapshot test for `ModeLifecycle.enter([.rawMode, .altScreen])` followed by `exit()`: feed the emitted bytes into the `VirtualTerminal`, assert the terminal ends in the default state.
   - **No automated test for signal handling.** Spawning a subprocess and signalling it from a test is fragile across platforms; this corner gets manual verification. Document the manual test procedure in `CONTRIBUTING.md`.

## What's _not_ in this slice

For clarity, things that look like they belong here but don't:

- **Windows support.** Separate slice. POSIX-only for now.
- **The damage-tracking renderer.** That's slice 4. The renderer uses `PlatformIO.write` and `flush`; it doesn't change `PlatformIO` itself.
- **The full input parser.** Slice 5 reads from `bytes` and produces `InputEvent`s. Slice 3 just delivers raw `UInt8`s.
- **Width handling for CJK/emoji.** That's a buffer concern, slice 4 territory.
- **Mode toggling mid-run.** Slice 3 establishes the lifecycle; Phase 3's modes introduce the dynamic-toggle patterns when they're needed.

## Three things to flag

1. **The "ModeLifecycle is an actor" decision.** The actor is still the right default, but do not expose an API that requires users to invent unstructured cleanup. Prefer a scoped `TerminalSession.withApplicationTerminal(configuration:) { ... }` entry point. A class plus a lock would make some syntax easier while making ownership and teardown less explicit; it should not be the default design.

2. **The signal handler approach is genuinely subtle and easy to get wrong.** I'd plan to write that one file very carefully, with citations to async-signal-safe function lists in the doc comments, and have it reviewed by anyone you trust who knows POSIX well. It's the part of Tessera most likely to have a latent bug that bites someone six months from now.

3. **Documented terminal recovery is a small detail that punches above its weight for user trust.** When (not if) someone's terminal ends up in a weird state during early development, a prominently documented one-command fix turns a class of bad first impressions into a non-issue. On POSIX that command already exists (`reset`, `stty sane`); on Windows there is no native equivalent, so document the PowerShell RIS one-liner. A shipped `tessera-reset` executable was considered and rejected: Tessera is a library, not a CLI, so it has no distribution path to the people who would run it.
