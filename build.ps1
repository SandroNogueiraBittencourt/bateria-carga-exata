# ============================================================
#  build.ps1
#  Converte carregamentoBateria.ps1 em executavel (.exe)
#
#  USO: Executar no Windows 11 como Administrador
#       na mesma pasta do carregamentoBateria.ps1
#
#       .\build.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$scriptName = "carregamentoBateria"
$scriptPath = Join-Path $PSScriptRoot "$scriptName.ps1"
$outputPath = Join-Path $PSScriptRoot "$scriptName.exe"
$iconPath   = Join-Path $PSScriptRoot "icone.ico"    # opcional

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build - Monitor de Bateria" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Verifica se o script fonte existe ---
if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERRO] '$scriptPath' nao encontrado." -ForegroundColor Red
    Write-Host "Coloque build.ps1 na mesma pasta do $scriptName.ps1" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host "[OK] Script encontrado: $scriptPath" -ForegroundColor Green

# --- 2. Instala ps2exe se necessario ---
Write-Host ""
Write-Host "Verificando modulo ps2exe..." -ForegroundColor Cyan

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Instalando ps2exe (primeira vez)..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
        Write-Host "[OK] ps2exe instalado com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "[ERRO] Falha ao instalar ps2exe: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Tente manualmente:" -ForegroundColor Yellow
        Write-Host "  Install-Module -Name ps2exe -Scope CurrentUser -Force" -ForegroundColor White
        Write-Host ""
        pause
        exit 1
    }
} else {
    Write-Host "[OK] ps2exe ja esta instalado." -ForegroundColor Green
}

Import-Module ps2exe -Force

# --- 3. Remove exe antigo se existir ---
if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
    Write-Host "[OK] Exe anterior removido." -ForegroundColor Green
}

# --- 4. Monta parametros de compilacao ---
$params = @{
    InputFile    = $scriptPath
    OutputFile   = $outputPath
    NoConsole    = $true       # somente GUI, sem janela de terminal
    RequireAdmin = $true       # pede elevacao (brilho + desligamento)
    Title        = "Monitor de Bateria"
    Description  = "Monitoramento inteligente de bateria para Windows 11"
    Company      = "bateria-carga-exata"
    Product      = "Battery Alert Shutdown"
    Version      = "2.0.0.0"
    Copyright    = "MIT License"
}

# Adiciona icone se existir na pasta
if (Test-Path $iconPath) {
    $params["IconFile"] = $iconPath
    Write-Host "[OK] Icone encontrado: $iconPath" -ForegroundColor Green
} else {
    Write-Host "[INFO] Nenhum icone.ico encontrado, usando icone padrao." -ForegroundColor Yellow
}

# --- 5. Compila ---
Write-Host ""
Write-Host "Compilando..." -ForegroundColor Cyan
Write-Host "  Entrada : $scriptPath" -ForegroundColor White
Write-Host "  Saida   : $outputPath" -ForegroundColor White
Write-Host "  Console : Oculto (somente GUI)" -ForegroundColor White
Write-Host "  Admin   : Sim (UAC)" -ForegroundColor White
Write-Host ""

try {
    Invoke-PS2EXE @params

    if (Test-Path $outputPath) {
        $fileInfo = Get-Item $outputPath
        $sizeKB   = [math]::Round($fileInfo.Length / 1KB, 1)
        $sizeMB   = [math]::Round($fileInfo.Length / 1MB, 2)

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "  Compilado com sucesso!" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Arquivo : $outputPath" -ForegroundColor White
        Write-Host "  Tamanho : $sizeKB KB ($sizeMB MB)" -ForegroundColor White
        Write-Host "  Versao  : 2.0.0.0" -ForegroundColor White
        Write-Host ""
        Write-Host "  Para executar:" -ForegroundColor Cyan
        Write-Host "    Duplo clique em $scriptName.exe" -ForegroundColor White
        Write-Host "    (vai solicitar permissao de Administrador)" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "[ERRO] O arquivo .exe nao foi gerado." -ForegroundColor Red
    }
} catch {
    Write-Host "[ERRO] Falha na compilacao:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
}

Write-Host ""
pause
