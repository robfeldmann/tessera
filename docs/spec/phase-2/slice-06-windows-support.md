---
type: spec
description: "Slice 6: Windows support for PlatformIO (SetConsoleMode, ReadConsoleInput, Windows signal equivalents)"
---

# Slice 6: Windows support for `PlatformIO` (SetConsoleMode, ReadConsoleInput, Windows signal equivalents)

Slice 6 is the last slice of Phase 2 and the one that makes "cross-platform" go from spec aspiration to demonstrable fact. The good news: because slices 2-5 were designed around bytes-in/bytes-out, the encoder, parser, buffer, and renderer don't care what OS they're running on. The Windows-specific work is confined to `PlatformIO` and the signal-equivalent layer. The bad news: Windows console programming is its own world with its own footguns, and "confined to one file" is still a meaningful amount of work.

## The strategic decision: VT mode everywhere

> [!note] Ratatui References
>
> - Ratatui's `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160) wraps a `Write` and delegates all terminal manipulation to crossterm, whose `Command` trait has an ANSI `write_ansi` path and a Windows-only `execute_winapi` fallback (`crossterm` `src/command.rs`, lines 12–27).
> - crossterm's Windows raw-mode implementation shows the flag-dance baseline: it clears `ENABLE_LINE_INPUT`, `ENABLE_ECHO_INPUT`, and `ENABLE_PROCESSED_INPUT` through console mode APIs (`crossterm` `src/terminal/sys/windows.rs`, lines 9–38). Tessera adds VT input/output flags on top of that and treats failure as unsupported.
> - The `ScrollUpInRegion` and `ScrollDownInRegion` commands (`ratatui-crossterm/src/lib.rs`, lines 737, 785) implement `execute_winapi` returning `Unsupported` — Ratatui explicitly does not support the legacy Windows console API for scrolling, reinforcing the VT-mode-only strategy.
> - `TermionBackend` (`ratatui-termion/src/lib.rs`, line 97) is POSIX-only and provides no Windows path — another signal that the ecosystem treats VT mode as the cross-platform baseline.
> - This aligns with Tessera's decision: require `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on Windows, don't maintain a legacy `INPUT_RECORD` / `WriteConsoleOutput` code path.

Modern Windows (10 build 1809+ and all of 11) supports ANSI escape sequences natively when you enable two console mode flags: `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on the output handle and `ENABLE_VIRTUAL_TERMINAL_INPUT` on the input handle. Once enabled, the terminal behaves much like a POSIX terminal: your encoder's bytes are interpreted correctly, and stdin delivers ANSI sequences for arrow keys, function keys, etc.

This is the load-bearing strategic call for Windows: **require VT mode, don't fall back to legacy console APIs.** The alternative — `INPUT_RECORD` events from `ReadConsoleInput`, `WriteConsoleOutput` for rendering, separate code paths for input parsing — would roughly double the size of `TesseraTerminal` and have you maintaining two different input parsers forever. The minimum-Windows-version cost (Windows 10 1809, October 2018) is acceptable; anyone running anything older is outside Tessera's target audience.

The practical consequence: **slices 2, 4, and 5 work on Windows unchanged.** No conditional code in the encoder, renderer, or parser. The whole Windows port lives in `PlatformIO` and the cleanup machinery.

## The three problems this slice solves

1. **Mode setup is different.** Windows has no `termios`; it has `GetConsoleMode` / `SetConsoleMode` with a set of bit flags. The flags-to-set and flags-to-clear differ from POSIX, and you do them on two separate handles (input and output).

2. **There are no signals.** Windows has `SetConsoleCtrlHandler`, which catches Ctrl-C / Ctrl-Break / window close / logoff / shutdown. The lifecycle is different: handlers run on a dedicated thread, not in the interrupted thread's context, and the process is given a short window to clean up before being killed.

3. **No `poll` or `select` on stdin.** Windows uses `WaitForSingleObject` (or `WaitForMultipleObjects`) on console handles. The async-input pattern from slice 3 needs to be rebuilt against this primitive. The shape is similar — wait with a timeout, read available bytes, yield — but the API is foreign.

## The Windows `PlatformIO`

> [!note] Ratatui References
>
> - The `Backend` trait (`ratatui-core/src/backend.rs`, line 157) defines the platform abstraction: `draw`, `clear`, `size`, `window_size`, `flush`, cursor manipulation. Tessera's `PlatformIO` mirrors this split — one trait/actor with platform-specific implementations behind `#if os(Windows)`.
> - `CrosstermBackend` (`ratatui-crossterm/src/lib.rs`, line 160, `Backend` impl at line 226) shows the pattern: wrap a writer, implement `Backend` methods by queuing crossterm commands. On Windows, crossterm's `Command::execute_winapi` is the fallback; with VT mode enabled, `write_ansi` is used instead.
> - `TermionBackend` (`ratatui-termion/src/lib.rs`, line 97, `Backend` impl at line 162) is Unix-only — its `size()` at line 259 uses `termion::terminal_size()` which maps to `TIOCGWINSZ`. The contrast with Windows' `GetConsoleScreenBufferInfo` is instructive.
> - `TestBackend` (`ratatui-core/src/backend/test.rs`, line 32) renders to an in-memory `Buffer` and provides `resize()` (line 138) and `assert_buffer_lines()` (line 199) — the model for Tessera's platform-independent encoder/parser tests.
> - `WindowSize` struct (`ratatui-core/src/backend.rs`, line 139) carries both character dimensions (`columns_rows: Size`) and pixel dimensions — Tessera's `TerminalSize` is the character-only equivalent.

