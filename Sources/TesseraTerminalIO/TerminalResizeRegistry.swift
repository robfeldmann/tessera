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
        let signalSource = ResizeSignalSource(
          querySize: querySize,
          continuation: continuation
        )

        continuation.onTermination = { _ in
          signalSource.cancel()
        }

        signalSource.resume()
      }
    }
  }

  /// Sendable wrapper around a Dispatch signal source.
  ///
  /// `DispatchSourceSignal` is thread-safe but does not currently conform to `Sendable`.
  /// This wrapper keeps the source private and exposes only `resume()` and `cancel()`,
  /// which are safe to call from the stream termination closure.
  private final class ResizeSignalSource: @unchecked Sendable {
    private let source: any DispatchSourceSignal

    init(
      querySize: @escaping @Sendable () async throws -> TerminalSize,
      continuation: AsyncStream<TerminalSize>.Continuation
    ) {
      signal(SIGWINCH, SIG_IGN)
      source = DispatchSource.makeSignalSource(signal: SIGWINCH)

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
    }

    func cancel() {
      source.cancel()
    }

    func resume() {
      source.resume()
    }
  }
#endif
