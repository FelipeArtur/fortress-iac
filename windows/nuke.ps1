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
#    Dnscache often refuses the first stop ("cannot accept control messages at
#    this time") while it is busy reloading the giant hosts, so retry until it
#    actually reports Stopped instead of trusting a single fire-and-forget call.
Write-Host ":: [2/5] Stopping DNS Client service to release the hosts lock..."
$dnsStopped = $false
for ($i = 1; $i -le 10; $i++) {
    Stop-Service -Name Dnscache -Force -ErrorAction SilentlyContinue
    & sc.exe stop Dnscache | Out-Null
    Start-Sleep -Seconds 2
    if ((Get-Service -Name Dnscache -ErrorAction SilentlyContinue).Status -eq 'Stopped') {
        $dnsStopped = $true
        Write-Host "   Dnscache stopped (attempt $i)."
        break
    }
    Write-Host "   Dnscache still running, retrying ($i/10)..."
}
if (-not $dnsStopped) {
    Write-Warning "   Could not stop Dnscache; the hosts file may stay locked."
    Write-Warning "   Disabling it so it is NOT running after a reboot:"
    Write-Warning "     Set-Service Dnscache -StartupType Disabled; Restart-Computer"
    Write-Warning "   then re-run nuke.ps1, and afterwards re-enable it:"
    Write-Warning "     Set-Service Dnscache -StartupType Automatic; Start-Service Dnscache"
}

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
# Retry the write: even after Dnscache stops, an antivirus (e.g. Defender) can
# briefly hold the handle. Loop a few times before giving actionable advice.
$written = $false
for ($i = 1; $i -le 5; $i++) {
    try {
        [System.IO.File]::WriteAllText($HostsFile, $DefaultHosts, $Utf8NoBom)
        $written = $true
        break
    } catch {
        Write-Host "   hosts still locked, retrying ($i/5)..."
        Start-Sleep -Seconds 2
    }
}
if (-not $written) {
    Write-Warning "   Could not write hosts; another process holds it (Dnscache or antivirus)."
    Write-Warning "   Disable Dnscache and reboot, then re-run this script:"
    Write-Warning "     Set-Service Dnscache -StartupType Disabled; Restart-Computer"
}

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
