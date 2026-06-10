import CustomDump
import Testing

@testable import TesseraTerminalIO

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

#if os(macOS) || os(Linux)
  @Test
  func `posix input loop yields bytes written to descriptor`() async throws {
    let pipe = try FileDescriptorPipe()
    defer { pipe.closeAll() }

    let stream = POSIXInputLoop.bytes(fileDescriptor: pipe.readDescriptor)
    var iterator = stream.makeAsyncIterator()

    try pipe.write([0x61, 0x62])

    let first = await iterator.next()
    let second = await iterator.next()

    expectNoDifference(first, 0x61)
    expectNoDifference(second, 0x62)
  }

  @Test
  func `posix input loop finishes on eof`() async throws {
    let pipe = try FileDescriptorPipe()
    defer { pipe.closeAll() }

    let stream = POSIXInputLoop.bytes(fileDescriptor: pipe.readDescriptor)
    var iterator = stream.makeAsyncIterator()

    pipe.closeWriteDescriptor()

    let end = await iterator.next()

    expectNoDifference(end, nil)
  }

  private final class FileDescriptorPipe: @unchecked Sendable {
    private var descriptors: [CInt] = [-1, -1]

    var readDescriptor: CInt {
      descriptors[0]
    }

    init() throws {
      guard pipe(&descriptors) == 0 else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
    }

    func closeAll() {
      if descriptors[0] >= 0 {
        close(descriptors[0])
        descriptors[0] = -1
      }
      closeWriteDescriptor()
    }

    func closeWriteDescriptor() {
      if descriptors[1] >= 0 {
        close(descriptors[1])
        descriptors[1] = -1
      }
    }

    func write(_ bytes: [UInt8]) throws {
      let written = bytes.withUnsafeBufferPointer { buffer in
        systemWrite(descriptors[1], buffer.baseAddress, bytes.count)
      }

      guard written == bytes.count else {
        throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
      }
    }
  }

  private func systemWrite(
    _ fileDescriptor: CInt,
    _ buffer: UnsafePointer<UInt8>?,
    _ count: Int
  ) -> Int {
    #if os(macOS)
      Darwin.write(fileDescriptor, buffer, count)
    #elseif os(Linux)
      Glibc.write(fileDescriptor, buffer, count)
    #endif
  }
#endif
