<#
Provision a Windows 11 ARM64 Tessera guest: the toolchain the repository names, OpenSSH
Server with the host's key, and the UTM guest tools.

`mise run vm:windows-provision` delivers and runs this script over SSH with the versions
from the checkout (.swift-version, mise.toml's zig). On a guest without SSH yet, run it
once by hand from an elevated PowerShell:

    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\provision-windows-vm.ps1 -ExpectedSwiftVersion 6.3.3 -ZigVersion 0.15.2

The script is idempotent: every step checks before it installs. When an install leaves a
reboot pending it stops early. Over SSH it exits with code 100 and the host reboots the
guest and reruns it; from a console it registers a one-time logon task that reruns it,
then reboots.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSwiftVersion,

    # The Zig that scripts/build-libghostty-vt.ps1 expects (mise.toml's [tools] zig).
    [Parameter(Mandatory = $true)]
    [string]$ZigVersion,

    # Public key to add to administrators_authorized_keys; AuthorizedKeyPath is read when
    # this is empty and the file exists.
    [string]$AuthorizedKey = "",
    [string]$AuthorizedKeyPath = "C:\Windows\Temp\tessera-vm.pub",

    [string]$GitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/Git-2.54.0-arm64.exe",
    [string]$VisualStudioBootstrapperUrl = "https://aka.ms/vs/17/release/vs_community.exe",
    [string]$UtmGuestToolsUrl = "https://getutm.app/downloads/utm-guest-tools-latest.iso",
    # Empty derives the swift.org ARM64 installer URL from ExpectedSwiftVersion.
    [string]$SwiftInstallerUrl = "",

    # Stop with exit code 100 instead of rebooting, even from a console.
    [switch]$NoAutoReboot
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$StateDir = "C:\ProgramData\Tessera\Provision"
$LogPath = Join-Path $StateDir "provision-windows-vm.log"
$ResumeTaskName = "TesseraProvisionResume"
$ExitRebootRequired = 100
$script:RebootRequested = $false

New-Item -ItemType Directory -Force $StateDir | Out-Null

function Write-Log {
    param([string]$Message)

    $line = "{0} {1}" -f ([DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")), $Message
    Add-Content -Path $LogPath -Value $line
    Write-Host $line
}

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Log "==> $Name"
    & $Body
}

function Test-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# Installers write the new PATH to the registry; the running process keeps its stale
# copy until it restarts. Rebuild $env:Path so fresh tools resolve in this session.
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-PendingReboot {
    if ($script:RebootRequested) { return $true }
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    foreach ($key in $keys) {
        if (Test-Path $key) { return $true }
    }
    $pending = Get-ItemProperty `
        -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations `
        -ErrorAction SilentlyContinue
    return $null -ne $pending
}

function Get-InstalledProduct {
    param([string]$Pattern)
    Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -match $Pattern } |
        Select-Object -First 1
}

function Invoke-Download {
    param(
        [string]$Uri,
        [string]$OutFile
    )

    Write-Log "Downloading $Uri"
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing
}

function Invoke-Installer {
    param(
        [string]$Name,
        [string]$Path,
        [string[]]$Arguments,
        [int[]]$AllowedExitCodes = @(0)
    )

    Write-Log "Running $Name installer: $Path $($Arguments -join ' ')"
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru
    Write-Log "$Name installer exit code: $($process.ExitCode)"
    if ($AllowedExitCodes -notcontains $process.ExitCode) {
        throw "$Name installer failed with exit code $($process.ExitCode)"
    }
    if ($process.ExitCode -eq 3010) {
        $script:RebootRequested = $true
    }
    Update-SessionPath
}

# Register a one-time elevated scheduled task that reruns this script at the next logon
# and then removes itself (the console path through a reboot).
function Register-ResumeTask {
    $argument = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" " +
        "-ExpectedSwiftVersion `"$ExpectedSwiftVersion`" -ZigVersion `"$ZigVersion`" " +
        "-AuthorizedKeyPath `"$AuthorizedKeyPath`""
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive
    Register-ScheduledTask `
        -TaskName $ResumeTaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Force | Out-Null
}

function Unregister-ResumeTask {
    if (Get-ScheduledTask -TaskName $ResumeTaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $ResumeTaskName -Confirm:$false
    }
}

function Stop-ForReboot {
    param([string]$Reason)

    if ($env:SSH_CONNECTION -or $NoAutoReboot) {
        Write-Log "Reboot required ($Reason); exiting with code $ExitRebootRequired for the host to reboot the guest and rerun this script."
        exit $ExitRebootRequired
    }
    Write-Log "Reboot required ($Reason); registering the resume task and rebooting in 10 seconds. Sign in as the same user and provisioning continues."
    Register-ResumeTask
    Start-Sleep -Seconds 10
    Restart-Computer -Force
    exit 0
}

function Get-SwiftInstallerUrl {
    param([string]$Version)
    return "https://download.swift.org/swift-$Version-release/windows10-arm64/swift-$Version-RELEASE/swift-$Version-RELEASE-windows10-arm64.exe"
}

# A successful run must never re-trigger itself at the next logon.
Unregister-ResumeTask

Invoke-Step "Verify administrator token" {
    if (-not (Test-Administrator)) {
        throw "This script needs an administrator token: run it from an elevated PowerShell, or over SSH as a member of Administrators."
    }
}

Invoke-Step "Enable OpenSSH Server" {
    $capability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    if ($capability.State -ne "Installed") {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    }
    Set-Service -Name sshd -StartupType Automatic
    if ((Get-Service sshd).Status -ne "Running") {
        Start-Service sshd
    }
    $rule = Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
    if ($rule) {
        Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Enabled True -Profile Any
    } else {
        New-NetFirewallRule `
            -Name OpenSSH-Server-In-TCP `
            -DisplayName "OpenSSH Server (sshd)" `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -Profile Any `
            -LocalPort 22 | Out-Null
    }
}

Invoke-Step "Authorize the host's SSH key" {
    $key = $AuthorizedKey.Trim()
    if ([string]::IsNullOrWhiteSpace($key) -and (Test-Path $AuthorizedKeyPath)) {
        $key = (Get-Content -Raw -Path $AuthorizedKeyPath).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Log "No key given; SSH authentication unchanged."
        return
    }
    $dst = "C:\ProgramData\ssh\administrators_authorized_keys"
    New-Item -ItemType Directory -Force "C:\ProgramData\ssh" | Out-Null
    $existing = @(Get-Content $dst -ErrorAction SilentlyContinue)
    if ($existing -contains $key) {
        Write-Log "Key already authorized."
    } else {
        Add-Content -Path $dst -Value $key
        Write-Log "Added the key to $dst"
    }
    icacls $dst /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null
}

Invoke-Step "Keep the account's password from expiring" {
    # Windows expires local passwords after 42 days; sshd then refuses them, and only a
    # console sign-in can set a new one. A snapshot or base image must not go stale.
    $user = Get-LocalUser -Name $env:USERNAME
    if ($user.PasswordExpires) {
        Set-LocalUser -Name $env:USERNAME -PasswordNeverExpires $true
        Write-Log "Set PasswordNeverExpires for $env:USERNAME"
    } else {
        Write-Log "Password of $env:USERNAME already never expires."
    }
}

Invoke-Step "Enable Developer Mode for unprivileged symlinks" {
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $current = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
    if ($current.AllowDevelopmentWithoutDevLicense -eq 1 -and $current.AllowAllTrustedApps -eq 1) {
        Write-Log "Developer Mode already enabled."
        return
    }
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name AllowDevelopmentWithoutDevLicense -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name AllowAllTrustedApps -Value 1 -PropertyType DWord -Force | Out-Null
}

Invoke-Step "Install Git" {
    Update-SessionPath
    if (Test-Command "git") {
        Write-Log "Git already available: $((& git --version) -join ' ')"
    } else {
        $installer = Join-Path $env:TEMP ([IO.Path]::GetFileName($GitInstallerUrl))
        Invoke-Download -Uri $GitInstallerUrl -OutFile $installer
        Invoke-Installer `
            -Name "Git" `
            -Path $installer `
            -Arguments @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-") `
            -AllowedExitCodes @(0, 3010)
    }
    if ((git config --global --get core.symlinks) -ne "true") {
        git config --global core.symlinks true
        Write-Log "Set core.symlinks=true"
    }
}

Invoke-Step "Install the Visual Studio 2022 C++ workload and Windows 11 SDK" {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $existing = & $vswhere `
            -latest `
            -products Microsoft.VisualStudio.Product.Community `
            -requires Microsoft.VisualStudio.Workload.NativeDesktop `
            -property installationPath
        if (-not [string]::IsNullOrWhiteSpace($existing)) {
            Write-Log "Visual Studio C++ workload already available at $existing"
            return
        }
    }
    $installer = Join-Path $env:TEMP "vs_community.exe"
    Invoke-Download -Uri $VisualStudioBootstrapperUrl -OutFile $installer
    Invoke-Installer `
        -Name "Visual Studio 2022 Community" `
        -Path $installer `
        -Arguments @(
            "--wait",
            "--quiet",
            "--norestart",
            "--add", "Microsoft.VisualStudio.Workload.NativeDesktop",
            "--add", "Microsoft.VisualStudio.Component.Windows11SDK.26100",
            "--includeRecommended"
        ) `
        -AllowedExitCodes @(0, 3010)
}

