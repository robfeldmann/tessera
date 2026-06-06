import CustomDump
import Dependencies
import DependenciesTestSupport
import SystemPackage
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalIO

@Test
func `size returns terminal device dependency size`() async throws {
  let terminalDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 80, rows: 24))

  try await withDependencies {
    $0.terminalDevice = await terminalDevice.terminalDevice
  } operation: {
    let io = PlatformIO()
    let size = try await io.size

    expectNoDifference(size, TerminalSize(columns: 80, rows: 24))
  }
}

@Test
func `write sends bytes to terminal device dependency`() async throws {
  let terminalDevice = InMemoryTerminalDevice()

  try await withDependencies {
    $0.terminalDevice = await terminalDevice.terminalDevice
  } operation: {
    let io = PlatformIO()

    try await io.write([0x48, 0x69])
    try await io.write([0x21])
  }

  let bytes = await terminalDevice.bytes
  expectNoDifference(bytes, [0x48, 0x69, 0x21])
}

@Test
func `bytes reads terminal device dependency input bytes`() async {
  let terminalDevice = InMemoryTerminalDevice(inputBytes: [0x61, 0x62])

  await withDependencies {
    $0.terminalDevice = await terminalDevice.terminalDevice
  } operation: {
    let io = PlatformIO()
    var iterator = io.bytes.makeAsyncIterator()

    let first = await iterator.next()
    let second = await iterator.next()
    let end = await iterator.next()

    expectNoDifference(first, 0x61)
    expectNoDifference(second, 0x62)
    expectNoDifference(end, nil)
  }
}

@Test
func `alt screen methods emit alternate screen bytes`() async throws {
  let terminalDevice = InMemoryTerminalDevice()

  try await withDependencies {
    $0.terminalDevice = await terminalDevice.terminalDevice
  } operation: {
    let io = PlatformIO()

    try await io.enterAltScreen()
    try await io.exitAltScreen()
  }

  let bytes = await terminalDevice.bytes
  expectNoDifference(bytes, Array("\u{1B}[?1049h\u{1B}[?1049l".utf8))
}

@Test
func `raw mode methods call terminal device dependency`() async throws {
  let terminalDevice = InMemoryTerminalDevice()

  try await withDependencies {
    $0.terminalDevice = await terminalDevice.terminalDevice
  } operation: {
    let io = PlatformIO()

    try await io.enterRawMode()
    try await io.exitRawMode()
  }

  let events = await terminalDevice.events
  expectNoDifference(events, [.enterRawMode, .exitRawMode])
}

@Test
func `write propagates terminal device dependency errors`() async {
  await withDependencies {
    $0.terminalDevice = TerminalDevice(
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { _ in throw PlatformIOError.writeFailed(errno: .ioError) }
    )
  } operation: {
    let io = PlatformIO()

    await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
      try await io.write([0x00])
    }
  }
}

@Test
func `platform io uses the default test terminal device`() async throws {
  let io = PlatformIO()
  let size = try await io.size

  expectNoDifference(size, TerminalSize(columns: 1, rows: 1))
  try await io.write([0x00])
}
