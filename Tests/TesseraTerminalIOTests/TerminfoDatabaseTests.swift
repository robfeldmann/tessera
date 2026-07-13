import Foundation
import Testing

@testable import TesseraTerminalIO

@Suite("Terminfo database")
struct TerminfoDatabaseTests {
  @Test
  func `reads both ncurses magic variants`() {
    let legacy = database(files: [
      "/terms/x/xterm": entry(magic: .legacy, numbers: [42])
    ])
    #expect(
      legacy.underlineDeclarations() == .init(style: .notDeclared, color: .notDeclared)
    )

    let extended = database(files: [
      "/terms/x/xterm": entry(
        magic: .extended,
        numbers: [42],
        extendedNumberNames: ["Xnum"],
        extendedNumbers: [4_096],
        extendedStrings: [
          ("Smulx", "\u{1B}[4:%p1%dm"),
          ("Setulc", "\u{1B}[58:2::%p1%d"),
        ],
      )
    ])
    #expect(
      extended.underlineDeclarations() == .init(style: .declared, color: .declared)
    )
  }

  @Test
  func `honors Boolean alignment before and within extended data`() {
    let reader = database(files: [
      "/terms/x/xterm": entry(
        magic: .extended,
        booleans: [1],
        standardStrings: ["ab"],
        extendedBooleans: [1],
        extendedBooleanNames: ["Xbool"],
        extendedStrings: [
          ("Smulx", "style"),
          ("Setulc", "color"),
        ]
      )
    ])

    #expect(
      reader.underlineDeclarations() == .init(style: .declared, color: .declared)
    )
  }

  @Test
  func `reports each extended underline declaration independently`() {
    for (strings, expected) in [
      ([], TerminfoUnderlineDeclarations(style: .notDeclared, color: .notDeclared)),
      (
        [("Smulx", "style")],
        TerminfoUnderlineDeclarations(style: .declared, color: .notDeclared)
      ),
      (
        [("Setulc", "color")],
        TerminfoUnderlineDeclarations(style: .notDeclared, color: .declared)
      ),
      (
        [("Smulx", "style"), ("Setulc", "color")],
        TerminfoUnderlineDeclarations(style: .declared, color: .declared)
      ),
    ] {
      let reader = database(files: [
        "/terms/x/xterm": entry(magic: .extended, extendedStrings: strings)
      ])
      #expect(reader.underlineDeclarations() == expected)
    }
  }

  @Test
  func `does not treat the Su Boolean as underline color`() {
    // `Su` is a Boolean capability. A named Boolean must not be mistaken for the actual
    // Setulc extended string declaration.
    let reader = database(files: [
      "/terms/x/xterm": entry(
        magic: .extended,
        extendedBooleans: [1],
        extendedBooleanNames: [
          "Su"
        ]
      )
    ])

    #expect(
      reader.underlineDeclarations() == .init(style: .notDeclared, color: .notDeclared)
    )
  }

  @Test
  func `accepts cancelled strings and arbitrary value bytes`() {
    var cancelledStandard = entry(magic: .legacy, standardStrings: ["value"])
    cancelledStandard[14] = 0xFE
    cancelledStandard[15] = 0xFF
    let cancelledStandardReader = database(files: [
      "/terms/x/xterm": cancelledStandard
    ])
    #expect(
      cancelledStandardReader.underlineDeclarations()
        == .init(style: .notDeclared, color: .notDeclared)
    )

    var cancelledExtended = entry(
      magic: .extended,
      extendedStrings: [("Smulx", "style"), ("Setulc", "color")]
    )
    cancelledExtended[24] = 0xFE
    cancelledExtended[20] = 3
    cancelledExtended[25] = 0xFF
    let cancelledExtendedReader = database(files: [
      "/terms/x/xterm": cancelledExtended
    ])
    #expect(
      cancelledExtendedReader.underlineDeclarations()
        == .init(style: .notDeclared, color: .declared)
    )

    var arbitraryStandard = entry(magic: .legacy, standardStrings: ["ok"])
    arbitraryStandard[16] = 0xFF
    let arbitraryStandardReader = database(files: [
      "/terms/x/xterm": arbitraryStandard
    ])
    #expect(
      arbitraryStandardReader.underlineDeclarations()
        == .init(style: .notDeclared, color: .notDeclared)
    )

    var arbitraryExtended = entry(
      magic: .extended,
      extendedStrings: [("X", "ok"), ("Smulx", "style")]
    )
    arbitraryExtended[32] = 0xFF
    let arbitraryExtendedReader = database(files: [
      "/terms/x/xterm": arbitraryExtended
    ])
    #expect(
      arbitraryExtendedReader.underlineDeclarations()
        == .init(style: .declared, color: .notDeclared)
    )
  }

  @Test
  func `rejects truncated oversized and invalid-offset entries`() {
    let truncated = database(files: ["/terms/x/xterm": Data([0x1A, 0x01])])
    #expect(truncated.underlineDeclarations() == .unknown)

    let oversized = database(files: [
      "/terms/x/xterm": Data(repeating: 0, count: 1_048_577)
    ])
    #expect(oversized.underlineDeclarations() == .unknown)

    var invalidOffset = entry(magic: .legacy, standardStrings: ["ok"])
    // The first standard string offset begins after the 12-byte header and two name bytes.
    // Change it to point one byte beyond its one-string table.
    invalidOffset[14] = 3
    invalidOffset[15] = 0
    let invalid = database(files: ["/terms/x/xterm": invalidOffset])
    #expect(invalid.underlineDeclarations() == .unknown)

    var invalidExtendedNameOffset = entry(
      magic: .extended,
      extendedStrings: [("Smulx", "style")]
    )
    // The name offset follows the extended header and its one value offset.
    invalidExtendedNameOffset[26] = 6
    invalidExtendedNameOffset[27] = 0
    let invalidExtended = database(files: ["/terms/x/xterm": invalidExtendedNameOffset])
    #expect(invalidExtended.underlineDeclarations() == .unknown)
  }

  @Test
  func `uses TERMINFO HOME and TERMINFO_DIRS precedence`() {
    let reader = TerminfoDatabase(
      environment: [
        "TERM": "xterm",
        "TERMINFO": "/override",
        "HOME": "/home/me",
        "TERMINFO_DIRS": "/configured",
      ],
      readFile: { path in
        [
          "/override/x/xterm": entry(
            magic: .extended, extendedStrings: [("Smulx", "style")]),
          "/home/me/.terminfo/x/xterm": entry(
            magic: .extended,
            extendedStrings: [("Setulc", "color")]
          ),
          "/configured/x/xterm": entry(
            magic: .extended,
            extendedStrings: [("Smulx", "style"), ("Setulc", "color")]
          ),
        ][path]
      },
      systemRoots: []
    )
    #expect(
      reader.underlineDeclarations() == .init(style: .declared, color: .notDeclared)
    )

    let homeFallback = TerminfoDatabase(
      environment: [
        "TERM": "xterm",
        "TERMINFO": "/missing",
        "HOME": "/home/me",
        "TERMINFO_DIRS": "/configured",
      ],
      readFile: { path in
        [
          "/home/me/.terminfo/x/xterm": entry(
            magic: .extended,
            extendedStrings: [("Setulc", "color")]
          ),
          "/configured/x/xterm": entry(
            magic: .extended,
            extendedStrings: [("Smulx", "style"), ("Setulc", "color")]
          ),
        ][path]
      },
      systemRoots: []
    )
    #expect(
      homeFallback.underlineDeclarations() == .init(style: .notDeclared, color: .declared)
    )

    let directoriesFallback = TerminfoDatabase(
      environment: [
        "TERM": "xterm",
        "TERMINFO": "/missing",
        "HOME": "/missing-home",
        "TERMINFO_DIRS": "/configured",
      ],
      readFile: { path in
        path == "/configured/x/xterm"
          ? entry(
            magic: .extended,
            extendedStrings: [("Smulx", "style"), ("Setulc", "color")]
          )
          : nil
      },
      systemRoots: []
    )
    #expect(
      directoriesFallback.underlineDeclarations()
        == .init(style: .declared, color: .declared)
    )
  }

  @Test
  func `searches first-character and hexadecimal layouts`() {
    let firstCharacter = database(files: [
      "/terms/x/xterm": entry(magic: .extended, extendedStrings: [("Smulx", "style")])
    ])
    #expect(
      firstCharacter.underlineDeclarations()
        == .init(style: .declared, color: .notDeclared)
    )

    let hexadecimal = database(files: [
      "/terms/78/xterm": entry(magic: .extended, extendedStrings: [("Setulc", "color")])
    ])
    #expect(
      hexadecimal.underlineDeclarations() == .init(style: .notDeclared, color: .declared)
    )
  }

  @Test
  func `uses system roots only for an empty TERMINFO_DIRS component`() {
    let restoredByEmptyComponent = TerminfoDatabase(
      environment: ["TERM": "xterm", "TERMINFO_DIRS": "/custom::/later"],
      readFile: { path in
        path == "/system/x/xterm"
          ? entry(magic: .extended, extendedStrings: [("Smulx", "style")])
          : nil
      },
      systemRoots: ["/system"]
    )
    #expect(
      restoredByEmptyComponent.underlineDeclarations()
        == .init(style: .declared, color: .notDeclared)
    )

    let noEmptyComponent = TerminfoDatabase(
      environment: ["TERM": "xterm", "TERMINFO_DIRS": "/custom:/later"],
      readFile: { path in
        path == "/system/x/xterm"
          ? entry(magic: .extended, extendedStrings: [("Smulx", "style")])
          : nil
      },
      systemRoots: ["/system"]
    )
    #expect(noEmptyComponent.underlineDeclarations() == .unknown)
  }

  @Test
  func `returns unknown for foreign-endian hashed unsupported and unsafe entries`() {
    let foreignEndian = database(files: [
      "/terms/x/xterm": Data([0x01, 0x1A] + Array(repeating: 0, count: 10))
    ])
    #expect(foreignEndian.underlineDeclarations() == .unknown)

    let unsupported = database(files: [
      "/terms/x/xterm": Data([0x00, 0x00] + Array(repeating: 0, count: 10))
    ])
    #expect(unsupported.underlineDeclarations() == .unknown)

    let hashedOnly = database(files: [
      "/terms/hash/xterm": entry(magic: .extended, extendedStrings: [("Smulx", "style")])
    ])
    #expect(hashedOnly.underlineDeclarations() == .unknown)

    let unsafeName = TerminfoDatabase(
      environment: ["TERM": "../xterm", "TERMINFO": "/terms"]
    ) { _ in entry(magic: .extended, extendedStrings: [("Smulx", "style")]) }
    #expect(unsafeName.underlineDeclarations() == .unknown)
  }

  private func database(files: [String: Data]) -> TerminfoDatabase {
    TerminfoDatabase(
      environment: ["TERM": "xterm", "TERMINFO": "/terms"],
      readFile: { files[$0] },
      systemRoots: []
    )
  }
}

