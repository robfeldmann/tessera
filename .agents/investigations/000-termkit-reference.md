---
name: TermKit Reference Lessons
date: 2026-06-04
status: resolved
---

# TermKit Reference Lessons

## Question

What can Tessera learn from the Swift TUI library checked out at
`~/Developer/migueldeicaza/TermKit/main`, section-by-section against
`docs/Spec.md`, and are there TermKit files worth keeping as reference material,
especially for the under-specified Phase 4 view layer?

## Findings

### High-level fit

- TermKit is most useful as a **Swift-native UI-layer reference**, not as a
  terminal-foundation reference. Its strongest pieces are `View`, layout,
  responder/focus, widgets, dialogs, and desktop/window composition.
- TermKit's terminal layer is useful as contrast but should not be copied
  directly. It mixes terminal mode ownership, driver I/O, parsing, buffering,
  and app lifecycle in `Application`/`UnixDriver`, which conflicts with
  Tessera's isolation rule that illegal terminal operations should be
  unrepresentable.
- TermKit's DocC architecture pages are good orientation material:
  - `Sources/TermKit/TermKit.docc/Architecture-Overview.md`
  - `Sources/TermKit/TermKit.docc/Architecture-Rendering.md`
  - `Sources/TermKit/TermKit.docc/Architecture-Drivers.md`
  - `Sources/TermKit/TermKit.docc/Architecture-ViewHierarchy.md`

### Phase 0: Foundation

Relevant TermKit files:

- `Package.swift`
- `.github/workflows/build.yml`
- `.github/workflows/docc.yml`
- `Tests/TermKitTests/*`

Lessons:

- TermKit has a normal SwiftPM package shape with DocC docs and examples. This
  supports Tessera's Phase 0 emphasis on proving package, test, CI, and docs
  loops early.
- The TermKit test suite is much thinner than Tessera's spec wants. Do not treat
  it as a model for terminal snapshot coverage.

### Phase 1: Walking skeleton

Relevant TermKit files:

- `Sources/TermKit/Drivers/ConsoleDriver.swift`
- `Sources/TermKit/Drivers/UnixDriver.swift`
- `Sources/TermKit/Core/Layer.swift`
- `Sources/TermKit/Core/Painter.swift`
- `Sources/TermKit/Core/Application.swift`
- `Sources/TermKit/Core/Events.swift`
- `Sources/TermKit/Core/WcWidth.swift`
- `Sources/TermKit/Views/Label.swift`

Lessons:

- `ConsoleDriver` is the closest TermKit analog to Ratatui's backend boundary:
  it exposes cursor movement, attributes, character output, refresh, size, and
  end/cleanup operations. It is useful as a checklist for minimum driver shape.
- `Layer` is a simple 2D cell buffer with row-major storage and dirty-row flags.
  It is a useful minimal Swift example, but Tessera's `Buffer` should remain
  lower-level and width-aware earlier than TermKit's layer abstraction.
- `Painter` is a strong Swift reference for a borrowed-ish drawing context:
  current position, current attribute, origin, clipping, text, primitives,
  clearing, and layer blitting. This maps well to Tessera's Phase 4 `Frame` API.
- TermKit's input parser in `UnixDriver` is intentionally simple, but it parses
  regular input byte-by-byte, so it is not a good model for Unicode-safe Phase 1+
  parsing.

### Phase 2 slice 1: Snapshot harness

Relevant TermKit files:

- `Sources/TermKit/Drivers/TTYDriver.swift`
- `Tests/TermKitTests/TermKitTests.swift`

Lessons:

- `TTYDriver` is a useful idea: a no-terminal/testing driver selected by
  `TERMKIT_DRIVER=tty`. Tessera's snapshot harness is more ambitious, but a
  plain capture backend can still be useful for unit tests that do not require a
  VT emulator.
- TermKit does not provide a Ghostty/libvterm-style terminal snapshot oracle.
  This reinforces Tessera's decision to build the snapshot harness first.

### Phase 2 slice 2: ANSI encoder

Relevant TermKit files:

- `Sources/TermKit/Drivers/TerminalCapability.swift`
- `Sources/TermKit/Drivers/XtermCapability.swift`
- `Sources/TermKit/Drivers/TerminfoParser.swift`
- `Sources/TermKit/Drivers/UnixDriver.swift`

Lessons:

- `TerminalCapability` is a catalog of semantic terminal sequences. It covers
  cursor movement, erasing, SGR, colors, alternate screen, cursor visibility,
  wrapping, mouse modes, and query sequences.
