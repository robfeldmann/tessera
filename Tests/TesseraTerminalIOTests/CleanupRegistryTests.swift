import CustomDump
import Testing

@testable import TesseraTerminalIO

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

#if os(macOS) || os(Linux)
  @Suite(.serialized)
  struct CleanupRegistryTests {
    @Test
    func `cleanup registry writes installed teardown bytes`() async throws {
      let pipe = try FileDescriptorPipe()
      defer {
        CleanupRegistry.clear()
        pipe.closeAll()
      }

      CleanupRegistry.install(
        inputFileDescriptor: -1,
        outputFileDescriptor: pipe.writeDescriptor,
        teardownBytes: [0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x6C],
        savedTermios: nil
      )

      CleanupRegistry.performEmergencyCleanupForTesting()
      pipe.closeWriteDescriptor()

      let bytes = try pipe.readAll()
      expectNoDifference(bytes, [0x1B, 0x5B, 0x3F, 0x31, 0x30, 0x34, 0x39, 0x6C])
    }

    @Test
    func `cleanup registry clear removes installed teardown bytes`() async throws {
      let pipe = try FileDescriptorPipe()
      defer {
        CleanupRegistry.clear()
        pipe.closeAll()
      }

      CleanupRegistry.install(
        inputFileDescriptor: -1,
        outputFileDescriptor: pipe.writeDescriptor,
        teardownBytes: [0x1B],
        savedTermios: nil
      )
      CleanupRegistry.clear()
      CleanupRegistry.performEmergencyCleanupForTesting()
      pipe.closeWriteDescriptor()

      let bytes = try pipe.readAll()
      expectNoDifference(bytes, [])
    }
  }

  private final class FileDescriptorPipe: @unchecked Sendable {
    private var descriptors: [CInt] = [-1, -1]

    var writeDescriptor: CInt {
      descriptors[1]
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

    func readAll() throws -> [UInt8] {
      var bytes: [UInt8] = []
      var buffer = [UInt8](repeating: 0, count: 32)

      while true {
        let capacity = buffer.count
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
          systemRead(descriptors[0], pointer.baseAddress, capacity)
        }

        if count > 0 {
          bytes.append(contentsOf: buffer.prefix(count))
        } else if count == 0 {
          return bytes
        } else if errno == EINTR {
          continue
        } else {
          throw PlatformIOError.writeFailed(errno: .init(rawValue: errno))
        }
      }
    }
  }

  private func systemRead(
    _ fileDescriptor: CInt,
    _ buffer: UnsafeMutablePointer<UInt8>?,
    _ count: Int
  ) -> Int {
    #if os(macOS)
      Darwin.read(fileDescriptor, buffer, count)
    #elseif os(Linux)
      Glibc.read(fileDescriptor, buffer, count)
    #endif
  }
#endif
