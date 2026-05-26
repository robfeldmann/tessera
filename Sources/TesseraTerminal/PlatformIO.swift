/// Platform I/O
///
/// **Job:** Put the terminal into the right mode for a TUI app and put it back when done.
/// Handle the OS-level details so nothing above this layer touches POSIX or Win32 directly.
///
/// **Responsibilities:**
///
/// - **Raw mode toggling.** On POSIX: read current `termios`, save it, set ICANON/ECHO/ISIG/IEXTEN off,
///   set min-bytes/timeout, apply. On Windows: equivalent via `SetConsoleMode`.
/// - **Alternate screen entry/exit.** Emit/withdraw `?1049h` / `?1049l` (delegates to `ControlSequence`).
/// - **Signal handling.** Install handlers for `SIGINT`, `SIGTERM`, `SIGHUP`, `SIGQUIT`, `SIGWINCH`.
///   The first four trigger graceful teardown of all enabled modes. `SIGWINCH` produces a resize event.
/// - **`atexit` registration.** Belt-and-suspenders cleanup if the app exits via a path that didn't go through
///   Tessera's runtime.
/// - **File descriptor I/O.** A small async-sequence abstraction over stdin reads. Stdout writes go through
///   a buffered writer that flushes on explicit demand (the renderer batches updates).
/// - **Terminal size query.** `TIOCGWINSZ` on POSIX, `GetConsoleScreenBufferInfo` on Windows.
public actor PlatformIO {
  /// Creates a new POSIX terminal interface.
  public init() {}
}
