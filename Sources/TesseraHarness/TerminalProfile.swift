import TesseraTerminal

/// The colour level a headless session renders with: the `colors=` option of the `term`
/// header.
package enum TerminalColors: String, CaseIterable, Equatable, Sendable {
  case ansi16 = "16"
  case indexed256 = "256"
  case none
  case truecolor = "true"

  /// The accepted spellings, in the order the grammar lists them.
  package static let spellings = ["none", "16", "256", "true"]

  /// The override a session applies, so the renderer degrades colours to this level.
  var override: ColorCapabilityOverride {
    switch self {
    case .ansi16: .force(.ansi16)
    case .indexed256: .force(.indexed256)
    case .none: .force(.noColor)
    case .truecolor: .force(.truecolor)
    }
  }
}

/// The colour scheme the harness reports when a session asks the terminal for its colours:
/// the `theme=` option of the `term` header.
///
/// A scenario that names no theme runs against a terminal whose colours are unknown: the
/// harness answers no colour query, as a terminal that cannot report them would. The values
/// are fixed, so a golden never depends on any real terminal's palette.
package enum TerminalTheme: String, CaseIterable, Equatable, Sendable {
  case dark
  case light

  /// An 8-bit colour.
  struct RGB: Equatable, Sendable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8

    init(_ red: UInt8, _ green: UInt8, _ blue: UInt8) {
      self.red = red
      self.green = green
      self.blue = blue
    }
  }

  /// The accepted spellings, in the order the grammar lists them.
  package static let spellings = ["light", "dark"]

  /// ANSI slots 0 through 15 (OSC 4), xterm's defaults in both themes.
  static let palette: [RGB] = [
    RGB(0x00, 0x00, 0x00), RGB(0xCD, 0x00, 0x00), RGB(0x00, 0xCD, 0x00),
    RGB(0xCD, 0xCD, 0x00), RGB(0x00, 0x00, 0xEE), RGB(0xCD, 0x00, 0xCD),
    RGB(0x00, 0xCD, 0xCD), RGB(0xE5, 0xE5, 0xE5), RGB(0x7F, 0x7F, 0x7F),
    RGB(0xFF, 0x00, 0x00), RGB(0x00, 0xFF, 0x00), RGB(0xFF, 0xFF, 0x00),
    RGB(0x5C, 0x5C, 0xFF), RGB(0xFF, 0x00, 0xFF), RGB(0x00, 0xFF, 0xFF),
    RGB(0xFF, 0xFF, 0xFF),
  ]

  /// The default foreground (OSC 10).
  var foreground: RGB {
    switch self {
    case .dark: RGB(0xD4, 0xD4, 0xD4)
    case .light: RGB(0x1E, 0x1E, 0x1E)
    }
  }

  /// The default background (OSC 11).
  var background: RGB {
    switch self {
    case .dark: RGB(0x1E, 0x1E, 0x1E)
    case .light: RGB(0xFF, 0xFF, 0xFF)
    }
  }
}

/// The terminal a headless run presents to the application: what a scenario's `term` header
/// names.
package struct TerminalProfile: Equatable, Sendable {
  /// The colour level the session renders with. Plain cells, with no colour, by default.
  package var colors: TerminalColors

  /// The colour scheme the harness reports to colour queries, or `nil` for unknown colours.
  package var theme: TerminalTheme?

  package init(colors: TerminalColors = .none, theme: TerminalTheme? = nil) {
    self.colors = colors
    self.theme = theme
  }
}
