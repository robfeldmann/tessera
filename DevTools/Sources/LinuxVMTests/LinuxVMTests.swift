import Foundation

@main
enum LinuxVMTests {
  static func main() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()

    let script = """
      if command -v mise >/dev/null 2>&1; then
        exec mise run vm:linux-test
      elif [ -x "$HOME/.local/bin/mise" ]; then
        exec "$HOME/.local/bin/mise" run vm:linux-test
      else
        echo "error: mise not found. Install it from https://mise.jdx.dev"
        exit 1
      fi
      """

    let process = Process()
    process.currentDirectoryURL = repositoryRoot
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-lc", script]
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw ExitError(status: process.terminationStatus)
    }
  }
}

private struct ExitError: Error, CustomStringConvertible {
  let status: Int32

  var description: String {
    "Linux VM tests failed with exit code \(status)."
  }
}