private enum TerminfoMagic {
  case extended
  case legacy

  var value: UInt16 {
    switch self {
    case .extended:
      0x021E
    case .legacy:
      0x011A
    }
  }
}

private func entry(
  magic: TerminfoMagic,
  names: [UInt8] = [0x78, 0],
  booleans: [UInt8] = [],
  numbers: [Int] = [],
  standardStrings: [String?] = [],
  extendedBooleans: [UInt8] = [],
  extendedBooleanNames: [String] = [],
  extendedNumberNames: [String] = [],
  extendedNumbers: [Int] = [],
  extendedStrings: [(String, String?)] = []
) -> Data {
  var bytes: [UInt8] = []
  appendShort(magic.value, to: &bytes)
  appendShort(UInt16(names.count), to: &bytes)
  appendShort(UInt16(booleans.count), to: &bytes)
  appendShort(UInt16(numbers.count), to: &bytes)
  appendShort(UInt16(standardStrings.count), to: &bytes)

  let standardTable = stringTable(for: standardStrings)
  appendShort(UInt16(standardTable.bytes.count), to: &bytes)
  bytes += names
  bytes += booleans
  appendEvenPadding(to: &bytes)
  for number in numbers {
    appendNumber(number, magic: magic, to: &bytes)
  }
  for offset in standardTable.offsets {
    appendShort(UInt16(bitPattern: Int16(offset)), to: &bytes)
  }
  bytes += standardTable.bytes

  guard magic == .extended else {
    return Data(bytes)
  }

  appendEvenPadding(to: &bytes)

  precondition(extendedBooleans.count == extendedBooleanNames.count)
  precondition(extendedNumbers.count == extendedNumberNames.count)
  let extendedTable = stringTable(for: extendedStrings.map(\.1))
  let nameTable = stringTable(
    for: extendedBooleanNames.map(Optional.some)
      + extendedNumberNames.map(Optional.some)
      + extendedStrings.map(\.0)
  )
  appendShort(UInt16(extendedBooleans.count), to: &bytes)
  appendShort(UInt16(extendedNumbers.count), to: &bytes)
  appendShort(UInt16(extendedStrings.count), to: &bytes)
  let extendedItemCount =
    nameTable.offsets.count + extendedTable.offsets.count { $0 >= 0 }
  appendShort(UInt16(extendedItemCount), to: &bytes)
  appendShort(UInt16(extendedTable.bytes.count + nameTable.bytes.count), to: &bytes)
  bytes += extendedBooleans
  appendEvenPadding(to: &bytes)
  for number in extendedNumbers {
    appendNumber(number, magic: magic, to: &bytes)
  }
  for offset in extendedTable.offsets {
    appendShort(UInt16(bitPattern: Int16(offset)), to: &bytes)
  }
  for offset in nameTable.offsets {
    appendShort(UInt16(bitPattern: Int16(offset)), to: &bytes)
  }
  bytes += extendedTable.bytes
  bytes += nameTable.bytes
  return Data(bytes)
}

