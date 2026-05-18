# ============================================================
#  carregamentoBateria.ps1
#  Interface grafica Windows Forms + logica de monitoramento
#
#  Logica (adaptada do script Bash original):
#
#  DESCARREGANDO:
#    < 40%      → avisa para carregar (label amarelo)
#    40% a 49%  → desliga o computador imediatamente
#    >= 50%     → exibe "aguarde, X% ainda" (label neutro)
#
#  CARREGANDO:
#    < 40%      → avisa que ainda esta carregando (label azul)
#    >= 40%     → avisa para desligar da tomada + bip (label verde)
#
#  Windows 11 — Windows Forms (.NET nativo)
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuracoes ---
$INTERVALO_MS   = 3000   # Intervalo de verificacao (ms)
$FREQ_BIP       = 1000   # Frequencia do bip (Hz)
$DUR_BIP        = 400    # Duracao do bip (ms)

# --- Estado global ---
$script:rodando     = $false
$script:ultimoAviso = ""

# ============================================================
#  FUNCOES AUXILIARES
# ============================================================

function Get-BateriaInfo {
    $bat = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if (-not $bat) { return $null }
    return [PSCustomObject]@{
        Percentual = [int]$bat.EstimatedChargeRemaining
        Carregando = $bat.BatteryStatus -in @(2, 3, 6, 7, 8, 9)
    }
}

function Emitir-Bip {
    [Console]::Beep($FREQ_BIP, $DUR_BIP)
}

function Get-CorBarra {
    param([int]$Pct)
    if ($Pct -ge 50) { return [System.Drawing.Color]::FromArgb(29, 158, 117)  }  # verde
    if ($Pct -ge 40) { return [System.Drawing.Color]::FromArgb(239, 159, 39)  }  # amarelo
    return             [System.Drawing.Color]::FromArgb(226, 75, 74)               # vermelho
}

# ============================================================
#  JANELA PRINCIPAL
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Monitor de Bateria"
$form.Size            = New-Object System.Drawing.Size(400, 520)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = [System.Drawing.Color]::FromArgb(245, 245, 243)
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 10)

# --- Titulo ---
$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text      = "Monitor de Bateria"
$lblTitulo.Font      = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$lblTitulo.ForeColor = [System.Drawing.Color]::FromArgb(44, 44, 42)
$lblTitulo.AutoSize  = $true
$lblTitulo.Location  = New-Object System.Drawing.Point(20, 20)
$form.Controls.Add($lblTitulo)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text      = "Windows 11 — Script PowerShell"
$lblSub.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblSub.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblSub.AutoSize  = $true
$lblSub.Location  = New-Object System.Drawing.Point(20, 48)
$form.Controls.Add($lblSub)

# --- Painel porcentagem ---
$painelPct = New-Object System.Windows.Forms.Panel
$painelPct.Size        = New-Object System.Drawing.Size(358, 140)
$painelPct.Location    = New-Object System.Drawing.Point(20, 80)
$painelPct.BackColor   = [System.Drawing.Color]::White
$painelPct.BorderStyle = "FixedSingle"
$form.Controls.Add($painelPct)

$lblPct = New-Object System.Windows.Forms.Label
$lblPct.Text      = "—"
$lblPct.Font      = New-Object System.Drawing.Font("Segoe UI", 52, [System.Drawing.FontStyle]::Bold)
$lblPct.ForeColor = [System.Drawing.Color]::FromArgb(44, 44, 42)
$lblPct.AutoSize  = $true
$lblPct.Location  = New-Object System.Drawing.Point(16, 14)
$painelPct.Controls.Add($lblPct)

$lblDeCarga = New-Object System.Windows.Forms.Label
$lblDeCarga.Text      = "de carga"
$lblDeCarga.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$lblDeCarga.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblDeCarga.AutoSize  = $true
$lblDeCarga.Location  = New-Object System.Drawing.Point(18, 92)
$painelPct.Controls.Add($lblDeCarga)