The API stays identical to slice 3's POSIX version — including its visibility. `PlatformIO` remains `package`-level on Windows too; `TerminalSession` is still the only public facade, per the ownership thesis. The whole point of the abstraction is that callers (and the rest of the package) don't know which platform they're on:

```swift
package actor PlatformIO {
    package init(handles: consuming PlatformHandles) throws
    package func write(_ bytes: [UInt8])  // buffers; flush performs the syscall
    package func flush() async throws
    package nonisolated var bytes: AsyncStream<[UInt8]> { get }  // chunked; empty = idle
    package func size() async throws -> TerminalSize
    package nonisolated var sizeChanges: AsyncStream<TerminalSize> { get }
    package func enableRawMode() async throws
    package func disableRawMode() async throws
}
```

Inside, the file splits by platform:

```swift
#if os(Windows)
import WinSDK
// Windows implementation
#else
import Darwin  // or Glibc
// POSIX implementation
#endif
```

Two parallel implementations behind one public surface. The duplication is acceptable because each is small (~300 LOC) and the platform-specific concerns don't share much.

### Mode setup on Windows

The Windows equivalent of "raw mode + alt screen" is a flag dance on two handles:

```swift
// Input handle (GetStdHandle(STD_INPUT_HANDLE))
//   Disable: ENABLE_ECHO_INPUT, ENABLE_LINE_INPUT, ENABLE_PROCESSED_INPUT
//   Enable:  ENABLE_VIRTUAL_TERMINAL_INPUT, ENABLE_WINDOW_INPUT
//
// Output handle (GetStdHandle(STD_OUTPUT_HANDLE))
//   Enable:  ENABLE_VIRTUAL_TERMINAL_PROCESSING,
//            DISABLE_NEWLINE_AUTO_RETURN,
//            ENABLE_PROCESSED_OUTPUT
```

A few notes worth pinning down:

- **`ENABLE_WINDOW_INPUT` is how you get resize events on Windows.** With it set, the input stream yields `WINDOW_BUFFER_SIZE_EVENT` records when the console resizes. We translate those into `TerminalSize` and yield to `sizeChanges`.
- **`DISABLE_NEWLINE_AUTO_RETURN` matters more than it sounds.** Without it, Windows secretly turns `\n` at the right margin into `\r\n` and _suppresses scrolling_ in some cases — exactly the kind of subtle alteration that breaks a renderer designed against POSIX byte semantics.
- **Save the original flags before modifying.** Same teardown discipline as POSIX: `init` captures the pre-existing modes, `disableRawMode` restores them. Stored in the cleanup registry for emergency exit.
- **Alt screen still uses `\e[?1049h` / `\e[?1049l`**, because with `ENABLE_VIRTUAL_TERMINAL_PROCESSING` set, the Windows console interprets those sequences correctly. This is the payoff of the VT-mode strategy.

