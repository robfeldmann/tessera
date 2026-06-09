import CustomDump
import SystemPackage
import TesseraTerminalCore
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminalIO

@Test
func `size returns terminal device seam size`() async throws {
  let terminalDevice = InMemoryTerminalDevice(size: TerminalSize(columns: 80, rows: 24))
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  let size = try await io.size()

  expectNoDifference(size, TerminalSize(columns: 80, rows: 24))
}

@Test
func `write buffers bytes until flush`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  await io.write([0x48, 0x69])
  await io.write([0x21])

  let bytesBeforeFlush = await terminalDevice.bytes
  expectNoDifference(bytesBeforeFlush, [])

  try await io.flush()

  let bytesAfterFlush = await terminalDevice.bytes
  expectNoDifference(bytesAfterFlush, [0x48, 0x69, 0x21])
}

@Test
func `array slice write buffers bytes until flush`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)
  let bytes: [UInt8] = [0x00, 0x48, 0x69, 0x21]

  await io.write(bytes[1...2])
  await io.write(bytes[3...])
  try await io.flush()

  let writtenBytes = await terminalDevice.bytes
  expectNoDifference(writtenBytes, [0x48, 0x69, 0x21])
}

@Test
func `bytes reads terminal device seam input bytes`() async {
  let terminalDevice = InMemoryTerminalDevice(inputBytes: [0x61, 0x62])
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)
  var iterator = io.bytes.makeAsyncIterator()

  let first = await iterator.next()
  let second = await iterator.next()
  let end = await iterator.next()

  expectNoDifference(first, 0x61)
  expectNoDifference(second, 0x62)
  expectNoDifference(end, nil)
}

@Test
func `alt screen methods emit alternate screen bytes`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  try await io.enableAltScreen()
  try await io.disableAltScreen()

  let bytes = await terminalDevice.bytes
  expectNoDifference(bytes, Array("\u{1B}[?1049h\u{1B}[?1049l".utf8))
}

@Test
func `raw mode methods call terminal device seam`() async throws {
  let terminalDevice = InMemoryTerminalDevice()
  let io = PlatformIO(terminalDevice: await terminalDevice.terminalDevice)

  try await io.enableRawMode()
  try await io.disableRawMode()

  let events = await terminalDevice.events
  expectNoDifference(events, [.enterRawMode, .exitRawMode])
}

@Test
func `flush propagates terminal device seam errors and preserves buffered bytes`() async {
  let io = PlatformIO(
    terminalDevice: TerminalDevice(
      size: { TerminalSize(columns: 1, rows: 1) },
      write: { _ in throw PlatformIOError.writeFailed(errno: .ioError) }
    )
  )

  await io.write([0x00])

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await io.flush()
  }

  await #expect(throws: PlatformIOError.writeFailed(errno: .ioError)) {
    try await io.flush()
  }
}