# Barra de progresso
$barraPanel = New-Object System.Windows.Forms.Panel
$barraPanel.Size      = New-Object System.Drawing.Size(210, 16)
$barraPanel.Location  = New-Object System.Drawing.Point(130, 30)
$barraPanel.BackColor = [System.Drawing.Color]::FromArgb(209, 209, 199)
$painelPct.Controls.Add($barraPanel)

$barraFill = New-Object System.Windows.Forms.Panel
$barraFill.Size      = New-Object System.Drawing.Size(0, 16)
$barraFill.Location  = New-Object System.Drawing.Point(0, 0)
$barraFill.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
$barraPanel.Controls.Add($barraFill)

# Marcacao do limite 40%
$marca40 = New-Object System.Windows.Forms.Panel
$marca40.Size      = New-Object System.Drawing.Size(2, 24)
$marca40.Location  = New-Object System.Drawing.Point([int](210 * 0.40), -4)
$marca40.BackColor = [System.Drawing.Color]::FromArgb(226, 75, 74)
$barraPanel.Controls.Add($marca40)

$lblMarca40 = New-Object System.Windows.Forms.Label
$lblMarca40.Text      = "40%"
$lblMarca40.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblMarca40.ForeColor = [System.Drawing.Color]::FromArgb(226, 75, 74)
$lblMarca40.AutoSize  = $true
$lblMarca40.Location  = New-Object System.Drawing.Point(130, 50)
$painelPct.Controls.Add($lblMarca40)

# --- Cards de info ---
$cardStatus = New-Object System.Windows.Forms.Panel
$cardStatus.Size        = New-Object System.Drawing.Size(170, 70)
$cardStatus.Location    = New-Object System.Drawing.Point(20, 238)
$cardStatus.BackColor   = [System.Drawing.Color]::White
$cardStatus.BorderStyle = "FixedSingle"
$form.Controls.Add($cardStatus)

$lblStatusTitulo = New-Object System.Windows.Forms.Label
$lblStatusTitulo.Text      = "STATUS"
$lblStatusTitulo.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblStatusTitulo.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblStatusTitulo.AutoSize  = $true
$lblStatusTitulo.Location  = New-Object System.Drawing.Point(10, 10)
$cardStatus.Controls.Add($lblStatusTitulo)

$lblStatusValor = New-Object System.Windows.Forms.Label
$lblStatusValor.Text      = "—"
$lblStatusValor.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(44, 44, 42)
$lblStatusValor.AutoSize  = $true
$lblStatusValor.Location  = New-Object System.Drawing.Point(10, 34)
$cardStatus.Controls.Add($lblStatusValor)

$cardMonitor = New-Object System.Windows.Forms.Panel
$cardMonitor.Size        = New-Object System.Drawing.Size(170, 70)
$cardMonitor.Location    = New-Object System.Drawing.Point(208, 238)
$cardMonitor.BackColor   = [System.Drawing.Color]::White
$cardMonitor.BorderStyle = "FixedSingle"
$form.Controls.Add($cardMonitor)

$lblMonitorTitulo = New-Object System.Windows.Forms.Label
$lblMonitorTitulo.Text      = "MONITORAMENTO"
$lblMonitorTitulo.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$lblMonitorTitulo.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblMonitorTitulo.AutoSize  = $true
$lblMonitorTitulo.Location  = New-Object System.Drawing.Point(10, 10)
$cardMonitor.Controls.Add($lblMonitorTitulo)

$lblMonitorValor = New-Object System.Windows.Forms.Label
$lblMonitorValor.Text      = "Parado"
$lblMonitorValor.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblMonitorValor.AutoSize  = $true
$lblMonitorValor.Location  = New-Object System.Drawing.Point(10, 34)
$cardMonitor.Controls.Add($lblMonitorValor)

# --- Painel de aviso principal ---
$painelAviso = New-Object System.Windows.Forms.Panel
$painelAviso.Size        = New-Object System.Drawing.Size(358, 64)
$painelAviso.Location    = New-Object System.Drawing.Point(20, 326)
$painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(241, 239, 232)
$painelAviso.BorderStyle = "FixedSingle"
$form.Controls.Add($painelAviso)

