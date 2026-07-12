# ``PlatformIOError``

Errors reported while Tessera performs platform terminal I/O.

## Topics

### Windows console failures

- ``PlatformIOError/consoleModeFailed(operation:errorCode:)``
- ``PlatformIOError/consoleOperationFailed(operation:errorCode:)``
- ``PlatformIOError/unsupportedTerminalEnvironment``

### Input, terminal, and platform failures

- ``PlatformIOError/inputClosed``
- ``PlatformIOError/rawModeFailed(errno:)``
- ``PlatformIOError/terminalSizeUnavailable(errno:)``
- ``PlatformIOError/unsupportedPlatform``

### Output failures

- ``PlatformIOError/writeFailed(errno:)``
- ``PlatformIOError/writeInterrupted``
- ``PlatformIOError/writeWouldBlock``

## ``WindowsConsoleOperation``

A Windows console operation identified by ``PlatformIOError/consoleOperationFailed(operation:errorCode:)``.

### Screen, input, and output operations

- ``WindowsConsoleOperation/getConsoleScreenBufferInfo``
- ``WindowsConsoleOperation/peekConsoleInput``
- ``WindowsConsoleOperation/readConsoleInput``
- ``WindowsConsoleOperation/readFile``
- ``WindowsConsoleOperation/waitForSingleObject``
- ``WindowsConsoleOperation/writeFile``
- ``WindowsConsoleOperation/description``

## ``WindowsConsoleModeOperation``

A Windows console-mode operation identified by ``PlatformIOError/consoleModeFailed(operation:errorCode:)``.

### Reading and setting console modes

- ``WindowsConsoleModeOperation/getInputMode``
- ``WindowsConsoleModeOperation/getOutputMode``
- ``WindowsConsoleModeOperation/setInputMode``
- ``WindowsConsoleModeOperation/setOutputMode``
- ``WindowsConsoleModeOperation/description``