### The input read loop on Windows

The Windows equivalent of slice 3's `poll` loop:

```swift
private func inputLoop() async {
    let handle = GetStdHandle(STD_INPUT_HANDLE)
    var buffer = [UInt8](repeating: 0, count: 256)

    while !Task.isCancelled {
        let result = WaitForSingleObject(handle, 100)  // 100ms timeout

        switch result {
        case WAIT_OBJECT_0:
            // Data available — but it might be a non-character event
            // (window resize, focus, mouse) that we need to filter.
            // With ENABLE_VIRTUAL_TERMINAL_INPUT, key events arrive as
            // bytes via ReadFile, but resize events still arrive as
            // INPUT_RECORDs and need PeekConsoleInput / ReadConsoleInput.
            handleAvailableInput(handle, into: &buffer)

        case WAIT_TIMEOUT:
            continue  // loop, check cancellation

        default:
            break  // error
        }
    }
}
```

The wrinkle: even with `ENABLE_VIRTUAL_TERMINAL_INPUT`, **resize and focus events don't come through as escape sequences in the byte stream.** They arrive as `INPUT_RECORD`s that you have to drain via `ReadConsoleInput`. The handle is "signaled" when _any_ event is available, character or otherwise.

The standard pattern is:

1. `PeekConsoleInput` to see what events are queued.
2. For each event: if it's a key event, leave it for `ReadFile` to deliver as bytes. If it's a resize or focus event, consume it with `ReadConsoleInput` and yield to the appropriate stream.
3. Then call `ReadFile` to drain pending character bytes.

This is more contorted than POSIX. It works, it's well-documented, and Microsoft's own `conhost` source confirms this is the intended pattern — but it's the one part of slice 6 most likely to have subtle bugs.

**One owning loop drives both streams.** A consequence of the above that the `PlatformIO` sketch above hides: because byte input and `WINDOW_BUFFER_SIZE_EVENT` records share the single console input queue, the `bytes` and `sizeChanges` streams cannot each spin up their own loop over `STD_INPUT_HANDLE` — two loops would steal events from each other. On Windows the live device owns **one** input loop, created once, that fans out byte chunks to `bytes` and translated resize events to `sizeChanges`. This differs from POSIX, where `bytes` comes from the read loop and `sizeChanges` comes from an independent `SIGWINCH` registry, so the two never contend. Also only call `ReadFile` once `PeekConsoleInput` shows character bytes are queued, so a pending resize/focus record never blocks `ReadFile` on a keypress.

### Output writes on Windows

Comparatively easy. `WriteFile` on `STD_OUTPUT_HANDLE` with the byte buffer. With `ENABLE_VIRTUAL_TERMINAL_PROCESSING` set, the bytes are interpreted as ANSI sequences. Same buffered-write + `flush` pattern as POSIX.

One Windows-specific subtlety: `WriteFile` to a console can do partial writes in extremely large buffers. Loop until the whole buffer is consumed. POSIX has the same issue but it's rarely hit in practice; on Windows it's more common.

### Terminal size on Windows

`GetConsoleScreenBufferInfo` returns a struct with the window rect. The visible size is `srWindow.Right - srWindow.Left + 1` by `srWindow.Bottom - srWindow.Top + 1`. (Not `dwSize`, which is the scrollback buffer size — a classic confusion.)

For `sizeChanges`, the `WINDOW_BUFFER_SIZE_EVENT` from `ReadConsoleInput` includes the new size directly. No need to re-query.

## Signal-equivalent handling on Windows

> [!note] Ratatui References
>
> - The `init` module (`ratatui/src/init.rs`) installs a panic hook via `set_panic_hook()` (line 566) that calls `restore()` before re-invoking the original hook. This is the Ratatui equivalent of Tessera's cleanup registry: ensure terminal state is restored on any exit path.
> - `try_restore()` (`ratatui/src/init.rs`, lines 554–560) performs `disable_raw_mode()` then `LeaveAlternateScreen` — the teardown order. On Windows, Tessera's `tesseraCtrlHandler` does the analogous work: `SetConsoleMode` restore + teardown bytes via `WriteFile`.
> - `try_init()` (`ratatui/src/init.rs`, lines 397–404) shows the setup order: `set_panic_hook` → `enable_raw_mode` → `EnterAlternateScreen` → backend → `Terminal`. Tessera's `PlatformIO.init` follows the same discipline: register cleanup before modifying terminal state.
> - Windows `SetConsoleCtrlHandler` runs on a dedicated thread (not the interrupted thread), which is simpler than POSIX signal handlers where async-signal-safety constraints apply. Ratatui avoids this complexity entirely by delegating to crossterm's platform layer.

