<#
.SYNOPSIS
    Fortress IaC — Adult Shield & SafeSearch (Windows)
.DESCRIPTION
    Applies adult content filtering and forces SafeSearch mode on major search
    engines (Google, Bing, DuckDuckGo) via Windows hosts file manipulation.
#>

$ErrorActionPreference = "Stop"

# Requires elevation (Administrator)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Access denied. Run PowerShell as Administrator."
    exit 1
}

$Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"
$HostsFile = "$env:windir\System32\drivers\etc\hosts"
$HostsLocal = "$env:windir\System32\drivers\etc\hosts.local"
$BackupFile = "$env:windir\System32\drivers\etc\hosts.bak"
$TmpDownload = "$env:TEMP\hosts_stevenblack.tmp"
$TmpFinal = "$env:TEMP\hosts_final.tmp"

# Ensures the existence of hosts.local for custom local routes
if (!(Test-Path $HostsLocal)) {
    Write-Host ":: [1/6] Creating file for local hosts at $HostsLocal..."
    if (Select-String -Path $HostsFile -Pattern "StevenBlack" -Quiet) {
        New-Item -Path $HostsLocal -ItemType File -Force | Out-Null
    } else {
        Copy-Item -Path $HostsFile -Destination $HostsLocal -Force
    }
}

Write-Host ":: [2/6] Downloading StevenBlack's blocklist matrix..."
try {
    Invoke-WebRequest -Uri $Url -OutFile $TmpDownload -UseBasicParsing
} catch {
    Write-Error "[!] Failed to download the list. Aborting."
    exit 1
}

Write-Host ":: [3/6] Preparing Local Entries..."
$LocalContent = Get-Content -Path $HostsLocal -Raw
$ListContent = Get-Content -Path $TmpDownload -Raw

$FinalContent = $LocalContent + "`n`n# ==========================================`n# FORTRESS: BLOCKLIST (StevenBlack)`n# ==========================================`n" + $ListContent

Write-Host ":: [4/6] Injecting SafeSearch Module (Google, Bing, DuckDuckGo)..."

function Resolve-SafeSearch {
    param([string]$Domain, [string]$Fallback)
    try {
        # Filter to A records only. Resolve-DnsName returns the full answer
        # chain (CNAME + A); the first record is often a CNAME whose
        # .IPAddress is null, which would silently produce an empty IP.
        $Record = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop |
            Where-Object { $_.Type -eq 'A' -and $_.IPAddress } |
            Select-Object -First 1
        if ($Record) { return $Record.IPAddress }
        return $Fallback
    } catch {
        return $Fallback
    }
}

$IpGoogle = Resolve-SafeSearch -Domain "forcesafesearch.google.com" -Fallback "216.239.38.120"
$IpBing = Resolve-SafeSearch -Domain "strict.bing.com" -Fallback "204.79.197.220"
$IpDdg = Resolve-SafeSearch -Domain "safe.duckduckgo.com" -Fallback "107.20.240.232"

$SafeSearchBlock = @"

# ==========================================
# FORTRESS: FORCED SAFESEARCH
# ==========================================
$IpGoogle www.google.com
$IpGoogle www.google.com.br
$IpGoogle google.com
$IpBing www.bing.com
$IpBing bing.com
$IpDdg duckduckgo.com
$IpDdg www.duckduckgo.com
"@

$FinalContent += $SafeSearchBlock

# Normalize all line endings to CRLF for Windows.
$FinalContent = $FinalContent -replace "`r`n", "`n" -replace "`n", "`r`n"

# Write WITHOUT a BOM. PowerShell 5.1 '-Encoding utf8' emits a BOM, which
# corrupts the first hosts entry and breaks resolution. UTF8Encoding($false)
# guarantees no BOM while preserving any non-ASCII comments in hosts.local.
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($TmpFinal, $FinalContent, $Utf8NoBom)

Write-Host ":: [5/6] Applying replacement to the hosts file..."
Copy-Item -Path $HostsFile -Destination $BackupFile -Force
Copy-Item -Path $TmpFinal -Destination $HostsFile -Force
Remove-Item -Path $TmpDownload -Force -ErrorAction SilentlyContinue
Remove-Item -Path $TmpFinal -Force -ErrorAction SilentlyContinue

Write-Host ":: [6/6] Flushing DNS resolution cache..."
Clear-DnsClientCache

Write-Host ">> Operation complete. Traffic blocked and Search Engines set to Strict mode."
