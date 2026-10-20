import Tessera
import TesseraTerminalSnapshotSupport

/// A dev-owned run loop over `TerminalSession` with an optional control socket.
///
/// The loop is the only code that touches the app, the graph, or the terminal. Real input and
/// control requests arrive as messages on one merged stream, so an injected key goes through
/// exactly the same `step` as a typed one and every reply is produced between two steps.
public enum LiveRunner {
  public struct Options: Sendable {
    /// Where to serve the control socket; `nil` leaves the endpoint closed (the default).
    public var socketPath: String?

    /// Leaves the loop when terminal input ends. Headless tests turn this off.
    public var exitWhenInputCloses: Bool

    public init(socketPath: String? = nil, exitWhenInputCloses: Bool = true) {
      self.socketPath = socketPath
      self.exitWhenInputCloses = exitWhenInputCloses
    }
  }

  private enum Message: Sendable {
    case control(ControlRequest)
    case inputEnded
    case terminal(InputEvent)
  }

  /// Opens the real terminal and runs `CounterApp`.
  public static func run(options: Options) async throws {
    try await TerminalSession.withApplicationTerminal(
      configuration: .default
    ) { terminal in
      try await loop(app: CounterApp(), options: options, terminal: terminal)
    }
  }

  /// Runs the merged event loop until the app, a `quit` request, or terminal input ends it.
  public static func loop<App: LiveApp>(
    app: App,
    options: Options,
    terminal: isolated TerminalSession
  ) async throws {
    let server: ControlServer? =
      if let path = options.socketPath {
        try await ControlServer.start(path: path)
      } else {
        nil
      }

    let (messages, sink) = AsyncStream<Message>.makeStream()
    // Public-API merge point: `nextEvent()` is pumped into the same stream the control
    // requests use, so the loop never awaits the terminal directly.
    let inputPump = Task.detached {
      do {
        while true {
          sink.yield(.terminal(try await terminal.nextEvent()))
        }
      } catch {
        sink.yield(.inputEnded)
      }
    }
    let controlPump = Task.detached {
      guard let server else {
        return
      }
      for await request in server.requests {
        sink.yield(.control(request))
      }
    }

    let context = LoopContext(app: app)

    do {
      try await context.draw(on: terminal)
      loop: for await message in messages {
        switch message {
        case .terminal(let event):
          guard try await context.step(event, on: terminal) else {
            break loop
          }

        case .inputEnded:
          if options.exitWhenInputCloses {
            break loop
          }

        case .control(let request):
          switch request.operation {
          case .text:
            let reply = ControlProtocol.success(context.screenReply().members)
            await server?.reply(request.id, reply)

          case .tree:
            await server?.reply(
              request.id,
              ControlProtocol.success(Projection.tree(context.app.graph.diagnostics).members)
            )

          case .key(let key, let name):
            let before = context.frames
            let keepRunning = try await context.step(.key(key), on: terminal)
            if !keepRunning {
              await server?.stopListening()
            }
            await server?.reply(
              request.id,
              ControlProtocol.success([
                "frame": .int(context.frames),
                "key": .string(name),
                "redrawn": .bool(context.frames != before),
              ])
            )
            if !keepRunning {
              break loop
            }

          case .quit:
            // Unlink first so the path is gone by the time the client reads `ok`.
            await server?.stopListening()
            await server?.reply(request.id, ControlProtocol.success())
            break loop
          }
        }
      }
    } catch {
      inputPump.cancel()
      controlPump.cancel()
      await server?.shutdown()
      throw error
    }

    inputPump.cancel()
    controlPump.cancel()
    await server?.shutdown()
  }
}

/// Loop-owned mutable state. Every method that touches the terminal takes it as `isolated`,
/// so the whole step runs inside the session actor exactly like the Showcase loop.
private final class LoopContext<App: LiveApp> {
  let app: App
  private(set) var drawnSize = TerminalSize(columns: 1, rows: 1)
  private(set) var frames = 0

  init(app: App) {
    self.app = app
  }

  func draw(on terminal: isolated TerminalSession) async throws {
    try await terminal.draw { frame in
      drawnSize = frame.size
      app.graph.render(into: frame)
    }
    frames += 1
  }

  /// The canonical step: dispatch, model update, graph update, then draw when dirty.
  func step(_ event: InputEvent, on terminal: isolated TerminalSession) async throws -> Bool {
    _ = app.graph.dispatch(event)
    guard app.apply(event) else {
      return false
    }
    if case .resize(let size) = event {
      app.graph.resize(to: size)
    }
    app.graph.update()
    if app.graph.needsRender {
      try await draw(on: terminal)
    }
    return true
  }

  /// Render mirror: the current graph into a throwaway Ghostty VT, never the live terminal.
  func screenReply() -> JSONValue {
    let snapshot = VirtualTerminal.snapshot(size: drawnSize) { frame in
      app.graph.render(into: frame)
    }
    return Projection.screen(snapshot, frame: frames, size: drawnSize)
  }
}

extension JSONValue {
  /// The members of an object value; empty for any other case.
  var members: [String: JSONValue] {
    guard case .object(let members) = self else {
      return [:]
    }
    return members
  }
}