private func stringTable(for strings: [String?]) -> (offsets: [Int], bytes: [UInt8]) {
  var offsets: [Int] = []
  var bytes: [UInt8] = []
  for string in strings {
    guard let string else {
      offsets.append(-1)
      continue
    }
    offsets.append(bytes.count)
    bytes += string.utf8
    bytes.append(0)
  }
  return (offsets, bytes)
}

private func appendShort(_ value: UInt16, to bytes: inout [UInt8]) {
  bytes.append(UInt8(truncatingIfNeeded: value))
  bytes.append(UInt8(truncatingIfNeeded: value >> 8))
}

private func appendNumber(_ number: Int, magic: TerminfoMagic, to bytes: inout [UInt8]) {
  switch magic {
  case .legacy:
    appendShort(UInt16(bitPattern: Int16(number)), to: &bytes)
  case .extended:
    let value = UInt32(bitPattern: Int32(number))
    bytes.append(UInt8(truncatingIfNeeded: value))
    bytes.append(UInt8(truncatingIfNeeded: value >> 8))
    bytes.append(UInt8(truncatingIfNeeded: value >> 16))
    bytes.append(UInt8(truncatingIfNeeded: value >> 24))
  }
}

private func appendEvenPadding(to bytes: inout [UInt8]) {
  if !bytes.count.isMultiple(of: 2) {
    bytes.append(0)
  }
}
