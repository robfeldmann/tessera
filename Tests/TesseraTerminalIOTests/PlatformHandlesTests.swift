import CustomDump
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  @Test
  func `file descriptor stores raw value`() {
    let descriptor = FileDescriptor(rawValue: 123)

    expectNoDifference(descriptor.rawValue, 123)
  }

  @Test
  func `platform handles store consumed descriptors`() {
    let handles = PlatformHandles(
      stdin: FileDescriptor(rawValue: 10),
      stdout: FileDescriptor(rawValue: 11)
    )

    expectNoDifference(handles.stdin.rawValue, 10)
    expectNoDifference(handles.stdout.rawValue, 11)
  }

  @Test
  func `standard platform handles use standard descriptors`() throws {
    let handles = try PlatformHandles.standard()

    expectNoDifference(handles.stdin.rawValue, STDIN_FILENO)
    expectNoDifference(handles.stdout.rawValue, STDOUT_FILENO)
  }
#elseif os(Windows)
  @Test
  func `platform handles store console handles`() {
    let handles = PlatformHandles(inputHandle: 0x10, outputHandle: 0x20)

    expectNoDifference(handles.inputHandle, 0x10)
    expectNoDifference(handles.outputHandle, 0x20)
  }

  @Test
  func `standard platform handles use standard console handles`() async throws {
    let system = WindowsConsoleSystem.stub(
      standardInputHandle: { 0x10 },
      standardOutputHandle: { 0x20 },
      getConsoleMode: { _ in 0x0001 }
    )

    try await WindowsConsoleSystem.$override.withValue(system) {
      let handles = try PlatformHandles.standard()

      expectNoDifference(handles.inputHandle, 0x10)
      expectNoDifference(handles.outputHandle, 0x20)
    }
  }

  @Test
  func `standard platform handles reject missing standard handles`() async {
    let system = WindowsConsoleSystem.stub(
      standardInputHandle: { nil },
      standardOutputHandle: { 0x20 },
      getConsoleMode: { _ in 0x0001 }
    )

    await #expect(throws: PlatformIOError.unsupportedTerminalEnvironment) {
      try await WindowsConsoleSystem.$override.withValue(system) {
        try PlatformHandles.standard()
      }
    }
  }

  @Test
  func `standard platform handles reject redirected input or output`() async {
    let system = WindowsConsoleSystem.stub(
      standardInputHandle: { 0x10 },
      standardOutputHandle: { 0x20 },
      getConsoleMode: { handle in handle == 0x10 ? nil : 0x0001 }
    )

    await #expect(throws: PlatformIOError.unsupportedTerminalEnvironment) {
      try await WindowsConsoleSystem.$override.withValue(system) {
        try PlatformHandles.standard()
      }
    }
  }
#endif