$lblAvisoIcone = New-Object System.Windows.Forms.Label
$lblAvisoIcone.Text      = "ℹ"
$lblAvisoIcone.Font      = New-Object System.Drawing.Font("Segoe UI", 18)
$lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblAvisoIcone.AutoSize  = $true
$lblAvisoIcone.Location  = New-Object System.Drawing.Point(10, 18)
$painelAviso.Controls.Add($lblAvisoIcone)

$lblAviso = New-Object System.Windows.Forms.Label
$lblAviso.Text      = "Aguardando inicio do monitoramento..."
$lblAviso.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$lblAviso.ForeColor = [System.Drawing.Color]::FromArgb(95, 94, 90)
$lblAviso.Size      = New-Object System.Drawing.Size(310, 50)
$lblAviso.Location  = New-Object System.Drawing.Point(44, 8)
$painelAviso.Controls.Add($lblAviso)

# --- Legenda dos limites ---
$painelLegenda = New-Object System.Windows.Forms.Panel
$painelLegenda.Size        = New-Object System.Drawing.Size(358, 50)
$painelLegenda.Location    = New-Object System.Drawing.Point(20, 406)
$painelLegenda.BackColor   = [System.Drawing.Color]::White
$painelLegenda.BorderStyle = "FixedSingle"
$form.Controls.Add($painelLegenda)

function Add-LegendaItem {
    param([System.Drawing.Color]$Cor, [string]$Texto, [int]$X)
    $dot = New-Object System.Windows.Forms.Panel
    $dot.Size      = New-Object System.Drawing.Size(10, 10)
    $dot.Location  = New-Object System.Drawing.Point($X, 20)
    $dot.BackColor = $Cor
    $painelLegenda.Controls.Add($dot)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $Texto
    $lbl.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(95, 94, 90)
    $lbl.AutoSize  = $true
    $lbl.Location  = New-Object System.Drawing.Point(($X + 14), 18)
    $painelLegenda.Controls.Add($lbl)
}

Add-LegendaItem -Cor ([System.Drawing.Color]::FromArgb(226,75,74))   -Texto "< 40%"    -X 8
Add-LegendaItem -Cor ([System.Drawing.Color]::FromArgb(239,159,39))  -Texto "40–49%"   -X 80
Add-LegendaItem -Cor ([System.Drawing.Color]::FromArgb(29,158,117))  -Texto ">= 50%"   -X 160
Add-LegendaItem -Cor ([System.Drawing.Color]::FromArgb(24,95,165))   -Texto "Carregando" -X 232

# --- Botoes ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text      = "▶  Start"
$btnStart.Size      = New-Object System.Drawing.Size(170, 44)
$btnStart.Location  = New-Object System.Drawing.Point(20, 464)
$btnStart.FlatStyle = "Flat"
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStart.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text      = "■  Parar"
$btnStop.Size      = New-Object System.Drawing.Size(170, 44)
$btnStop.Location  = New-Object System.Drawing.Point(208, 464)
$btnStop.FlatStyle = "Flat"
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(209, 209, 199)
$btnStop.ForeColor = [System.Drawing.Color]::FromArgb(95, 94, 90)
$btnStop.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStop.FlatAppearance.BorderSize = 0
$btnStop.Enabled   = $false
$form.Controls.Add($btnStop)

# ============================================================
#  FUNCAO CENTRAL DE LOGICA (equivalente ao awk do Bash)
# ============================================================

