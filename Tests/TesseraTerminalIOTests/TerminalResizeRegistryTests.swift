import CustomDump
import TesseraTerminalCore
import Testing

@testable import TesseraTerminalIO

#if os(macOS) || os(Linux)
  @Test
  func `resize registry yields queried sizes for notifications`() async throws {
    let (notifications, notificationContinuation) = AsyncStream.makeStream(of: Void.self)
    let sizes = [
      TerminalSize(columns: 80, rows: 24),
      TerminalSize(columns: 100, rows: 30),
    ]
    let calls = SyscallCallCounter()
    let stream = TerminalResizeRegistry.sizeChanges(
      querySize: { sizes[calls.increment()] },
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
    let calls = SyscallCallCounter()
    let stream = TerminalResizeRegistry.sizeChanges(
      querySize: {
        if calls.increment() == 0 {
          throw PlatformIOError.terminalSizeUnavailable(errno: .ioError)
        }
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

  @Test(.timeLimit(.minutes(1)))
  func `resize stream termination cancels notification producer`() async throws {
    let (terminations, terminationContinuation) = AsyncStream.makeStream(of: Void.self)
    let notifications = AsyncStream<Void> { continuation in
      continuation.onTermination = { _ in terminationContinuation.yield() }
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

    // Resumes when the notification stream is terminated; a producer that is never
    // cancelled leaves this waiting until the time limit fails the test.
    var terminationIterator = terminations.makeAsyncIterator()
    let terminated: Void? = await terminationIterator.next()
    #expect(terminated != nil)
  }
#endif
