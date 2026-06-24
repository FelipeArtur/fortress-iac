<#
.SYNOPSIS
    Fortress IaC — NUKE (Windows)
.DESCRIPTION
    Last-resort reset. Unlike uninstall.ps1 this does not try to be clean: it
    force-removes the scheduled task, STOPS the DNS Client service to release
    the lock on the hosts file (fixes "the file is in use by another process"),
    overwrites hosts with a stock empty default, deletes the DoH policy keys,
    and brings DNS back up. Use only when you just need the internet back.

    WARNING: this discards ALL custom hosts entries (yours included). It writes
    the default Windows hosts file from scratch.
#>

$ErrorActionPreference = "Continue"  # nuclear: never abort, push through every step

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Access denied. Run PowerShell as Administrator."
    exit 1
}

$TaskName = "Fortress-IaC-Update"
$HostsFile = "$env:windir\System32\drivers\etc\hosts"

# 1. Force-kill the scheduled task so nothing re-fortresses on the next boot.
Write-Host ":: [1/5] Force-removing scheduled task '$TaskName'..."
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

# 2. Stop the DNS Client service. It keeps an open handle on the hosts file; a
#    huge fortressed hosts makes it busy and locks the file, which is the
#    "resource in use" error. Stopping it releases the handle so we can write.
Write-Host ":: [2/5] Stopping DNS Client service to release the hosts lock..."
Stop-Service -Name Dnscache -Force -ErrorAction SilentlyContinue
# Fallback for when the service refuses Stop-Service (it is protected on some
# builds): kill it via sc.exe, which does not error the script.
& sc.exe stop Dnscache | Out-Null
Start-Sleep -Seconds 2

# 3. Overwrite hosts with the stock Windows default (no blocks, no redirects).
Write-Host ":: [3/5] Writing a clean default hosts file..."
$DefaultHosts = @"
# Copyright (c) 1993-2009 Microsoft Corp.
#
# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.
#
# For example:
#
#      102.54.94.97     rhino.acme.com          # source server
#       38.25.63.10     x.acme.com              # x client host

# localhost name resolution is handled within DNS itself.
#	127.0.0.1       localhost
#	::1             localhost
"@
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$DefaultHosts = $DefaultHosts -replace "`r`n", "`n" -replace "`n", "`r`n"
[System.IO.File]::WriteAllText($HostsFile, $DefaultHosts, $Utf8NoBom)

# Drop the fortress backup too, so a future install starts from this clean state.
Remove-Item -Path "$env:windir\System32\drivers\etc\hosts.bak" -Force -ErrorAction SilentlyContinue

# 4. Delete the DoH browser policy keys so browsers stop being managed.
Write-Host ":: [4/5] Removing DoH browser policies..."
$ChromiumPolicies = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
    "HKLM:\SOFTWARE\Policies\Google\Chrome",
    "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
)
foreach ($key in $ChromiumPolicies) {
    Remove-ItemProperty -Path $key -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
}
Remove-Item -Path "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS" -Recurse -Force -ErrorAction SilentlyContinue

# 5. Bring the DNS Client back up and flush.
Write-Host ":: [5/5] Restarting DNS Client and flushing cache..."
Start-Service -Name Dnscache -ErrorAction SilentlyContinue
& sc.exe start Dnscache | Out-Null
Clear-DnsClientCache

Write-Host ">> NUKED. hosts reset, task gone, DoH unlocked. Reboot if anything still misbehaves, then go play."