Windows has `SetConsoleCtrlHandler`, which lets you register a callback for these events:

- `CTRL_C_EVENT` — user pressed Ctrl-C (sort of equivalent to SIGINT)
- `CTRL_BREAK_EVENT` — user pressed Ctrl-Break (SIGQUIT-ish)
- `CTRL_CLOSE_EVENT` — user clicked the window close button (SIGHUP-ish)
- `CTRL_LOGOFF_EVENT` — user logging off (service processes only)
- `CTRL_SHUTDOWN_EVENT` — system shutting down (service processes only)

The handler is called on a dedicated thread spun up by the system, with the process given approximately **5 seconds** to return before being killed (the close event window is even tighter — about 5 seconds, but the OS UI may force the issue sooner).

The Tessera handler does the same minimal work as the POSIX signal handler: read the cleanup registry's saved console modes, restore them via `SetConsoleMode`, write the teardown bytes via `WriteFile`. Then return `FALSE` from the handler, which lets the default behavior proceed (terminating the process).

This handler lives in the `CTesseraTerminalPlatform` C shim, not in Swift, mirroring how the POSIX path already keeps its signal handler in C (`tessera_cleanup_*` in `cleanup.c`, registered via `CleanupRegistry.installHandlers()`). The shim branches internally on `#if defined(_WIN32)`; the die-now restore reads the stored console handles + saved modes and calls `SetConsoleMode` / `WriteFile` directly. (Earlier drafts sketched a Swift `tesseraCtrlHandler`; the C-shim placement is the chosen design because it stays consistent with the existing teardown architecture.)

```c
// In CTesseraTerminalPlatform (cleanup.c), alongside the POSIX signal handler.
static BOOL WINAPI tessera_cleanup_ctrl_handler(DWORD ctrl_type) {
  switch (ctrl_type) {
    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
      tessera_cleanup_perform();  // restore SetConsoleMode + WriteFile teardown bytes
      return FALSE;               // let the default handler proceed (process termination)
    default:
      return FALSE;
  }
}
```

Two design notes:

- **The handler runs in a separate thread, not in the main thread's context.** This is different from POSIX (where signal handlers interrupt the current thread) but actually _simpler_ — you don't need to worry about async-signal-safety in the same way, because you're not interrupting anything. You still need to be careful about touching shared state, but standard locks work; you're not banned from allocating, for example. This is a small but real ergonomic improvement.
- **Return `FALSE` so the default handler proceeds.** Returning `TRUE` would mark the event as handled and prevent termination, which sounds appealing but means Ctrl-C silently does nothing — usually not what users expect. Let the process die; our job was to clean up first.

### What about `atexit`?

Windows has `atexit`, and it works the same way. Use it as the layer-3 backstop, identical pattern to POSIX.

### What about catastrophic exit?

A `TerminateProcess` (analogous to `kill -9`) bypasses all handlers on Windows just like POSIX. The documented escape hatch still applies — but unlike POSIX, Windows has no native `reset`/`stty sane`, so document a PowerShell one-liner that emits RIS (`ESC c`), e.g. `[Console]::Write([char]27 + 'c')`, which works on any VT-capable Windows console.

## The cleanup registry, generalized

> [!note] Ratatui References
>
> - Ratatui's cleanup is orchestrated by `restore()` (`ratatui/src/init.rs`, lines 524–532) and `try_restore()` (lines 554–560), which call `disable_raw_mode()` followed by `LeaveAlternateScreen`. The panic hook (`set_panic_hook`, line 566) wraps `restore()` to cover the panic path.
> - Tessera's `CleanupRegistry` is the Swift analog: a single atomic reference holding `CleanupState` (platform-specific saved modes), with `performEmergencyCleanup` as the restore function. The `#if os(Windows)` conditional in `CleanupState` parallels how crossterm internally branches between `termios` restore on POSIX and `SetConsoleMode` restore on Windows.
> - The `DefaultTerminal` type alias (`ratatui/src/init.rs`, line 213) binds `Terminal<CrosstermBackend<Stdout>>` — a single concrete type that works on all platforms because crossterm handles the platform divergence internally. Tessera achieves the same with `PlatformIO`'s `#if os(Windows)` split.

