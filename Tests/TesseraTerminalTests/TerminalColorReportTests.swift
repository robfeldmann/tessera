import CustomDump
import Foundation
import TesseraTerminalCore
import TesseraTerminalIO
import TesseraTerminalInput
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminal

// MARK: - Colour round on the wire

@Test
func
  `colour round is one write of OSC 10, OSC 11, and sixteen OSC 4 queries ended by DA1`()
  async throws
{
  let device = ColorTerminalDevice(palette: .dark)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)

  try await session.queryActiveCapabilities()

  let writes = await device.writes
  expectNoDifference(writes.filter(isColorRound), [expectedColorRoundBytes])
  expectNoDifference(
    expectedColorRoundBytes,
    ActiveCapabilityProbeCoordinator.colorQueryBytes(scope: .all)
  )
}

@Test
func `colour probe asks only for the background under NO_COLOR`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .seconds(30),
    capabilityDetection: .active
  )

  let report = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: ["NO_COLOR": "1"]
  ) { session in
    session.capabilities.colorReport
  }

  let writes = await device.writes
  expectNoDifference(
    writes.filter(isColorRound),
    [Array("\u{1B}]11;?\u{1B}\\\u{1B}[c".utf8)]
  )
  expectNoDifference(
    report,
    TerminalColorReport(background: Palette.dark.background)
  )
}

@Test(arguments: [CapabilityDetectionMode.passive, .disabled])
func `passive and disabled detection send no colour queries and no mode 2031`(
  _ detection: CapabilityDetectionMode
) async throws {
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(capabilityDetection: detection)

  let report = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    try await session.resumeAfterSuspend()
    return session.capabilities.colorReport
  }

  let bytes = await device.bytes
  expectNoDifference(report, TerminalColorReport())
  #expect(!bytes.containsSubsequence(Array("\u{1B}]".utf8)))
  #expect(!bytes.containsSubsequence(Array("2031".utf8)))
}

@Test
func
  `active detection enables mode 2031 after the alternate screen and disables it first`()
  async throws
{
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 4, rows: 2))
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .zero,
    capabilityDetection: .active
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    #expect(session.enabledProtocolModes.contains(.colorSchemeNotifications))
  }

  let events = await device.events
  let enable = InMemoryTerminalDeviceEvent.flush(Array("\u{1B}[?2031h".utf8))
  let disable = InMemoryTerminalDeviceEvent.flush(Array("\u{1B}[?2031l".utf8))
  let enableIndex = try #require(events.firstIndex(of: enable))
  let disableIndex = try #require(events.firstIndex(of: disable))
  let altScreenEntry = try #require(events.firstIndex(of: .enterAltScreen))
  let altScreenExit = try #require(events.firstIndex(of: .exitAltScreen))
  #expect(altScreenEntry < enableIndex)
  #expect(disableIndex < altScreenExit)
  expectNoDifference(events.filter { $0 == enable }.count, 1)
}

@Test
func `default configuration and session wait one second for each probe round`()
  async throws
{
  expectNoDifference(TerminalApplicationConfiguration().activeProbeTimeout, .seconds(1))
  expectNoDifference(
    TerminalApplicationConfiguration(modes: [.rawMode]).activeProbeTimeout,
    .seconds(1)
  )

  let device = ColorTerminalDevice(palette: .dark, behavior: .silent)
  let slept = SleepRecorder()
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice)
  ) { duration in await slept.record(duration) }
  await session.startInputPump()

  try await session.queryActiveCapabilities()

  let durations = await slept.durations
  #expect(!durations.isEmpty)
  #expect(durations.allSatisfy { $0 == .seconds(1) })
}

@Test
func `colour report keeps the newest reply per colour and ignores other slots`() {
  let first = TerminalRGBColor(red: 1, green: 2, blue: 3)
  let second = TerminalRGBColor(red: 4, green: 5, blue: 6)
  var report = TerminalColorReport()

  for role in [TerminalColorRole.foreground, .background, .slot(0), .slot(15)] {
    report.record(TerminalColorReply(role: role, color: first))
  }
  report.record(TerminalColorReply(role: .background, color: second))
  report.record(TerminalColorReply(role: .slot(16), color: second))
  report.record(TerminalColorReply(role: .slot(-1), color: second))

  expectNoDifference(
    report,
    TerminalColorReport(
      foreground: first,
      background: second,
      slots: [0: first, 15: first]
    )
  )
  expectNoDifference(report[.foreground], first)
  expectNoDifference(report[.slot(15)], first)
  expectNoDifference(report[.slot(7)], nil)
}

