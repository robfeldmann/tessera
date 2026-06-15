#Requires -RunAsAdministrator

<#
Provision a Windows 11 ARM64 Tessera development VM.

Run once from an elevated PowerShell session inside the Windows guest:

    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
    .\scripts\setup-windows-vm.ps1

The script installs the Windows prerequisites for the Swift toolchain, enables OpenSSH
Server, and verifies that Swift matches the repository's .swift-version.
#>

[CmdletBinding()]
param(
    [string]$ExpectedSwiftVersion = "6.3.2"
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Host "==> $Name" -ForegroundColor Cyan
    & $Body
}

function Test-Command {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

Invoke-Step "Verify winget is available" {
    if (-not (Test-Command "winget")) {
        throw "winget is not available. Install/update App Installer from Microsoft Store, then rerun this script."
    }
}

Invoke-Step "Install Git" {
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
}

Invoke-Step "Install Visual Studio 2022 Community C++ toolchain" {
    winget install `
        --id Microsoft.VisualStudio.2022.Community `
        -e `
        --accept-source-agreements `
        --accept-package-agreements `
        --override "--wait --quiet --norestart --add Microsoft.VisualStudio.Workload.NativeDesktop --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --includeRecommended"
}

Invoke-Step "Verify Visual Studio C++ workload" {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe was not found after Visual Studio installation. Reboot if installation just finished, then rerun."
    }

    $installPath = & $vswhere `
        -latest `
        -products Microsoft.VisualStudio.Product.Community `
        -requires Microsoft.VisualStudio.Workload.NativeDesktop `
        -property installationPath
    if ([string]::IsNullOrWhiteSpace($installPath)) {
        throw "Visual Studio C++ workload was not found. Rerun this script or repair Visual Studio with Desktop development with C++."
    }

    Write-Host "Found Visual Studio at $installPath"
}

Invoke-Step "Install Swift toolchain" {
    winget install --id Swift.Toolchain -e --accept-source-agreements --accept-package-agreements
}

Invoke-Step "Enable OpenSSH Server" {
    $capability = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    if ($capability.State -ne "Installed") {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    }

    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd

    if (-not (Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -Name OpenSSH-Server-In-TCP `
            -DisplayName "OpenSSH Server (sshd)" `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22
    }
}

Invoke-Step "Verify Swift version" {
    $swift = Get-Command swift -ErrorAction SilentlyContinue
    if ($null -eq $swift) {
        throw "swift.exe was not found on PATH. Open a new PowerShell window after installation and rerun this script."
    }

    $versionOutput = & swift --version
    Write-Host $versionOutput
    if ($versionOutput -notmatch [regex]::Escape($ExpectedSwiftVersion)) {
        throw "Expected Swift $ExpectedSwiftVersion. Update .swift-version or install the matching Windows toolchain."
    }
}

Invoke-Step "Show SSH connection details" {
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name.Split("\")[-1]
    $addresses = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
        Select-Object -ExpandProperty IPAddress

    Write-Host "OpenSSH Server is running. From macOS, connect with one of:"
    foreach ($address in $addresses) {
        Write-Host "  ssh $user@$address"
    }
    Write-Host "If you use UTM port forwarding, connect to the configured localhost port instead."
}
