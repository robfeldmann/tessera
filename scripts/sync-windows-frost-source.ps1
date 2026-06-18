<#
Extract a Tessera source archive into a Windows Frost guest path.
#>

[CmdletBinding()]
param(
    [string]$ArchivePath = "C:\Windows\Temp\tessera-source.tar.gz",
    [string]$Destination = "C:\Users\tester\tessera"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ArchivePath)) {
    throw "Source archive not found: $ArchivePath"
}

if (Test-Path $Destination) {
    Remove-Item -Recurse -Force $Destination
}
New-Item -ItemType Directory -Force $Destination | Out-Null

Write-Host "Extracting $ArchivePath to $Destination"
tar -xf $ArchivePath -C $Destination
if ($LASTEXITCODE -ne 0) {
    throw "tar failed with exit code $LASTEXITCODE"
}

Write-Host "Source sync complete: $Destination"
