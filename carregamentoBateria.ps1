# ============================================================
#  carregamentoBateria.ps1
#
#  Comportamento:
#  - CARREGANDO ao atingir 50%:
#    Fica emitindo bips em loop ate o usuario retirar o carregador
#    ou pressionar ENTER para confirmar que ja retirou.
#
#  - DESCARREGANDO ao atingir 50%:
#    Emite 4 bips, aguarda 1 minuto e desliga o computador.
#
#  Compatible com Windows 11
# ============================================================

# --- Configuracoes ---
$LIMITE_BATERIA   = 50    # % que dispara o alerta
$INTERVALO_SEG    = 30    # Intervalo de verificacao em segundos
$MINUTOS_ESPERA   = 1     # Minutos antes de desligar (modo descarga)
$QTDE_BIPS        = 4     # Numero de bips no alerta de descarga
$FREQ_BIP_CARGA   = 1200  # Frequencia do bip (Hz) — carregando
$FREQ_BIP_DESC    = 800   # Frequencia do bip (Hz) — descarregando
$DUR_BIP          = 300   # Duracao de cada bip (ms)
$PAUSA_BIPS       = 300   # Pausa entre bips (ms)
$INTERVALO_LOOP   = 5     # Segundos entre cada rodada de bips no loop de carga

# --- Funcoes auxiliares ---

function Get-BateriaInfo {
    $bat = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if (-not $bat) { return $null }
    return [PSCustomObject]@{
        Percentual = $bat.EstimatedChargeRemaining
        # BatteryStatus: 1=Discharging, 2=AC/Unknown, 3=Fully Charged,
        #                6=Charging, 7=Charging&High, 8=Charging&Low, 9=Charging&Critical
        Carregando = $bat.BatteryStatus -in @(2, 3, 6, 7, 8, 9)
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

# --- Modo CARREGANDO: loop de bips ate desconectar ou confirmar ---
function Iniciar-AlertaCarga {
    Write-Host ""
    Write-Host "*** ALERTA: Bateria em $LIMITE_BATERIA% e CARREGANDO! ***" -ForegroundColor Yellow
    Write-Host "Retire o carregador ou pressione ENTER para confirmar." -ForegroundColor Yellow
    Write-Host ""

    while ($true) {
        # Verifica se o usuario pressionou ENTER
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Enter) {
                Write-Host ""
                Write-Host "[OK] Confirmado pelo usuario. Encerrando alerta." -ForegroundColor Green
                return "ok_usuario"
            }
        }

        # Verifica se o carregador foi retirado
        $info = Get-BateriaInfo
        if ($null -ne $info -and -not $info.Carregando) {
            Write-Host ""
            Write-Host "[OK] Carregador retirado. Encerrando alerta." -ForegroundColor Green
            return "carregador_retirado"
        }

        # Emite bips de aviso
        Emitir-Bips -Quantidade 2 -Frequencia $FREQ_BIP_CARGA -Duracao $DUR_BIP -Pausa $PAUSA_BIPS
        Start-Sleep -Seconds $INTERVALO_LOOP
    }
}

# --- Modo DESCARREGANDO: bips + contagem regressiva + desligamento ---
function Iniciar-AlertaDescarga {
    Write-Host ""
    Write-Host "*** ALERTA: Bateria em $LIMITE_BATERIA% e DESCARREGANDO! ***" -ForegroundColor Red
    Write-Host "Emitindo $QTDE_BIPS bips..."

    Emitir-Bips -Quantidade $QTDE_BIPS -Frequencia $FREQ_BIP_DESC -Duracao $DUR_BIP -Pausa $PAUSA_BIPS

    $segundosEspera = $MINUTOS_ESPERA * 60
    Write-Host ""
    Write-Host "Desligando em $MINUTOS_ESPERA minuto(s)... Pressione Ctrl+C para cancelar!" -ForegroundColor Red

    for ($s = $segundosEspera; $s -gt 0; $s--) {
        Write-Host "`rDesligando em $s segundo(s)...   " -NoNewline -ForegroundColor Red
        Start-Sleep -Seconds 1
    }

    Write-Host ""
    Write-Host "Desligando agora!" -ForegroundColor Red
    Stop-Computer -Force
}

# --- Inicio ---
Clear-Host
Write-Host "=============================================="
Write-Host "   Monitor de Bateria 50% - Windows 11"
Write-Host "=============================================="
Write-Host "Limite configurado : $LIMITE_BATERIA%"
Write-Host "Verificacao a cada : $INTERVALO_SEG segundos"
Write-Host ""
Write-Host "  [Carregando]     -> bips em loop ate retirar o carregador ou pressionar ENTER"
Write-Host "  [Descarregando]  -> 4 bips + $MINUTOS_ESPERA min de espera + desligamento"
Write-Host "----------------------------------------------"
Write-Host "Pressione Ctrl+C para cancelar a qualquer momento."
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

    if (-not $disparado -and $info.Percentual -le $LIMITE_BATERIA) {
        $disparado = $true

        if ($info.Carregando) {
            $resultado = Iniciar-AlertaCarga
            # Apos o alerta, retoma o monitoramento normalmente
            Write-Host ""
            Write-Host "Retomando monitoramento..." -ForegroundColor Cyan
            $disparado = $false   # Permite disparar novamente se necessario
        } else {
            Iniciar-AlertaDescarga
            break
        }
    }

    Start-Sleep -Seconds $INTERVALO_SEG
}