Slice 3 introduced `CleanupRegistry` with a POSIX-shaped `CleanupState` holding `termios`. Slice 6 generalizes it:

```swift
internal struct CleanupState {
    let teardownBytes: [UInt8]

    #if os(Windows)
    let savedInputMode: DWORD
    let savedOutputMode: DWORD
    let inputHandle: HANDLE
    let outputHandle: HANDLE
    #else
    let savedTermios: termios
    let fd: Int32
    #endif
}
```

The `performEmergencyCleanup` function branches on platform internally. The rest of the registry — the atomic reference, install/clear API, the contract that it only writes pre-computed bytes — stays identical.

This is the one place in `TesseraTerminal` with non-trivial conditional code. Keeping it walled off in one file means the rest of the library stays platform-clean.

## A note on PowerShell, conhost, and Windows Terminal

Three contexts to know about:

- **Windows Terminal** (the modern app): excellent VT support, no quirks, the target environment.
- **`conhost.exe`** (the legacy console window): VT support with `ENABLE_VIRTUAL_TERMINAL_PROCESSING` on Windows 10 1809+, but with some minor SGR rendering quirks. Works fine for Tessera.
- **PowerShell ISE**: not a real console. Doesn't support raw mode, won't work. Detect via `GetConsoleMode` failing and throw a clear error: "Tessera requires a console terminal; PowerShell ISE is not supported. Use Windows Terminal or PowerShell in a normal console."

The detection-and-clear-error pattern is the right move for any unsupported environment (mintty in legacy mode, very old conhost, redirected stdin/stdout to a pipe). Tessera should fail fast and explain rather than silently misbehave.

## CI and the snapshot harness on Windows

Two things to set up:

1. **Windows in the GitHub Actions matrix** is finally not skipped. The `swift build` / `swift test` jobs run on `windows-latest`, and `TesseraTerminalTests` + `TesseraTests` execute normally. This validates the encoder, parser, buffer, renderer, and `PlatformIO` mode logic on Windows.

2. **Snapshot tests already run on macOS and Linux** via the direct libghostty-vt from-source build that Slice 1 shipped (the `CGhosttyVT` module plus the scripted zig build, cached in CI). Windows snapshot coverage waits until that build path is proven on Windows runners — attempt it in this slice; if the zig/libghostty-vt toolchain fights back, document the skip and move on. Cross-platform correctness for Windows in the meantime is inferred from the encoder/parser unit tests (which run identically on all platforms) plus macOS/Linux snapshot coverage.

The reasoning for accepting a temporary Windows gap: byte streams are platform-independent, so macOS/Linux snapshot tests prove the _encoding_ is right; the platform-specific code in `PlatformIO` is small, well-isolated, and verified by its own targeted tests on each platform.

## Testing strategy for slice 6

The asymmetry: most of `TesseraTerminal`'s tests are platform-independent and just need to _also_ run on Windows. The Windows-specific work has a smaller, more focused test set:

- **`PlatformIO` mode tests on Windows.** Verify `enableRawMode` sets the right flags and `disableRawMode` restores them. Use a mock console handle if possible; otherwise integration-test against the real console with careful save/restore.
- **Resize event translation test.** Inject a `WINDOW_BUFFER_SIZE_EVENT` (or, more realistically, structure the code so the event-translation function is unit-testable in isolation) and assert it yields a correct `TerminalSize`.
- **Ctrl handler installation test.** Verify `SetConsoleCtrlHandler` is called during `init` and removed on teardown. Behavior of the handler itself is manual-verification territory, like the POSIX signal handler.
- **The full Phase 1+2 walking skeleton on Windows.** Run it manually in Windows Terminal, in conhost, and in a PowerShell console. Verify: arrow keys work, q exits cleanly, Ctrl-C restores the terminal, resizing the window updates the layout. Same manual procedure documented in `CONTRIBUTING.md` as for POSIX.

