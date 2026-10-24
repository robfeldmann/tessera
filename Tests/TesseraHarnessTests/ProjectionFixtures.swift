import TesseraCore
import TesseraLayout
import TesseraRuntime
import TesseraTerminal
import TesseraTerminalInput

@testable import TesseraHarness

/// A custom layout that puts every child at the origin: the defect plan 034 fixed in `ForEach`,
/// written by hand so a check has something to find.
private struct Overlap: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    let sizes = subviews.map { $0.sizeThatFits(proposal) }
    return TerminalSize(
      columns: sizes.map(\.columns).max() ?? 0, rows: sizes.map(\.rows).max() ?? 0)
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    for subview in subviews {
      subview.place(at: bounds.origin, proposal: proposal)
    }
  }
}

/// Two children on one frame, under a layout that is not a `ZStack`.
final class OverlapApp: Application {
  var body: some View {
    Overlap {
      Text("first")
      Text("second")
    }
  }

  func apply(_ event: InputEvent) {}
}

/// A view wider than the fixed frame it is offered: it measures more than it was proposed and
/// is clipped by the frame.
final class OverflowApp: Application {
  var body: some View {
    VStack(spacing: 0) {
      Text("wide content").frame(width: 4)
      Text("ok")
    }
  }

  func apply(_ event: InputEvent) {}
}

/// `OK` over `status`, and the frame and padding modifiers, as the catalog draws them.
final class LayersApp: Application {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack {
        Text("status")
        Text("OK").frame(width: 2)
      }
      Text("Go").padding(1)
      ForEach(["a", "b"], id: \.self) { name in
        Text(name)
      }
    }
  }

  func apply(_ event: InputEvent) {}
}

/// Text with a style of its own: bold red, then underlined on a blue background.
final class StyledApp: Application {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("bold", style: Style(foreground: .rgb(255, 0, 0), attributes: .bold))
      Text("plain")
      Text("blue", style: Style(background: .indexed(4), underlineStyle: .single))
    }
  }

  func apply(_ event: InputEvent) {}
}

/// Wide content: `東京` is four cells.
final class WideApp: Application {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("東京 map")
      Text("after")
    }
  }

  func apply(_ event: InputEvent) {}
}

/// A counter that is clean after every step it ignores: it returns its root explicitly, so
/// reconciliation skips the whole tree when nothing changed.
private struct Stable: View, Equatable {
  var count: Int

  var body: some View {
    Text("count \(count)")
  }
}

/// An app whose steps sometimes change nothing: `+` counts and every other key is ignored.
///
/// The body returns its root explicitly: a view builder would wrap it in a tuple view, which
/// is not equatable and so is dirty after every update.
final class SteadyApp: Application {
  private var count = 0

  var body: some View {
    let root = Stable(count: count)
    return root.equatable()
  }

  func apply(_ event: InputEvent) {
    if case .key(let key) = event, key.code == .character("+") {
      count += 1
    }
  }
}

/// An app that grows and shrinks its node list, to show which nodes a step adds and removes.
final class GrowingApp: Application {
  private var items = ["a"]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(items, id: \.self) { item in
        Text(item)
      }
    }
  }

  func apply(_ event: InputEvent) {
    guard case .key(let key) = event else {
      return
    }
    switch key.code {
    case .character("+"): items.append(String(UnicodeScalar(UInt8(97 + items.count))))
    case .character("-"): _ = items.popLast()
    default: break
    }
  }
}

/// Layers that a list and an `if` build under a `ZStack`: layout looks through both, so the
/// items share one frame by contract.
final class ListLayersApp: Application {
  private let shown = true

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack {
        ForEach(["abcd", "ef"], id: \.self) { layer in
          Text(layer)
        }
      }
      ZStack {
        Text("base")
        if shown {
          Text("g")
          Text("h")
        }
      }
    }
  }

  func apply(_ event: InputEvent) {}
}

/// The same list under a layout that is not a `ZStack`: its items on one frame are the defect.
final class ListOverlapApp: Application {
  var body: some View {
    Overlap {
      ForEach(["a", "b"], id: \.self) { name in
        Text(name)
      }
    }
  }

  func apply(_ event: InputEvent) {}
}

enum ProjectionFixtures {
  /// The apps the projection, check, and trace tests run, each at one registered name.
  @MainActor
  static func registry() -> ApplicationRegistry {
    var registry = ApplicationRegistry()
    registry.register("overlap", viewports: [.desktop]) { OverlapApp() }
    registry.register("overflow", viewports: [.desktop]) { OverflowApp() }
    registry.register("layers", viewports: [.desktop]) { LayersApp() }
    registry.register("styled", viewports: [.desktop]) { StyledApp() }
    registry.register("wide", viewports: [.desktop]) { WideApp() }
    registry.register("steady", viewports: [.desktop]) { SteadyApp() }
    registry.register("growing", viewports: [.desktop]) { GrowingApp() }
    registry.register("list-layers", viewports: [.desktop]) { ListLayersApp() }
    registry.register("list-overlap", viewports: [.desktop]) { ListOverlapApp() }
    registry.register("shadowed-list", viewports: [.desktop]) { ShadowedListApp() }
    return registry
  }
}
