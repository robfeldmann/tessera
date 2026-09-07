import Tessera

/// A scaffold-free Text/layout specimen, shared by live input and captured scenarios.
/// All content is synthetic and restricted to printable ASCII for the initial exporter.
package final class LayoutSpecimen {
  package var message = "A small view, through the real terminal."

  package var content: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Hello, Tessera").bold().foreground(.indexed(14))
      Text(message).wrapped(.word)
      Text("Press q to quit.").style(Style().dim())
    }
    .padding(1)
  }

  package init() {}
}
