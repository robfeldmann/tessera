import TesseraCore
import TesseraLayout
import TesseraRuntime
import TesseraTerminalInput

/// A view of the app's own that is named like a library list. It is a composite whose body is
/// two views and no container, so layout has no container to place them in and puts them on
/// one frame; nothing about the name makes it a `ForEach`.
///
/// This file uses no `ForEach` of the library: the name here is the app's.
private struct ForEach: View {
  @ViewBuilder var body: some View {
    Text("first")
    Text("second")
  }
}

/// `ZStack { ForEach() }` with the app's own `ForEach`. A `ZStack` overlaps its layers by
/// contract, but the app's view is one layer, and the two texts in its body are not.
final class ShadowedListApp: Application {
  var body: some View {
    ZStack {
      ForEach()
    }
  }

  func apply(_ event: InputEvent) {}
}
