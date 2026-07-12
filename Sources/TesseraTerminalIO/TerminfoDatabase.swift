import Foundation

/// Whether a terminfo entry explicitly declares an underline capability.
public enum TerminfoCapabilityDeclaration: Equatable, Sendable {
  /// The entry explicitly declares the capability.
  case declared

  /// The entry is valid but does not declare the capability.
  case notDeclared

  /// No usable terminfo entry was available.
  case unknown
}

/// Independent underline declarations read from a terminfo entry.
public struct TerminfoUnderlineDeclarations: Equatable, Sendable {
  /// No usable terminfo entry was available.
  public static let unknown = Self(style: .unknown, color: .unknown)

  /// The declaration for extended underline styles (`Smulx`).
  public var style: TerminfoCapabilityDeclaration

  /// The declaration for underline color (`Setulc`).
  public var color: TerminfoCapabilityDeclaration

  /// Creates independent underline declaration evidence.
  public init(
    style: TerminfoCapabilityDeclaration,
    color: TerminfoCapabilityDeclaration
  ) {
    self.style = style
    self.color = color
  }
}

/// A bounded, read-only terminfo directory-tree reader.
///
/// The reader intentionally implements only the ncurses compiled-entry layout needed to
/// inspect extension declarations. It neither loads ncurses nor executes terminal tools.
public struct TerminfoDatabase: Sendable {
  private struct EntryReader {
    private let entry: Data
    private(set) var offset = 0

    var isAtEnd: Bool {
      offset == entry.count
    }

    init(_ entry: Data) {
      self.entry = entry
    }

    mutating func readUInt16() -> UInt16? {
      guard let range = take(2) else {
        return nil
      }
      return UInt16(entry[range.lowerBound]) | (UInt16(entry[range.lowerBound + 1]) << 8)
    }

    mutating func readCount() -> Int? {
      guard let value = readUInt16() else {
        return nil
      }
      let signedValue = Int16(bitPattern: value)
      return signedValue >= 0 ? Int(signedValue) : nil
    }

    mutating func take(_ count: Int) -> Range<Int>? {
      guard count >= 0,
        let end = TerminfoDatabase.checkedSum(offset, count),
        end <= entry.count
      else {
        return nil
      }
      defer { offset = end }
      return offset..<end
    }

    mutating func skip(_ count: Int) -> Bool {
      take(count) != nil
    }

    mutating func skipProduct(_ lhs: Int, _ rhs: Int) -> Bool {
      guard let count = TerminfoDatabase.checkedProduct(lhs, rhs) else {
        return false
      }
      return skip(count)
    }

    mutating func takeProduct(_ lhs: Int, _ rhs: Int) -> Range<Int>? {
      guard let count = TerminfoDatabase.checkedProduct(lhs, rhs) else {
        return nil
      }
      return take(count)
    }

    mutating func alignToEven() -> Bool {
      offset.isMultiple(of: 2) || skip(1)
    }
  }

  /// The largest compiled entry accepted by the reader.
  ///
  /// This bound is deliberately much larger than normal terminfo entries while preventing
  /// hostile environment paths from making startup allocate or scan an unbounded file.
  private static let maximumEntrySize = 1 << 20

  private static let defaultSystemRoots = [
    "/etc/terminfo",
    "/lib/terminfo",
    "/usr/share/terminfo",
  ]

  /// The production reader using the process environment and ordinary file reads.
  public static var system: Self {
    system(environment: ProcessInfo.processInfo.environment)
  }

  private let environment: [String: String]
  private let readFile: @Sendable (String) -> Data?
  private let systemRoots: [String]

  /// Creates a reader with injectable environment and filesystem seams.
  ///
  /// `readFile` receives complete candidate paths and should return `nil` for an absent or
  /// unreadable entry. Supplying both seams makes lookup deterministic without changing
  /// the process environment or filesystem.
  public init(
    environment: [String: String],
    readFile: @escaping @Sendable (String) -> Data?
  ) {
    self.init(
      environment: environment,
      readFile: readFile,
      systemRoots: Self.defaultSystemRoots
    )
  }

