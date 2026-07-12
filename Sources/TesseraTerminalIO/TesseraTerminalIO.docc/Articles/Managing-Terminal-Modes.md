# Managing Terminal Modes

Treat terminal modes as a scoped resource. Entering raw input, the alternate screen, or an
input-reporting protocol changes state outside the process; leaving that state changed after an
application finishes is observable to the next program in the terminal.

``ModeLifecycle`` coordinates that ownership. Request modes with ``ModeLifecycle/enter(_:)``
and always pair it with ``ModeLifecycle/exit()``. `TesseraTerminal/TerminalSession` is the
higher-level owner for an application: its scoped entry point keeps terminal acquisition, use,
and restoration together. Most applications should use that session API rather than manage a
lifecycle directly.

```swift
import TesseraTerminalIO
import TesseraTerminalANSI

func withInputModes<Result: Sendable>(
  using lifecycle: ModeLifecycle,
  operation: () async throws -> Result
) async throws -> Result {
  try await lifecycle.enter([
    .rawMode,
    .altScreen,
    .bracketedPaste,
    .focusEvents,
    .mouseTracking(.buttonEvents),
    .kittyKeyboard,
  ])

  do {
    let result = try await operation()
    try await lifecycle.exit()
    return result
  } catch {
    try? await lifecycle.exit()
    throw error
  }
}
```

The example shows the pairing, not a public construction path: ``ModeLifecycle`` is created by
terminal-session infrastructure. For an application scope, use
`TesseraTerminal/TerminalSession/withApplicationTerminal(configuration:_:)` so that the
session owns setup and restoration alongside the application body.

## Choose the modes your application needs

``ModeLifecycle/Mode`` describes the terminal state Tessera can acquire:

- ``ModeLifecycle/Mode/rawMode`` enables raw input handling.
- ``ModeLifecycle/Mode/altScreen`` uses the alternate screen buffer.
- ``ModeLifecycle/Mode/cursorStyle(_:)`` applies a session-owned `CursorStyle`.
- ``ModeLifecycle/Mode/bracketedPaste`` requests bracketed-paste reports.
- ``ModeLifecycle/Mode/focusEvents`` requests focus reports.
- ``ModeLifecycle/Mode/mouseTracking(_:)`` requests `MouseTracking` reports.
- ``ModeLifecycle/Mode/kittyKeyboard`` requests the Kitty keyboard protocol.

`enter(_:)` acquires a request in a canonical order, and `exit()` releases modes in reverse
acquisition order. That symmetry matters when modes interact and when cleanup must restore the
terminal after an error. An attempt to enter a mode slot that is already occupied reports
``ModeLifecycleError/modesAlreadyActive(_:)``; unsupported requests report
``ModeLifecycleError/unsupportedModes(_:)``.

## Distinguish confirmed state from cleanup state

``ModeLifecycle/activeModes`` is the set the lifecycle currently believes active. It is the
normal success-state view after an enter operation completes.

``ModeLifecycle/modesPossiblyActive`` is more conservative. If I/O fails after a terminal
change may have been emitted but before the lifecycle can confirm it, the mode appears there.
It is not a claim that the terminal definitely changed; it is cleanup information. Call
``ModeLifecycle/exit()`` before discarding the lifecycle so it can attempt teardown for both
active and possibly-active state.

## Read Windows diagnostics as environment facts

On Windows, ``PlatformIOError/consoleModeFailed(operation:errorCode:)`` identifies a failed
input or output console-mode operation with its Windows error code. Tessera requires a
VT-capable Windows console: Windows Terminal, or Windows 10 version 1809 or newer, satisfies
that requirement. ``PlatformIOError/unsupportedTerminalEnvironment`` means the environment is
not a controllable console; PowerShell ISE, redirected input or output, Cygwin, and MSYS2
terminals are unsupported. A normal Windows Terminal or PowerShell console is supported.

``WindowsConsoleModeOperation`` names the mode operation involved, while
``WindowsConsoleOperation`` names other Windows console operations such as input, output, and
screen-buffer calls. Use these values and their error codes to report the factual failure; they
do not expose console handles.

## Topics

### Mode ownership

- ``ModeLifecycle``
- ``ModeLifecycle/Mode``
- ``ModeLifecycle/enter(_:)``
- ``ModeLifecycle/exit()``

### State and failures

- ``ModeLifecycle/activeModes``
- ``ModeLifecycle/modesPossiblyActive``
- ``ModeLifecycleError``
- ``PlatformIOError``
