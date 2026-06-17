# Manual Windows VM with UTM

Metadata:

- Last verified: 2026-06-14
- Host macOS: 26.5.1 (25F80)
- UTM: 4.7.5
- Guest OS: Windows 11 ARM64, 25H2 English multi-edition ISO
- Guest architecture: ARM64 / aarch64
- Swift: follows `.swift-version`, target `aarch64-unknown-windows-msvc`
- Recommended VM name: `tessera-windows`
- Recommended Windows user: `tess`

This guide walks through creating a Windows 11 ARM64 VM manually in
[UTM](https://mac.getutm.app/). If you already know your way around Windows VM setup, you
can jump to
[Quick setup for experienced contributors](#quick-setup-for-experienced-contributors). Use
this manual path if you want maximum control over the Windows desktop VM or if the
scripted Frost workflow in `docs/WindowsFrostVM.md` does not fit your setup.

For the recommended repeatable test workflow, start with `docs/WindowsFrostVM.md`. For a
hand-managed Windows desktop VM, continue here.

The goal is a VM you can reach with SSH, then drive from macOS with:

```sh
export TESSERA_WINDOWS_VM_SSH=tessera-windows
just windows-vm-check
just test-windows-vm
```

Fish users can use `set -x TESSERA_WINDOWS_VM_SSH tessera-windows` instead of `export`.

## Quick setup for experienced contributors

If you already know how to install Windows in UTM:

1. Create a Windows 11 ARM64 VM named `tessera-windows`.
2. Install UTM Guest Tools.
3. Create a Windows user with a real password.
4. Copy or clone Tessera into the guest.
5. Run `scripts/setup-windows-vm.ps1` from elevated PowerShell.
6. Configure SSH key auth from macOS.
7. Run:

   ```fish
   set -x TESSERA_WINDOWS_VM_SSH tessera-windows
   just windows-vm-check
   just test-windows-vm
   ```

The rest of this guide explains those steps in detail.

## Prerequisites

Install the macOS tools from the project `Brewfile` using [Homebrew](https://brew.sh/):

```sh
cd /path/to/tessera
brew bundle install
```

This includes [UTM](https://mac.getutm.app/), which runs the Windows VM.

You also need enough disk space for the Windows VM. UTM stores the VM as a local bundle on
your Mac.

## 1. Download the Windows 11 ARM64 ISO

1. Open <https://www.microsoft.com/software-download/windows11arm64>.
2. In the download dropdown, select **Windows 11 (multi-edition ISO for Arm64)**.
3. Click **Download Now**.
4. For product language, select **English (United States)**.
5. Click **Confirm**.
6. Click the second **Download Now** button that appears after confirmation.

The downloaded file used while writing this guide was:

```text
~/Downloads/Win11_25H2_English_Arm64_v2.iso
```

Microsoft shows Windows PowerShell verification instructions. On macOS, verify the ISO
with `shasum` instead:

```sh
shasum -a 256 ~/Downloads/Win11_25H2_English_Arm64_v2.iso
```

For the English 64-bit ISO above, the expected SHA-256 was:

```text
638aa2c88e94385b00f4f178d071e3df0b7d9e335577a83bd533b7f2eb65adf0
```

The verified ISO was 7.4 GB.

## 2. Create the UTM VM

1. Open UTM.
2. Click **Create a New Virtual Machine**.
3. Choose **Virtualize**.
4. Choose **Windows**.
5. If UTM asks for hardware before the ISO picker, use:
   - Memory: **8192 MB**
   - CPU cores: **4**
6. For **Boot ISO Image**, choose the Windows ARM64 ISO from `~/Downloads`.
7. Leave **Install drivers and SPICE tools** enabled if UTM shows that option.
8. Storage: **80 GB**.
9. Shared directory: leave unset for now.
10. Name: **tessera-windows**.
11. Save and start the VM.

### If the VM boots to the UEFI shell

The first boot may land at `UEFI Interactive Shell v2.2` instead of Windows Setup. If so:

1. At the `Shell>` prompt, type:

   ```text
   exit
   ```

2. In Boot Manager, select:

   ```text
   UEFI QEMU QEMU USB HARDDRIVE 1-0000:00:04.0-4.1
   ```

3. When `Press any key to boot...` appears, press Enter quickly.

That should start Windows Setup. If the exact USB entry differs, choose the USB hard drive
entry that corresponds to the installer ISO.

## 3. Install Windows

In Windows Setup:

1. Select language/region/keyboard defaults.
2. Choose **Windows 11 Pro** if available.
3. Accept the license terms.
4. Select the unallocated virtual disk and continue.
5. Let Windows copy files and reboot.

During reboots, if `Press any key to boot...` appears again, do **not** press anything.
Let the VM continue booting from the virtual disk.

During first-boot setup:

1. Select country/region.
2. Select keyboard layout.
3. Skip adding a second keyboard layout unless you need one.
4. Let Windows check for updates.
5. When asked for a user name, use **tess**.
6. Set a real password. Do not leave the password blank if you want SSH to work.

A blank password may work for desktop login, but Windows OpenSSH rejects blank-password
SSH login. If you already created a blank password, set one later from Administrator
PowerShell:

```powershell
net user tess *
```

## 4. Install UTM Guest Tools

After Windows reaches the desktop, UTM Guest Tools should appear automatically if the VM
was created with driver/SPICE tools enabled.

Run the installer and accept the defaults. During the walkthrough, this completed without
extra interaction and noticeably improved the VM display resolution.

If Windows prompts to turn on clipboard history, that is optional.

## 5. Bootstrap Git and clone Tessera

Open Windows PowerShell and verify basic networking:

```powershell
winget --version
hostname
Test-NetConnection github.com -Port 443
```

Install Git:

```powershell
winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
```

Close PowerShell and open a new PowerShell window so `git` is on `PATH`, then verify:

```powershell
git --version
```

Clone Tessera. Use either the upstream repository URL or your fork URL:

```powershell
cd $HOME
git clone <tessera-repository-url> tessera
cd tessera
git status
```

If you prefer GitHub CLI, authenticate first:

```powershell
winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements
gh auth login
cd $HOME
gh repo clone <owner>/tessera tessera
cd tessera
```

## 6. Run the Windows provisioning script

Open **Windows PowerShell as Administrator** and run:

```powershell
cd $HOME\tessera
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
.\scripts\setup-windows-vm.ps1
```

The script installs or verifies:

- Git
- Visual Studio 2022 Community with the C++ workload and Windows 11 SDK
- Swift matching `.swift-version`
- OpenSSH Server

Visual Studio installation usually leaves a reboot pending. The script detects this,
registers a one-time resume task, and reboots after a 10-second warning. Sign back in as
the same user and setup continues automatically — no need to relaunch the script by hand.
Pass `-NoAutoReboot` if you would rather reboot yourself and rerun the script manually.

The script also refreshes its own `PATH` after installing Git and Swift, so a single run
no longer requires closing and reopening PowerShell for those tools to resolve.

Enabling OpenSSH can appear silent for a few minutes. Wait before interrupting it.

A successful run ends with Swift version output and SSH connection details. The Swift
version should match `.swift-version`, and the target should be
`aarch64-unknown-windows-msvc`:

```text
Swift version <version>
Target: aarch64-unknown-windows-msvc
Build config: +assertions
OpenSSH Server is running. From macOS, connect with one of:
  ssh tess@<vm-ip>
```

## 7. Verify SSH reachability from macOS

You can ask UTM for the VM IP address:

```sh
just windows-vm-ip
```

Or directly:

```sh
utmctl ip-address tessera-windows
```

From macOS, first check that port 22 is reachable:

```sh
nc -vz <vm-ip> 22
```

Then test password SSH:

```sh
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no tess@<vm-ip> swift --version
```

If `nc` times out, check the Windows network profile and OpenSSH firewall rule from an
Administrator PowerShell:

```powershell
Get-NetConnectionProfile
Get-Service sshd
Get-NetTCPConnection -LocalPort 22 -State Listen
Get-NetFirewallRule -Name OpenSSH-Server-In-TCP | Format-List Name,Enabled,Direction,Action,Profile
```

If the network category is `Public`, make sure the SSH firewall rule applies to all
profiles:

```powershell
Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any
```

The provisioning script should do this automatically, but the command is useful for
troubleshooting.

## 8. Configure SSH key authentication

The `just` recipes use non-interactive SSH, so password prompts are not enough. Configure
key-based auth.

On macOS, generate a dedicated key:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/tessera_windows -N "" -C "tessera-windows"
ssh-add --apple-use-keychain ~/.ssh/tessera_windows
```

The fastest path is the helper recipe, which uses password SSH for this one-time step and
installs the key into the administrators key file with the correct ACLs:

```sh
just windows-vm-install-ssh-key
```

It defaults to `~/.ssh/tessera_windows.pub`; override with `TESSERA_WINDOWS_VM_PUBKEY`.

To do it by hand instead, copy the public key into the Windows VM:

```sh
scp -o PreferredAuthentications=password -o PubkeyAuthentication=no ~/.ssh/tessera_windows.pub tess@<vm-ip>:'C:/Users/tess/tessera_windows.pub'
```

For a Windows administrator account, install the key into the administrators key file. In
**Windows PowerShell as Administrator**, run these as separate commands:

```powershell
New-Item -ItemType Directory -Force C:\ProgramData\ssh | Out-Null
Get-Content $HOME\tessera_windows.pub | Add-Content -Path C:\ProgramData\ssh\administrators_authorized_keys
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r /grant Administrators:F /grant SYSTEM:F
```

On macOS, add an SSH config entry:

```sshconfig
Host tessera-windows
  HostName <vm-ip>
  User tess
  IdentityFile ~/.ssh/tessera_windows
  IdentitiesOnly yes
  PreferredAuthentications publickey
```

Test key auth:

```sh
ssh tessera-windows swift --version
```

It should not ask for a password.

## 9. Run from macOS with Just

Start the VM, if needed:

```sh
just windows-vm-start
```

Set the VM SSH target:

```sh
export TESSERA_WINDOWS_VM_SSH=tessera-windows
```

Fish users can run:

```fish
set -x TESSERA_WINDOWS_VM_SSH tessera-windows
```

Verify the VM:

```sh
just windows-vm-check
```

Run the Windows test loop:

```sh
just test-windows-vm
```

A successful run means macOS can reach the VM, Swift is available in Windows, and the
Windows build/test command runs inside the guest. If tests fail, treat the output as a
normal Windows build or test failure rather than a VM setup failure.

## UTM CLI helpers

The project includes `just` recipes around UTM's `utmctl` CLI. They fail with a clear
message if UTM is not installed.

```sh
just windows-vm-start
just windows-vm-status
just windows-vm-ip
just windows-vm-stop
```

By default these target a VM named `tessera-windows`. Override the name with:

```sh
export TESSERA_WINDOWS_VM_NAME=my-windows-vm
```

You can also push the current local provisioning script into the guest after UTM Guest
Tools are installed:

```sh
just windows-vm-push-setup-script
```

By default, that writes to:

```text
C:\Windows\Temp\setup-windows-vm.ps1
```

Override with:

```sh
export TESSERA_WINDOWS_VM_SETUP_PATH='C:\Users\<user>\Downloads\setup-windows-vm.ps1'
```

## Notes for local development

The Windows VM should have its own checkout and its own `.build` directory. Do not build
from a macOS shared folder or share `.build` between macOS and Windows.

For active development, edit on macOS and push the current branch straight into the guest
checkout over SSH, without going through GitHub:

```sh
just windows-vm-sync
just test-windows-vm
```

`windows-vm-sync` configures `receive.denyCurrentBranch=updateInstead` on the guest repo
and force-pushes (with lease) your current branch, updating the guest working tree in
place. The guest tree must be clean for the push to apply, so commit or stash guest-side
changes first. This keeps `.build` and other platform-specific artifacts entirely on the
guest. You can still use normal Git operations inside the Windows checkout when preferred.
