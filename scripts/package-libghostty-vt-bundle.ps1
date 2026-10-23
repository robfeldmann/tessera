<#
.SYNOPSIS
Add a Windows libghostty-vt variant to an SE-0482 artifact bundle.

.DESCRIPTION
Windows counterpart of scripts/package-libghostty-vt-bundle.sh. Copies the
ghostty-vt-static.lib that scripts/build-libghostty-vt.ps1 installed into a
GhosttyVTLibrary.artifactbundle variant directory, then rewrites the bundle's
info.json from every variant the bundle holds, so repeated runs merge. A variant
whose triples another variant in the bundle already claims is refused. The bundle
also gets Ghostty's LICENSE and scripts\ghostty-vt-licenses\ as
THIRD_PARTY_LICENSES\. The variant table matches the shell script's.

.PARAMETER Variant
windows-arm64 or windows-x86_64 (default: the host's).

.PARAMETER Library
Static library to copy (default: the pinned build's
<output root>\<revision>\<variant>\lib\ghostty-vt-static.lib).

.PARAMETER Bundle
Bundle directory (default: .build\ghostty-vt\GhosttyVTLibrary.artifactbundle, which
TESSERA_GHOSTTY_VT_BUNDLE=local selects in Package.swift).

.PARAMETER License
Ghostty LICENSE to place at the bundle root (default: the pinned source checkout's
LICENSE, when present).

Environment:
  GHOSTTY_VT_REVISION_FILE  Revision file path
  GHOSTTY_VT_OUTPUT_DIR     Output root (default: %LOCALAPPDATA%\tessera\libghostty-vt)
#>

[CmdletBinding()]
param(
    [string]$Variant = "",
    [string]$Library = "",
    [string]$Bundle = "",
    [string]$License = ""
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# The one table of variants, as in package-libghostty-vt-bundle.sh.
$VariantTriples = [ordered]@{
    "macos-arm64" = @("arm64-apple-macosx")
    "macos-x86_64" = @("x86_64-apple-macosx")
    "macos-universal" = @("arm64-apple-macosx", "x86_64-apple-macosx")
    "linux-arm64" = @("aarch64-unknown-linux-gnu")
    "linux-x86_64" = @("x86_64-unknown-linux-gnu")
    "linux-musl-arm64" = @("aarch64-swift-linux-musl")
    "linux-musl-x86_64" = @("x86_64-swift-linux-musl")
    "windows-arm64" = @("aarch64-unknown-windows-msvc")
    "windows-x86_64" = @("x86_64-unknown-windows-msvc")
}

function Get-LibraryName {
    param([string]$Name)
    if ($Name.StartsWith("windows-")) { "ghostty-vt-static.lib" } else { "libghostty-vt.a" }
}

$revisionFile = if ($env:GHOSTTY_VT_REVISION_FILE) {
    $env:GHOSTTY_VT_REVISION_FILE
} else {
    Join-Path $RepoRoot "scripts\ghostty-vt-version.txt"
}
$revision = (Get-Content -LiteralPath $revisionFile | Out-String).Trim()
$outputRoot = if ($env:GHOSTTY_VT_OUTPUT_DIR) {
    $env:GHOSTTY_VT_OUTPUT_DIR
} else {
    Join-Path $env:LOCALAPPDATA "tessera\libghostty-vt"
}

if (-not $Variant) {
    $Variant = switch ($env:PROCESSOR_ARCHITECTURE) {
        "ARM64" { "windows-arm64" }
        "AMD64" { "windows-x86_64" }
        default { throw "unsupported architecture: $env:PROCESSOR_ARCHITECTURE" }
    }
}
if (-not $VariantTriples.Contains($Variant)) {
    throw "unknown variant: $Variant"
}
$libraryName = Get-LibraryName $Variant
if (-not $Library) {
    $Library = Join-Path $outputRoot "$revision\$Variant\lib\$libraryName"
}
if (-not (Test-Path -LiteralPath $Library)) {
    throw "library not found: $Library (run scripts\build-libghostty-vt.ps1 first)"
}
if (-not $Bundle) {
    $Bundle = Join-Path $RepoRoot ".build\ghostty-vt\GhosttyVTLibrary.artifactbundle"
}
# .NET file APIs resolve relative paths against the process directory, not PowerShell's
# location, so make the bundle path absolute before info.json is written.
$Bundle = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Bundle)
$sourceLicense = Join-Path $outputRoot "source\$revision\LICENSE"
if (-not $License -and (Test-Path -LiteralPath $sourceLicense)) {
    $License = $sourceLicense
}

# Two variants that claim the same triple make SwiftPM's choice ambiguous, for example a
# local macos-arm64 build added to a bundle that already holds macos-universal.
foreach ($other in $VariantTriples.Keys) {
    if ($other -eq $Variant) {
        continue
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Bundle "$other\$(Get-LibraryName $other)"))) {
        continue
    }
    foreach ($triple in $VariantTriples[$Variant]) {
        if ($VariantTriples[$other] -contains $triple) {
            throw "$Bundle already has variant $other for $triple; remove it before adding $Variant"
        }
    }
}

$variantDir = Join-Path $Bundle $Variant
if (Test-Path -LiteralPath $variantDir) {
    Remove-Item -LiteralPath $variantDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $variantDir | Out-Null
Copy-Item -LiteralPath $Library -Destination (Join-Path $variantDir $libraryName)
if ($License) {
    Copy-Item -LiteralPath $License -Destination (Join-Path $Bundle "LICENSE")
}
# The third-party components linked into the archives (see the directory's README.md).
$licensesDir = Join-Path $Bundle "THIRD_PARTY_LICENSES"
if (Test-Path -LiteralPath $licensesDir) {
    Remove-Item -LiteralPath $licensesDir -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $RepoRoot "scripts\ghostty-vt-licenses") -Destination $licensesDir -Recurse

# Rewrite info.json from the variant directories present, so repeated runs merge.
$entries = foreach ($name in $VariantTriples.Keys) {
    $file = Get-LibraryName $name
    if (-not (Test-Path -LiteralPath (Join-Path $Bundle "$name\$file"))) {
        continue
    }
    $triples = ($VariantTriples[$name] | ForEach-Object { "`"$_`"" }) -join ", "
    @(
        "        {",
        "          `"path`": `"$name/$file`",",
        "          `"supportedTriples`": [$triples],",
        "          `"staticLibraryMetadata`": { `"headerPaths`": [] }",
        "        }"
    ) -join "`n"
}
$version = $revision.Substring(0, [Math]::Min(12, $revision.Length))
$infoJson = @(
    "{",
    "  `"schemaVersion`": `"1.0`",",
    "  `"artifacts`": {",
    "    `"GhosttyVTLibrary`": {",
    "      `"type`": `"staticLibrary`",",
    "      `"version`": `"$version`",",
    "      `"variants`": [",
    ($entries -join ",`n"),
    "      ]",
    "    }",
    "  }",
    "}"
) -join "`n"
[System.IO.File]::WriteAllText((Join-Path $Bundle "info.json"), $infoJson + "`n", $Utf8NoBom)

Write-Host "Packaged $Variant into $Bundle"
