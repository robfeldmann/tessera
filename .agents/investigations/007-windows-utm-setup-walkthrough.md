---
name: Windows UTM setup walkthrough
date: 2026-06-14
status: open
---

# Windows UTM setup walkthrough

## Question

What exact steps successfully get a noob-friendly Windows 11 ARM64 + Swift development VM
working for Tessera on Apple Silicon with UTM, and which details should be promoted into
`CONTRIBUTING.md`?

## Findings

- UTM was installed via Homebrew before this walkthrough started.
- Initial docs were too high-level for a contributor who has not installed Windows in UTM
  before.
- Official setup references to verify during the walkthrough:
  - Microsoft Windows 11 Arm ISO download page:
    <https://learn.microsoft.com/en-us/windows/arm/iso>
  - UTM Windows guide: <https://docs.getutm.app/guides/windows/>
  - UTM Windows 11 ARM gallery page: <https://mac.getutm.app/gallery/windows-11-arm>

## Walkthrough log

- Done: acquire Windows 11 ARM64 ISO.
  - Successful entry point used by Rob:
    <https://www.microsoft.com/software-download/windows11arm64> instead of the Learn
    page.
  - Page flow:
    1. Select `Windows 11 (multi-edition ISO for Arm64)` from the download dropdown.
    2. Click `Download Now`.
    3. Select product language: `English (United States)`.
    4. Click `Confirm`.
    5. Click the second `Download Now` button after the language confirmation.
  - The page offers an optional SHA-256 verification step. For English 64-bit, Rob saw:
    `638AA2C88E94385B00F4F178D071E3DF0B7D9E335577A83BD533B7F2EB65ADF0`.
  - Microsoft shows a Windows PowerShell `Get-FileHash` example. On macOS, this worked:
    `shasum -a 256 ~/Downloads/Win11_25H2_English_Arm64_v2.iso`.
  - Downloaded file: `/Users/rob/Downloads/Win11_25H2_English_Arm64_v2.iso`.
  - File size: 7.4 GB.
  - SHA-256 verification succeeded. macOS output:
    `638aa2c88e94385b00f4f178d071e3df0b7d9e335577a83bd533b7f2eb65adf0`.
- In progress: create UTM VM.
  - UTM asked for hardware settings before the ISO picker; otherwise the documented flow
    matched.
  - First boot landed in `UEFI Interactive Shell v2.2` instead of Windows Setup. The
    screen showed `FS0` as `CDROM` and a `Shell>` prompt, which suggests the ISO is
    attached but firmware did not automatically boot the Windows EFI loader.
  - Successful recovery:
    1. At `Shell>`, type `exit`.
    2. In Boot Manager, select `UEFI QEMU QEMU USB HARDDRIVE 1-0000:00:04.0-4.1`.
    3. At `Press any key to boot...`, press Enter quickly.
    4. Windows Setup starts at the language settings dialog.
- In progress: complete Windows install / first boot.
  - Windows Setup language dialog appeared after manual ISO boot.
  - Actual setup flow differed slightly from the predicted flow:
    - Product key screen did not appear before edition selection.
    - Windows 11 Pro was available and selected.
    - Disk selection came after accepting license terms.
    - No separate `Custom: Install Windows only (advanced)` install type screen appeared.
  - Selected the unallocated VM disk and Windows began copying files with the message that
    it will restart several times.
  - On reboot, `Press any key to boot from CD/DVD/USB...` appeared again. Successful
    action: do nothing. The VM continued into the disk-based Windows install flow and
    reached the installing progress screen.
  - First-boot setup flow:
    - Selected country/region.
    - Selected keyboard layout.
    - Skipped adding a second keyboard layout.
    - Windows checked for updates.
    - Setup did not ask `who this device is for`; it asked for a name. Entered `rob`.
    - Left password blank.
    - Windows continued to `getting the latest security updates...`.
    - After updates/desktop transition, `UTM Guest Tools` appeared next.
  - UTM Guest Tools install succeeded by running the installer with defaults; no extra
    interaction was required.
  - VM display resolution improved noticeably after Guest Tools.
  - First paste attempt showed a Windows prompt/button to `Turn on` clipboard history.