- Tessera should prefer its planned semantic `ControlSequence` enum over
  TermKit's string properties. The enum gives exhaustive switching, stricter
  tests, and avoids leaking raw escape strings.
- TermKit's RGB-to-256-color quantization in `UnixDriver` is worth referencing
  later for capability-aware color fallback, but Tessera's Phase 2 can continue
  emitting truecolor as specified.

### Phase 2 slice 3: Mode lifecycle + real PlatformIO + signals

Relevant TermKit files:

- `Sources/TermKit/Drivers/UnixDriver.swift`
- `Sources/TermKit/Drivers/WindowsDriver.swift`
- `Sources/TermKit/Core/Application.swift`

Lessons:

- `UnixDriver` demonstrates termios raw mode, alternate screen entry, mouse mode
  enablement, SIGWINCH handling via `DispatchSourceSignal`, suspend/resume, and
  teardown.
- The main negative lesson: these side effects happen inside driver init/end and
  are not represented by a cleanup registry or mode lifecycle object. Tessera
  should keep its stricter `ModeLifecycle`/`CleanupRegistry` design.
- TermKit's suspend/resume path is worth reviewing: it disables modes and restores
  termios before `SIGTSTP`, then reapplies raw mode and redraws on resume.

### Phase 2 slice 4: Width-aware buffer + damage renderer

Relevant TermKit files:

- `Sources/TermKit/Core/Layer.swift`
- `Sources/TermKit/Core/Painter.swift`
- `Sources/TermKit/Core/WcWidth.swift`
- `Sources/TermKit/Drivers/UnixDriver.swift`
- `Sources/TermKit/Core/Application.swift`

Lessons:

- TermKit has two layers of damage tracking: per-view `Layer.dirtyRows`, and
  `UnixDriver.modifiedRows`/`previousScreenBuffer` for optimized refresh.
- `Painter.add(rune:maxWidth:)` uses `termKitWcWidth`, advances by display width,
  clips to the visible rect, and stores `\u{0}` in the following cell for double
  width characters. This is relevant to Tessera's continuation-cell design.
- TermKit's physical refresh is row-granular, not cell-run diffing. Tessera should
  keep the Ratatui-style buffer diff plan for more precise damage emission.
- TermKit's layer composition is highly relevant to Phase 4 z-ordering, but its
  terminal renderer is less precise than Tessera's Phase 2 target.

### Phase 2 slice 5: Legacy input parser

Relevant TermKit files:

- `Sources/TermKit/Core/Events.swift`
- `Sources/TermKit/Drivers/UnixDriver.swift`

Lessons:

- `Events.swift` has a compact `Key`, `KeyEvent`, `MouseFlags`, and `MouseEvent`
  model worth comparing while naming Tessera input events.
- `UnixDriver.parseSpecialKey()` is useful only as a small catalog of common CSI
  and SS3 sequences for arrows, navigation, and F1-F10.
- Do not copy the parser architecture. It mutates a shared `Data` buffer, has
  simplistic ESC ambiguity handling, and treats non-ASCII characters as single
  bytes. Tessera's streaming state machine and `.unknown(bytes:)` policy remain
  better.

### Phase 2 slice 6: Windows support

Relevant TermKit files:

- `Sources/TermKit/Drivers/WindowsDriver.swift`
- `Sources/TermKit/Drivers/ConsoleDriver.swift`
- `Sources/TermKit/Core/Application.swift`

Lessons:

- TermKit has a driver selection model (`auto`, `curses`, `unix`, `tty`,
  `windows`) that is worth referencing for Tessera's platform abstraction and
  testing knobs.
- The spec's Windows plan is more detailed and should remain the source of truth:
  VT mode everywhere, cleanup generalization, and explicit Windows signal
  equivalents.

### Phase 3 slice 1: Bracketed paste

Relevant TermKit files:

- None found as direct implementation references.

Lessons:

- TermKit does not appear to implement bracketed paste mode or paste parsing.
  Tessera's planned declarative mode lifecycle and parser mode are still needed.

### Phase 3 slice 2: Focus events

Relevant TermKit files:

- `Sources/TermKit/Core/View.swift`
- `Sources/TermKit/Core/Application.swift`
- `Sources/TermKit/Core/Responder.swift`

Lessons:

- TermKit has application-level focus routing and a responder chain, but not
  terminal focus-reporting protocol support.
