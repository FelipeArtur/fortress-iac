<#
.SYNOPSIS
    Fortress IaC Installer for Windows
.DESCRIPTION
    Creates the scheduled task to execute fortress-update.ps1 on system startup
    and also weekly.
#>

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Access denied. Run PowerShell as Administrator to install."
    exit 1
}

$TaskName = "Fortress-IaC-Update"
$ScriptPath = Resolve-Path ".\fortress-update.ps1" | Select-Object -ExpandProperty Path
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

# Triggers on system startup and every week (Sunday 03:00)
$TriggerBoot = New-ScheduledTaskTrigger -AtStartup
# Delay 3 min after boot so the network stabilizes before DNS resolution
# (parity with the Linux timer's OnBootSec=5min). Otherwise SafeSearch
# resolution fails at startup and the script falls back to hardcoded IPs.
$TriggerBoot.Delay = "PT3M"
$TriggerWeekly = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00AM

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Write-Host "Creating the Scheduled Task '$TaskName'..."
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($TriggerBoot, $TriggerWeekly) -Principal $Principal -Force | Out-Null

Write-Host "Starting the first execution immediately..."
Start-ScheduledTask -TaskName $TaskName

Write-Host "Installation completed successfully."