- In progress: install/provision Git, Visual Studio C++ tools, Swift, and OpenSSH.
  - Windows basics verification succeeded:
    - `winget --version` -> `v1.28.240`.
    - `hostname` -> `WIN-34624J28GPJ`.
    - `Test-NetConnection github.com -Port 443` succeeded over `Ethernet`, source address
      `192.168.64.2`.
  - After copying from PowerShell, Windows prompted to sign in to Microsoft 365 Copilot;
    ignored because it is unrelated to the dev VM setup.
  - Bootstrap issue found: current docs say to run repo script, but Git may not be
    installed yet. Successful docs should either install Git first with winget or provide
    a one-line script download path.
  - Git install command used:
    `winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements`.
  - `winget` displayed Microsoft Store source agreements/geographic region notice, then
    downloaded `Git-2.54.0-arm64.exe` from GitHub, verified the installer hash, and
    reported `Successfully installed`.
  - In the same PowerShell window immediately after install, `git --version` failed with
    `The term 'git' is not recognized...`; PATH had not refreshed yet.
  - Closing PowerShell and opening a new PowerShell window fixed PATH. `git --version`
    returned `git version 2.54.0.windows.1`.
- In progress: verify macOS SSH access.
  - After pulling commit `996255f`, rerunning `setup-windows-vm.ps1` succeeded.
  - Script output confirmed:
    - Git installed/current.
    - Visual Studio installed/current.
    - Visual Studio C++ workload found at
      `C:\Program Files\Microsoft Visual Studio\2022\Community`.
    - Swift installed/current.
    - Swift version:
      - `Swift version 6.3.2 (swift-6.3.2-RELEASE)`
      - `Target: aarch64-unknown-windows-msvc`
      - `Build config: +assertions`
    - OpenSSH Server running.
    - VM SSH target shown: `ssh rob@192.168.64.2`.
  - From macOS, `ssh rob@192.168.64.2 swift --version` took a while and timed out.
  - macOS diagnostics:
    - `ping -c 3 192.168.64.2` got 100% packet loss.
    - `nc -vz 192.168.64.2 22` timed out.
  - Windows diagnostics:
    - `Get-Service sshd` showed `Running`.
    - `Get-NetTCPConnection -LocalPort 22 -State Listen` showed listeners on `::` and
      `0.0.0.0`.
    - `OpenSSH-Server-In-TCP` firewall rule existed, enabled, inbound allow, but profile
      was only `Private`.
    - `Get-NetConnectionProfile` showed the Ethernet network category is `Public`, so the
      Private-only SSH firewall rule does not apply.
    - Local Windows loopback test succeeded: `Test-NetConnection 127.0.0.1 -Port 22` ->
      `TcpTestSucceeded: True`.
    - A follow-up `nc -vz 192.168.64.2 22` from macOS still timed out. Note: the attempted
      firewall command was missing `-Profile Any`, so retry with the exact command before
      assuming UTM port forwarding is required.
    - Running the exact command
      `Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any` fixed host-to-guest
      SSH reachability.
    - From macOS, `nc -vz 192.168.64.2 22` then succeeded.
    - First SSH connection accepted and stored host key. Blank password failed; OpenSSH
      refused login and disconnected after too many authentication failures. Need either
      set a Windows password for `rob` or configure SSH public-key auth. For noob-friendly
      docs, passwordless Windows accounts should be avoided if SSH is required.
    - Set a Windows password for `rob` with `net user rob *`.
    - From macOS, password SSH then succeeded with:

      ```fish
      ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no rob@192.168.64.2 swift --version
      ```

    - Remote Swift output confirmed 6.3.2 / aarch64 Windows MSVC.
    - `just windows-vm-check` failed with `Permission denied` because the recipe uses
      `ssh -o BatchMode=yes`, which intentionally disables password prompts. Need
      configure SSH public-key auth for the Windows account before the Just recipes can
      work unattended.
    - Generated macOS key as `~/.ssh/tessera_windows` and added it to the Apple keychain
      with `ssh-add --apple-use-keychain ~/.ssh/tessera_windows`.
    - Initial public-key login test `ssh tessera-windows swift --version` failed with
      `Permission denied (publickey,password,keyboard-interactive)`. Likely Windows
      OpenSSH admin-account behavior: members of Administrators may need keys in
      `%ProgramData%\ssh\administrators_authorized_keys` rather than per-user
      `authorized_keys`.
    - A fish one-liner using piped stdin into remote PowerShell was fragile; split the key
      install into `scp` plus Windows-side PowerShell commands instead.
    - First Windows-side attempt accidentally combined `Add-Content` and `icacls` on one
      line, causing `Add-Content : A positional parameter cannot be found...`. Docs should
      show separate commands and use explicit `-Path`/`-Value` arguments.
    - Public-key auth succeeded after copying `~/.ssh/tessera_windows.pub` into the VM,
      appending it to `C:\ProgramData\ssh\administrators_authorized_keys`, and setting
      permissions with
      `icacls ... /inheritance:r /grant Administrators:F /grant SYSTEM:F`.
    - On macOS, `set -x TESSERA_WINDOWS_VM_SSH tessera-windows` followed by
      `just windows-vm-check` succeeded and printed Swift 6.3.2 / aarch64 Windows MSVC.