Roughly 15-25 Windows-specific tests, plus the existing platform-independent tests now running on the Windows matrix entry.

## Definition of done for slice 6

1. `PlatformIO` has a complete Windows implementation behind `#if os(Windows)`, with the same public API as POSIX.
2. Console mode setup using `GetConsoleMode` / `SetConsoleMode` with the documented flag combinations on the input and output handles.
3. Async input loop using `WaitForSingleObject` + `ReadConsoleInput` + `ReadFile`, draining non-character events (resize, focus) and yielding character bytes through the same `AsyncStream<[UInt8]>`.
4. `WINDOW_BUFFER_SIZE_EVENT` translation into `sizeChanges` stream.
5. `SetConsoleCtrlHandler` installed for `CTRL_C_EVENT`, `CTRL_BREAK_EVENT`, `CTRL_CLOSE_EVENT`. Handler restores console modes and writes teardown bytes via the cleanup registry.
6. `CleanupRegistry` generalized to hold either POSIX or Windows state, with platform-specific `performEmergencyCleanup`.
7. `atexit` backstop installed on Windows (same pattern as POSIX).
8. Windows terminal-recovery command documented (PowerShell RIS one-liner) alongside the POSIX `reset`/`stty sane` docs — no shipped executable.
9. Fail-fast detection for unsupported environments (ISE, redirected I/O, very old Windows): `PlatformIO.init` throws a clear error explaining the requirement.
10. GitHub Actions matrix runs the test suite on `windows-latest`; snapshot tests skipped on Windows with an explicit comment.
11. Manual verification on Windows Terminal and conhost: walking skeleton works, Ctrl-C restores cleanly, resize works, exit is clean.
12. ~15-25 Windows-specific unit tests for the mode-setting and event-translation logic.

## What's not in this slice

- **Windows snapshot test coverage.** Tracked as a separate issue; depends on libghostty-vt Windows distribution or from-source build path.
- **Legacy console (`conhost` pre-1809) support.** Out of scope; we require modern Windows.
- **WSL-specific behavior.** WSL terminals are POSIX from Tessera's point of view — they run Linux Swift, talk to a Linux PTY. No special handling needed; works through the POSIX path.
- **Windows-specific ANSI quirks.** Some sequences behave subtly differently on conhost vs. Windows Terminal (e.g., certain OSC sequences). For Phase 2, we don't paper over these; if a user reports a specific issue, it gets a targeted workaround in Phase 5 polish.
- **`STD_ERROR_HANDLE` handling.** Tessera writes to stdout; stderr is the application's concern.
- **Cygwin / MSYS2 terminals.** They emulate POSIX badly and inconsistently; not supported. Users in those environments should use Windows Terminal directly.

## Three things to flag

1. **Requiring Windows 10 1809+ is a real but defensible cost.** It's been seven years; corporate environments may still have Windows 10 LTSC versions without it, but those users are already constrained in many other ways. A clearer-error-than-segfault on older Windows ("Tessera requires Windows 10 version 1809 or newer for VT support") is the right move. Worth documenting prominently.

2. **The `INPUT_RECORD` event filtering inside the read loop is the most subtle code in slice 6.** Specifically: when the input handle is signaled, you don't always want to call `ReadFile` — sometimes the only queued event is a non-character event, and `ReadFile` would block waiting for actual characters. The `PeekConsoleInput` + selective drain pattern handles this correctly but is easy to get subtly wrong. Worth writing carefully and commenting heavily; future-you will not remember why this loop is shaped the way it is.

3. **The "two parallel implementations behind one public API" structure** is the right call for slice 6 but it does increase the project's surface area meaningfully. From here forward, every change to `PlatformIO`'s public API needs to be implemented twice. The duplication is bounded (~300 LOC per side) and the platforms diverge fundamentally enough that _attempting_ to unify them would be worse — but worth being explicit that this is the project's cross-platform tax, paid in one specific place.

---

That's slice 6, and with it Phase 2 is complete. `TesseraTerminal` is now a publishable-as-alpha cross-platform terminal foundation: cell-accurate buffer, damage-tracking renderer, full legacy input parser, robust teardown discipline, and demonstrable parity across macOS, Linux, and Windows.
