# ============================================================
#  Monitor-Bateria50.ps1
#  Monitora a bateria e desliga o PC ao atingir 50% de carga.
#  Funciona tanto descarregando quanto carregando.
#  Compatible com Windows 11
# ============================================================

# --- Configuracoes ---
$LIMITE_BATERIA  = 50          # % que dispara o alerta
$INTERVALO_SEG   = 30          # Intervalo de verificacao em segundos
$MINUTOS_ESPERA  = 1           # Minutos de espera antes de desligar apos os bips
$QTDE_BIPS       = 4           # Numero de bips
$FREQ_BIP        = 1000        # Frequencia do bip (Hz)
$DUR_BIP         = 300         # Duracao de cada bip (ms)
$PAUSA_BIPS      = 300         # Pausa entre bips (ms)

# --- Funcoes auxiliares ---

function Get-BateriaInfo {
    $bat = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if (-not $bat) { return $null }
    return [PSCustomObject]@{
        Percentual  = $bat.EstimatedChargeRemaining
        # BatteryStatus: 1=Discharging, 2=AC/Unknown, 3=Fully Charged,
        #                6=Charging, 7=Charging&High, 8=Charging&Low, 9=Charging&Critical
        Status      = $bat.BatteryStatus
        Carregando  = $bat.BatteryStatus -in @(2, 3, 6, 7, 8, 9)
    }
}

function Emitir-Bips {
    param([int]$Quantidade, [int]$Frequencia, [int]$Duracao, [int]$Pausa)
    for ($i = 1; $i -le $Quantidade; $i++) {
        [console]::Beep($Frequencia, $Duracao)
        if ($i -lt $Quantidade) { Start-Sleep -Milliseconds $Pausa }
    }
}

function Mostrar-Status {
    param($Info)
    $statusTxt = if ($Info.Carregando) { "Carregando" } else { "Descarregando" }
    $hora = Get-Date -Format "HH:mm:ss"
    Write-Host "[$hora] Bateria: $($Info.Percentual)%  |  $statusTxt"
}

# --- Inicio ---
Clear-Host
Write-Host "=============================================="
Write-Host "   Monitor de Bateria 50% - Windows 11"
Write-Host "=============================================="
Write-Host "Limite configurado : $LIMITE_BATERIA%"
Write-Host "Verificacao a cada : $INTERVALO_SEG segundos"
Write-Host "Desligamento apos  : $MINUTOS_ESPERA minuto(s) de aviso"
Write-Host "----------------------------------------------"
Write-Host "Pressione Ctrl+C para cancelar."
Write-Host ""

$disparado = $false

while ($true) {
    $info = Get-BateriaInfo

    if ($null -eq $info) {
        Write-Host "[AVISO] Nenhuma bateria detectada. Rodando em modo desktop ou erro de leitura."
        Start-Sleep -Seconds $INTERVALO_SEG
        continue
    }

    Mostrar-Status -Info $info

    # Dispara somente uma vez por execucao
    if (-not $disparado -and $info.Percentual -le $LIMITE_BATERIA) {
        $disparado = $true

        Write-Host ""
        Write-Host "*** ALERTA: Bateria em $($info.Percentual)%! ***" -ForegroundColor Yellow
        Write-Host "Emitindo $QTDE_BIPS bips..."

        Emitir-Bips -Quantidade $QTDE_BIPS -Frequencia $FREQ_BIP `
                    -Duracao $DUR_BIP -Pausa $PAUSA_BIPS

        $segundosEspera = $MINUTOS_ESPERA * 60
        Write-Host ""
        Write-Host "Desligando em $MINUTOS_ESPERA minuto(s)... Pressione Ctrl+C para cancelar!" `
                   -ForegroundColor Red

        # Contagem regressiva visivel
        for ($s = $segundosEspera; $s -gt 0; $s--) {
            Write-Host "`rDesligando em $s segundo(s)...   " -NoNewline -ForegroundColor Red
            Start-Sleep -Seconds 1
        }

        Write-Host ""
        Write-Host "Desligando agora!" -ForegroundColor Red
        Stop-Computer -Force
        break
    }

    Start-Sleep -Seconds $INTERVALO_SEG
}
