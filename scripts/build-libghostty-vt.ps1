<#
.SYNOPSIS
Build Ghostty's libghostty-vt on Windows from the pinned revision.

.DESCRIPTION
Windows counterpart of scripts/build-libghostty-vt.sh. Builds the pinned
libghostty-vt revision (scripts/ghostty-vt-version.txt) with Zig and installs it
under:

  $env:GHOSTTY_VT_OUTPUT_DIR (default: $env:LOCALAPPDATA\tessera\libghostty-vt)
    \<revision>\windows-<arch>\

It also materializes the generated headers into the workspace (gitignored):

  Sources\CGhosttyVT\include\ghostty\

Zig fetches the dependencies itself during `zig build`. That needs Zig 0.17 or
later on Windows: Zig 0.15 could not reach https://deps.files.ghostty.org there
(TlsInitializationFailed).

.PARAMETER Force
Rebuild even when the pinned artifact already exists.

Environment:
  GHOSTTY_VT_REVISION_FILE  Revision file path
  GHOSTTY_VT_OUTPUT_DIR     Output root (default: %LOCALAPPDATA%\tessera\libghostty-vt)
  GHOSTTY_VT_SOURCE_DIR     Source checkout path
  GHOSTTY_VT_ZIG_VERSION    Zig version to install when missing (default: 0.17.0)
  ZIG_EXECUTABLE            Zig executable path when `zig` is not on PATH
  ZIG_GLOBAL_CACHE_DIR      Zig global cache (default: %LOCALAPPDATA%\zig)
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step {
    param([string]$Message)
    Write-Host "[build-libghostty-vt] $Message"
}

# ── Revision ────────────────────────────────────────────────────────────────

$revisionFile = if ($env:GHOSTTY_VT_REVISION_FILE) {
    $env:GHOSTTY_VT_REVISION_FILE
} else {
    Join-Path $RepoRoot "scripts\ghostty-vt-version.txt"
}
$revision = (Get-Content -Path $revisionFile -Raw).Trim()
if (-not $revision) {
    throw "empty revision in $revisionFile"
}

# ── Paths ───────────────────────────────────────────────────────────────────

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    "ARM64" { "arm64" }
    "AMD64" { "x86_64" }
    default { throw "unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
}
$zigArch = switch ($arch) {
    "arm64" { "aarch64" }
    "x86_64" { "x86_64" }
}

$outputRoot = if ($env:GHOSTTY_VT_OUTPUT_DIR) {
    $env:GHOSTTY_VT_OUTPUT_DIR
} else {
    Join-Path $env:LOCALAPPDATA "tessera\libghostty-vt"
}
$installDir = Join-Path $outputRoot "$revision\windows-$arch"
$sourceDir = if ($env:GHOSTTY_VT_SOURCE_DIR) {
    $env:GHOSTTY_VT_SOURCE_DIR
} else {
    Join-Path $outputRoot "source\$revision"
}

if (-not $env:ZIG_GLOBAL_CACHE_DIR) {
    $env:ZIG_GLOBAL_CACHE_DIR = Join-Path $env:LOCALAPPDATA "zig"
}

function Copy-HeaderBridge {
    $bridgeDir = Join-Path $RepoRoot "Sources\CGhosttyVT\include\ghostty"
    $sourceHeaders = Join-Path $installDir "include\ghostty"
    if (Test-Path $bridgeDir) {
        Remove-Item -Recurse -Force $bridgeDir
    }
    Copy-Item -Recurse -Path $sourceHeaders -Destination $bridgeDir
    Write-Step "materialized headers: $bridgeDir"
}

# ── Early exit when already built ───────────────────────────────────────────

$vtHeader = Join-Path $installDir "include\ghostty\vt.h"
$staticLib = Join-Path $installDir "lib\ghostty-vt-static.lib"
if (-not $Force -and (Test-Path $vtHeader) -and (Test-Path $staticLib)) {
    Copy-HeaderBridge
    Write-Step "libghostty-vt already built: $installDir"
    exit 0
}

