import Dispatch
import TesseraTerminalCore

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

    /// Creates a stream that yields sizes for deterministic notification streams.
    package static func sizeChanges(
      querySize: @escaping @Sendable () async throws -> TerminalSize,
      notifications: AsyncStream<Void>
    ) -> AsyncStream<TerminalSize> {
      AsyncStream { continuation in
        let task = Task {
          for await _ in notifications {
            do {
              continuation.yield(try await querySize())
            } catch {
              // Resize streams are notifications; a failed size query is ignored so a
              // later notification can still yield a valid size.
            }
          }
          continuation.finish()
        }

        continuation.onTermination = { _ in
          task.cancel()
        }
      }
    }
  }

  /// Owns the process's SIGWINCH Dispatch source for one size-change stream.
  ///
  /// `DispatchSourceSignal` does not conform to `Sendable`, but the source never escapes
  /// this class. The type is `Sendable` because of a lifecycle invariant the compiler
  /// cannot see: the source is configured once in `init`, then receives exactly one
  /// `resume()` (from `sizeChanges`) and exactly one `cancel()` (from the stream's
  /// `onTermination`). The event handler runs on Dispatch's default queue and only spawns
  /// a `Task` that queries the size and yields into the continuation. The continuation is
  /// finished solely from the cancel handler, so the stream ends after the source stops
  /// delivering events.
  ///
  /// `init` sets `signal(SIGWINCH, SIG_IGN)` so no default action runs for the signal
  /// while Dispatch, which still observes ignored signals, delivers it to the source. The
  /// disposition is process-wide and is never restored: restoring the previous one can
  /// race with another source that also sets it.
  private final class ResizeSignalSource: Sendable {
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
