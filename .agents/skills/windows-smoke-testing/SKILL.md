---
name: windows-smoke-testing
description:
  Smoke test Tessera example apps and terminal behavior on the UTM Windows Frost VM. Use
  when changing Windows terminal I/O, render output, protocol demos, or example apps.
version: 0.1.0
---

# Windows Smoke Testing

Use the UTM Windows Frost VM to prove example apps work against a real Windows console,
not only stubbed syscalls.

## Prerequisites

- UTM Windows Frost VM is booted.
- Source tree is the macOS checkout.
- Use `pnpm`/`pnpx` for Node tooling if needed; use SwiftPM directly inside Windows.
- Prefer `SSHPASS` in the environment for SSH automation; do not paste passwords into
  transcripts unless the user already asked for that credential.

Find the VM IP:

```sh
utmctl ip-address tessera-frost-import
```

Fallback inside the Windows guest:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
  Select-Object -ExpandProperty IPAddress
```

## Sync Current Source

From macOS:

```sh
just windows-frost sync-utm <vm-ip>
```

This replaces `C:\Users\tester\tessera` in the Windows guest. If sync fails because an
example executable is locked, stop the stale process and sync again:

```sh
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  tester@<vm-ip> "taskkill /IM <ExampleName>.exe /F"

just windows-frost sync-utm <vm-ip>
```

## Build an Example on Windows

Use SwiftPM directly; `just` and `fzf` are not required in the Windows guest.

```sh
sshpass -e ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -o PreferredAuthentications=password -o PubkeyAuthentication=no \
  tester@<vm-ip> \
  "powershell -NoProfile -Command \"cd C:\\Users\\tester\\tessera; swift build --package-path .\\Examples --product <ProductName>\""
```

Run manually in the UTM GUI for visual confirmation:

```powershell
cd C:\Users\tester\tessera
swift run --package-path .\Examples <ProductName>
```

Built executables are usually under:

```text
C:\Users\tester\tessera\Examples\.build\aarch64-unknown-windows-msvc\debug\<ProductName>.exe
```

## Automated PTY Smoke Pattern

For scripted smoke tests, drive an interactive SSH PTY from an `eval` cell or another real
program, not a fragile shell one-liner. Pattern:

1. Start `ssh -tt tester@<vm-ip>` running the built `.exe`.
2. Wait for initial render.
3. Write bytes to stdin with short sleeps between semantic inputs.
4. Send `q` or the app's documented quit key.
5. Assert exit code `0` and inspect captured output for observable text.

Keep a GUI/manual pass for visual rendering issues; byte capture cannot prove glyph cell
alignment.

## Choosing Smoke Coverage

Choose inputs from the behavior being changed rather than from a specific executable,
scene, or sample.

Prefer smoke scenarios that prove one externally visible contract at a time:

- startup reaches an interactive terminal state
- ordinary printable keys reach the application
- Enter or another transition key advances the application state
- the documented quit key exits with status `0`
- bracketed paste is parsed as paste when the app supports it
- resize invalidates/redraws without corrupting output
- visual ruler/cell-alignment checks look correct in the UTM GUI

Useful input sequences:

```text
printable keys:      h e l
transition key:      ENTER
quit key:            q
bracketed paste:     ESC [ 200 ~ pasted text ESC [ 201 ~
page navigation:     app-specific next/previous keys, with short sleeps between inputs
```

Assertions should be stable and behavior-oriented:

- process exits `0`
- captured output contains a readiness marker
- captured output contains the expected parsed key/paste/transition marker
- captured output contains the expected restored/cleanup marker
- a GUI screenshot shows aligned cell rulers or expected terminal styling

Keep scenario-specific names, scene numbers, and sample text in the task, test, or
investigation that used them.

## Validation Checklist

For non-trivial Windows terminal changes:

1. Build the affected example locally:

   ```sh
   swift build --package-path Examples --product <ProductName>
   ```

2. Sync to UTM Windows Frost:

   ```sh
   just windows-frost sync-utm <vm-ip>
   ```

3. Build the affected example on Windows.
4. Run an automated PTY smoke when possible.
5. Run the app in the UTM GUI when the behavior is visual or glyph-width-sensitive.
6. Run the narrowest relevant Swift test filter, on Windows if the code is Windows-only.
7. Run changed-file quality before yielding:

   ```sh
   just quality changed
   ```