- Open question discovered during clone step: the most common workflow may be that a macOS
  developer already has the repo cloned locally before provisioning the Windows VM. In
  that case, the preferred first-time VM bootstrap may be: get OpenSSH working first, then
  clone or sync from the local macOS repo rather than from github.com. Need to validate a
  better macOS-to-Windows sync loop after OpenSSH is enabled. Candidate approaches:
  - Use GitHub for committed branch integration only.
  - Add the Windows checkout/bare repo as an SSH git remote from macOS and push local
    branches directly to the VM.
  - Use a generated patch or bundle for unpushed local work.
  - Use file sync only if we can avoid copying `.build` and other platform-specific
    artifacts.
- Done for Phase 0: clone Tessera in the guest and run `swift test --no-parallel` via
  `just test-windows-vm`.
  - From macOS, `just test-windows-vm` successfully connected to the VM, printed Swift
    6.3.2, fetched package dependencies, and began building.
  - Expected Phase 1 compile failure occurred in `CTesseraTerminalPlatform`:
    `fatal error: 'termios.h' file not found` from
    `Sources/CTesseraTerminalPlatform/include/CTesseraTerminalPlatform.h:5:10`.
  - This confirms the Phase 0 workflow is usable enough to expose the planned Phase 1
    Windows-safe package work.
- Provisioning script first run output:
  - Git was already installed; no upgrade available.
  - Visual Studio Community installer downloaded and started, then printed
    `Restart your PC to finish installation.`
  - Despite the restart notice, `vswhere` found Visual Studio at
    `C:\Program Files\Microsoft Visual Studio\2022\Community`.
  - Swift 6.3.2 ARM64 installer downloaded 1.26 GB and reported `Successfully installed`.
  - Script reached `==> Enable OpenSSH Server` and then appeared to sit with a blinking
    cursor/no prompt, but eventually completed. Contributor docs should warn that enabling
    OpenSSH can be silent/slow.
  - OpenSSH capability output after completion:
    - `Online: True`
    - `RestartNeeded: False`
  - Script then failed at `==> Verify Swift version` because `swift.exe` was not on PATH
    in the current PowerShell process. Error said to open a new PowerShell window after
    installation and rerun the script.
  - After reboot, rerunning the script found Git, Visual Studio, and Swift already
    installed. `swift --version` printed
    `Swift version 6.3.2 (swift-6.3.2-RELEASE) Target: aarch64-unknown-windows-msvc` plus
    `Build config: +assertions`, but the script still threw `Expected Swift 6.3.2...`.
    Root cause: PowerShell captures multi-line command output as an array; `-notmatch`
    against the array returns non-matching lines, so the condition was truthy even though
    the first line matched. Fix script by joining `swift --version` output into one string
    before matching.