// MARK: - Replies fill the report

@Test(.timeLimit(.minutes(1)))
func `session fills the colour report before the first frame`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .seconds(30),
    capabilityDetection: .active
  )

  try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    expectNoDifference(session.capabilities.colorReport, Palette.dark.report)
  }
}

@Test(.timeLimit(.minutes(1)), arguments: [ReplyTerminator.st, .bel])
func `DA1 ends the colour round with every reply applied and the timeout unreached`(
  _ terminator: ReplyTerminator
) async throws {
  let device = ColorTerminalDevice(palette: .dark, terminator: terminator)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)

  let result = try await session.queryActiveCapabilities()

  let report = await session.capabilities.colorReport
  expectNoDifference(result, .resolved)
  expectNoDifference(report, Palette.dark.report)
}

@Test
func `colour probe timeout leaves inputs unknown, not failed`() async throws {
  let device = ColorTerminalDevice(palette: .dark, behavior: .silent)
  let session = await makeColorSession(device)

  let result = try await session.queryActiveCapabilities()

  let report = await session.capabilities.colorReport
  let writes = await device.writes
  expectNoDifference(result, .resolved)
  expectNoDifference(report, TerminalColorReport())
  #expect(writes.contains(expectedColorRoundBytes))
}

@Test(.timeLimit(.minutes(1)))
func `terminal that answers DA1 but no colours leaves every input unknown`() async throws
{
  let device = ColorTerminalDevice(palette: .dark, behavior: .answersDA1Only)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)

  try await session.queryActiveCapabilities()

  let report = await session.capabilities.colorReport
  expectNoDifference(report, TerminalColorReport())
}

@Test(.timeLimit(.minutes(1)))
func `colour probe reply after the sentinel is applied as an update`() async throws {
  let device = ColorTerminalDevice(palette: .dark, behavior: .answersDA1Only)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)
  try await session.queryActiveCapabilities()
  let reportAtSentinel = await session.capabilities.colorReport
  expectNoDifference(reportAtSentinel, TerminalColorReport())

  await device.send(colorReplyBytes(.dark, scope: .all, terminator: .st))

  let event = try await nextColorReport(from: session)
  expectNoDifference(
    event,
    TerminalColorReply(role: .foreground, color: Palette.dark.foreground)
  )
  await waitUntil("every late reply is applied") {
    await session.capabilities.colorReport == Palette.dark.report
  }
}

@Test(.timeLimit(.minutes(1)))
func `colour replies reach the app as colour events, never as keys`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)
  await device.send(Array("a".utf8))

  try await session.queryActiveCapabilities()

  var keys: [Key] = []
  var replies: [TerminalColorReply] = []
  while replies.count < 18 {
    switch try await session.nextEvent() {
    case .key(let key):
      keys.append(key)
    case .colorReport(let reply):
      replies.append(reply)
    default:
      break
    }
  }
  expectNoDifference(keys, [Key(code: .character("a"))])
  expectNoDifference(replies.count, 18)
}

// MARK: - Re-runs

@Test(.timeLimit(.minutes(1)))
func `colour scheme notification re-runs the colour round and applies the new colours`()
  async throws
{
  let device = ColorTerminalDevice(palette: .dark)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)
  try await session.queryActiveCapabilities()
  let initialReport = await session.capabilities.colorReport
  expectNoDifference(initialReport, Palette.dark.report)

  await device.setPalette(.light)
  await device.send(Array("\u{1B}[?997;2n".utf8))

  await waitUntil("the light palette replaces the dark one") {
    await session.capabilities.colorReport == Palette.light.report
  }
  let rounds = await device.writes.filter(isColorRound)
  expectNoDifference(rounds, [expectedColorRoundBytes, expectedColorRoundBytes])
}

@Test(.timeLimit(.minutes(1)))
func `colour probe re-runs on resume from suspend`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let session = await makeColorSession(device, endsOnlyAtSentinel: true)
  try await session.queryActiveCapabilities()

  await device.setPalette(.light)
  try await session.resumeAfterSuspend()

  await waitUntil("the light palette replaces the dark one") {
    await session.capabilities.colorReport == Palette.light.report
  }
  let rounds = await device.writes.filter(isColorRound)
  expectNoDifference(rounds, [expectedColorRoundBytes, expectedColorRoundBytes])
}

