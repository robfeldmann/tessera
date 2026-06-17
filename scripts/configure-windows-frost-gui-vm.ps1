<#
Configure quality-of-life settings for a Frost-built Windows GUI VM.

This is intended for the UTM-imported Frost VM after the base toolchain image has been
created. It is safe to rerun.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Host "==> $Name"
    & $Body
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Invoke-Step "Enable Developer Mode for unprivileged symlinks" {
    if (-not (Test-Administrator)) {
        throw "This script must run with an administrator token to enable Developer Mode."
    }

    $path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    New-Item -Path $path -Force | Out-Null
    New-ItemProperty -Path $path -Name AllowDevelopmentWithoutDevLicense -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $path -Name AllowAllTrustedApps -Value 1 -PropertyType DWord -Force | Out-Null
}

Invoke-Step "Enable Git symlink checkout support" {
    git config --global core.symlinks true
    git config --global --get core.symlinks
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
        Write-Host "Wrote $profilePath"
    }
}

Write-Host "✅ Frost GUI VM settings configured. Reopen PowerShell to verify the default directory."
