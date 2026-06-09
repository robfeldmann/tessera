import TesseraTerminal

/// Demonstrates the Phase 2 ANSI encoder by building terminal output from
/// semantic `ControlSequence` values.
@main
enum ANSIEncoderDemo {
  private static let colors: [Color] = [
    .ansi(.red),
    .ansi(.green),
    .ansi(.yellow),
    .ansi(.blue),
    .ansi(.magenta),
    .ansi(.cyan),
    .indexed(208),
    .rgb(120, 180, 255),
  ]

  static func main() async throws {
    let io = PlatformIO()
    var rawModeEntered = false
    var altScreenEntered = false

    do {
      try await io.enterRawMode()
      rawModeEntered = true

      try await write([.enterAltScreen, .cursorVisible(false)], to: io)
      altScreenEntered = true

      try await run(io: io)

      try await write([.cursorVisible(true), .exitAltScreen], to: io)
      altScreenEntered = false

      try await io.exitRawMode()
      rawModeEntered = false
    } catch {
      if altScreenEntered {
        try? await write([.cursorVisible(true), .exitAltScreen], to: io)
      }
      if rawModeEntered {
        try? await io.exitRawMode()
      }
      throw error
    }
  }

  private static func run(io: PlatformIO) async throws {
    var colorIndex = 0
    var bold = true
    var underline = false
    var reverse = false
    var lastKey: Character = " "

    try await render(
      colorIndex: colorIndex,
      bold: bold,
      underline: underline,
      reverse: reverse,
      lastKey: lastKey,
      to: io
    )

    for await byte in io.bytes {
      switch InputParser.parse(byte) {
      case .quit:
        return
      case .character("c"):
        colorIndex = (colorIndex + 1) % colors.count
      case .character("b"):
        bold.toggle()
      case .character("u"):
        underline.toggle()
      case .character("r"):
        reverse.toggle()
      case .character(let character):
        lastKey = character
      case nil:
        continue
      }

      try await render(
        colorIndex: colorIndex,
        bold: bold,
        underline: underline,
        reverse: reverse,
        lastKey: lastKey,
        to: io
      )
    }
  }

  private static func render(
    colorIndex: Int,
    bold: Bool,
    underline: Bool,
    reverse: Bool,
    lastKey: Character,
    to io: PlatformIO
  ) async throws {
    let color = colors[colorIndex]
    try await write(
      [
        .enterSynchronizedOutput,
        .setWindowTitle("Tessera ANSI Encoder Demo"),
        .cursorPosition(TerminalPosition(column: 0, row: 0)),
        .eraseInDisplay(.all),
        .setForeground(.ansi(.brightWhite)),
        .setBold(true),
        .text("Tessera ANSI Encoder Demo\r\n\r\n"),
        .resetAttributes,
        .text("This screen is composed from ControlSequence values.\r\n\r\n"),
        .text("Controls: c color, b bold, u underline, r reverse, q quit.\r\n"),
        .text("Last key: "),
        .setForeground(.ansi(.brightYellow)),
        .text(String(lastKey)),
        .resetAttributes,
        .text("\r\n\r\n"),
        .text("Sample: "),
        .setForeground(color),
        .setBold(bold),
        .setUnderline(underline),
        .setReverse(reverse),
        .text("semantic operation → exact ANSI bytes"),
        .resetAttributes,
        .text("\r\n\r\n"),
        .setDim(true),
        .text("raw mode and alternate screen will be restored on exit."),
        .resetAttributes,
        .exitSynchronizedOutput,
      ],
      to: io
    )
  }

  private static func write(
    _ sequences: [ControlSequence],
    to io: PlatformIO
  ) async throws {
    try await io.write(ANSIEncoder.encode(sequences))
  }
}