function Aplicar-Logica {
    param([int]$Pct, [bool]$Carregando)

    # Atualiza porcentagem e barra
    $lblPct.Text         = "$Pct%"
    $lblPct.ForeColor    = Get-CorBarra -Pct $Pct
    $barraFill.Width     = [int](210 * $Pct / 100)
    $barraFill.BackColor = Get-CorBarra -Pct $Pct

    if ($Carregando) {
        $lblStatusValor.Text      = "Carregando"
        $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(24, 95, 165)

        if ($Pct -lt 40) {
            # Ainda carregando, abaixo de 40% — aguarda
            $aviso = "Bateria em $Pct%, carregando ate 40%..."
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(230, 241, 251)
            $lblAvisoIcone.Text      = "⚡"
            $lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(24, 95, 165)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(24, 95, 165)
        } else {
            # Carregando e ja atingiu 40% — avisar para desligar da tomada
            $aviso = "Bateria em $Pct%! Desligue da tomada!"
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(234, 243, 222)
            $lblAvisoIcone.Text      = "⚠"
            $lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(59, 109, 17)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(59, 109, 17)

            # Bip a cada leitura (equivalente ao \a do Bash)
            if ($script:rodando) { Emitir-Bip }
        }

    } else {
        $lblStatusValor.Text      = "Descarregando"
        $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(226, 75, 74)

        if ($Pct -lt 40) {
            # Abaixo de 40% descarregando — avisa para carregar
            $aviso = "Bateria em $Pct%! Carregue ate 40%."
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(252, 235, 235)
            $lblAvisoIcone.Text      = "🔋"
            $lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(163, 45, 45)

        } elseif ($Pct -lt 50) {
            # Entre 40% e 49% descarregando — desliga
            $aviso = "Bateria em $Pct%! Desligando agora..."
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(252, 235, 235)
            $lblAvisoIcone.Text      = "⚠"
            $lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $lblAviso.Text           = $aviso
            $form.Refresh()
            Start-Sleep -Seconds 3
            Stop-Computer -Force
            return

        } else {
            # 50% ou mais descarregando — status normal, aguarda
            $aviso = "Aguarde, $Pct% ainda..."
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(241, 239, 232)
            $lblAvisoIcone.Text      = "ℹ"
            $lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(95, 94, 90)
        }
    }

    $lblAviso.Text = $aviso
}

# ============================================================
#  TIMER PRINCIPAL
# ============================================================

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $INTERVALO_MS

$timer.Add_Tick({
    $info = Get-BateriaInfo
    if ($null -eq $info) {
        $lblAviso.Text = "Nenhuma bateria detectada."
        return
    }
    Aplicar-Logica -Pct $info.Percentual -Carregando $info.Carregando
})

# ============================================================
#  EVENTOS DOS BOTOES
# ============================================================

$btnStart.Add_Click({
    $script:rodando = $true
    $timer.Start()

    $btnStart.Enabled   = $false
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(15, 110, 86)
    $btnStop.Enabled    = $true
    $btnStop.BackColor  = [System.Drawing.Color]::FromArgb(226, 75, 74)
    $btnStop.ForeColor  = [System.Drawing.Color]::White

    $lblMonitorValor.Text      = "Ativo"
    $lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(29, 158, 117)

    # Leitura imediata
    $info = Get-BateriaInfo
    if ($info) {
        Aplicar-Logica -Pct $info.Percentual -Carregando $info.Carregando
    }
})

$btnStop.Add_Click({
    $script:rodando = $false
    $timer.Stop()

    $btnStart.Enabled   = $true
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
    $btnStop.Enabled    = $false
    $btnStop.BackColor  = [System.Drawing.Color]::FromArgb(209, 209, 199)
    $btnStop.ForeColor  = [System.Drawing.Color]::FromArgb(95, 94, 90)

    $lblMonitorValor.Text      = "Parado"
    $lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)

    $painelAviso.BackColor = [System.Drawing.Color]::FromArgb(241, 239, 232)
    $lblAvisoIcone.Text    = "ℹ"
    $lblAvisoIcone.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
    $lblAviso.ForeColor    = [System.Drawing.Color]::FromArgb(95, 94, 90)
    $lblAviso.Text         = "Monitoramento pausado."
})

# ============================================================
#  INICIA A JANELA
# ============================================================

[System.Windows.Forms.Application]::Run($form)