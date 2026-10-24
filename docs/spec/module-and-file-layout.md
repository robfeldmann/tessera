---
type: spec
description: "Proposed module and file layout"
---

# Proposed module and file layout

This is a proposed landing shape for the package as the spec is implemented. It is not a promise that every file must exist on day one, and it should not prevent small files from being merged or split when the implementation reveals a better seam. Its purpose is to make ownership and dependency direction obvious before code starts accumulating.

The package should use multiple SwiftPM targets, not just folders inside two large modules. That keeps builds focused, lets tests run against individual layers, and lets SwiftPM itself enforce architectural boundaries. The public user experience should still be simple: most users import `TesseraTerminal` or `Tessera`, while the package internally keeps ANSI, buffer, input, rendering, IO, layout, widgets, and runtime separate.

Two rules matter more than the exact filenames:

1. `TesseraTerminal`-level targets must not depend on `Tessera`-level targets. The terminal substrate is the lower layer.
2. Platform-specific code should stay behind narrow targets/files and public abstractions. Most of the encoder, parser, buffer, renderer, and tests should be platform-independent.

Recommended product/target shape:

```text
Products:
  Tessera                  // public view/runtime product
  TesseraTerminal          // public terminal-foundation product
  TesseraTestSupport       // public view-layer test and snapshot support
  TesseraHarness           // public harness: registry, scenarios, CLI; for test and dev targets

Targets:
  Tessera                  // re-export target for the view/runtime product
  TesseraCore              // view protocol, graph, environment, focus (Phase 4 slices 1, 4)
  TesseraLayout            // Layout protocol, stacks, flex, grid, decoration (slices 2, 3, 5, 6)
  TesseraWidgets           // ScrollView/SplitView (slice 2), controls (slice 4), List/TextInput (slice 7)
  TesseraTestSupport       // graph/layout/widget snapshots; re-exports terminal test support
  TesseraRuntime           // Application contract (Phase 4); optional @MainActor convenience loop (Phase 5)
  TesseraHarness           // drives an app headlessly and live: registry, viewports, scenarios, CLI entry point

  TesseraTerminal          // re-export target for the terminal product
  TesseraTerminalANSI
  TesseraTerminalBuffer
  TesseraTerminalCore
  TesseraTerminalIO
  TesseraTerminalInput
  TesseraTerminalRendering
  TesseraTerminalSnapshotSupport
  TesseraTerminalTestSupport
```

