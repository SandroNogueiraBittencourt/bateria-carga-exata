# ============================================================
#  carregamentoBateria.ps1
#  Interface grafica + monitoramento de bateria
#  Windows 11 — Windows Forms (.NET nativo)
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Configuracoes ---
$LIMITE_BATERIA  = 50
$INTERVALO_MS    = 5000   # Intervalo de verificacao (ms)
$MINUTOS_ESPERA  = 1
$FREQ_BIP_CARGA  = 1200
$FREQ_BIP_DESC   = 800
$DUR_BIP         = 300
$PAUSA_BIPS      = 300

# --- Variaveis de estado ---
$script:rodando       = $false
$script:alertaAtivo   = $false
$script:timerDescarga = $null
$script:segundos      = 0

# ============================================================
#  FUNCOES AUXILIARES
# ============================================================

function Get-BateriaInfo {
    $bat = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    if (-not $bat) { return $null }
    return [PSCustomObject]@{
        Percentual = $bat.EstimatedChargeRemaining
        Carregando = $bat.BatteryStatus -in @(2, 3, 6, 7, 8, 9)
    }
}

function Emitir-Bips {
    param([int]$Freq, [int]$Qtd = 2)
    for ($i = 1; $i -le $Qtd; $i++) {
        [Console]::Beep($Freq, $DUR_BIP)
        if ($i -lt $Qtd) { Start-Sleep -Milliseconds $PAUSA_BIPS }
    }
}

function Get-CorBateria {
    param([int]$Pct)
    if ($Pct -gt 60) { return [System.Drawing.Color]::FromArgb(29, 158, 117)  }
    if ($Pct -gt 30) { return [System.Drawing.Color]::FromArgb(239, 159, 39)  }
    return             [System.Drawing.Color]::FromArgb(226, 75, 74)
}

# ============================================================
#  JANELA PRINCIPAL
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Monitor de Bateria"
$form.Size            = New-Object System.Drawing.Size(380, 480)
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

# --- Painel de porcentagem ---
$painelPct = New-Object System.Windows.Forms.Panel
$painelPct.Size        = New-Object System.Drawing.Size(338, 140)
$painelPct.Location    = New-Object System.Drawing.Point(20, 80)
$painelPct.BackColor   = [System.Drawing.Color]::White
$painelPct.BorderStyle = "FixedSingle"
$form.Controls.Add($painelPct)

$lblPct = New-Object System.Windows.Forms.Label
$lblPct.Text      = "—"
$lblPct.Font      = New-Object System.Drawing.Font("Segoe UI", 48, [System.Drawing.FontStyle]::Bold)
$lblPct.ForeColor = [System.Drawing.Color]::FromArgb(44, 44, 42)
$lblPct.AutoSize  = $true
$lblPct.Location  = New-Object System.Drawing.Point(20, 18)
$painelPct.Controls.Add($lblPct)

$lblDeCarga = New-Object System.Windows.Forms.Label
$lblDeCarga.Text      = "de carga"
$lblDeCarga.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$lblDeCarga.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblDeCarga.AutoSize  = $true
$lblDeCarga.Location  = New-Object System.Drawing.Point(22, 90)
$painelPct.Controls.Add($lblDeCarga)

# Barra de progresso
$barraPanel = New-Object System.Windows.Forms.Panel
$barraPanel.Size      = New-Object System.Drawing.Size(200, 16)
$barraPanel.Location  = New-Object System.Drawing.Point(118, 32)
$barraPanel.BackColor = [System.Drawing.Color]::FromArgb(209, 209, 199)
$painelPct.Controls.Add($barraPanel)

$barraFill = New-Object System.Windows.Forms.Panel
$barraFill.Size      = New-Object System.Drawing.Size(0, 16)
$barraFill.Location  = New-Object System.Drawing.Point(0, 0)
$barraFill.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
$barraPanel.Controls.Add($barraFill)

$lblLimite = New-Object System.Windows.Forms.Label
$lblLimite.Text      = "Limite configurado: 50%"
$lblLimite.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblLimite.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblLimite.AutoSize  = $true
$lblLimite.Location  = New-Object System.Drawing.Point(118, 56)
$painelPct.Controls.Add($lblLimite)

$lblIntervalo = New-Object System.Windows.Forms.Label
$lblIntervalo.Text      = "Verificacao a cada 5 segundos"
$lblIntervalo.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblIntervalo.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
$lblIntervalo.AutoSize  = $true
$lblIntervalo.Location  = New-Object System.Drawing.Point(118, 76)
$painelPct.Controls.Add($lblIntervalo)

# --- Cards de info ---
$cardStatus = New-Object System.Windows.Forms.Panel
$cardStatus.Size        = New-Object System.Drawing.Size(160, 70)
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
$cardMonitor.Size        = New-Object System.Drawing.Size(160, 70)
$cardMonitor.Location    = New-Object System.Drawing.Point(198, 238)
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

# --- Caixa de alerta ---
$painelAlerta = New-Object System.Windows.Forms.Panel
$painelAlerta.Size        = New-Object System.Drawing.Size(338, 52)
$painelAlerta.Location    = New-Object System.Drawing.Point(20, 326)
$painelAlerta.BackColor   = [System.Drawing.Color]::FromArgb(250, 238, 218)
$painelAlerta.BorderStyle = "FixedSingle"
$painelAlerta.Visible     = $false
$form.Controls.Add($painelAlerta)

