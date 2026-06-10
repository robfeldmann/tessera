import CTesseraTerminalPlatform

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

/// Registers signal-safe terminal cleanup state for catastrophic exits.
///
/// POSIX signal handlers may only perform a very small set of async-signal-safe
/// operations. Tessera keeps the unsafe surface in `CTesseraTerminalPlatform`: Swift
/// prepares immutable teardown bytes and saved termios, while the C shim only loads the
/// current state and uses syscalls (`write(2)`, `tcsetattr`, `signal`, `raise`) on the
/// die-now path.
package enum CleanupRegistry {
  /// Installs the current emergency cleanup state.
  #if os(macOS) || os(Linux)
    package static func install(
      inputFileDescriptor: CInt,
      outputFileDescriptor: CInt,
      teardownBytes: [UInt8],
      savedTermios: termios?
    ) {
      teardownBytes.withUnsafeBufferPointer { buffer in
        guard var termiosCopy = savedTermios else {
          tessera_cleanup_install(
            inputFileDescriptor,
            outputFileDescriptor,
            buffer.baseAddress,
            buffer.count,
            nil
          )
          return
        }

        withUnsafePointer(to: &termiosCopy) { termiosPointer in
          tessera_cleanup_install(
            inputFileDescriptor,
            outputFileDescriptor,
            buffer.baseAddress,
            buffer.count,
            termiosPointer
          )
        }
      }
    }
  #else
    package static func install(
      inputFileDescriptor _: CInt,
      outputFileDescriptor _: CInt,
      teardownBytes _: [UInt8],
      savedTermios _: Never?
    ) {}
  #endif

  /// Clears the current emergency cleanup state.
  package static func clear() {
    tessera_cleanup_clear()
  }

  /// Installs process-level signal handlers and the `atexit` backstop once.
  package static func installHandlers() {
    tessera_cleanup_install_handlers()
  }

  /// Performs cleanup through the C shim. Intended for tests and `atexit` backstops.
  package static func performEmergencyCleanupForTesting() {
    tessera_cleanup_perform()
  }
}