- Its `processHotKey` → focused `processKey` → `processColdKey` sequence is a
  useful UI routing pattern for Tessera Phase 4/5, independent of terminal focus
  events.

### Phase 3 slice 3: SGR mouse tracking

Relevant TermKit files:

- `Sources/TermKit/Drivers/UnixDriver.swift`
- `Sources/TermKit/Core/Application.swift`
- `Sources/TermKit/Core/Events.swift`
- `Sources/TermKit/Core/View.swift`

Lessons:

- TermKit enables SGR mouse and mouse motion tracking, decodes SGR mouse events,
  maps screen coordinates to the deepest view, supports mouse enter/leave,
  global/root mouse handlers, mouse grab, and continuous button-pressed behavior.
- These are strong Phase 4/5 references for routing mouse events through a view
  tree.
- Negative lesson: TermKit enables mouse modes eagerly in `UnixDriver` init.
  Tessera should keep mouse tracking as dynamic terminal requirements collected
  from views and applied by `ModeLifecycle`.

### Phase 3 slice 4: Kitty keyboard protocol

Relevant TermKit files:

- None found as direct implementation references.

Lessons:

- TermKit has legacy key events only. There is no apparent Kitty keyboard protocol
  support, protocol-level negotiation, or modern modifier-rich key representation.

### Phase 3 slice 5: OSC 8 hyperlinks

Relevant TermKit files:

- None found as direct implementation references.

Lessons:

- TermKit has no obvious OSC 8/hyperlink cell metadata path. Tessera's renderer
  state machine for hyperlink enter/exit and URI sanitization remains separate.

### Phase 3 slice 6: Terminal capability detection

Relevant TermKit files:

- `Sources/TermKit/Drivers/TerminalCapability.swift`
- `Sources/TermKit/Drivers/TerminfoParser.swift`
- `Sources/TermKit/Drivers/XtermCapability.swift`
- `Sources/TermKit/Drivers/UnixDriver.swift`

Lessons:

- TermKit's capability detection combines `COLORTERM`, terminfo color counts,
  and `TERM` fallback heuristics. This is useful evidence for Tessera's "hints,
  not truth" principle.
- `TerminfoParser` is a useful local Swift reference if Tessera later wants to
  parse terminfo without shelling out, but Tessera should avoid making startup
  fragile or blocking on active queries.

### Phase 4: View layer (`Tessera` module)

Relevant TermKit files:

- `Sources/TermKit/Core/View.swift`
- `Sources/TermKit/Core/Painter.swift`
- `Sources/TermKit/Core/Layer.swift`
- `Sources/TermKit/Core/Pos.swift`
- `Sources/TermKit/Core/Dim.swift`
- `Sources/TermKit/Core/EdgeInsets.swift`
- `Sources/TermKit/Core/BorderStyle.swift`
- `Sources/TermKit/Core/Responder.swift`
- `Sources/TermKit/Core/Toplevel.swift`
- `Sources/TermKit/Core/Window.swift`
- `Sources/TermKit/Core/StandardDesktop.swift`
- `Sources/TermKit/Views/Button.swift`
- `Sources/TermKit/Views/Label.swift`
- `Sources/TermKit/Views/ListView.swift`
- `Sources/TermKit/Views/ScrollView.swift`
- `Sources/TermKit/Views/TextField.swift`
- `Sources/TermKit/Views/TextView.swift`
- `Sources/TermKit/Views/SplitView.swift`
- `Sources/TermKit/Views/TabView.swift`
- `Sources/TermKit/Views/StatusBar.swift`
- `Sources/TermKit/Views/Menu.swift`
- `Sources/TermKit/Views/CommandPalette.swift`
- `Sources/TermKit/Dialogs/Dialog.swift`
- `Sources/TermKit/Dialogs/MessageBox.swift`
- `Sources/TermKit/Dialogs/InputBox.swift`
- `Sources/TermKit/Dialogs/FileDialog.swift`

Lessons:

- TermKit is strongest here. Its view tree, focus chain, responder model,
  invalidation, box model, layout primitives, painter, and widget set are all
  worth studying before specifying Phase 4.
- `View` provides a concrete UIKit/AppKit-shaped reference: subviews,
  superview, frame/bounds/content frame, margin/border/padding, color scheme,
  `setNeedsDisplay`, `setNeedsLayout`, focusability, and overridable drawing and
  event methods.
