<#
Run Tessera's tests inside the Windows guest.

`mise run vm:windows-test` runs this over SSH after `vm:windows-push`. The package links
libghostty-vt from the published artifact bundle, so nothing is built with Zig here. It runs
`swift test --no-parallel` with the given arguments, exiting with swift's status.
#>

[CmdletBinding()]
param(
    [string]$RepoPath = (Join-Path $env:USERPROFILE "tessera"),
    [string[]]$SwiftTestArgs = @()
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Rebuild $env:Path from the registry so tools installed after sshd started resolve.
$machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"

Set-Location $RepoPath

Write-Host "==> Swift"
swift --version

$swiftArgs = @("test", "--no-parallel") + $SwiftTestArgs
Write-Host "==> swift $($swiftArgs -join ' ')"
& swift @swiftArgs
exit $LASTEXITCODE
