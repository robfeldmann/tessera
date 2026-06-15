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
- Pending: verify macOS SSH access.
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
- Pending: clone Tessera in the guest and run `swift test --no-parallel`.
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

## Conclusion

Open. Update this investigation after each successful step, then use it to rewrite the
Windows section of `CONTRIBUTING.md` with exact steps, URLs, screenshots/labels if useful,
and troubleshooting notes.
