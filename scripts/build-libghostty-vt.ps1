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

Zig's Windows package fetcher fails against https://deps.files.ghostty.org
(TlsInitializationFailed), so this script prefetches every dependency listed in
the pinned checkout's build.zig.zon.json with curl.exe and hands the local files
to `zig fetch`, which produces identical content-addressed cache keys.

.PARAMETER Force
Rebuild even when the pinned artifact already exists.

Environment:
  GHOSTTY_VT_REVISION_FILE  Revision file path
  GHOSTTY_VT_OUTPUT_DIR     Output root (default: %LOCALAPPDATA%\tessera\libghostty-vt)
  GHOSTTY_VT_SOURCE_DIR     Source checkout path
  GHOSTTY_VT_ZIG_VERSION    Zig version to install when missing (default: 0.15.2)
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

function Resolve-Zig {
    if ($env:ZIG_EXECUTABLE) {
        return $env:ZIG_EXECUTABLE
    }
    $onPath = Get-Command zig -ErrorAction SilentlyContinue
    if ($onPath -and ((& $onPath.Source version) -like "0.15*")) {
        return $onPath.Source
    }
    $zigVersion = if ($env:GHOSTTY_VT_ZIG_VERSION) { $env:GHOSTTY_VT_ZIG_VERSION } else { "0.15.2" }
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
if ($zigVersionOutput -notlike "0.15*") {
    Write-Warning "expected Zig 0.15.x, found $zigVersionOutput"
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

# ── Dependency prefetch ─────────────────────────────────────────────────────
#
# Mirrors upstream nix/build-support/fetch-zig-cache.sh: `zig build --fetch`
# misses transitive dependencies (ziglang/zig#20976), and Zig's own downloader
# fails with TlsInitializationFailed on Windows. build.zig.zon.json maps every
# transitive dependency's Zig cache key to its URL, so download with curl.exe
# and let `zig fetch <local-file>` unpack, hash, and verify each one.

$zonJsonPath = Join-Path $sourceDir "build.zig.zon.json"
if (-not (Test-Path $zonJsonPath)) {
    throw "missing $zonJsonPath; cannot prefetch dependencies"
}
$zonJson = Get-Content -Path $zonJsonPath -Raw | ConvertFrom-Json
$cachePackages = Join-Path $env:ZIG_GLOBAL_CACHE_DIR "p"
$fetchTemp = Join-Path $env:TEMP "tessera-ghostty-prefetch"
New-Item -ItemType Directory -Force -Path $fetchTemp | Out-Null

function Invoke-ZigFetch {
    param(
        [string]$LocalPath,
        [string]$ExpectedKey
    )
    $fetched = (& $zig fetch $LocalPath) -join "`n"
    if ($LASTEXITCODE -ne 0) {
        throw "zig fetch failed for ${LocalPath}: $fetched"
    }
    $fetchedKey = $fetched.Trim()
    if ($fetchedKey -ne $ExpectedKey) {
        throw "cache key mismatch for ${LocalPath}: expected $ExpectedKey, got $fetchedKey"
    }
}

foreach ($property in $zonJson.PSObject.Properties) {
    $expectedKey = $property.Name
    $dependency = $property.Value
    if (Test-Path (Join-Path $cachePackages $expectedKey)) {
        continue
    }
    $url = $dependency.url
    Write-Step "prefetching $($dependency.name) ($expectedKey)"
    if ($url -like "git+https://*") {
        # Zig would fetch this over its broken TLS path. A source archive of the
        # same commit has identical manifest-filtered contents, so it hashes to
        # the same cache key. Fall back to a real clone if that ever diverges.
        if ($url -notmatch '^git\+(https://[^#]+)#([0-9a-f]{40})$') {
            throw "unparseable git dependency url: $url"
        }
        $repoUrl = $Matches[1]
        $commit = $Matches[2]
        $archivePath = Join-Path $fetchTemp "$($dependency.name)-$commit.tar.gz"
        & curl.exe -fL --retry 3 -o $archivePath "$repoUrl/archive/$commit.tar.gz"
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed for $repoUrl/archive/$commit.tar.gz"
        }
        try {
            Invoke-ZigFetch -LocalPath $archivePath -ExpectedKey $expectedKey
        } catch {
            Write-Warning "archive fetch diverged ($_); falling back to git clone"
            $clonePath = Join-Path $fetchTemp "$($dependency.name)-$commit"
            if (Test-Path $clonePath) {
                Remove-Item -Recurse -Force $clonePath
            }
            git clone -q $repoUrl $clonePath
            git -C $clonePath checkout -q $commit
            Invoke-ZigFetch -LocalPath $clonePath -ExpectedKey $expectedKey
        }
    } else {
        $fileName = ([Uri]$url).Segments[-1]
        $archivePath = Join-Path $fetchTemp $fileName
        & curl.exe -fL --retry 3 -o $archivePath $url
        if ($LASTEXITCODE -ne 0) {
            throw "curl failed for $url"
        }
        Invoke-ZigFetch -LocalPath $archivePath -ExpectedKey $expectedKey
    }
}

# Post-condition: every manifest entry must now be cached.
$missing = @(
    $zonJson.PSObject.Properties |
        Where-Object { -not (Test-Path (Join-Path $cachePackages $_.Name)) } |
        ForEach-Object { $_.Name }
)
if ($missing.Count -gt 0) {
    throw "dependencies missing from Zig cache after prefetch: $($missing -join ', ')"
}
Remove-Item -Recurse -Force $fetchTemp -ErrorAction SilentlyContinue
Write-Step "all $($zonJson.PSObject.Properties.Name.Count) dependencies cached"

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
