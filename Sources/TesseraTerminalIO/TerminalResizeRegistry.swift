import Dispatch
import TesseraTerminalCore

#if os(macOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

#if os(macOS) || os(Linux)
  /// Produces terminal-size changes from SIGWINCH notifications.
  package enum TerminalResizeRegistry {
    /// Creates a stream that yields sizes returned by `querySize` when SIGWINCH arrives.
    package static func sizeChanges(
      querySize: @escaping @Sendable () async throws -> TerminalSize
    ) -> AsyncStream<TerminalSize> {
      AsyncStream { continuation in
        signal(SIGWINCH, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGWINCH)

        source.setEventHandler {
          Task {
            do {
              continuation.yield(try await querySize())
            } catch {
              // Resize streams are notifications; a failed size query is ignored so a
              // later SIGWINCH can still yield a valid size.
            }
          }
        }

        source.setCancelHandler {
          continuation.finish()
        }

        continuation.onTermination = { _ in
          source.cancel()
        }

        source.resume()
      }
    }
  }
#endif
