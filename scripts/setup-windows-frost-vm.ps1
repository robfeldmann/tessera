<#
Provision a Frost-built Windows 11 ARM64 Tessera toolchain image.

Run from an elevated PowerShell session inside the Frost guest, typically over SSH:

    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\setup-windows-frost-vm.ps1

The script is intentionally idempotent. If a reboot is required, it writes a marker under
C:\ProgramData\Tessera\FrostProvision and exits with code 100. The host-side provisioner
should reboot the VM, wait for SSH, and rerun this script until it reports completion.
#>

[CmdletBinding()]
param(
    [string]$ExpectedSwiftVersion = "6.3.2",

    # Public key content to install for unattended SSH access. If this is omitted and
    # AuthorizedKeyPath exists, the key is read from that path.
    [string]$AuthorizedKey = "",

    [string]$AuthorizedKeyPath = "C:\Windows\Temp\tessera_frost_authorized_key.pub",

    [string]$GitInstallerUrl = "https://github.com/git-for-windows/git/releases/download/v2.54.0.windows.1/Git-2.54.0-arm64.exe",

    [string]$VisualStudioBootstrapperUrl = "https://aka.ms/vs/17/release/vs_community.exe",

    # Leave empty to derive the official Swift ARM64 installer URL from ExpectedSwiftVersion.
    [string]$SwiftInstallerUrl = ""
)

$ErrorActionPreference = "Stop"

$StateDir = "C:\ProgramData\Tessera\FrostProvision"
$CompleteMarker = Join-Path $StateDir "complete.txt"
$RebootMarker = Join-Path $StateDir "reboot-required.txt"
$LogPath = Join-Path $StateDir "setup-windows-frost-vm.log"

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

function Get-SwiftInstallerUrl {
    param([string]$Version)

    return "https://download.swift.org/swift-$Version-release/windows10-arm64/swift-$Version-RELEASE/swift-$Version-RELEASE-windows10-arm64.exe"
}

function Exit-RebootRequired {
    "Reboot required before continuing. Reboot the guest, wait for SSH, then rerun this script." |
        Set-Content -Path $RebootMarker
    Write-Log "Reboot required; marker written to $RebootMarker"
    exit 100
}

function Invoke-Download {
    param(
        [string]$Uri,
        [string]$OutFile
    )

    Write-Log "Downloading $Uri"
    $ProgressPreference = "SilentlyContinue"
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

    Update-SessionPath
}

Invoke-Step "Verify administrator token" {
    if (-not (Test-Administrator)) {
        throw "This script must run with an administrator token. Frost's default tester user should be in Administrators."
    }
}

Invoke-Step "Enable Developer Mode for unprivileged symlinks" {
    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name AllowDevelopmentWithoutDevLicense -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name AllowAllTrustedApps -Value 1 -PropertyType DWord -Force | Out-Null
}

Invoke-Step "Verify download access" {
    $null = Invoke-WebRequest -Uri "https://download.swift.org" -UseBasicParsing -Method Head
}

Invoke-Step "Install Git" {
    if (Test-Command "git") {
        Write-Log "Git already available."
        return
    }

    $installer = Join-Path $env:TEMP "Git-2.54.0-arm64.exe"
    Invoke-Download -Uri $GitInstallerUrl -OutFile $installer
    Invoke-Installer `
        -Name "Git" `
        -Path $installer `
        -Arguments @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-") `
        -AllowedExitCodes @(0, 3010)
}

Invoke-Step "Install Visual Studio 2022 Community C++ toolchain" {
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

Invoke-Step "Enable Git symlink checkout support" {
    Update-SessionPath
    git config --global core.symlinks true
    $symlinks = git config --global --get core.symlinks
    Write-Log "core.symlinks=$symlinks"
}

Invoke-Step "Check for pending reboot after Visual Studio" {
    if (Test-PendingReboot) {
        Exit-RebootRequired
    }

    if (Test-Path $RebootMarker) {
        Remove-Item $RebootMarker -Force
    }
    Write-Log "No reboot pending."
}

Invoke-Step "Verify Visual Studio C++ workload" {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe was not found after Visual Studio installation."
    }

    $installPath = & $vswhere `
        -latest `
        -products Microsoft.VisualStudio.Product.Community `
        -requires Microsoft.VisualStudio.Workload.NativeDesktop `
        -property installationPath
    if ([string]::IsNullOrWhiteSpace($installPath)) {
        throw "Visual Studio C++ workload was not found."
    }

    Write-Log "Found Visual Studio at $installPath"
}

