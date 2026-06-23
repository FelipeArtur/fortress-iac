<#
.SYNOPSIS
    Fortress IaC — Escudo Adulto & SafeSearch (Windows)
.DESCRIPTION
    Aplica filtragem de conteúdo adulto e força o modo de Busca Segura nos
    principais mecanismos de pesquisa (Google, Bing, DuckDuckGo) via manipulação
    do arquivo de hosts do Windows.
#>

$ErrorActionPreference = "Stop"

# Requer elevação (Administrador)
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Acesso negado. Execute o PowerShell como Administrador."
    exit 1
}

$Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn/hosts"
$HostsFile = "$env:windir\System32\drivers\etc\hosts"
$HostsLocal = "$env:windir\System32\drivers\etc\hosts.local"
$BackupFile = "$env:windir\System32\drivers\etc\hosts.bak"
$TmpDownload = "$env:TEMP\hosts_stevenblack.tmp"
$TmpFinal = "$env:TEMP\hosts_final.tmp"

# Garante a existência do hosts.local para rotas locais customizadas
if (!(Test-Path $HostsLocal)) {
    Write-Host ":: [1/6] Criando arquivo para hosts locais em $HostsLocal..."
    if (Select-String -Path $HostsFile -Pattern "StevenBlack" -Quiet) {
        New-Item -Path $HostsLocal -ItemType File -Force | Out-Null
    } else {
        Copy-Item -Path $HostsFile -Destination $HostsLocal -Force
    }
}

Write-Host ":: [2/6] Baixando a matriz de bloqueio de StevenBlack..."
try {
    Invoke-WebRequest -Uri $Url -OutFile $TmpDownload -UseBasicParsing
} catch {
    Write-Error "[!] Falha ao baixar a lista. Abortando."
    exit 1
}

Write-Host ":: [3/6] Preparando Entradas Locais..."
$LocalContent = Get-Content -Path $HostsLocal -Raw
$ListContent = Get-Content -Path $TmpDownload -Raw

$FinalContent = $LocalContent + "`n`n# ==========================================`n# FORTRESS: BLOCKLIST (StevenBlack)`n# ==========================================`n" + $ListContent

Write-Host ":: [4/6] Injetando Módulo SafeSearch (Google, Bing, DuckDuckGo)..."

function Resolve-SafeSearch {
    param([string]$Domain, [string]$Fallback)
    try {
        $Result = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop | Select-Object -First 1
        return $Result.IPAddress
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
Set-Content -Path $TmpFinal -Value $FinalContent -Encoding utf8

Write-Host ":: [5/6] Aplicando substituição no arquivo de hosts..."
Copy-Item -Path $HostsFile -Destination $BackupFile -Force
Copy-Item -Path $TmpFinal -Destination $HostsFile -Force
Remove-Item -Path $TmpDownload -Force

Write-Host ":: [6/6] Expurgando o cache de resolução DNS..."
Clear-DnsClientCache

Write-Host ">> Operação concluída. Tráfego bloqueado e Motores de Busca em modo Estrito."