Invoke-Step "Check for a pending reboot after Visual Studio" {
    if (Test-PendingReboot) {
        Stop-ForReboot "Visual Studio"
    }
    Write-Log "No reboot pending."
}

Invoke-Step "Install the Swift toolchain" {
    Update-SessionPath
    if (Test-Command "swift") {
        $versionOutput = (& swift --version) -join "`n"
        if ($versionOutput -match [regex]::Escape($ExpectedSwiftVersion)) {
            Write-Log "Swift $ExpectedSwiftVersion already available."
            return
        }
        Write-Log "Swift on PATH does not match ${ExpectedSwiftVersion}: $versionOutput"
    }
    $url = $SwiftInstallerUrl
    if ([string]::IsNullOrWhiteSpace($url)) {
        $url = Get-SwiftInstallerUrl -Version $ExpectedSwiftVersion
    }
    $installer = Join-Path $env:TEMP "swift-$ExpectedSwiftVersion-windows10-arm64.exe"
    Invoke-Download -Uri $url -OutFile $installer
    Invoke-Installer `
        -Name "Swift toolchain" `
        -Path $installer `
        -Arguments @("/quiet", "/norestart") `
        -AllowedExitCodes @(0, 3010)
}

Invoke-Step "Check for a pending reboot after Swift" {
    if (Test-PendingReboot) {
        Stop-ForReboot "Swift"
    }
    Write-Log "No reboot pending."
}

