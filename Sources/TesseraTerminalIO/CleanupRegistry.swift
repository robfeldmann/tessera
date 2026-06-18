import CTesseraTerminalPlatform

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
  #elseif os(Windows)
    package static func install(
      inputHandle: UInt,
      outputHandle: UInt,
      teardownBytes: [UInt8],
      savedInputMode: UInt32,
      savedOutputMode: UInt32
    ) {
      teardownBytes.withUnsafeBufferPointer { buffer in
        tessera_cleanup_install_windows(
          UnsafeMutableRawPointer(bitPattern: inputHandle),
          UnsafeMutableRawPointer(bitPattern: outputHandle),
          buffer.baseAddress,
          buffer.count,
          savedInputMode,
          savedOutputMode
        )
      }
    }
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

  /// Returns whether the C cleanup shim currently stores saved terminal attributes.
  package static func hasSavedTermiosForTesting() -> Bool {
    tessera_cleanup_has_saved_termios_for_testing() != 0
  }

  /// Returns whether the C cleanup shim currently stores saved Windows console modes.
  package static func hasSavedWindowsModesForTesting() -> Bool {
    tessera_cleanup_has_saved_windows_modes_for_testing() != 0
  }

  /// Returns whether the C cleanup shim has installed process cleanup handlers.
  package static func hasInstalledHandlersForTesting() -> Bool {
    tessera_cleanup_has_installed_handlers_for_testing() != 0
  }

  /// Clears the C cleanup shim's installed-handlers flag so tests can prove the query is
  /// side-effect free without installing real process handlers.
  package static func resetHandlersForTesting() {
    tessera_cleanup_reset_handlers_for_testing()
  }
}
