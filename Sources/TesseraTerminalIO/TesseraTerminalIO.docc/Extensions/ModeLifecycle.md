# ``ModeLifecycle``

Coordinates acquisition and symmetric release of terminal modes for terminal-session
infrastructure.

## Topics

### Managing modes

- ``enter(_:)``
- ``exit()``

### Inspecting lifecycle state

- ``activeModes``
- ``modesPossiblyActive``

### Mode requests

- ``Mode``

## ``ModeLifecycle/Mode``

A terminal mode that the lifecycle can acquire.

### Input and screen modes

- ``ModeLifecycle/Mode/rawMode``
- ``ModeLifecycle/Mode/altScreen``
- ``ModeLifecycle/Mode/bracketedPaste``
- ``ModeLifecycle/Mode/focusEvents``
- ``ModeLifecycle/Mode/mouseTracking(_:)``
- ``ModeLifecycle/Mode/kittyKeyboard``

### Cursor styling

- ``ModeLifecycle/Mode/cursorStyle(_:)``

## ``ModeLifecycleError``

An error reported while entering requested lifecycle modes.

### Invalid mode requests

- ``ModeLifecycleError/modesAlreadyActive(_:)``
- ``ModeLifecycleError/unsupportedModes(_:)``
