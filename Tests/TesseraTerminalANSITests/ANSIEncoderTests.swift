import Foundation
import TesseraTerminalSnapshotSupport
import Testing

@testable import TesseraTerminalANSI

@Test
func `empty sequence list encodes no bytes`() {
  expectBytes(ANSIEncoder.encode([]), [])
}

@Test
func `control sequence bytes convenience uses encode into`() {
  #expect(ControlSequence.bell.bytes == ANSIEncoder.encode([.bell]))
}

func expectBytes(
  _ actual: [UInt8],
  _ expected: [UInt8]
) {
  #expect(actual == expected, "expected bytes: \(hex(expected)); actual bytes: \(hex(actual))")
}

func utf8(_ string: String) -> [UInt8] {
  Array(string.utf8)
}

func feed(
  _ sequences: [ControlSequence],
  into terminal: VirtualTerminal
) {
  terminal.feed(ANSIEncoder.encode(sequences))
}

private func hex(_ bytes: [UInt8]) -> String {
  bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
