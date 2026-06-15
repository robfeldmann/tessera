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
    [string]$ExpectedSwiftVersion = "6.3.2",

    # Skip the automatic reboot-and-resume when a tool install (typically Visual
    # Studio) leaves a reboot pending. Use this if you want to reboot yourself.
    [switch]$NoAutoReboot
)

$ErrorActionPreference = "Stop"

$ResumeTaskName = "TesseraWindowsVMSetupResume"

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

# winget writes the updated PATH to the registry, but the running process keeps
# its stale copy until it restarts. Rebuild $env:Path from the machine and user
# registry values so freshly installed tools (git, swift) resolve in this same
# session instead of forcing "close PowerShell and rerun".
function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
}

function Test-PendingReboot {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    foreach ($key in $keys) {
        if (Test-Path $key) { return $true }
    }
    $pending = (Get-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
            -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
    return $null -ne $pending
}

# Register a one-time elevated scheduled task that reruns this script at the next
# logon, then remove itself. Used to continue automatically after a reboot.
function Register-ResumeTask {
    $argument = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($NoAutoReboot) { $argument += " -NoAutoReboot" }
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

# Clear any leftover resume task from a previous reboot-resume cycle so a
# successful run never re-triggers itself at the next logon.
Unregister-ResumeTask

Invoke-Step "Verify winget is available" {
    if (-not (Test-Command "winget")) {
        throw "winget is not available. Install/update App Installer from Microsoft Store, then rerun this script."
    }
}

Invoke-Step "Install Git" {
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
    Update-SessionPath
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

Invoke-Step "Check for pending reboot" {
    if (-not (Test-PendingReboot)) {
        Write-Host "No reboot pending."
        return
    }

    if ($NoAutoReboot) {
        throw "A reboot is pending (typically from Visual Studio). Reboot, then rerun this script."
    }

    Write-Host "A reboot is pending (typically from Visual Studio)." -ForegroundColor Yellow
    Write-Host "Registering a one-time resume task and rebooting in 10 seconds..."
    Write-Host "Sign back in as the same user and setup will continue automatically."
    Register-ResumeTask
    Start-Sleep -Seconds 10
    Restart-Computer -Force
    exit 0
}

Invoke-Step "Install Swift toolchain" {
    winget install --id Swift.Toolchain -e --accept-source-agreements --accept-package-agreements
    Update-SessionPath
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

Invoke-Step "Verify Swift version" {
    Update-SessionPath
    $swift = Get-Command swift -ErrorAction SilentlyContinue
    if ($null -eq $swift) {
        throw "swift.exe was not found on PATH even after refreshing it. Open a new PowerShell window and rerun this script."
    }

    $versionOutput = (& swift --version) -join "`n"
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
