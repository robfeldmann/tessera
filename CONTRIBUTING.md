# Contributing to Tessera

Thank you for your interest in contributing to Tessera! This document provides guidelines
and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to abide by our
[Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When
creating a bug report, include:

- A clear and descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots if applicable
- Environment details (Swift version, platform, etc.)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please provide:

- A clear and descriptive title
- A detailed description of the proposed feature
- Any relevant examples or mockups
- Explanation of why this enhancement would be useful

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run checks and tests (`just ci`)
5. Commit your changes (`git commit -m 'feat: Adds amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

### Prerequisites

- Swift 6.3 or later
- Xcode 26 or later (for macOS development)

### Installing Dependencies (Recommended)

We recommend using [Homebrew](https://brew.sh/) to manage local development tools. We
provide a `Brewfile` to install everything at once:

```sh
brew bundle install
```

This will install the following tools:

- **[SwiftLint](https://github.com/realm/SwiftLint)** (0.54.0): For Swift code linting.
- **[swift-format](https://github.com/apple/swift-format)** (602.0.0): For Swift code
  formatting.
- **[pre-commit](https://pre-commit.com/)**: For managing git hooks.
- **[just](https://github.com/casey/just)**: For running project tasks.
- **[Lima](https://lima-vm.io/)**: For optional Docker-free Linux test runs.
- **[UTM](https://mac.getutm.app/)**: For optional Windows GUI VM runs on Apple Silicon.
- **[QEMU](https://www.qemu.org/)**, **swtpm**, and **sshpass**: For scripted Windows VM
  runs with Frost. Frost uses SSH key authentication once its key exists; `sshpass` is
  still required for provisioning and password-auth fallback.
- **[Prettier](https://prettier.io/)**: For Markdown and config file formatting.
- **[Python 3](https://www.python.org/)**: For local documentation previews
  (`just docs preview`).

Exact versions are pinned in `.pre-commit-config.yaml`.

After installing dependencies, set up the git hooks:

```sh
just setup hooks
```

### Alternative Installation

If you prefer not to use Homebrew, you can install these tools individually using their
respective installation guides linked above. Ensure they are available in your system
`PATH`.

## Local Development Loop

Use `just` for the normal macOS development loop. Recipes are grouped by area; run `just`
to list the available modules and commands.

```sh
just core build
just core test
just quality lint
just docs
```

`just core build` and `just core test` are the fastest checks while editing.
`just quality lint` runs formatting, Swift formatting checks, Markdown checks, and DocC
warnings-as-errors checks. `just docs` generates the combined DocC archive for local
inspection.

If a branch or worktree behaves differently than expected, run `just core doctor` and see
[Local development state](docs/LocalDevelopmentState.md). That page explains which
artifacts are per-checkout, machine-global, or VM-local.

### Linux Cross-Build from macOS

For a lightweight Linux compatibility check without Docker or a VM, install the Static
Linux SDK that matches the local Swift toolchain and build with it:

```sh
just linux install-sdk
just linux build
```

The supported Swift toolchain version lives in `.swift-version`. Matching Static Linux SDK
metadata lives in `scripts/config/swift-sdks.json`, and the `just` recipes read that
metadata for the SDK URL, checksum, and identifier.

`swift sdk install` installs a specific artifact bundle; it does not discover SDKs from a
catalog. The SDK version must match the local Swift toolchain. If the package moves to a
new Swift toolchain, update `.swift-version` and `scripts/config/swift-sdks.json`
together.

This proves the package compiles for Linux from macOS. It does not run the Linux test
suite; tests need a Linux runtime such as Lima or CI.

### Terminal Lifecycle Manual Verification

Terminal lifecycle changes need manual checks in a real terminal in addition to unit
tests. Use two terminal tabs or panes: one to run a Tessera demo/fixture and one to send
signals.

```sh
# Pane 1
cd Examples
swift run LifecycleModesDemo
```

```sh
# Pane 2: find and terminate the fixture
pgrep -fl LifecycleModesDemo
kill -TERM <pid>
```

Verify these cases before merging lifecycle, signal-handling, or renderer changes:

- Press `Ctrl-C` while the fixture is running; the shell should return with normal echo
  and the primary screen visible.
- Send `SIGTERM` from another pane with `kill -TERM <pid>`; the terminal should be
  restored.
- If practical, close the pane/tab or disconnect the session to exercise `SIGHUP`.
- Resize the pane repeatedly while the fixture is running; it should keep responding and
  repaint the full screen after resize.
- While a demo is actively redrawing, interrupt it with `Ctrl-C` or `SIGTERM`;
  synchronized output should not leave a visibly half-rendered frame behind in supported
  terminals, and unsupported terminals should still recover modes and the primary screen.
- If you are testing an injected write/flush failure, the next successful draw should
  erase and repaint conservatively rather than trusting partially written damage bytes.

If a development build ever leaves your terminal wedged, type the recovery command for
your platform even if input is not visible, then press Enter.

On macOS and Linux:

```sh
reset
```

If `reset` does not restore normal input echo, try:

```sh
stty sane
```

On Windows PowerShell, emit terminal reset and visibility sequences directly because
Windows has no native `reset` or `stty sane` command:

```powershell
[Console]::Write([char]27 + '[?1049l' + [char]27 + '[?25h' + [char]27 + 'c')
```

### Linux Test Runs with Lima

Use [Lima](https://lima-vm.io/) when you want to run `swift test` on Linux without Docker.
Create and start an Ubuntu 24.04 instance:

```sh
just linux start
```

The checked-in Lima config creates an Ubuntu 24.04 VM with 4 CPUs and 12 GiB of memory,
mounts this repository into the VM, installs Linux build tools, and installs Swift from
`.swift-version` using Swiftly. The default VM name is `tessera-linux`; set
`TESSERA_LINUX_VM_NAME` when two worktrees need separate running VMs. Once the VM is
ready, run the Linux test suite from macOS:

```sh
just linux test
```

To run a focused Linux test from macOS, pass SwiftPM test arguments after `--`. The recipe
keeps the Linux defaults (`--jobs 2 --no-parallel`) and appends your filter:

```sh
just linux test -- --filter PlatformHandlesTests
```

Prefer this targeted form while iterating; use `just linux test` for the full Linux suite.

You can also open a shell in the VM for debugging:

```sh
just linux shell
cd /path/to/tessera
swift test
```

When finished, stop the VM (_you may need to `exit` the VM to return to macOS_):

```sh
just linux stop
```

Remove it entirely when you want a fresh environment next time. Stop the VM before
deleting it:

```sh
just linux stop
just linux delete
```

### Windows Test Runs

Windows development on an Apple Silicon Mac has two supported local VM workflows:

- **Recommended scripted workflow:** use Frost for repeatable image builds, disposable
  test runs, persistent SSH sessions, and optional UTM GUI import. Start with
  [Windows VM with Frost](docs/WindowsFrostVM.md).
- **Manual desktop workflow:** use UTM directly when you want to create and manage the
  Windows VM yourself. Follow [Manual Windows VM with UTM](docs/WindowsVM.md).

For the normal Frost test loop, build the Frost images once, then run:

```sh
just windows-frost test
```

To run a focused Frost test, pass SwiftPM test arguments after `--`. The recipe keeps the
Windows default (`--no-parallel`) and appends your filter:

```sh
just windows-frost test -- --filter WindowsInputLoopTests
```

The hosted CI matrix runs macOS, Linux, and Windows. Windows uses a split build/test shape
so the SwiftPM cache can be saved immediately after `swift build`, then runs the full
Windows suite with `swift test --no-parallel`. If a future Windows bring-up needs a
focused local loop again, `just ci ci-windows` accepts `TESSERA_CI_WINDOWS_TEST_FILTER`:

```sh
TESSERA_CI_WINDOWS_TEST_FILTER=TesseraTerminalIOTests just ci ci-windows
```

To spend fewer hosted minutes while iterating:

- Prove changes locally in Frost or UTM before pushing.
- Keep the `skip-ci` label on draft PRs until a hosted run is needed.
- Push one fixup commit per validation attempt so workflow concurrency cancels obsolete
  runs.
- Rerun only failed jobs in GitHub Actions; avoid rerunning the full workflow unless setup
  or cache state changed.

The CI workflow restores the SwiftPM cache before `swift build`, keyed by the runner OS,
architecture, `.swift-version`, and `Package.resolved`; when there is no exact cache hit,
it saves the cache immediately after a successful build and before tests. Hosted
macOS/Linux jobs pin `GHOSTTY_VT_OUTPUT_DIR` to `.build/libghostty-vt` so the Ghostty
header symlink and linker flags agree. Windows does not resolve the Swift-DocC plugin or
build libghostty-vt during this slice, so DocC/Ghostty cache state and prerequisites
remain non-Windows concerns.

For manual GUI validation, run a Tessera terminal demo in each Windows host terminal you
intend to support:

- Windows Terminal running PowerShell.
- PowerShell in classic conhost.
- `cmd.exe` in classic conhost.

In each host, verify arrow keys, `q` clean exit, `Ctrl-C` cleanup, resize-driven redraw,
and terminal restoration. After interruption, the prompt should return with normal input
echo, a visible cursor, and the primary screen active.

For manual UTM VM runs, bootstrap the VM and then run:

```sh
export TESSERA_WINDOWS_VM_SSH=tessera-windows
just windows-utm check
just windows-utm test
```

Manual UTM tests accept the same forwarded SwiftPM arguments:

```sh
just windows-utm test -- --filter WindowsConsoleModeTests
```

Use the detailed guides above for first-time setup, SSH configuration, GUI validation, and
troubleshooting.

### Pre-commit Hooks

We use the [pre-commit](https://pre-commit.com/) framework to ensure code quality and
conventional commit messages. To install it:

```sh
# Install the framework (if not already installed)
brew install pre-commit

# Install the hooks for this project
just setup hooks
```

This will configure Git to run `swift-format`, `swiftlint`, and commit message checks
automatically.

### Linting

```sh
# Run all linters (auto-fixes safe issues first)
just quality lint

# Or run individual linters
swiftlint
swift-format lint -r Sources Tests Package.swift
```

### Formatting

```sh
swift-format format -i -r Sources Tests
```

## Coding Standards

### General Guidelines

- Follow Swift API Design Guidelines
- Use Swift 6 language features appropriately
- Write documentation comments for public APIs
- Keep functions small and focused
- Prefer value types over reference types when appropriate

### Code Style

- **Indentation**: 2 spaces (no tabs)
- **Line length**: Maximum 90 characters (soft limit), 150 characters (hard limit)
- **Trailing commas**: Required in multi-line arrays and dictionaries
- **Imports**: Sorted alphabetically
- **Properties**: Sorted alphabetically within their visibility groups
- **Naming**: Use camelCase for variables/functions, PascalCase for types

### Concurrency

- Use structured concurrency whenever possible
- Mark async functions appropriately
- Use actors for shared mutable state
- Enable strict concurrency checking

### Testing

- Write tests for all new functionality
- Use Swift Testing framework
- Follow the Arrange-Act-Assert pattern
- Test edge cases and error conditions
- Aim for high code coverage

## Review Process

All submissions require review. Reviewers will check for:

- Correctness and completeness
- Code style and conventions
- Test coverage
- Documentation
- Performance implications

## License

By contributing, you agree that your contributions will be licensed under the project's
license.