$lblAlerta = New-Object System.Windows.Forms.Label
$lblAlerta.Text      = ""
$lblAlerta.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblAlerta.ForeColor = [System.Drawing.Color]::FromArgb(133, 79, 11)
$lblAlerta.Size      = New-Object System.Drawing.Size(318, 42)
$lblAlerta.Location  = New-Object System.Drawing.Point(10, 5)
$painelAlerta.Controls.Add($lblAlerta)

# --- Botoes ---
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text      = "▶  Start"
$btnStart.Size      = New-Object System.Drawing.Size(160, 44)
$btnStart.Location  = New-Object System.Drawing.Point(20, 396)
$btnStart.FlatStyle = "Flat"
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStart.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text      = "■  Parar"
$btnStop.Size      = New-Object System.Drawing.Size(160, 44)
$btnStop.Location  = New-Object System.Drawing.Point(198, 396)
$btnStop.FlatStyle = "Flat"
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(209, 209, 199)
$btnStop.ForeColor = [System.Drawing.Color]::FromArgb(95, 94, 90)
$btnStop.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStop.FlatAppearance.BorderSize = 0
$btnStop.Enabled   = $false
$form.Controls.Add($btnStop)

# ============================================================
#  TIMER PRINCIPAL DE MONITORAMENTO
# ============================================================

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $INTERVALO_MS

$timer.Add_Tick({
    $info = Get-BateriaInfo
    if ($null -eq $info) { return }

    $pct = $info.Percentual
    $lblPct.Text         = "$pct%"
    $lblPct.ForeColor    = Get-CorBateria -Pct $pct
    $barraFill.Width     = [int](200 * $pct / 100)
    $barraFill.BackColor = Get-CorBateria -Pct $pct

    if ($info.Carregando) {
        $lblStatusValor.Text      = "Carregando"
        $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
    } else {
        $lblStatusValor.Text      = "Descarregando"
        $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(226, 75, 74)
    }

    if ($pct -le $LIMITE_BATERIA -and -not $script:alertaAtivo) {
        $script:alertaAtivo = $true

        if ($info.Carregando) {
            $painelAlerta.BackColor = [System.Drawing.Color]::FromArgb(250, 238, 218)
            $lblAlerta.ForeColor    = [System.Drawing.Color]::FromArgb(133, 79, 11)
            $lblAlerta.Text         = "⚠ $pct% atingido carregando! Retire o carregador ou clique em Parar."
            $painelAlerta.Visible   = $true

            $script:timerDescarga = New-Object System.Windows.Forms.Timer
            $script:timerDescarga.Interval = 4000
            $script:timerDescarga.Add_Tick({
                $infoLoop = Get-BateriaInfo
                if ($null -ne $infoLoop -and -not $infoLoop.Carregando) {
                    $script:timerDescarga.Stop()
                    $painelAlerta.Visible = $false
                    $script:alertaAtivo   = $false
                    return
                }
                Emitir-Bips -Freq $FREQ_BIP_CARGA -Qtd 2
            })
            $script:timerDescarga.Start()
            Emitir-Bips -Freq $FREQ_BIP_CARGA -Qtd 2

        } else {
            $painelAlerta.BackColor = [System.Drawing.Color]::FromArgb(252, 235, 235)
            $lblAlerta.ForeColor    = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $painelAlerta.Visible   = $true

            Emitir-Bips -Freq $FREQ_BIP_DESC -Qtd 4

            $script:segundos = $MINUTOS_ESPERA * 60
            $script:timerDescarga = New-Object System.Windows.Forms.Timer
            $script:timerDescarga.Interval = 1000
            $script:timerDescarga.Add_Tick({
                $script:segundos--
                $lblAlerta.Text = "⚠ Desligando em $($script:segundos) segundo(s)... Clique em Parar para cancelar."
                if ($script:segundos -le 0) {
                    $script:timerDescarga.Stop()
                    Stop-Computer -Force
                }
            })
            $script:timerDescarga.Start()
        }
    }
})

# ============================================================
#  EVENTOS DOS BOTOES
# ============================================================

$btnStart.Add_Click({
    $script:rodando     = $true
    $script:alertaAtivo = $false
    $timer.Start()

    $btnStart.Enabled   = $false
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(15, 110, 86)
    $btnStop.Enabled    = $true
    $btnStop.BackColor  = [System.Drawing.Color]::FromArgb(226, 75, 74)
    $btnStop.ForeColor  = [System.Drawing.Color]::White

    $lblMonitorValor.Text      = "Ativo"
    $lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(29, 158, 117)

    $info = Get-BateriaInfo
    if ($info) {
        $pct = $info.Percentual
        $lblPct.Text         = "$pct%"
        $lblPct.ForeColor    = Get-CorBateria -Pct $pct
        $barraFill.Width     = [int](200 * $pct / 100)
        $barraFill.BackColor = Get-CorBateria -Pct $pct
        if ($info.Carregando) {
            $lblStatusValor.Text      = "Carregando"
            $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
        } else {
            $lblStatusValor.Text      = "Descarregando"
            $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(226, 75, 74)
        }
    }
})

$btnStop.Add_Click({
    $script:rodando     = $false
    $script:alertaAtivo = $false
    $timer.Stop()
    if ($script:timerDescarga) { $script:timerDescarga.Stop() }
    $painelAlerta.Visible = $false

    $btnStart.Enabled   = $true
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
    $btnStop.Enabled    = $false
    $btnStop.BackColor  = [System.Drawing.Color]::FromArgb(209, 209, 199)
    $btnStop.ForeColor  = [System.Drawing.Color]::FromArgb(95, 94, 90)

    $lblMonitorValor.Text      = "Parado"
    $lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
})

# ============================================================
#  INICIA A JANELA
# ============================================================

[System.Windows.Forms.Application]::Run($form)