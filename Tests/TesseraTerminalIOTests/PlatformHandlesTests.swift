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
#endif
