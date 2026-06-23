<#
.SYNOPSIS
    Instalador do Fortress IaC para Windows
.DESCRIPTION
    Cria a tarefa agendada para executar o fortress-update.ps1 na inicialização
    do sistema e também semanalmente.
#>

$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Acesso negado. Execute o PowerShell como Administrador para instalar."
    exit 1
}

$TaskName = "Fortress-IaC-Update"
$ScriptPath = Resolve-Path ".\fortress-update.ps1" | Select-Object -ExpandProperty Path
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

# Dispara na inicialização do sistema e a cada semana (Domingo 03:00)
$TriggerBoot = New-ScheduledTaskTrigger -AtStartup
$TriggerWeekly = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00AM

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Write-Host "Criando a Tarefa Agendada '$TaskName'..."
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger @($TriggerBoot, $TriggerWeekly) -Principal $Principal -Force | Out-Null

Write-Host "Iniciando a primeira execução imediatamente..."
Start-ScheduledTask -TaskName $TaskName

Write-Host "Instalação concluída com sucesso."