- `Painter` is the closest conceptual match to Tessera's borrowed `Frame`:
  scoped drawing, clipping, current style, primitive drawing, text output, and
  layer blitting. Tessera can adopt similar ergonomics while enforcing
  nonescaping borrowed frame capabilities.
- `Pos` and `Dim` are useful references for constraint-like terminal layout:
  absolute, percent, center, fill, anchor-end, and relative-to-view sizing.
  Tessera's stack-based layout can still learn from their ergonomics.
- TermKit's `EdgeInsets`, `BorderStyle`, `drawBox`, and content-frame model are
  directly relevant to Tessera's `Style.padding`, borders, alignment, and box
  views.
- TermKit's `ScrollView` TODOs are valuable warnings: clipping, dirty-region
  translation, and child render regions become tricky when content offsets are
  involved. Tessera should specify scroll clipping and invalidation carefully.
- `TextField` is a useful reference for cursor management, width-aware text
  storage, secret/password display, clipboard hooks, text-changed callbacks, and
  key handling.
- `StandardDesktop`, `Window`, and `Dialog` are good references for modal stacks,
  z-order, window management, and built-in desktop-style examples, even if
  Tessera starts smaller.
- Avoid copying TermKit's object-owned rendering directly. Tessera's spec wants
  views to render into a borrowed frame and declare terminal requirements, while
  runtime/session code owns mode application and render scheduling.

### Phase 5: Runtime + polish

Relevant TermKit files:

- `Sources/TermKit/Core/Application.swift`
- `Sources/TermKit/Core/Toplevel.swift`
- `Sources/TermKit/Core/StandardDesktop.swift`
- `Sources/Example/*.swift`
- `Sources/TermKit/TermKit.docc/*.md`

Lessons:

- TermKit's `Application` is a useful reference for a convenience runtime:
  toplevel stack, modal presentation, main-queue event delivery, focus routing,
  layout/display invalidation, 60 Hz-ish throttled refresh, terminal resize, and
  shutdown.
- The examples and DocC docs are useful models for Tessera's later tutorial and
  example-app phase.
- Tessera should keep tests more deterministic than TermKit's runtime style. The
  spec's explicit-event/explicit-render runtime test harness is still the better
  direction.

### Things TermKit does especially well

- **Swift-native TUI ergonomics:** `View`, `Painter`, `Pos`, `Dim`,
  `ColorScheme`, widgets, dialogs, and desktop examples make TermKit the most
  useful local reference for Tessera Phase 4.
- **Layer-backed composition:** each view draws to its own `Layer`, then the tree
  is composited for z-ordering. Tessera may not use the same storage model, but
  the composition story is worth studying.
- **Responder/focus routing:** hot keys, focused keys, cold keys, mouse enter/
  leave, mouse grab, and root mouse handlers are practical UI-runtime patterns.
- **Box model:** margin, border, padding, content frame, and `drawBox` give a
  concrete terminal adaptation of web/UIKit-style layout concepts.
- **Driver selection knobs:** environment/programmatic selection of curses, unix,
  tty, and windows drivers is a useful runtime/testing pattern.
- **DocC organization:** TermKit has focused architecture and control docs that
  can inspire Tessera's Phase 5 documentation structure.

### Things to avoid copying

- Terminal mode side effects are embedded in `UnixDriver` init/end rather than
  made explicit through an isolated lifecycle/cleanup capability.
- Input parsing is not robust enough for Tessera's goals: byte-wise Unicode,
  simplistic ESC ambiguity, no bracketed paste, no Kitty keyboard, and limited
  unknown-sequence preservation.
- Rendering updates are mostly row-granular; Tessera should keep its
  cell-diff/damage renderer plan.
- Terminal requirements are imperative side effects, not dynamic declarations
  collected from views.
- Application shutdown calls `exit`, which is not a good model for a reusable
  library/runtime with deterministic tests.

## Conclusion

TermKit should be added to the Phase 4 reference set. The files most worth
keeping open while specifying Tessera's view layer are `View.swift`,
`Painter.swift`, `Layer.swift`, `Pos.swift`, `Dim.swift`, `Responder.swift`,
`TextField.swift`, `ScrollView.swift`, `Window.swift`, `StandardDesktop.swift`,
and the DocC architecture pages.

For Phases 1-3, TermKit is mostly a contrast/reference checklist rather than a
blueprint. It validates many concepts in the spec, but Tessera's stricter
terminal ownership, semantic encoder, streaming parser, cleanup lifecycle,
snapshot harness, and modern protocol plans should remain intact.
