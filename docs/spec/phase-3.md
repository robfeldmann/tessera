---
type: spec
description: "Phase 3: Modern terminal protocols"
---

# Phase 3: Modern terminal protocols

Phase 2 made `TesseraTerminal` a solid legacy terminal foundation: raw mode, alternate screen, cell-accurate rendering, cross-platform IO, and a parser for the input sequences that terminal apps have depended on for decades.

Phase 3 is where Tessera stops being merely compatible and becomes _modern-terminal native_. These protocols are not part of the original ANSI/VT baseline, but they are what real contemporary TUIs rely on for correctness and polish: pasted text should not look like a thousand typed keypresses, focus changes should be observable, mouse events should carry position and modifiers, keyboard input should be disambiguated, and rendered text should be able to expose hyperlinks.

The important framing: Phase 3 is still `TesseraTerminal`, not the view library. Nothing here introduces `View`, layout, widgets, or application architecture. Each slice extends the terminal substrate by adding one protocol to the encoder, parser, lifecycle, and test harness. The public API should grow only where the protocol creates genuinely new semantic events or rendering capabilities.

By the end of Phase 3, `TesseraTerminal` should be feature-complete enough that Phase 4 can build the view layer without stopping to redesign terminal IO.

The slice order is intentional:

1. Bracketed paste mode — smallest modern parser mode; establishes the Phase 3 pattern.
2. Focus events — another small opt-in mode; adds lifecycle symmetry and simple events.
3. SGR mouse tracking — larger event surface, but still independent of keyboard protocol.
4. Kitty keyboard protocol — largest parser/API change; do it after the smaller modes are proven.
5. OSC 8 hyperlinks — output-side rendering capability, best after input protocols settle.
6. Terminal capability detection — optional final slice, because it may reshape how the earlier protocols are enabled but should not block implementing them.
7. Kitty graphics protocol — output-side; reuses the encoder/parser patterns from earlier slices and adds the first protocol-native active probe (`a=q` followed by DA1) for large non-text output.

Terminal protocol modes are controlled by the session/runtime, not by direct widget mutation. Views and widgets may declare capabilities they require, but they do not directly enable, disable, or write terminal mode sequences. The runtime/session collects current requirements, checks them against application configuration, computes the effective mode set, and applies changes through `ModeLifecycle`.

Mode categories for Phase 3:

1. **Lifecycle/session modes.** Raw mode, alt screen, saved terminal state, and Windows VT flags are owned by `TerminalSession` and established for the session lifetime.
2. **Application protocol modes.** Bracketed paste, focus events, mouse tracking, and Kitty keyboard affect input semantics. They are controlled by application configuration and, where appropriate, declarative dynamic requirements. High-noise modes such as all-motion mouse tracking require explicit application permission.
3. **Frame/render-scoped terminal state.** Synchronized output, cursor placement, cursor visibility, style state, hyperlinks, raw payloads, graphics placements, and damage-tracking state are renderer-owned. Widgets may express desired cursor/style state or call `Frame.writeRaw`/`Frame.placeImage`, but they do not emit raw mode bytes directly. Kitty graphics image transmission (Slice 7) is a session-scoped side channel outside `ModeLifecycle`, not frame-scoped output — there is no enable sequence to track.

## Sections

- [Phase 3 ground truth: the implemented substrate](phase-3/ground-truth.md)
- [Dynamic mode changes (`ModeLifecycle.apply`)](phase-3/dynamic-mode-changes.md)
- [Slice 1: Bracketed paste mode](phase-3/slice-01-bracketed-paste-mode.md)
- [Slice 2: Focus events](phase-3/slice-02-focus-events.md)
- [Slice 3: SGR mouse tracking](phase-3/slice-03-sgr-mouse-tracking.md)
- [Slice 4: Kitty keyboard protocol](phase-3/slice-04-kitty-keyboard-protocol.md)
- [Slice 5: OSC 8 hyperlinks](phase-3/slice-05-osc-8-hyperlinks.md)
- [Slice 6: Terminal capability detection](phase-3/slice-06-terminal-capability-detection.md)
- [Slice 7: Kitty graphics protocol](phase-3/slice-07-kitty-graphics-protocol.md)
- [Slice 8: Color degradation baseline](phase-3/slice-08-color-degradation-baseline.md)
- [Slice 9: OSC 52 clipboard](phase-3/slice-09-osc-52-clipboard.md)
- [Slice 10: Cursor styling](phase-3/slice-10-cursor-styling.md)
- [Slice 11: Underline extensions](phase-3/slice-11-underline-extensions.md)
- [Slice 12: Runtime protocol control](phase-3/slice-12-runtime-protocol-control.md)
