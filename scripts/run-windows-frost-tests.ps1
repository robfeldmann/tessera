<#
Run Tessera tests inside a Windows Frost guest.
#>

[CmdletBinding()]
param(
    [string]$RepoPath = "C:\Users\tester\tessera"
)

$ErrorActionPreference = "Stop"

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
}

Update-SessionPath
Set-Location $RepoPath

Write-Host "==> Swift"
swift --version

Write-Host "==> swift test --no-parallel"
swift test --no-parallel
exit $LASTEXITCODE
