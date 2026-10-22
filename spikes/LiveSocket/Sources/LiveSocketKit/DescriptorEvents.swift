import Dispatch
import Foundation

/// Read-readiness notifications for a non-blocking descriptor, delivered as an `AsyncStream`.
///
/// The stream owns the descriptor: `cancel()` finishes the stream and closes the descriptor
/// from the dispatch source's cancel handler, which is the only point where closing is safe
/// while a source is registered. Events coalesce (`bufferingNewest(1)`), so consumers drain
/// the descriptor until `EAGAIN` before awaiting the next event.
final class DescriptorEvents: Sendable {
  let descriptor: Int32
  let readable: AsyncStream<Void>
  private let continuation: AsyncStream<Void>.Continuation
  private let source: any DispatchSourceRead

  init(descriptor: Int32) {
    let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let source = DispatchSource.makeReadSource(
      fileDescriptor: descriptor,
      queue: DispatchQueue.global(qos: .utility)
    )
    source.setEventHandler { continuation.yield() }
    source.setCancelHandler { _ = close(descriptor) }
    self.descriptor = descriptor
    self.readable = stream
    self.continuation = continuation
    self.source = source
    source.resume()
  }

  /// Ends the event stream without touching the descriptor.
  func finish() {
    continuation.finish()
  }

  /// Ends the event stream and closes the descriptor. Safe to call more than once.
  func cancel() {
    continuation.finish()
    source.cancel()
  }
}
