<#
.SYNOPSIS
    Fortress IaC Installer for Windows
.DESCRIPTION
    Creates the scheduled task to execute fortress-update.ps1 on system startup
    and also weekly, and disables DNS-over-HTTPS (DoH) in supported browsers via
    policy so they cannot bypass the hosts-based filtering.
#>

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Access denied. Run PowerShell as Administrator to install."
    exit 1
}

# Disable DNS-over-HTTPS via browser policy. Without this, browsers resolve
# domains over an encrypted DNS channel and ignore the hosts file entirely,
# defeating the whole filter. Setting it as a managed policy also prevents a
# user from re-enabling it in the browser UI (the toggle becomes greyed out).
# NOTE: this writes machine-wide policy keys under HKLM\SOFTWARE\Policies and
# will make the browser report "managed by your organization" — expected.
function Disable-BrowserDoH {
    # Chromium-family browsers: DnsOverHttpsMode = "off" (REG_SZ).
    $ChromiumPolicies = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
        "HKLM:\SOFTWARE\Policies\Google\Chrome",
        "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
    )
    foreach ($key in $ChromiumPolicies) {
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -Path $key -Name "DnsOverHttpsMode" -Value "off" -Type String
    }

    # Firefox uses its own policy tree; Enabled=0 turns DoH off, Locked=1 pins it.
    $Firefox = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS"
    New-Item -Path $Firefox -Force | Out-Null
    Set-ItemProperty -Path $Firefox -Name "Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $Firefox -Name "Locked"  -Value 1 -Type DWord

    Write-Host "DoH disabled via policy for Edge, Chrome, Brave, and Firefox."
}

Write-Host "Hardening browsers (disabling DNS-over-HTTPS)..."
Disable-BrowserDoH

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

# Apply the filter now by running the engine DIRECTLY in this elevated session.
# We intentionally do NOT use Start-ScheduledTask here: the task runs as SYSTEM,
# which does not inherit the interactive user's network/proxy and can silently
# fail to download the blocklist on first install. A direct call guarantees the
# block is applied immediately, with working network. The task still handles the
# scheduled boot/weekly runs.
Write-Host "Applying the filter now (first run)..."
& $ScriptPath

Write-Host "Installation completed successfully."