  /// Creates a reader with explicit system fallback roots.
  public init(
    environment: [String: String],
    readFile: @escaping @Sendable (String) -> Data?,
    systemRoots: [String]
  ) {
    self.environment = environment
    self.readFile = readFile
    self.systemRoots = systemRoots
  }

  /// Creates a production reader for an explicit environment.
  public static func system(environment: [String: String]) -> Self {
    let readFile: @Sendable (String) -> Data? = { path in
      guard
        let handle = try? FileHandle(
          forReadingFrom: URL(fileURLWithPath: path)
        )
      else {
        return nil
      }
      defer { try? handle.close() }
      return try? handle.read(upToCount: maximumEntrySize + 1)
    }
    return Self(
      environment: environment,
      readFile: readFile,
      systemRoots: defaultSystemRoots
    )
  }

  /// Reads underline declarations for `terminal`, or for `TERM` when it is omitted.
  public func underlineDeclarations(
    for terminal: String? = nil
  ) -> TerminfoUnderlineDeclarations {
    #if os(Windows)
      return .unknown
    #else
      guard let terminal = terminal ?? environment["TERM"],
        Self.isSafeTerminalName(terminal)
      else {
        return .unknown
      }

      for root in searchRoots() {
        for path in Self.entryPaths(root: root, terminal: terminal) {
          guard let entry = readFile(path) else {
            continue
          }
          return Self.parse(entry) ?? .unknown
        }
      }
      return .unknown
    #endif
  }

  private func searchRoots() -> [String] {
    var roots: [String] = []

    if let terminfo = environment["TERMINFO"], !terminfo.isEmpty {
      roots.append(terminfo)
    }
    if let home = environment["HOME"], !home.isEmpty {
      roots.append(Self.join(home, ".terminfo"))
    }

    guard let configuredDirectories = environment["TERMINFO_DIRS"],
      !configuredDirectories.isEmpty
    else {
      roots.append(contentsOf: systemRoots)
      return roots
    }

    for component in configuredDirectories.split(
      separator: ":", omittingEmptySubsequences: false) {
      if component.isEmpty {
        roots.append(contentsOf: systemRoots)
      } else {
        roots.append(String(component))
      }
    }
    return roots
  }
}

extension TerminfoDatabase {
  private static func entryPaths(root: String, terminal: String) -> [String] {
    guard let firstByte = terminal.utf8.first else {
      return []
    }
    let firstCharacter = String(UnicodeScalar(firstByte))
    let hexadecimalDirectory = String(format: "%02x", firstByte)
    let upperHexadecimalDirectory = hexadecimalDirectory.uppercased()

    return [
      join(join(root, firstCharacter), terminal),
      join(join(root, hexadecimalDirectory), terminal),
      join(join(root, upperHexadecimalDirectory), terminal),
    ]
  }

  private static func isSafeTerminalName(_ terminal: String) -> Bool {
    guard !terminal.isEmpty, terminal.utf8.count == terminal.count else {
      return false
    }
    return terminal.utf8.allSatisfy { byte in
      byte >= 0x21 && byte <= 0x7E && byte != 0x2F && byte != 0x5C
    }
  }

  private static func join(_ root: String, _ component: String) -> String {
    root == "/" ? "/\(component)" : "\(root)/\(component)"
  }

