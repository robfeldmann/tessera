import InlineSnapshotTesting
import TesseraTerminalBuffer
import TesseraTerminalCore
import TesseraTerminalInput
import TesseraTestSupport
import Testing

@testable import TesseraCore

private final class AppearanceTrace {
  var events: [String] = []
  var renderers: [String] = []
  var resolutions: [String] = []

  var snapshot: String {
    (["resolutions:"]
      + resolutions
      + ["renderers:"]
      + renderers
      + ["events:"]
      + events)
      .joined(separator: "\n")
  }
}

private struct AppearanceLeaf: InputLeafView, _FocusAppearanceRendering,
  _FocusAppearanceResponder,
  _FocusableView
{
  let id: FocusID
  let disposition: FocusAppearanceDisposition
  let eventDisposition: EventDisposition
  let trace: AppearanceTrace

  func _focusID(in environment: EnvironmentValues) -> FocusID? {
    environment.isEnabled ? id : nil
  }

  func _resolveFocusAppearance(
    in context: FocusAppearanceContext
  ) -> FocusAppearanceDisposition {
    trace.resolutions.append(
      "leaf:\(context.focusedBounds.size.columns)x\(context.focusedBounds.size.rows)"
    )
    return disposition
  }

  func _renderFocusAppearance(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  ) {
    trace.renderers.append("leaf")
    region.write("L", at: TerminalPosition(column: 0, row: 0))
  }

  func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    TerminalSize(columns: 3, rows: 2)
  }

  func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    region.write("abc", at: TerminalPosition(column: 0, row: 0))
    region.write("def", at: TerminalPosition(column: 0, row: 1))
  }

  func handleEvent(
    _ event: InputEvent,
    state: inout Void,
    context: inout ResponderContext
  ) -> EventDisposition {
    trace.events.append("leaf")
    return eventDisposition
  }
}

private struct AppearanceHost<Content: View>: View, _FocusAppearanceRendering,
  _FocusAppearanceResponder
{
  let name: String
  let disposition: FocusAppearanceDisposition
  let trace: AppearanceTrace
  let content: Content

  var body: some View {
    content
  }

  init(
    _ name: String,
    disposition: FocusAppearanceDisposition = .handled,
    trace: AppearanceTrace,
    @ViewBuilder content: () -> Content
  ) {
    self.name = name
    self.disposition = disposition
    self.trace = trace
    self.content = content()
  }

  func _resolveFocusAppearance(
    in context: FocusAppearanceContext
  ) -> FocusAppearanceDisposition {
    trace.resolutions.append(
      "\(name):\(context.hostBounds.size.columns)x\(context.hostBounds.size.rows)"
    )
    return disposition
  }

  func _renderFocusAppearance(
    in region: inout RenderRegion,
    environment: EnvironmentValues
  ) {
    trace.renderers.append(name)
    region.write(String(name.prefix(1)), at: TerminalPosition(column: 0, row: 0))
  }
}

private final class MutableAppearanceFixture {
  enum Host {
    case inner
    case none
    case outer
  }

  var appearance = FocusAppearance.automatic
  var host = Host.inner
}

private struct ReplacingAppearanceFixture: View {
  let model: MutableAppearanceFixture
  let trace: AppearanceTrace
  let id = FocusID("focus")

  @ViewBuilder
  var body: some View {
    switch model.host {
    case .inner:
      AppearanceHost("inner", trace: trace) {
        leaf
      }
    case .none:
      leaf
    case .outer:
      AppearanceHost("outer", trace: trace) {
        leaf
      }
    }
  }

  private var leaf: some View {
    Text("abc")
      .focusable(id)
      .focusAppearance(model.appearance)
  }
}

@Test
func `focused node handles its local appearance before ancestors`() {
  let trace = AppearanceTrace()
  let id = FocusID("leaf")
  let graph = ViewGraph(
    root: {
      AppearanceHost("outer", trace: trace) {
        AppearanceLeaf(
          id: id,
          disposition: .handled,
          eventDisposition: .handled,
          trace: trace
        )
      }
    },
    size: TerminalSize(columns: 3, rows: 2)
  )
  graph.focus.focus(id)

  let buffer = withTestFrame(size: TerminalSize(columns: 3, rows: 2)) {
    graph.render(into: $0)
  }.buffer

  assertInlineSnapshot(of: trace.snapshot, as: .lines) {
    """
    resolutions:
    leaf:3x2
    renderers:
    leaf
    events:
    """
  }
  assertInlineSnapshot(of: buffer, as: .bufferState) {
    """
    L b c
    d e f
    """
  }
}

