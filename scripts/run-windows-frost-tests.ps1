<#
Run Tessera tests inside a Windows Frost guest.
#>

[CmdletBinding()]
param(
    [string]$RepoPath = "C:\Users\tester\tessera",
    [string]$SwiftTestArgsBase64 = ""
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

Write-Host "==> Swift"
swift --version

$swiftTestArgs = Decode-SwiftTestArgs -EncodedArgs $SwiftTestArgsBase64
$swiftArgs = @("test", "--no-parallel") + $swiftTestArgs

Write-Host "==> swift $($swiftArgs -join ' ')"
& swift @swiftArgs
exit $LASTEXITCODE
