# ``TesseraTerminal``

@Metadata {
    @PageImage(purpose: icon, source: "terminal-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "terminal-card", alt: "Module card.")
}

Tessera’s terminal producer substrate.

## Overview

`TesseraTerminal` is the public import surface for producing terminal output and
reacting to terminal input. It is a terminal substrate, not a view toolkit: applications
compose their own state and presentation, then use the substrate to describe and deliver
terminal work.

The substrate composes three layers. `TesseraTerminalANSI` expresses semantic terminal
operations; `TesseraTerminalBuffer` stores cell-oriented output; and
`TesseraTerminalRendering` turns changed cells into terminal output. ``TerminalSession``
owns the live-session lifecycle, scoped drawing, size changes, and semantic input events.
The APIs use Swift 6’s strict isolation model, with a session actor and a non-escaping,
borrowed ``/TesseraTerminalBuffer/Frame`` for each draw transaction.

`TesseraTerminalCore` supplies core geometry, `TesseraTerminalIO` supplies I/O, and
`TesseraTerminalInput` supplies semantic terminal input through the same interface.

## Topics

### Essentials

- ``TerminalSession``
- <doc:Building-on-the-Terminal-Substrate>
- <doc:Modern-Terminal-Protocols>
