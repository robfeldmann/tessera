<#
Run Tessera's tests inside the Windows guest with the Ghostty-backed snapshot support.

`mise run vm:windows-test` runs this over SSH after `vm:windows-push`. It builds and caches
libghostty-vt for the pinned revision (scripts/build-libghostty-vt.ps1 skips a cached
artifact), points the package at it through GHOSTTY_VT_OUTPUT_DIR, and runs
`swift test --no-parallel` with the given arguments, exiting with swift's status.
#>

[CmdletBinding()]
param(
    [string]$RepoPath = (Join-Path $env:USERPROFILE "tessera"),
    # The Zig scripts/build-libghostty-vt.ps1 installs when none is found (mise.toml's zig).
    [string]$ZigVersion = "",
    [string[]]$SwiftTestArgs = @()
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Rebuild $env:Path from the registry so tools installed after sshd started resolve.
$machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
$user = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"

Set-Location $RepoPath

if ($ZigVersion) {
    $env:GHOSTTY_VT_ZIG_VERSION = $ZigVersion
}
if (-not $env:GHOSTTY_VT_OUTPUT_DIR) {
    $env:GHOSTTY_VT_OUTPUT_DIR = Join-Path $env:LOCALAPPDATA "tessera\libghostty-vt"
}
& (Join-Path $RepoPath "scripts\build-libghostty-vt.ps1")
if ($LASTEXITCODE) {
    exit $LASTEXITCODE
}
$revision = (Get-Content -Path (Join-Path $RepoPath "scripts\ghostty-vt-version.txt") -Raw).Trim()
Write-Host "==> Ghostty VT enabled (artifact: $env:GHOSTTY_VT_OUTPUT_DIR\$revision\windows-arm64)"

Write-Host "==> Swift"
swift --version

$swiftArgs = @("test", "--no-parallel") + $SwiftTestArgs
Write-Host "==> swift $($swiftArgs -join ' ')"
& swift @swiftArgs
exit $LASTEXITCODE
