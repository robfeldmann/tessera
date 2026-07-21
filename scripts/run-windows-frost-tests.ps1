<#
Run Tessera tests inside a Windows Frost guest.
#>

[CmdletBinding()]
param(
    [string]$RepoPath = "C:\Users\tester\tessera",
    [string]$SwiftTestArgsBase64 = "",
    [string]$GhosttyOutputDir = "",
    [string]$SwiftPMCachePath = ""
)

$ErrorActionPreference = "Stop"

function Update-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
}

function Decode-SwiftTestArgs {
    param([string]$EncodedArgs)

    if (-not $EncodedArgs) {
        return @()
    }

    $json = [Text.Encoding]::UTF8.GetString(
        [Convert]::FromBase64String($EncodedArgs)
    )
    return @($json | ConvertFrom-Json)
}

Update-SessionPath
Set-Location $RepoPath

if ($GhosttyOutputDir) {
    # Enable Ghostty-backed snapshot support: materialize the generated headers
    # (the source archive carries none; the directory is gitignored), point the
    # package manifest at the provisioned artifact, and opt in to CGhosttyVT.
    $revision = (Get-Content -Path (Join-Path $RepoPath "scripts\ghostty-vt-version.txt") -Raw).Trim()
    $artifactDir = Join-Path $GhosttyOutputDir "$revision\windows-arm64"
    $artifactHeaders = Join-Path $artifactDir "include\ghostty"
    if (-not (Test-Path (Join-Path $artifactDir "lib\ghostty-vt-static.lib"))) {
        Write-Error "libghostty-vt artifact missing at $artifactDir"
        exit 1
    }
    $bridgeDir = Join-Path $RepoPath "Sources\CGhosttyVT\include\ghostty"
    if (Test-Path $bridgeDir) {
        Remove-Item -Recurse -Force $bridgeDir
    }
    Copy-Item -Recurse -Path $artifactHeaders -Destination $bridgeDir
    $env:GHOSTTY_VT_OUTPUT_DIR = $GhosttyOutputDir
    Write-Host "==> Ghostty VT enabled (artifact: $artifactDir)"
}

Write-Host "==> Swift"
swift --version

$swiftTestArgs = Decode-SwiftTestArgs -EncodedArgs $SwiftTestArgsBase64
$swiftArgs = @("test", "--no-parallel", "--enable-dependency-cache")
if ($SwiftPMCachePath) {
    $swiftArgs += @("--cache-path", $SwiftPMCachePath)
}
$swiftArgs += $swiftTestArgs

Write-Host "==> swift $($swiftArgs -join ' ')"
& swift @swiftArgs
exit $LASTEXITCODE