Invoke-Step "Install Swift toolchain" {
    Update-SessionPath
    if (Test-Command "swift") {
        $versionOutput = (& swift --version) -join "`n"
        if ($versionOutput -match [regex]::Escape($ExpectedSwiftVersion)) {
            Write-Log "Swift $ExpectedSwiftVersion already available."
            return
        }
    }

    $installerUrl = $SwiftInstallerUrl
    if ([string]::IsNullOrWhiteSpace($installerUrl)) {
        $installerUrl = Get-SwiftInstallerUrl -Version $ExpectedSwiftVersion
    }

    $installer = Join-Path $env:TEMP "swift-$ExpectedSwiftVersion-windows10-arm64.exe"
    Invoke-Download -Uri $installerUrl -OutFile $installer
    Invoke-Installer `
        -Name "Swift toolchain" `
        -Path $installer `
        -Arguments @("/quiet", "/norestart") `
        -AllowedExitCodes @(0, 3010)
}

Invoke-Step "Check for pending reboot after Swift" {
    if (Test-PendingReboot) {
        Exit-RebootRequired
    }
}

Invoke-Step "Enable OpenSSH Server" {
    $capability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    if ($capability.State -ne "Installed") {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    }

    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd

    $firewallRule = Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue
    if ($firewallRule) {
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
            -LocalPort 22
    }
}

Invoke-Step "Install SSH authorized key if provided" {
    $key = $AuthorizedKey.Trim()
    if ([string]::IsNullOrWhiteSpace($key) -and (Test-Path $AuthorizedKeyPath)) {
        $key = (Get-Content -Raw -Path $AuthorizedKeyPath).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($key)) {
        Write-Log "No authorized key provided; leaving SSH key auth unchanged."
        return
    }

    $dst = "C:\ProgramData\ssh\administrators_authorized_keys"
    New-Item -ItemType Directory -Force "C:\ProgramData\ssh" | Out-Null
    if (-not (Test-Path $dst) -or -not ((Get-Content $dst -ErrorAction SilentlyContinue) -contains $key)) {
        Add-Content -Path $dst -Value $key
    }

    icacls $dst /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null
    Write-Log "Installed SSH authorized key in $dst"
}

Invoke-Step "Verify Swift version" {
    Update-SessionPath
    $swift = Get-Command swift -ErrorAction SilentlyContinue
    if ($null -eq $swift) {
        throw "swift.exe was not found on PATH even after refreshing it."
    }

    $versionOutput = (& swift --version) -join "`n"
    Write-Log $versionOutput
    if ($versionOutput -notmatch [regex]::Escape($ExpectedSwiftVersion)) {
        throw "Expected Swift $ExpectedSwiftVersion. Update .swift-version or install the matching Windows toolchain."
    }
}

Invoke-Step "Verify Git" {
    Update-SessionPath
    $gitVersion = (& git --version) -join "`n"
    Write-Log $gitVersion
}

Invoke-Step "Make PowerShell start in the user's home directory" {
    $homeDirectory = $env:USERPROFILE
    $profilePaths = @(
        "$homeDirectory\Documents\WindowsPowerShell\profile.ps1",
        "$homeDirectory\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
        "$homeDirectory\Documents\PowerShell\profile.ps1",
        "$homeDirectory\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    )

    $content = @'
# Tessera Frost VM default location
if ($env:USERPROFILE -and (Test-Path $env:USERPROFILE)) {
    Set-Location $env:USERPROFILE
}
'@

    foreach ($profilePath in $profilePaths) {
        New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
        Set-Content -Path $profilePath -Value $content -Encoding UTF8
        Write-Log "Wrote $profilePath"
    }
}

"Tessera Frost provisioning completed at $([DateTime]::Now.ToString('O'))" |
    Set-Content -Path $CompleteMarker
Write-Log "Provisioning complete; marker written to $CompleteMarker"
