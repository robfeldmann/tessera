---
name: Windows AppleDouble Source Sync Warning
date: 2026-07-04
status: resolved
---

# Windows AppleDouble Source Sync Warning

## Question

Why does a Windows Swift build after macOS source sync warn that the
`CTesseraTerminalPlatform` umbrella header does not include
`._CTesseraTerminalPlatform.h`?

## Findings

- The Frost UTM source sync archives the macOS working tree in
  `scripts/windows-frost-sync-source.sh` using `git ls-files ... | tar ...`.
- After syncing to the Windows guest, `Get-ChildItem -Recurse -Force -Filter "._*"` found
  AppleDouble files throughout `C:\Users\tester\tessera`, including beside C headers under
  `Sources\CTesseraTerminalPlatform\include`.
- A Windows SwiftPM build reproduced the warning:
  `umbrella header for module 'CTesseraTerminalPlatform' does not include header '._CTesseraTerminalPlatform.h'`.
- The source archive is created on macOS; BSD tar can emit AppleDouble metadata files
  unless the copyfile behavior is disabled.

## Conclusion

Set `COPYFILE_DISABLE=1` for the source archive `tar` invocation and exclude any real
`._*` paths from the archive input. This prevents AppleDouble metadata from reaching the
Windows checkout, so Clang's module scanner no longer treats those metadata files as
headers.
