<#
.SYNOPSIS
    Fortress IaC Uninstaller for Windows
.DESCRIPTION
    Reverts every change made by install.ps1 and fortress-update.ps1:
    removes the scheduled task, restores the original hosts file from the
    backup, re-enables DNS-over-HTTPS by deleting the browser policy keys,
    and flushes the DNS cache. Run as Administrator.
#>

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Access denied. Run PowerShell as Administrator to uninstall."
    exit 1
}

$TaskName = "Fortress-IaC-Update"
$HostsFile = "$env:windir\System32\drivers\etc\hosts"
$BackupFile = "$env:windir\System32\drivers\etc\hosts.bak"

# 1. Remove the scheduled task FIRST. Otherwise the boot/weekly trigger would
#    re-fortress the hosts file after we restore it.
Write-Host ":: [1/4] Removing the Scheduled Task '$TaskName'..."
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "   Task removed."
} else {
    Write-Host "   Task not found (already removed)."
}

# 2. Restore the original hosts from the backup made on first install. If the
#    backup is missing (install never completed), strip the FORTRESS blocks so
#    we still hand back a working hosts file.
Write-Host ":: [2/4] Restoring the original hosts file..."
if (Test-Path $BackupFile) {
    Copy-Item -Path $BackupFile -Destination $HostsFile -Force
    Remove-Item -Path $BackupFile -Force
    Write-Host "   Restored from hosts.bak."
} else {
    Write-Warning "   hosts.bak not found. Stripping FORTRESS blocks in place."
    $lines = Get-Content -Path $HostsFile
    $clean = @()
    $skip = $false
    foreach ($line in $lines) {
        if ($line -match "FORTRESS:") { $skip = $true }
        if (-not $skip) { $clean += $line }
    }
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($HostsFile, ($clean -join "`r`n"), $Utf8NoBom)
}

# 3. Re-enable DNS-over-HTTPS by deleting the managed-policy keys the installer
#    wrote. This also clears the "managed by your organization" banner.
Write-Host ":: [3/4] Re-enabling DNS-over-HTTPS (removing browser policies)..."
$ChromiumPolicies = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Edge",
    "HKLM:\SOFTWARE\Policies\Google\Chrome",
    "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
)
foreach ($key in $ChromiumPolicies) {
    if (Test-Path $key) {
        Remove-ItemProperty -Path $key -Name "DnsOverHttpsMode" -ErrorAction SilentlyContinue
    }
}
$Firefox = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox\DNSOverHTTPS"
if (Test-Path $Firefox) {
    Remove-Item -Path $Firefox -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Flush the DNS cache so the old blocked/redirected entries stop resolving.
Write-Host ":: [4/4] Flushing DNS resolution cache..."
Clear-DnsClientCache

Write-Host ">> Uninstall complete. Original hosts restored and the filter is gone."
