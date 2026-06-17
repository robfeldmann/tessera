# Tessera DevTools

This package contains development-only utilities for working on Tessera. It is included in
`Tessera.xcworkspace` so tools can appear in Xcode's scheme picker without becoming part
of the main library package or public API.

## Linux VM Tests

`Linux VM Tests` is a small executable wrapper around the canonical Linux validation
command:

```fish
just linux test
```

Use it from Xcode when you want a visible reminder or one-click way to run the Linux test
suite. It is intentionally not part of the normal `Tessera` test plan because it may start
a Lima VM, requires local Linux tooling, and takes longer than the macOS unit tests.

The executable delegates to `just linux test`, which:

- starts the `tessera-linux` Lima VM without prompting when needed;
- runs the Linux build of `libghostty-vt`;
- runs `swift test --jobs 2` inside the VM;
- stops the VM afterward only if the command started it.

If the VM is already running, it is left running.

## Recommended usage

For day-to-day terminal use, prefer:

```fish
just linux test
```

From Xcode, open `Tessera.xcworkspace`, select the `Linux VM Tests` scheme, and run it.
Failures are reported as executable failures in Xcode rather than as structured Test
Navigator entries, so the CLI remains the best place for detailed Linux debugging.

## Requirements

- `just` available on `PATH`, or installed at `/opt/homebrew/bin/just`
- Lima installed and configured by the project scripts
- Swift toolchain installed inside the VM via the project's Linux setup flow