@Test(.timeLimit(.minutes(1)))
func `re-runs under NO_COLOR ask only for the background`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let session = await makeColorSession(
    device,
    endsOnlyAtSentinel: true,
    hasNoColorEnvironment: true
  )
  try await session.queryActiveCapabilities()

  try await session.resumeAfterSuspend()

  let backgroundOnly = Array("\u{1B}]11;?\u{1B}\\\u{1B}[c".utf8)
  let rounds = await device.writes.filter(isColorRound)
  expectNoDifference(rounds, [backgroundOnly, backgroundOnly])
}

@Test
func `resume does nothing before the active generation has run`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let session = await makeColorSession(device)

  try await session.resumeAfterSuspend()

  let writes = await device.writes
  expectNoDifference(writes, [])
}

@Test(.timeLimit(.minutes(1)))
func `a closed session sends no further colour queries`() async throws {
  let device = ColorTerminalDevice(palette: .dark)
  let io = PlatformIO(terminalDevice: await device.terminalDevice)
  let configuration = TerminalApplicationConfiguration(
    activeProbeTimeout: .seconds(30),
    capabilityDetection: .active
  )

  let session = try await TerminalSession.withApplicationTerminal(
    configuration: configuration,
    io: io,
    environment: [:]
  ) { session in
    session
  }
  let before = await device.writes

  try await session.resumeAfterSuspend()

  let after = await device.writes
  expectNoDifference(after, before)
}

private func nextColorReport(from session: TerminalSession) async throws
  -> TerminalColorReply
{
  while true {
    if case .colorReport(let reply) = try await session.nextEvent() {
      return reply
    }
  }
}

// MARK: - Fixtures

enum ReplyTerminator: Sendable, CustomStringConvertible {
  case bel
  case st

  var bytes: [UInt8] {
    switch self {
    case .bel:
      [0x07]
    case .st:
      [0x1B, 0x5C]
    }
  }

  var description: String {
    switch self {
    case .bel:
      "BEL"
    case .st:
      "ST"
    }
  }
}

private struct Palette: Sendable {
  static let dark = Self(
    foreground: TerminalRGBColor(red: 0xE0, green: 0xE0, blue: 0xE0),
    background: TerminalRGBColor(red: 0x10, green: 0x12, blue: 0x18),
    slots: (0..<16).map {
      TerminalRGBColor(red: UInt8($0 * 16), green: UInt8(255 - $0 * 16), blue: 0x40)
    }
  )

  static let light = Self(
    foreground: TerminalRGBColor(red: 0x20, green: 0x20, blue: 0x24),
    background: TerminalRGBColor(red: 0xF8, green: 0xF6, blue: 0xF0),
    slots: (0..<16).map {
      TerminalRGBColor(red: 0x30, green: UInt8($0 * 16), blue: UInt8(255 - $0 * 16))
    }
  )

  var foreground: TerminalRGBColor
  var background: TerminalRGBColor
  var slots: [TerminalRGBColor]

  var report: TerminalColorReport {
    TerminalColorReport(
      foreground: foreground,
      background: background,
      slots: Dictionary(uniqueKeysWithValues: slots.enumerated().map { ($0, $1) })
    )
  }
}

/// The color round the spec describes, spelled out byte for byte.
private let expectedColorRoundBytes = Array(
  ("\u{1B}]10;?\u{1B}\\" + "\u{1B}]11;?\u{1B}\\"
    + (0...15).map { "\u{1B}]4;\($0);?\u{1B}\\" }.joined() + "\u{1B}[c").utf8
)

private func isColorRound(_ bytes: [UInt8]) -> Bool {
  bytes.starts(with: [0x1B, 0x5D])
}

private func colorReplyBytes(
  _ palette: Palette,
  scope: ColorQueryScope,
  terminator: ReplyTerminator
) -> [UInt8] {
  func spec(_ color: TerminalRGBColor) -> String {
    func channel(_ value: UInt8) -> String {
      let text = String(Int(value) * 257, radix: 16)
      return String(repeating: "0", count: 4 - text.count) + text
    }
    return "rgb:\(channel(color.red))/\(channel(color.green))/\(channel(color.blue))"
  }

  var replies: [(String, TerminalRGBColor)] = []
  switch scope {
  case .all:
    replies.append(("10", palette.foreground))
    replies.append(("11", palette.background))
    for (slot, color) in palette.slots.enumerated() {
      replies.append(("4;\(slot)", color))
    }
  case .backgroundOnly:
    replies.append(("11", palette.background))
  }
  return replies.flatMap { code, color in
    [0x1B, 0x5D] + Array("\(code);\(spec(color))".utf8) + terminator.bytes
  }
}

