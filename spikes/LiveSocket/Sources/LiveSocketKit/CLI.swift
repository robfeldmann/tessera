import Foundation
import Tessera
import TesseraTerminalSnapshotSupport

/// Hand-rolled argument parsing for the `livesocket` executable.
public enum CLI {
  public static let environmentKey = "TESSERA_DEBUG_SOCKET"

  static let usage = """
    usage:
      livesocket run [--socket PATH]            run the counter app; PATH or $TESSERA_DEBUG_SOCKET opens the control socket
      livesocket ctl [--socket PATH] [--timeout SECONDS] '{"op":"text"}'
                                                send one request; exit 0 ok, 1 {"ok":false}, 2 usage, 3 no socket
      livesocket vt-replay --size COLSxROWS FILE
                                                feed recorded terminal bytes to a Ghostty VT and print its text
    ops: \(ControlProtocol.operationNames.joined(separator: ", "))
    """

  public static func main(_ arguments: [String]) async -> Int32 {
    var arguments = arguments[...]
    guard let command = arguments.popFirst() else {
      return fail(usage)
    }
    do {
      switch command {
      case "run":
        return try await run(&arguments)
      case "ctl":
        return try control(&arguments)
      case "vt-replay":
        return try replay(&arguments)
      case "-h", "--help", "help":
        print(usage)
        return 0
      default:
        return fail("unknown command \"\(command)\"\n\(usage)")
      }
    } catch let error as UsageError {
      return fail("\(error.message)\n\(usage)")
    } catch {
      FileHandle.standardError.write(Data("livesocket: \(error)\n".utf8))
      return 1
    }
  }

  private struct UsageError: Error {
    let message: String
  }

  private static func fail(_ message: String) -> Int32 {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    return ControlClient.ExitCode.usage
  }

  private static func run(_ arguments: inout ArraySlice<String>) async throws -> Int32 {
    var socketPath = ProcessInfo.processInfo.environment[environmentKey]
    while let argument = arguments.popFirst() {
      guard argument == "--socket", let path = arguments.popFirst() else {
        throw UsageError(message: "run: unexpected argument \"\(argument)\"")
      }
      socketPath = path
    }
    guard isatty(STDIN_FILENO) != 0, isatty(STDOUT_FILENO) != 0 else {
      throw UsageError(message: "run needs an interactive terminal on stdin and stdout")
    }
    try await LiveRunner.run(options: LiveRunner.Options(socketPath: socketPath))
    return 0
  }

  private static func control(_ arguments: inout ArraySlice<String>) throws -> Int32 {
    var socketPath = ProcessInfo.processInfo.environment[environmentKey]
    var timeout: TimeInterval = 10
    var request: String?
    while let argument = arguments.popFirst() {
      switch argument {
      case "--socket":
        guard let path = arguments.popFirst() else {
          throw UsageError(message: "ctl: --socket needs a path")
        }
        socketPath = path
      case "--timeout":
        guard let text = arguments.popFirst(), let seconds = TimeInterval(text), seconds > 0 else {
          throw UsageError(message: "ctl: --timeout needs a positive number of seconds")
        }
        timeout = seconds
      default:
        guard request == nil else {
          throw UsageError(message: "ctl: unexpected argument \"\(argument)\"")
        }
        request = argument
      }
    }
    guard let socketPath else {
      throw UsageError(message: "ctl: pass --socket PATH or set \(environmentKey)")
    }
    guard let request else {
      throw UsageError(message: "ctl: missing the JSON request")
    }
    let result = ControlClient.run(request: request, path: socketPath, timeout: timeout)
    print(result.output)
    return result.exitCode
  }

  private static func replay(_ arguments: inout ArraySlice<String>) throws -> Int32 {
    guard arguments.popFirst() == "--size", let size = arguments.popFirst(),
      let file = arguments.popFirst(), arguments.isEmpty
    else {
      throw UsageError(message: "vt-replay: expected --size COLSxROWS FILE")
    }
    let parts = size.split(separator: "x").compactMap { Int($0) }
    guard parts.count == 2 else {
      throw UsageError(message: "vt-replay: size must look like 80x24")
    }
    let bytes = try Data(contentsOf: URL(fileURLWithPath: file))
    let terminal = VirtualTerminal.ghostty(cols: parts[0], rows: parts[1])
    terminal.feed(Array(bytes))
    for row in Projection.rows(of: terminal.snapshot()) {
      print(row)
    }
    return 0
  }
}
