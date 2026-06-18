<#
Verify a Frost Tessera toolchain Windows image.
#>

[CmdletBinding()]
param(
    [string]$ExpectedSwiftVersion = "6.3.2",
    [string]$ExpectedWindowsSDK = "10.0.26100.0"
)

$ErrorActionPreference = "Stop"

function Invoke-Check {
    param(
        [string]$Name,
        [scriptblock]$Body
    )

    Write-Host "==> $Name"
    & $Body
}

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
}

Update-SessionPath

Invoke-Check "User" {
    whoami
}

Invoke-Check "Git" {
    $gitVersion = (& git --version) -join "`n"
    Write-Host $gitVersion
}

Invoke-Check "Swift" {
    $swiftVersion = (& swift --version) -join "`n"
    Write-Host $swiftVersion
    if ($swiftVersion -notmatch [regex]::Escape($ExpectedSwiftVersion)) {
        throw "Expected Swift $ExpectedSwiftVersion"
    }
}

Invoke-Check "Visual Studio C++ workload" {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found"
    }

    $installPath = & $vswhere `
        -latest `
        -products Microsoft.VisualStudio.Product.Community `
        -requires Microsoft.VisualStudio.Workload.NativeDesktop `
        -property installationPath
    if ([string]::IsNullOrWhiteSpace($installPath)) {
        throw "Visual Studio Native Desktop workload not found"
    }

    Write-Host $installPath
}

Invoke-Check "Windows SDK" {
    $sdkPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Include\$ExpectedWindowsSDK"
    if (-not (Test-Path $sdkPath)) {
        $available = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" `
            -Directory `
            -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Name
        throw "Windows SDK $ExpectedWindowsSDK not found. Available SDKs: $($available -join ', ')"
    }

    Write-Host "Windows SDK $ExpectedWindowsSDK found"
}

Write-Host "✅ Frost Windows toolchain checks passed"