# ── Tools ───────────────────────────────────────────────────────────────────

foreach ($tool in @("git", "curl.exe")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool is required"
    }
}

$zigVersion = if ($env:GHOSTTY_VT_ZIG_VERSION) { $env:GHOSTTY_VT_ZIG_VERSION } else { "0.17.0" }

function Resolve-Zig {
    if ($env:ZIG_EXECUTABLE) {
        return $env:ZIG_EXECUTABLE
    }
    $onPath = Get-Command zig -ErrorAction SilentlyContinue
    if ($onPath -and ((& $onPath.Source version) -eq $zigVersion)) {
        return $onPath.Source
    }
    $zigName = "zig-$zigArch-windows-$zigVersion"
    $zigRoot = Join-Path $env:LOCALAPPDATA "Programs\zig"
    $zigExe = Join-Path $zigRoot "$zigName\zig.exe"
    if (Test-Path $zigExe) {
        return $zigExe
    }
    Write-Step "installing Zig $zigVersion to $zigRoot"
    New-Item -ItemType Directory -Force -Path $zigRoot | Out-Null
    $zipPath = Join-Path $env:TEMP "$zigName.zip"
    & curl.exe -fL --retry 3 -o $zipPath "https://ziglang.org/download/$zigVersion/$zigName.zip"
    if ($LASTEXITCODE -ne 0) {
        throw "failed to download Zig $zigVersion"
    }
    Expand-Archive -Path $zipPath -DestinationPath $zigRoot -Force
    Remove-Item $zipPath
    if (-not (Test-Path $zigExe)) {
        throw "Zig archive did not produce $zigExe"
    }
    return $zigExe
}

$zig = Resolve-Zig
$zigVersionOutput = & $zig version
Write-Step "using Zig $zigVersionOutput ($zig)"
if ($zigVersionOutput -ne $zigVersion) {
    Write-Warning "expected Zig $zigVersion, found $zigVersionOutput"
}

# ── Source checkout ─────────────────────────────────────────────────────────

if (-not (Test-Path (Join-Path $sourceDir ".git"))) {
    Write-Step "cloning ghostty into $sourceDir"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sourceDir) | Out-Null
    git init -q $sourceDir
    git -C $sourceDir remote add origin https://github.com/ghostty-org/ghostty.git
}
git -C $sourceDir fetch --depth 1 origin $revision
if ($LASTEXITCODE -ne 0) {
    throw "git fetch of $revision failed"
}
git -C $sourceDir checkout -q --detach FETCH_HEAD
$actualRevision = (git -C $sourceDir rev-parse HEAD).Trim()
if ($actualRevision -ne $revision) {
    throw "checkout mismatch: expected $revision, got $actualRevision"
}

# ── Build ───────────────────────────────────────────────────────────────────

Write-Step "zig build -Demit-lib-vt (install: $installDir)"
Push-Location $sourceDir
try {
    & $zig build -Demit-lib-vt -Dsimd=false -Doptimize=ReleaseFast --prefix $installDir
    if ($LASTEXITCODE -ne 0) {
        throw "zig build failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

foreach ($artifact in @($vtHeader, $staticLib, (Join-Path $installDir "bin\ghostty-vt.dll"))) {
    if (-not (Test-Path $artifact)) {
        throw "build completed but expected artifact is missing: $artifact"
    }
}

$metadata = @(
    "revision=$revision",
    "platform=windows",
    "arch=$arch",
    "build_mode=ReleaseFast",
    "zig_version=$zigVersionOutput",
    "source_dir=$sourceDir"
) -join "`n"
[System.IO.File]::WriteAllText(
    (Join-Path $installDir "build-metadata.txt"),
    $metadata + "`n",
    $Utf8NoBom
)

Copy-HeaderBridge
Write-Step "Built libghostty-vt: $installDir"