private actor SleepRecorder {
  private(set) var durations: [Duration] = []

  func record(_ duration: Duration) {
    durations.append(duration)
  }
}

private actor ColorTerminalDevice {
  enum Behavior: Sendable {
    /// Answers every query, color round included, then its DA1.
    case answers
    /// Answers the color round's DA1 and nothing before it.
    case answersDA1Only
    /// Answers nothing.
    case silent
  }

  private let behavior: Behavior
  private let inputContinuation: AsyncStream<[UInt8]>.Continuation
  private let inputStream: AsyncStream<[UInt8]>
  private var palette: Palette
  private let terminator: ReplyTerminator
  private(set) var writes: [[UInt8]] = []

  var terminalDevice: TerminalDevice {
    let inputStream = inputStream
    return TerminalDevice(
      bytes: { inputStream },
      size: { TerminalSize(columns: 4, rows: 2) },
      write: { try await self.write($0) }
    )
  }

  init(
    palette: Palette,
    behavior: Behavior = .answers,
    terminator: ReplyTerminator = .st
  ) {
    let stream = AsyncStream<[UInt8]>.makeStream()
    self.behavior = behavior
    self.inputContinuation = stream.continuation
    self.inputStream = stream.stream
    self.palette = palette
    self.terminator = terminator
  }

  func send(_ bytes: [UInt8]) {
    inputContinuation.yield(bytes)
  }

  func setPalette(_ palette: Palette) {
    self.palette = palette
  }

  private func write(_ slice: ArraySlice<UInt8>) throws -> Int {
    let bytes = Array(slice)
    writes.append(bytes)
    guard behavior != .silent else {
      return bytes.count
    }

    let da1 = Array("\u{1B}[?1;2c".utf8)
    if isColorRound(bytes) {
      if behavior == .answers {
        let scope: ColorQueryScope =
          bytes.starts(with: Array("\u{1B}]10;".utf8)) ? .all : .backgroundOnly
        inputContinuation.yield(
          colorReplyBytes(palette, scope: scope, terminator: terminator))
      }
      inputContinuation.yield(da1)
    } else if bytes.starts(with: Array("\u{1B}[?2004$p".utf8)) {
      let modes = [2_004, 1_004, 1_002, 1_003, 1_006, 2_026]
      inputContinuation.yield(
        Array(modes.map { "\u{1B}[?\($0);1$y" }.joined().utf8)
      )
    } else if bytes == Array("\u{1B}[?u\u{1B}[c".utf8) {
      inputContinuation.yield(da1)
    } else if bytes.containsSubsequence(Array(",a=q,".utf8)) {
      inputContinuation.yield(da1)
    }
    return bytes.count
  }
}

/// A directly constructed session with its input pump running. With `endsOnlyAtSentinel`,
/// no round can end by timeout, so a round that never gets its DA1 hangs until the test's
/// time limit instead of passing quietly.
private func makeColorSession(
  _ device: ColorTerminalDevice,
  endsOnlyAtSentinel: Bool = false,
  hasNoColorEnvironment: Bool = false
) async -> TerminalSession {
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    hasNoColorEnvironment: hasNoColorEnvironment,
    probeImageID: KittyImageID(rawValue: 17)
  ) { _ in
    if endsOnlyAtSentinel {
      try await suspendUntilCancelled()
    }
  }
  await session.startInputPump()
  return session
}

/// Suspends until the surrounding task is cancelled, then throws `CancellationError`.
private func suspendUntilCancelled() async throws {
  let (stream, continuation) = AsyncStream<Void>.makeStream()
  for await _ in stream {}
  continuation.finish()
  try Task.checkCancellation()
}

extension [UInt8] {
  fileprivate func containsSubsequence(_ subsequence: [UInt8]) -> Bool {
    guard !subsequence.isEmpty, count >= subsequence.count else {
      return false
    }
    return indices.contains { index in
      let endIndex = index + subsequence.count
      guard endIndex <= self.endIndex else {
        return false
      }
      return Array(self[index..<endIndex]) == subsequence
    }
  }
}