  private static func parse(_ entry: Data) -> TerminfoUnderlineDeclarations? {
    guard !entry.isEmpty, entry.count <= maximumEntrySize else {
      return nil
    }

    var reader = EntryReader(entry)
    guard let magic = reader.readUInt16() else {
      return nil
    }

    let numberWidth: Int
    switch magic {
    case 0x011A:
      numberWidth = 2
    case 0x021E:
      numberWidth = 4
    default:
      // A byte-swapped entry also lands here: only little-endian ncurses storage is valid.
      return nil
    }

    guard let namesSize = reader.readCount(),
      let booleanCount = reader.readCount(),
      let numberCount = reader.readCount(),
      let stringCount = reader.readCount(),
      let stringTableSize = reader.readCount(),
      let names = reader.take(namesSize),
      Self.containsCString(in: entry, range: names, at: 0),
      reader.skip(booleanCount),
      reader.alignToEven(),
      reader.skipProduct(numberCount, numberWidth),
      let stringOffsets = reader.takeProduct(stringCount, 2),
      let stringTable = reader.take(stringTableSize),
      Self.validStringOffsets(
        in: entry,
        offsets: stringOffsets,
        table: stringTable,
        allowsCancelledValues: true
      )
    else {
      return nil
    }

    guard !reader.isAtEnd else {
      return Self.declarations(style: .notDeclared, color: .notDeclared)
    }

    guard reader.alignToEven(),
      let extendedBooleanCount = reader.readCount(),
      let extendedNumberCount = reader.readCount(),
      let extendedStringCount = reader.readCount(),
      let extendedStringTableItemCount = reader.readCount(),
      let extendedTableSize = reader.readCount(),
      let extendedNameCount = checkedSum(
        extendedBooleanCount,
        extendedNumberCount,
        extendedStringCount
      ),
      let expectedOffsetCount = checkedSum(extendedStringCount, extendedNameCount),
      reader.skip(extendedBooleanCount),
      reader.alignToEven(),
      reader.skipProduct(extendedNumberCount, numberWidth),
      let extendedOffsets = reader.takeProduct(expectedOffsetCount, 2),
      let valueOffsetBytes = checkedProduct(extendedStringCount, 2),
      let nameOffsetsStart = checkedSum(extendedOffsets.lowerBound, valueOffsetBytes),
      nameOffsetsStart <= extendedOffsets.upperBound,
      let extendedTable = reader.take(extendedTableSize),
      reader.isAtEnd
    else {
      return nil
    }

    let extendedStringOffsets = extendedOffsets.lowerBound..<nameOffsetsStart
    let extendedNameOffsets = nameOffsetsStart..<extendedOffsets.upperBound
    guard
      let presentStringCount = Self.presentStringCount(
        in: entry,
        offsets: extendedStringOffsets
      ),
      let expectedItemCount = checkedSum(extendedNameCount, presentStringCount),
      extendedStringTableItemCount == expectedItemCount
    else {
      return nil
    }
    guard
      let valueTableSize = Self.stringValueTableSize(
        in: entry,
        offsets: extendedStringOffsets,
        table: extendedTable
      ),
      let nameTableStart = checkedSum(extendedTable.lowerBound, valueTableSize),
      nameTableStart <= extendedTable.upperBound
    else {
      return nil
    }
    let extendedStringTable = extendedTable.lowerBound..<nameTableStart
    let extendedNameTable = nameTableStart..<extendedTable.upperBound
    guard
      Self.validStringOffsets(
        in: entry,
        offsets: extendedStringOffsets,
        table: extendedStringTable,
        allowsCancelledValues: true
      ),
      Self.validStringOffsets(
        in: entry,
        offsets: extendedNameOffsets,
        table: extendedNameTable,
        allowsCancelledValues: false
      )
    else {
      return nil
    }

    var style = TerminfoCapabilityDeclaration.notDeclared
    var color = TerminfoCapabilityDeclaration.notDeclared
    let stringNameStart = extendedBooleanCount + extendedNumberCount

    for index in 0..<extendedStringCount {
      guard
        let nameOffset = Self.offset(
          in: entry,
          offsets: extendedNameOffsets,
          index: stringNameStart + index
        ),
        let name = Self.cString(in: entry, table: extendedNameTable, offset: nameOffset),
        let valueOffset = Self.offset(
          in: entry, offsets: extendedStringOffsets, index: index)
      else {
        return nil
      }

      // Missing (-1) and cancelled (-2) strings are not actual declarations.
      if valueOffset == -1 || valueOffset == -2 {
        continue
      }
      guard valueOffset >= 0,
        Self.containsCString(in: entry, range: extendedStringTable, at: valueOffset)
      else {
        return nil
      }

      switch name {
      case "Smulx":
        style = .declared
      case "Setulc":
        color = .declared
      default:
        break
      }
    }

    return Self.declarations(style: style, color: color)
  }