@Test
func `delegation selects only the nearest willing ancestor`() {
  let trace = AppearanceTrace()
  let id = FocusID("leaf")
  let graph = ViewGraph(
    root: {
      AppearanceHost("outer", trace: trace) {
        AppearanceHost("inner", trace: trace) {
          AppearanceLeaf(
            id: id,
            disposition: .deferred,
            eventDisposition: .handled,
            trace: trace
          )
        }
      }
    },
    size: TerminalSize(columns: 3, rows: 2)
  )
  graph.focus.focus(id)

  _ = withTestFrame(size: TerminalSize(columns: 3, rows: 2)) {
    graph.render(into: $0)
  }

  #expect(graph.dispatch(.key(Key(code: .enter))) == .handled)
  assertInlineSnapshot(of: trace.snapshot, as: .lines) {
    """
    resolutions:
    leaf:3x2
    inner:3x2
    renderers:
    inner
    events:
    leaf
    """
  }
}

@Test
func `suppression stops delegation while a missing host uses the local fallback`() {
  let suppressedTrace = AppearanceTrace()
  let id = FocusID("leaf")
  let suppressed = ViewGraph(
    root: {
      AppearanceHost("outer", trace: suppressedTrace) {
        AppearanceHost("stop", disposition: .suppressed, trace: suppressedTrace) {
          AppearanceLeaf(
            id: id,
            disposition: .deferred,
            eventDisposition: .ignored,
            trace: suppressedTrace
          )
        }
      }
    },
    size: TerminalSize(columns: 3, rows: 2)
  )
  suppressed.focus.focus(id)
  let suppressedBuffer = withTestFrame(size: TerminalSize(columns: 3, rows: 2)) {
    suppressed.render(into: $0)
  }.buffer

  assertInlineSnapshot(of: suppressedTrace.snapshot, as: .lines) {
    """
    resolutions:
    leaf:3x2
    stop:3x2
    renderers:
    events:
    """
  }
  assertInlineSnapshot(of: suppressedBuffer, as: .bufferState) {
    """
    a b c
    d e f
    """
  }

  let fallbackTrace = AppearanceTrace()
  let fallback = ViewGraph(
    root: {
      AppearanceLeaf(
        id: id,
        disposition: .deferred,
        eventDisposition: .ignored,
        trace: fallbackTrace
      )
    },
    size: TerminalSize(columns: 3, rows: 2)
  )
  fallback.focus.focus(id)
  let fallbackBuffer = withTestFrame(size: TerminalSize(columns: 3, rows: 2)) {
    fallback.render(into: $0)
  }.buffer

  assertInlineSnapshot(of: fallbackTrace.snapshot, as: .lines) {
    """
    resolutions:
    leaf:3x2
    renderers:
    events:
    """
  }
  assertInlineSnapshot(of: fallbackBuffer, as: .bufferState) {
    """
    ╭{fg=indexed(0),bg=indexed(3),bold} ─{fg=indexed(0),bg=indexed(3),bold} ╮{fg=indexed(0),bg=indexed(3),bold}
    ╰{fg=indexed(0),bg=indexed(3),bold} ─{fg=indexed(0),bg=indexed(3),bold} ╯{fg=indexed(0),bg=indexed(3),bold}
    """
  }
}

@Test
func `policy and host replacement deterministically invalidate the selected host`() {
  let model = MutableAppearanceFixture()
  let trace = AppearanceTrace()
  let id = FocusID("focus")
  let size = TerminalSize(columns: 3, rows: 1)
  let graph = ViewGraph(
    root: { ReplacingAppearanceFixture(model: model, trace: trace) },
    size: size
  )
  graph.focus.focus(id)

  let inner = withTestFrame(size: size) { graph.render(into: $0) }.buffer

  model.host = .outer
  graph.update()
  let outer = withTestFrame(size: size) { graph.render(into: $0) }.buffer

  model.host = .none
  graph.update()
  let fallback = withTestFrame(size: size) { graph.render(into: $0) }.buffer
  #expect(graph.focus.focused == id)

  model.appearance = .none
  graph.update()
  let suppressed = withTestFrame(size: size) { graph.render(into: $0) }.buffer

  assertInlineSnapshot(of: trace.snapshot, as: .lines) {
    """
    resolutions:
    inner:3x1
    outer:3x1
    renderers:
    inner
    outer
    events:
    """
  }
  assertInlineSnapshot(of: inner, as: .bufferState) {
    """
    i b c
    """
  }
  assertInlineSnapshot(of: outer, as: .bufferState) {
    """
    o b c
    """
  }
  assertInlineSnapshot(of: fallback, as: .bufferState) {
    """
    ╭{fg=indexed(0),bg=indexed(3),bold} ─{fg=indexed(0),bg=indexed(3),bold} ╮{fg=indexed(0),bg=indexed(3),bold}
    """
  }
  assertInlineSnapshot(of: suppressed, as: .bufferState) {
    """
    a b c
    """
  }
  #expect(graph.focus.focused == id)
}