The `TesseraTerminal` targets are relatively concrete because Phases 1–3 define their responsibilities in detail. `TesseraTerminalTestSupport` owns terminal-specific fixtures, in-memory sessions, virtual-terminal snapshot helpers, and renderer diagnostics without making live-terminal escape hatches public. `TesseraTestSupport` is the elevated testing surface for view graphs, layouts, and widgets. It depends on `TesseraCore`, re-exports `TesseraTerminalTestSupport`, and owns stable high-level snapshot strategies rather than placing them in individual test files. The production `Tessera` targets follow the Phase 4 slice plan: `TesseraCore` for the view protocol, graph, environment, and responder system; `TesseraLayout` for the layout protocol, containers, and decoration; `TesseraWidgets` for the standard widget set; and `TesseraRuntime` for the app contract (`Application`, created in Phase 4 and re-exported by `Tessera`) and, in Phase 5, the optional convenience loop. `TesseraHarness` drives an app headlessly and live for tests and dev executables; app authors import it from those targets, never from production code, and it does not re-export `TesseraRuntime`. The isolation rules for the contract, the runtime, and the harness are the [Runtime isolation](phase-5-runtime-and-polish.md#runtime-isolation) section of Phase 5.

Swift SPI may be used sparingly when SwiftPM visibility is not expressive enough:

```swift
@_spi(TestSupport) public func rendererDiagnostics() -> RendererDiagnostics
```

SPI is an explicit opt-in for diagnostics, test hooks, and narrow cross-target seams. It must not become a production-facing way to bypass terminal ownership, leak raw handles, or write arbitrary bytes to a live terminal.

The `TesseraTerminal` and `Tessera` targets are intentionally thin public import surfaces. They should contain little more than re-exports:

```swift
@_exported import TesseraTerminalCore
@_exported import TesseraTerminalANSI
@_exported import TesseraTerminalBuffer
@_exported import TesseraTerminalRendering
@_exported import TesseraTerminalInput
@_exported import TesseraTerminalIO
```

Likewise, `Tessera` re-exports the view-layer targets and `TesseraTerminal` so app authors can usually write:

```swift
import Tessera
```

instead of importing a long list of implementation modules. Internal implementation code can still import the narrower target it actually needs.

Proposed source layout:

```text
Sources/
  TesseraTerminalCore/
    TerminalGeometry.swift        // TerminalSize, TerminalPosition, Rect-like helpers
    PackageInternals.swift        // shared package-level helpers, if needed

  TesseraTerminalANSI/          // Phase 2 encoder; Phase 3 protocol toggles
    ANSIEncoder.swift
    ControlSequence.swift
    EraseMode.swift
    Color.swift
    RawTerminalPayload.swift
    TextAttributes.swift

  TesseraTerminalBuffer/        // Phase 2 buffer/style; Phase 3 hyperlinks
    Buffer.swift
    Cell.swift
    CellDiffPolicy.swift
    CellWidth.swift
    Style.swift
    Hyperlink.swift

  TesseraTerminalRendering/     // Phase 2 damage renderer; Phase 3 OSC 8 output
    Renderer.swift
    Damage.swift
    RenderFrame.swift
    StyleDiff.swift

  TesseraTerminalInput/         // Phase 2 legacy input; Phase 3 modern protocols
    InputEvent.swift
    InputParser.swift
    Key.swift
    KeyCode.swift
    Modifiers.swift
    MouseEvent.swift
    TerminalCapabilities.swift

  TesseraTerminalIO/            // Phase 2 platform/lifecycle; Phase 3 mode cleanup
    PlatformIO.swift
    PlatformIO+POSIX.swift
    PlatformIO+Windows.swift
    ModeLifecycle.swift
    CleanupRegistry.swift
    SignalHandling+POSIX.swift
    SignalHandling+Windows.swift

  TesseraTerminalSnapshotSupport/ // Phase 1+ test harness support
    VirtualTerminal.swift
    SnapshotRenderer.swift
    SnapshotFixtures.swift

  TesseraTerminalTestSupport/
    TesseraTerminalTestSupport.swift
    InMemoryTerminalSession.swift
    BufferSnapshotting.swift
    VirtualTerminalSnapshotting.swift

  TesseraTestSupport/
    TesseraTestSupport.swift       // re-exports terminal test support
    GraphDiagnosticsSnapshotting.swift

  TesseraTerminal/
    TesseraTerminal.swift         // @_exported imports only

  Tessera/
    Tessera.swift                 // @_exported imports only

  TesseraRuntime/
    Application.swift             // the app contract (Phase 4)
    Step.swift                    // the canonical step, package-visible; hosts call it (Phase 4)
    ApplicationRuntime.swift      // optional @MainActor convenience loop (Phase 5)

  TesseraHarness/
    ApplicationRegistry.swift     // registry and Viewport (public)
    Driver.swift                  // main-actor shell over the step; headless and live hosts (package)
    Scenarios/                    // parser, runner, report, CLI entry point

  TesseraCore/                  // declarative view values and explicit graph runtime
    Views/
      View.swift                  // View protocol and Never primitive body
      ViewBuilder.swift           // result builder
      EmptyView.swift
      TupleView.swift
      ConditionalView.swift
      OptionalView.swift
      AnyView.swift               // AnyView and its identity barrier
      EquatableView.swift         // EquatableView and .equatable()
      IdentifiedView.swift        // .id() and its structural wrapper
      StructuralView.swift        // structural slots and child lowering
      ForEach.swift
      LeafView.swift              // third-party primitive seam
      ProposedSize.swift
      Binding.swift
      Text.swift
    Environment/
      EnvironmentKey.swift
      EnvironmentValues.swift
      EnvironmentModifier.swift
      EnvironmentReader.swift
    Runtime/
      ViewGraph.swift              // update/layout/render passes, dispatch, dump
      RuntimeNode.swift            // node storage, NodeState, and dirty flags
      NodeIdentity.swift
      TerminalRequirements.swift   // declarative requirements aggregation
    Diagnostics/
      GraphStatistics.swift
      NodeDiagnostics.swift
      GraphDiagnostics.swift
    Input/
      EventDisposition.swift
      ResponderContext.swift
      Focus.swift                  // FocusID, FocusManager, focusable/focused
      Responder.swift              // onKey and responder routing
      HitTesting.swift             // pointer handlers and hit-test policy
    Rendering/
      RenderRegion.swift

  TesseraLayout/                // Phase 4 slices 2, 2.5, 3, 5, 6
    Layout.swift                  // Layout protocol, Subviews, LayoutValueKey
    Stacks.swift                  // HStack, VStack, ZStack, Spacer, alignment
    FrameModifiers.swift          // frame, padding, layoutPriority
    Styling.swift                 // foreground/bold/style modifiers, defaultStyle key
    Decoration.swift              // border, overlay, background, Divider, Box
    Flex.swift                    // Phase 2.5 FlexConstraint, Flex, .flex
    Grid.swift                    // Slice 6 Grid, GridRow

  TesseraWidgets/               // Phase 4 slices 2, 2.5, 4, and 7
    ScrollView.swift
    SplitView.swift
    Controls.swift
    TextInput.swift
    List.swift
```

Within a target, source directories group durable responsibilities rather than delivery stages. Prefer one primary public concept per file, keep an underscored implementation beside the public API it supports, and retain tightly coupled helper types together when splitting them would widen access or obscure an ownership boundary. New source files must extend this structure instead of restoring a flat target root.

Proposed test layout mirrors the targets so each layer can be built and tested directly:

```text
Tests/
  TesseraTerminalANSITests/
    ANSIEncoderTests.swift
    ControlSequenceGoldenTests.swift

  TesseraTerminalBufferTests/
    BufferTests.swift
    CellWidthTests.swift
    StyleTests.swift
    HyperlinkTests.swift

  TesseraTerminalRenderingTests/
    RendererTests.swift
    DamageTests.swift
    SnapshotTests.swift

  TesseraTerminalInputTests/
    InputParserTests.swift
    InputParserLegacySequenceTests.swift
    InputParserBracketedPasteTests.swift
    InputParserFocusTests.swift
    InputParserMouseTests.swift
    InputParserKittyKeyboardTests.swift

  TesseraTerminalIOTests/
    ModeLifecycleTests.swift
    CleanupRegistryTests.swift
    PlatformIOTests.swift

  TesseraCoreTests/
    ReconciliationTests.swift     // identity rules, statistics, dump golden snapshots
    NodeStateLifetimeTests.swift
    EnvironmentTests.swift
    FocusRoutingTests.swift
    HitTestingTests.swift
  TesseraLayoutTests/
    StackDistributionTests.swift  // normative table tests
    FlexDistributionTests.swift  // Phase 2.5 normative constraint tables
    GridTests.swift              // Slice 6 shared-solver integration
    DecorationSnapshotTests.swift
    TextWrappingTests.swift       // measure/render agreement property tests
  TesseraWidgetsTests/
    TextInputTests.swift          // key-script state-machine tests
    ListTests.swift
    ScrollViewTests.swift
  TesseraRuntimeTests/
    ApplicationTests.swift        // adoption shapes written against `import Tessera`
```

Optional examples can sit outside the module graph and import the public products:

```text
Examples/
  TerminalLab/                  // Low-level TesseraTerminal playground, optional
  Counter/
  FileBrowser/
  ChatClient/
```

Suggested dependency direction inside `TesseraTerminal`:

- `TesseraTerminalCore` should contain tiny shared value types and helpers with no dependency on terminal IO.
- `TesseraTerminalANSI` should be pure and depend only on core value types.
- `TesseraTerminalBuffer` may depend on core geometry and style values, but not on IO.
- `TesseraTerminalRendering` may depend on buffer and ANSI targets, but not on platform-specific files.
- `TesseraTerminalInput` should be pure parser/event code; it should not own file descriptors or tasks.
- `TesseraTerminalIO` owns file descriptors, console handles, lifecycle, cleanup, and async streams. It may depend on ANSI and Input but should keep OS-specific code local.
- `TesseraTerminalSnapshotSupport` may depend on ANSI, Buffer, and Rendering, but production targets should not depend on snapshot helpers.

Dependency direction inside `Tessera`:

- `TesseraCore` defines the `View` protocol, graph, environment, focus/responder system, and `Text`. It directly depends only on `TesseraTerminalCore`, `TesseraTerminalBuffer` (the borrowed `Frame`/`Buffer`/`Style` seam), and `TesseraTerminalInput`; it never imports `TesseraTerminal`, `TesseraTerminalIO`, platform shims, or UI frameworks.
- `TesseraLayout` builds only on `TesseraCore`: the `Layout` protocol, containers, styling modifiers, and decoration.
- `TesseraWidgets` builds only on `TesseraCore` + `TesseraLayout`. It starts in Slice 2 rather than waiting for Slice 7 so ScrollView and SplitView do not require a temporary target.
- `TesseraRuntime` depends on `TesseraCore` and `TesseraTerminalInput` for the contract in Phase 4, and on the whole view layer plus `TesseraTerminal` once the Phase 5 runtime lands.
- `TesseraHarness` depends on `TesseraRuntime`, the view layer, and `TesseraTerminal`, and may use their `package` seams; it re-exports none of them.
- The `Tessera` target re-exports the public view-layer modules, `TesseraRuntime`, and `TesseraTerminal` for app authors.

Prefer Swift's access control to model intent:

- `public` for API that app authors should use.
- `package` for cross-target implementation details inside the Tessera package.
- `internal` for details local to one target.
- `private` / `fileprivate` for ordinary implementation hiding.

This modular target structure is more ceremony in `Package.swift`, but that ceremony buys faster focused tests, clearer compiler-enforced boundaries, and better context control for future implementation work.