  private static func declarations(
    style: TerminfoCapabilityDeclaration,
    color: TerminfoCapabilityDeclaration
  ) -> TerminfoUnderlineDeclarations {
    .init(style: style, color: color)
  }

  private static func checkedSum(_ values: Int...) -> Int? {
    var total = 0
    for value in values {
      let addition = total.addingReportingOverflow(value)
      guard !addition.overflow else {
        return nil
      }
      total = addition.partialValue
    }
    return total
  }

  private static func presentStringCount(
    in entry: Data,
    offsets: Range<Int>
  ) -> Int? {
    guard offsets.count.isMultiple(of: 2) else {
      return nil
    }

    var count = 0
    for index in 0..<(offsets.count / 2) {
      guard let offset = offset(in: entry, offsets: offsets, index: index) else {
        return nil
      }
      if offset >= 0 {
        count += 1
      } else if offset != -1 && offset != -2 {
        return nil
      }
    }
    return count
  }

  private static func stringValueTableSize(
    in entry: Data,
    offsets: Range<Int>,
    table: Range<Int>
  ) -> Int? {
    guard offsets.count.isMultiple(of: 2) else {
      return nil
    }

    var size = 0
    for index in 0..<(offsets.count / 2) {
      guard let offset = offset(in: entry, offsets: offsets, index: index) else {
        return nil
      }
      if offset == -1 || offset == -2 {
        continue
      }
      guard offset >= 0,
        let valueRange = cStringRange(in: entry, table: table, offset: offset),
        let relativeEnd = checkedSum(valueRange.upperBound - table.lowerBound, 1)
      else {
        return nil
      }
      size = max(size, relativeEnd)
    }
    return size
  }

  private static func validStringOffsets(
    in entry: Data,
    offsets: Range<Int>,
    table: Range<Int>,
    allowsCancelledValues: Bool
  ) -> Bool {
    guard offsets.count.isMultiple(of: 2) else {
      return false
    }
    for index in 0..<(offsets.count / 2) {
      guard let offset = offset(in: entry, offsets: offsets, index: index) else {
        return false
      }
      if offset == -1 || offset == -2 {
        guard allowsCancelledValues else {
          return false
        }
      } else if offset < 0
        || !containsCString(in: entry, range: table, at: offset) {
        return false
      }
    }
    return true
  }

  private static func offset(in entry: Data, offsets: Range<Int>, index: Int) -> Int? {
    guard index >= 0,
      let byteOffset = checkedProduct(index, 2),
      let position = checkedSum(offsets.lowerBound, byteOffset),
      position >= offsets.lowerBound,
      position + 1 < offsets.upperBound
    else {
      return nil
    }
    let value = UInt16(entry[position]) | (UInt16(entry[position + 1]) << 8)
    return Int(Int16(bitPattern: value))
  }

  private static func containsCString(
    in entry: Data,
    range: Range<Int>,
    at offset: Int
  ) -> Bool {
    cStringRange(in: entry, table: range, offset: offset) != nil
  }

  private static func cString(in entry: Data, table: Range<Int>, offset: Int) -> String? {
    guard let range = cStringRange(in: entry, table: table, offset: offset) else {
      return nil
    }
    return String(bytes: entry[range], encoding: .utf8)
  }

  private static func cStringRange(
    in entry: Data,
    table: Range<Int>,
    offset: Int
  ) -> Range<Int>? {
    guard offset >= 0,
      let start = checkedSum(table.lowerBound, offset),
      start >= table.lowerBound,
      start < table.upperBound
    else {
      return nil
    }

    var end = start
    while end < table.upperBound {
      if entry[end] == 0 {
        return start..<end
      }
      end += 1
    }
    return nil
  }

  private static func checkedProduct(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    return result.overflow ? nil : result.partialValue
  }
}
