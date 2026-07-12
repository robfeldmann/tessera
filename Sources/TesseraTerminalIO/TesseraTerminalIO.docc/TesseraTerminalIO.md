# ``TesseraTerminalIO``

@Metadata {
    @PageImage(purpose: icon, source: "io-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "io-card", alt: "Module card.")
}

Platform-specific terminal I/O, mode coordination, and diagnostics.

`TesseraTerminalIO` is the platform boundary that coordinates terminal state for a live
application session. ``ModeLifecycle`` acquires requested terminal modes and releases them
symmetrically; higher-level `TesseraTerminal/TerminalSession` owns the scoped application
access that creates, uses, and restores a live terminal.

Use the higher-level session API for an application. This module exposes the lifecycle and
diagnostic vocabulary that explains mode ownership and platform I/O failures; it does not
offer public raw-handle access or arbitrary live I/O.

## Topics

### Lifecycle modes

- ``ModeLifecycle``
- ``ModeLifecycle/Mode``
- ``ModeLifecycleError``
- <doc:Managing-Terminal-Modes>

### Errors

- ``PlatformIOError``

### Windows console diagnostics

- ``WindowsConsoleOperation``
- ``WindowsConsoleModeOperation``
