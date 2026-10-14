@echo off
setlocal
set "SELF=%~f0"
set "TEMPPS=%TEMP%\ImpressoraFix-%RANDOM%-%RANDOM%.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:SELF; $c=Get-Content -LiteralPath $p -Raw -Encoding UTF8; $marker=([char]58+'__POWERSHELL_BODY_8C21__'); $i=$c.IndexOf($marker); if($i -lt 0){exit 2}; $s=$c.Substring($i+$marker.Length); Set-Content -LiteralPath $env:TEMPPS -Value $s -Encoding UTF8; if(-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$env:TEMPPS+'"')); exit}; & $env:TEMPPS"
set "RC=%ERRORLEVEL%"
del "%TEMPPS%" >nul 2>&1
if not "%RC%"=="0" pause
exit /b %RC%
:__POWERSHELL_BODY_8C21__<#
  Correcao de impressoras de rede para Windows 10/11.
  Este arquivo gera backup e apresenta o resultado de cada etapa.
#>

$ErrorActionPreference = 'Stop'
$results = [System.Collections.Generic.List[object]]::new()
$transcriptStarted = $false
function Add-Result([string]$Step, [string]$Status, [string]$Reason = '') {
    $results.Add([pscustomobject]@{ Etapa = $Step; Status = $Status; Motivo = $Reason })
    $color = if ($Status -eq 'OK') { 'Green' } elseif ($Status -eq 'ERRO') { 'Red' } else { 'Yellow' }
    $line = "[$Status] $Step"
    if ($Reason) { $line += " - $Reason" }
    Write-Host $line -ForegroundColor $color
}
function Short-Error($ErrorRecord) {
    $message = ($ErrorRecord.Exception.Message -replace '\s+', ' ').Trim()
    if ($message.Length -gt 140) { $message = $message.Substring(0,137) + '...' }
    return $message
}
function Set-Dword([string]$Path, [string]$Name, [int]$Value) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
}
function Backup-RegKey([string]$Key, [string]$File) {
    $psPath = $Key -replace '^HKLM\\', 'HKLM:\'
    if (-not (Test-Path -LiteralPath $psPath)) { return $false }
    & "$env:WINDIR\System32\reg.exe" export $Key $File /y *> $null
    if ($LASTEXITCODE -ne 0) { throw 'reg.exe nao conseguiu exportar a chave' }
    return $true
}

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [Environment]::OSVersion.Version.Build
    if ($os.ProductType -ne 1) { throw 'Sistema Server nao suportado; nenhuma correcao aplicada' }
    if ($build -lt 17763) { throw "Windows build $build nao suportado" }

    $backupRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) ('ImpressoraFix-Backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $logFile = Join-Path $backupRoot 'execucao.log'
    Start-Transcript -Path $logFile -Force | Out-Null
    $transcriptStarted = $true
    Write-Host "Windows: $($os.Caption), build $build`nBackup e log: $backupRoot`n"

    $backupDefs = @(
        @('HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC','Printers-RPC.reg'),
        @('HKLM\SYSTEM\CurrentControlSet\Control\Print','Print.reg'),
        @('HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides','FeatureManagement-Overrides.reg')
    )
    foreach ($item in $backupDefs) {
        try {
            $exists = Backup-RegKey $item[0] (Join-Path $backupRoot $item[1])
            if ($exists) { Add-Result "Backup $($item[1])" 'OK' 'chave exportada' }
            else { Add-Result "Backup $($item[1])" 'Ignorado' 'chave ainda nao existia' }
        } catch { Add-Result "Backup $($item[1])" 'ERRO' (Short-Error $_) }
    }

    foreach ($feature in @('Printing-Foundation-LPDPrintService')) {
        try {
            $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction Stop
            if ($state.State -eq 'Enabled') { Add-Result $feature 'OK' 'ja estava habilitado'; continue }
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart -ErrorAction Stop | Out-Null
            Add-Result $feature 'OK' 'habilitado; pode exigir reinicializacao'
        } catch { Add-Result $feature 'ERRO' (Short-Error $_) }
    }
    try {
        $lprFeatures = @(Get-WindowsOptionalFeature -Online -ErrorAction Stop | Where-Object { $_.FeatureName -match 'LPR' })
        if ($lprFeatures.Count -eq 0) {
            Add-Result 'LPR Port Monitor' 'Ignorado' 'recurso LPR nao disponivel nesta instalacao do Windows'
        } else {
            foreach ($feature in $lprFeatures) {
                if ($feature.State -eq 'Enabled') { Add-Result "LPR Port Monitor ($($feature.FeatureName))" 'OK' 'ja estava habilitado'; continue }
                Enable-WindowsOptionalFeature -Online -FeatureName $feature.FeatureName -All -NoRestart -ErrorAction Stop | Out-Null
                Add-Result "LPR Port Monitor ($($feature.FeatureName))" 'OK' 'habilitado; pode exigir reinicializacao'
            }
        }
    } catch { Add-Result 'LPR Port Monitor' 'ERRO' (Short-Error $_) }

    $rpcPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC'
    foreach ($setting in @(
        @('RpcUseNamedPipeProtocol',1),
        @('RpcOverNamedPipes',1),
        @('RpcOverTcp',0)
    )) {
        try {
            Set-Dword $rpcPath $setting[0] $setting[1]
            Add-Result $setting[0] 'OK' "DWORD=$($setting[1])"
        } catch { Add-Result $setting[0] 'ERRO' (Short-Error $_) }
    }

    $override = switch ($build) {
        17763 { '3598754956' }
        18363 { '1921033356' }
        { $_ -in 19041,19042,19043,19044 } { '713073804' }
        default { $null }
    }
    if ($override) {
        try {
            Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides' $override 0
            Add-Result "Override legado 0x00000709 ($override)" 'OK' "compativel com build $build"
        } catch { Add-Result 'Override legado 0x00000709' 'ERRO' (Short-Error $_) }
    } else { Add-Result 'Override legado 0x00000709' 'Ignorado' "sem ajuste especifico fornecido para build $build" }

    try {
        Set-Dword 'HKLM:\SYSTEM\CurrentControlSet\Control\Print' 'RpcAuthnLevelPrivacyEnabled' 0
        Add-Result 'RpcAuthnLevelPrivacyEnabled' 'OK' 'DWORD=0 aplicado automaticamente; protecao RPC reduzida'
    } catch { Add-Result 'RpcAuthnLevelPrivacyEnabled' 'ERRO' (Short-Error $_) }

    try {
        Restart-Service -Name Spooler -Force -ErrorAction Stop
        Add-Result 'Reiniciar Spooler' 'OK' 'servico reiniciado'
    } catch { Add-Result 'Reiniciar Spooler' 'ERRO' (Short-Error $_) }

    Write-Host "`n========== RESUMO ==========" -ForegroundColor Cyan
    $results | ForEach-Object {
        $suffix = if ($_.Motivo) { " - $($_.Motivo)" } else { '' }
        Write-Host "[$($_.Status)] $($_.Etapa)$suffix"
    }
    $ok = @($results | Where-Object Status -eq 'OK').Count
    $skipped = @($results | Where-Object Status -eq 'Ignorado').Count
    $failed = @($results | Where-Object Status -eq 'ERRO').Count
    Write-Host "`nAplicados/concluidos: $ok | Ignorados: $skipped | Erros: $failed"
    Write-Host "Backup e log detalhado: $backupRoot"
} catch {
    Add-Result 'Execucao' 'ERRO' (Short-Error $_)
    Write-Host 'Execucao interrompida antes de concluir todas as etapas.' -ForegroundColor Red
} finally {
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
}
Read-Host 'Pressione Enter para fechar' | Out-Null

