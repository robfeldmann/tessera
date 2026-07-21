import Foundation
import TesseraTerminal

/// Demonstrates ANSI encoding by printing exact bytes for semantic `ControlSequence` values
/// without entering a live terminal session.
@main
enum ANSIEncoderDemo {
  static func main() {
    let sequences: [ControlSequence] = [
      .cursorPosition(TerminalPosition(column: 0, row: 0)),
      .setForeground(.ansi(.cyan)),
      .setBold(true),
      .text("Tessera ANSI Encoder Demo"),
      .resetAttributes,
    ]

    let bytes = ANSIEncoder.encode(sequences)

    writeLine("Semantic sequences:")
    for sequence in sequences {
      writeLine("- \(sequence)")
    }

    writeLine("\nExact bytes:")
    writeLine(bytes.map { String(format: "0x%02X", $0) }.joined(separator: " "))
  }
}

private func writeLine(_ line: String) {
  FileHandle.standardOutput.write(Data("\(line)\n".utf8))
}
