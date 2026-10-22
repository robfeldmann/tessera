---
type: spec
description: "Phase 2: Real terminal foundation"
---

# Phase 2: Real terminal foundation

Snapshot harness, ANSI encoder, damage-tracking renderer, mode lifecycle, signal handling, real PlatformIO with `AsyncStream`, Windows support, width handling, and the _legacy_ input parser (just escape sequences for arrow keys, function keys, basic stuff — no Kitty, no mouse, no paste yet).

## Sections

- [Slice 1: The snapshot harness](phase-2/slice-01-the-snapshot-harness.md)
- [Slice 2: ANSI Encoder](phase-2/slice-02-ansi-encoder.md)
- [Slice 3: mode lifecycle + real PlatformIO + signal handling](phase-2/slice-03-mode-lifecycle-and-platformio.md)
- [Slice 4: Width-aware `Buffer` + damage-tracking renderer](phase-2/slice-04-width-aware-buffer-and-renderer.md)
- [Slice 5: Legacy input parser (escape sequences, arrow keys, function keys, modifiers)](phase-2/slice-05-legacy-input-parser.md)
- [Slice 6: Windows support for `PlatformIO` (SetConsoleMode, ReadConsoleInput, Windows signal equivalents)](phase-2/slice-06-windows-support.md)
- [End of Phase 2](phase-2/end-of-phase-2.md)