## Switching VM user from `rob` to `tess`

After drafting docs with generic `tess` user instructions, Rob switched the existing VM
from the original `rob` user to a new `tess` user.

Successful sequence:

1. Create the user from Administrator PowerShell: `net user tess * /add`.
2. Password used during the walkthrough: `Te$$`.
3. Add to administrators: `net localgroup Administrators tess /add`.
4. Sign out and sign in as `tess` once so Windows creates `C:\Users\tess`.
5. Verify identity:
   - `whoami` -> `win-34624j28gpj\tess`
   - `$HOME` -> `C:\Users\tess`
6. Git was available for `tess`, but Swift was not. `winget list --id Swift.Toolchain`
   also showed no Swift package for `tess`, so Swift had to be installed again while
   signed in as `tess`:
   `winget install --id Swift.Toolchain -e --accept-source-agreements --accept-package-agreements`.
7. After reopening PowerShell, `swift --version` worked for `tess` and showed Swift 6.3.2.
8. Clone Tessera under `C:\Users\tess\tessera` and switch to `phase2-slice6-windows`.
9. Copy macOS SSH public key to `C:\Users\tess\tessera_windows.pub`.
10. From Administrator PowerShell, append the key to
    `C:\ProgramData\ssh\administrators_authorized_keys` and repair ACLs with `icacls`.
11. Update macOS SSH config for `User tess`.
12. `ssh tessera-windows whoami`, `ssh tessera-windows swift --version`, and
    `just windows-vm-check` succeeded.
13. `just test-windows-vm` again reached the expected Phase 1 `termios.h` failure, now
    from `C:\Users\tess\tessera\...`.

Finding: Swift/winget registration can be per-user enough that creating a new Windows user
after provisioning may require rerunning Swift installation for that user. For fresh docs,
this is avoided by creating/signing in as `tess` before running `setup-windows-vm.ps1`.

## UTM CLI follow-up

After the VM was working, Rob noticed `/opt/homebrew/bin/utmctl`. Local help showed UTM
4.7.5 provides useful VM control and guest-agent commands:

- `utmctl list` lists registered VMs and showed `tessera-windows` as `started`.
- `utmctl start tessera-windows` can start/resume the VM, with `--hide` available.
- `utmctl stop tessera-windows --request` can request guest shutdown.
- `utmctl ip-address tessera-windows` returned the guest IPs, including `192.168.64.2`.
- `utmctl file push <vm> <guest-path>` uploads stdin to the guest.
- `utmctl file pull <vm> <guest-path>` writes a guest file to stdout.
- `utmctl exec <vm> --cmd <cmd> ...` executes a guest command and returns its exit code.

Implications:

- `utmctl` cannot remove the manual Windows install/OOBE step, because the VM and Guest
  Tools/guest agent must exist first.
- It can likely streamline post-Guest-Tools bootstrap: discover the current VM IP, start
  or stop the VM from Just, and maybe push the provisioning script into the guest before a
  Git clone exists.
- `utmctl exec` needs more validation before relying on it for provisioning. A quick local
  test returned exit code 0 but no visible stdout for simple Windows commands, so SSH is
  still the clearer test runner for now.
- Candidate follow-up Just recipes:
  - `windows-vm-start`: `utmctl start --hide tessera-windows`
  - `windows-vm-stop`: `utmctl stop --request tessera-windows`
  - `windows-vm-ip`: first IPv4 from `utmctl ip-address tessera-windows`
  - `windows-vm-push-setup-script`: push `scripts/setup-windows-vm.ps1` via guest agent

## Conclusion

Resolved for Phase 0. The VM can be manually installed, provisioned with Swift 6.3.2 and
OpenSSH, reached from macOS with SSH key auth, and driven with `just windows-vm-check` and
`just test-windows-vm`. The Windows test run now reaches the expected Phase 1 portability
failure (`termios.h` missing), proving the Phase 0 workflow is good enough for local
iteration. The resulting contributor-facing walkthrough was promoted to
`docs/WindowsVM.md`.