Invoke-Step "Install Zig $ZigVersion" {
    # The layout scripts/build-libghostty-vt.ps1 resolves: %LOCALAPPDATA%\Programs\zig\<name>\zig.exe.
    $zigArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "aarch64" } else { "x86_64" }
    $zigName = "zig-$zigArch-windows-$ZigVersion"
    $zigRoot = Join-Path $env:LOCALAPPDATA "Programs\zig"
    $zigExe = Join-Path $zigRoot "$zigName\zig.exe"
    if (Test-Path $zigExe) {
        Write-Log "Zig already available: $(& $zigExe version) ($zigExe)"
        return
    }
    $archive = Join-Path $env:TEMP "$zigName.zip"
    Invoke-Download -Uri "https://ziglang.org/download/$ZigVersion/$zigName.zip" -OutFile $archive
    New-Item -ItemType Directory -Force $zigRoot | Out-Null
    Expand-Archive -Path $archive -DestinationPath $zigRoot -Force
    Remove-Item $archive -Force
    if (-not (Test-Path $zigExe)) {
        throw "Zig archive did not contain $zigExe"
    }
    Write-Log "Installed Zig $(& $zigExe version) at $zigExe"
}

Invoke-Step "Install the UTM guest tools" {
    $installed = Get-InstalledProduct -Pattern "^UTM Guest Tools"
    if ($installed) {
        Write-Log "$($installed.DisplayName) $($installed.DisplayVersion) already installed."
        return
    }
    $iso = Join-Path $env:TEMP "utm-guest-tools.iso"
    Invoke-Download -Uri $UtmGuestToolsUrl -OutFile $iso
    $image = Mount-DiskImage -ImagePath $iso -PassThru
    try {
        $letter = ($image | Get-Volume).DriveLetter
        $installer = Get-ChildItem "${letter}:\" -Filter "utm-guest-tools-*.exe" | Select-Object -First 1
        if (-not $installer) {
            throw "No utm-guest-tools-*.exe on the guest tools ISO"
        }
        Invoke-Installer -Name "UTM guest tools" -Path $installer.FullName -Arguments @("/S")
    } finally {
        Dismount-DiskImage -ImagePath $iso | Out-Null
        Remove-Item $iso -Force
    }
    # The SPICE agent and QEMU guest agent start after a reboot.
    $script:RebootRequested = $true
}

Invoke-Step "Verify the toolchain" {
    Update-SessionPath
    $swiftVersion = (& swift --version) -join "`n"
    Write-Log $swiftVersion
    if ($swiftVersion -notmatch [regex]::Escape($ExpectedSwiftVersion)) {
        throw "Expected Swift $ExpectedSwiftVersion on PATH."
    }
    Write-Log ((& git --version) -join "`n")
    $sdk = "${env:ProgramFiles(x86)}\Windows Kits\10\Include\10.0.26100.0"
    if (-not (Test-Path $sdk)) {
        throw "Windows SDK 10.0.26100.0 not found under ${env:ProgramFiles(x86)}\Windows Kits\10\Include"
    }
    Write-Log "Windows SDK 10.0.26100.0 found"
}

if (Test-PendingReboot) {
    Stop-ForReboot "installed components"
}

"Tessera provisioning completed at $([DateTime]::Now.ToString('O')) (Swift $ExpectedSwiftVersion, Zig $ZigVersion)" |
    Set-Content -Path (Join-Path $StateDir "complete.txt")
Write-Log "Provisioning complete."
