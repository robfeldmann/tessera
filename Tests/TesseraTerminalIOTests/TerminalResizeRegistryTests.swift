import CustomDump
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  @Test
  func `resize registry yields queried sizes for notifications`() async throws {
    let (notifications, notificationContinuation) = AsyncStream.makeStream(of: Void.self)
    final class State: @unchecked Sendable { var sizes = [TerminalSize(columns: 80, rows: 24), TerminalSize(columns: 100, rows: 30)] }
    let state = State()
    let stream = TerminalResizeRegistry.sizeChanges(
      querySize: { state.sizes.removeFirst() },
      notifications: notifications
    )
    var iterator = stream.makeAsyncIterator()

    notificationContinuation.yield(())
    notificationContinuation.yield(())
    notificationContinuation.finish()

    let first = await iterator.next()
    let second = await iterator.next()
    let end = await iterator.next()

    expectNoDifference(first, TerminalSize(columns: 80, rows: 24))
    expectNoDifference(second, TerminalSize(columns: 100, rows: 30))
    expectNoDifference(end, nil)
  }

  @Test
  func `resize registry ignores failed queries before later success`() async throws {
    let (notifications, notificationContinuation) = AsyncStream.makeStream(of: Void.self)
    final class State: @unchecked Sendable { var calls = 0 }
    let state = State()
    let stream = TerminalResizeRegistry.sizeChanges(
      querySize: {
        defer { state.calls += 1 }
        if state.calls == 0 { throw PlatformIOError.terminalSizeUnavailable(errno: .ioError) }
        return TerminalSize(columns: 90, rows: 25)
      },
      notifications: notifications
    )
    var iterator = stream.makeAsyncIterator()

    notificationContinuation.yield(())
    notificationContinuation.yield(())
    notificationContinuation.finish()

    let size = await iterator.next()
    let end = await iterator.next()

    expectNoDifference(size, TerminalSize(columns: 90, rows: 25))
    expectNoDifference(end, nil)
  }

  @Test
  func `resize stream termination cancels notification producer`() async throws {
    final class TerminationState: @unchecked Sendable { var terminated = false }
    let state = TerminationState()
    let notifications = AsyncStream<Void> { continuation in
      continuation.onTermination = { _ in state.terminated = true }
    }
    let stream = TerminalResizeRegistry.sizeChanges(
      querySize: { TerminalSize(columns: 1, rows: 1) },
      notifications: notifications
    )
    let pending = Task {
      var iterator = stream.makeAsyncIterator()
      return await iterator.next()
    }

    pending.cancel()
    _ = await pending.value
    for _ in 0..<20 where !state.terminated {
      await Task.yield()
    }

    #expect(state.terminated)
  }
#endif
