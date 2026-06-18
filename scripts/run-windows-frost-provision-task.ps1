<#
Run Tessera's Frost provisioning script through Windows Task Scheduler.

Run the provisioning script as an elevated scheduled task while the macOS host starts and
waits for it over SSH. This keeps long-running GUI/bootstrapper-style installers out of
the OpenSSH child process context. Earlier WinGet-based provisioning also hit WinGet error
0x8a15000f over OpenSSH; the current provisioner avoids WinGet for the heavy installs.
#>

[CmdletBinding()]
param(
    [string]$TaskName = "TesseraFrostProvision",
    [Parameter(Mandatory = $true)]
    [string]$ProvisionScript,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedSwiftVersion,
    [Parameter(Mandatory = $true)]
    [string]$AuthorizedKeyPath,
    [Parameter(Mandatory = $true)]
    [string]$UserName,
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [string]$GitInstallerUrl = "",
    [string]$VisualStudioBootstrapperUrl = "",
    [string]$SwiftInstallerUrl = "",
    [int]$TimeoutMinutes = 90
)

$ErrorActionPreference = "Stop"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$TaskUserName = $UserName
if ($TaskUserName -notmatch "[\\\\/@]") {
    $TaskUserName = "$env:COMPUTERNAME\$TaskUserName"
}
Write-Host "Registering task as $TaskUserName"

$provisionArgs = @(
    "-ExpectedSwiftVersion $ExpectedSwiftVersion",
    "-AuthorizedKeyPath `"$AuthorizedKeyPath`""
)
if (-not [string]::IsNullOrWhiteSpace($GitInstallerUrl)) {
    $provisionArgs += "-GitInstallerUrl `"$GitInstallerUrl`""
}
if (-not [string]::IsNullOrWhiteSpace($VisualStudioBootstrapperUrl)) {
    $provisionArgs += "-VisualStudioBootstrapperUrl `"$VisualStudioBootstrapperUrl`""
}
if (-not [string]::IsNullOrWhiteSpace($SwiftInstallerUrl)) {
    $provisionArgs += "-SwiftInstallerUrl `"$SwiftInstallerUrl`""
}

$argument = "-NoProfile -ExecutionPolicy Bypass -File `"$ProvisionScript`" $($provisionArgs -join ' ')"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(5)
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMinutes)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User $TaskUserName `
    -Password $Password `
    -RunLevel Highest `
    -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
do {
    Start-Sleep -Seconds 10
    $task = Get-ScheduledTask -TaskName $TaskName
    Write-Host "Task state: $($task.State)"
    if ((Get-Date) -gt $deadline) {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        throw "Timed out waiting for $TaskName"
    }
} while ($task.State -in @("Queued", "Running"))

$info = Get-ScheduledTaskInfo -TaskName $TaskName
Write-Host "Task result: $($info.LastTaskResult)"
exit $info.LastTaskResult
