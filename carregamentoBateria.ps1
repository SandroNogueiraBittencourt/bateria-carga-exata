# ============================================================
#  carregamentoBateria.ps1
#  Interface grafica RESPONSIVA + monitoramento + dreno
#
#  Logica:
#  DESCARREGANDO:
#    > 50%      -> ativa dreno (CPU stress + brilho maximo)
#    40% a 49%  -> desliga o computador
#    < 40%      -> avisa para carregar
#
#  CARREGANDO:
#    < 40%      -> avisa que esta carregando
#    >= 40%     -> avisa para desligar da tomada + bip
#
#  Windows 11 - Windows Forms (.NET nativo)
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- APIs nativas ---
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class PowerState {
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern uint SetThreadExecutionState(uint esFlags);

    private const uint ES_CONTINUOUS        = 0x80000000;
    private const uint ES_SYSTEM_REQUIRED   = 0x00000001;
    private const uint ES_DISPLAY_REQUIRED  = 0x00000002;

    public static void PreventSleep() {
        SetThreadExecutionState(
            ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED
        );
    }

    public static void AllowSleep() {
        SetThreadExecutionState(ES_CONTINUOUS);
    }
}

public static class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@

# Ativa DPI awareness antes de criar a janela
[DpiHelper]::SetProcessDPIAware()

# --- Configuracoes ---
$INTERVALO_MS     = 3000
$FREQ_BIP         = 1000
$DUR_BIP          = 400
$NUM_THREADS_CPU  = [Environment]::ProcessorCount
$MARGEM           = 16   # margem lateral padrao

# --- Estado global ---
$script:rodando       = $false
$script:drenoAtivo    = $false
$script:jobsCPU       = @()
$script:brilhoOriginal = $null

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

function Emitir-Bip { [Console]::Beep($FREQ_BIP, $DUR_BIP) }

function Get-CorBarra {
    param([int]$Pct)
    if ($Pct -ge 50) { return [System.Drawing.Color]::FromArgb(29, 158, 117) }
    if ($Pct -ge 40) { return [System.Drawing.Color]::FromArgb(239, 159, 39) }
    return [System.Drawing.Color]::FromArgb(226, 75, 74)
}

# --- Controle de brilho ---
function Get-BrilhoAtual {
    try {
        $b = Get-WmiObject -Namespace root\WMI -Class WmiMonitorBrightness -ErrorAction SilentlyContinue
        if ($b) { return [int]$b.CurrentBrightness }
    } catch {}
    return 50
}

function Set-Brilho {
    param([int]$Nivel)
    try {
        $m = Get-WmiObject -Namespace root\WMI -Class WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue
        if ($m) { $m.WmiSetBrightness(1, $Nivel) }
    } catch {}
}

# --- Estresse de CPU ---
function Iniciar-EstresseCPU {
    if ($script:drenoAtivo) { return }
    $script:drenoAtivo = $true
    $script:brilhoOriginal = Get-BrilhoAtual
    Set-Brilho -Nivel 100
    $script:jobsCPU = @()
    for ($i = 0; $i -lt $NUM_THREADS_CPU; $i++) {
        $job = Start-Job -ScriptBlock {
            while ($true) {
                [Math]::Sqrt([double]::MaxValue / 3.0) | Out-Null
                [Math]::Pow(2.71828, 100) | Out-Null
                [Math]::Sin(12345.6789) | Out-Null
            }
        }
        $script:jobsCPU += $job
    }
}

function Parar-EstresseCPU {
    if (-not $script:drenoAtivo) { return }
    $script:drenoAtivo = $false
    foreach ($job in $script:jobsCPU) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
    $script:jobsCPU = @()
    if ($null -ne $script:brilhoOriginal) {
        Set-Brilho -Nivel $script:brilhoOriginal
    }
}

# ============================================================
#  JANELA PRINCIPAL (responsiva)
# ============================================================

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Monitor de Bateria"
$form.MinimumSize     = New-Object System.Drawing.Size(360, 580)
$form.Size            = New-Object System.Drawing.Size(420, 680)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = [System.Drawing.Color]::FromArgb(245, 245, 243)
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 10)
$form.AutoScaleMode   = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.Padding         = New-Object System.Windows.Forms.Padding($MARGEM)

$form.Add_FormClosing({
    Parar-EstresseCPU
    [PowerState]::AllowSleep()
})

# ============================================================
#  HELPER: cria Label de forma concisa
# ============================================================

function New-Label {
    param(
        [string]$Text, [float]$FontSize = 10,
        [System.Drawing.FontStyle]$Style = "Regular",
        [System.Drawing.Color]$Color = [System.Drawing.Color]::FromArgb(44, 44, 42),
        [bool]$AutoSize = $true
    )
    $l = New-Object System.Windows.Forms.Label
    $l.Text      = $Text
    $l.Font      = New-Object System.Drawing.Font("Segoe UI", $FontSize, $Style)
    $l.ForeColor = $Color
    $l.AutoSize  = $AutoSize
    return $l
}

# ============================================================
#  CONTAINER PRINCIPAL (ScrollPanel para telas pequenas)
# ============================================================

$container = New-Object System.Windows.Forms.Panel
$container.Dock       = "Fill"
$container.AutoScroll = $true
$container.Padding    = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
$form.Controls.Add($container)

# ============================================================
#  TITULO
# ============================================================

$lblTitulo = New-Label -Text "Monitor de Bateria" -FontSize 14 -Style Bold
$lblTitulo.Location = New-Object System.Drawing.Point(4, 8)
$container.Controls.Add($lblTitulo)

$lblSub = New-Label -Text "Windows 11 - Script PowerShell" -FontSize 9 `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblSub.Location = New-Object System.Drawing.Point(4, 36)
$container.Controls.Add($lblSub)

# ============================================================
#  PAINEL PORCENTAGEM
# ============================================================

$painelPct = New-Object System.Windows.Forms.Panel
$painelPct.Location    = New-Object System.Drawing.Point(0, 66)
$painelPct.Height      = 120
$painelPct.BackColor   = [System.Drawing.Color]::White
$painelPct.BorderStyle = "FixedSingle"
$painelPct.Anchor      = "Top,Left,Right"
$container.Controls.Add($painelPct)

$lblPct = New-Label -Text "--" -FontSize 46 -Style Bold
$lblPct.Location = New-Object System.Drawing.Point(12, 6)
$painelPct.Controls.Add($lblPct)

$lblDeCarga = New-Label -Text "de carga" -FontSize 9 `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblDeCarga.Location = New-Object System.Drawing.Point(14, 72)
$painelPct.Controls.Add($lblDeCarga)

# Barra de progresso (reposicionada no Resize)
$barraPanel = New-Object System.Windows.Forms.Panel
$barraPanel.Height    = 16
$barraPanel.BackColor = [System.Drawing.Color]::FromArgb(209, 209, 199)
$painelPct.Controls.Add($barraPanel)

$barraFill = New-Object System.Windows.Forms.Panel
$barraFill.Size      = New-Object System.Drawing.Size(0, 16)
$barraFill.Location  = New-Object System.Drawing.Point(0, 0)
$barraFill.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
$barraPanel.Controls.Add($barraFill)

# Marcadores (reposicionados no Resize)
$marca40 = New-Object System.Windows.Forms.Panel
$marca40.Size      = New-Object System.Drawing.Size(2, 24)
$marca40.BackColor = [System.Drawing.Color]::FromArgb(226, 75, 74)
$barraPanel.Controls.Add($marca40)

$marca50 = New-Object System.Windows.Forms.Panel
$marca50.Size      = New-Object System.Drawing.Size(2, 24)
$marca50.BackColor = [System.Drawing.Color]::FromArgb(239, 159, 39)
$barraPanel.Controls.Add($marca50)

$lblMarca40 = New-Label -Text "40%" -FontSize 8 `
    -Color ([System.Drawing.Color]::FromArgb(226, 75, 74))
$painelPct.Controls.Add($lblMarca40)

$lblMarca50 = New-Label -Text "50%" -FontSize 8 `
    -Color ([System.Drawing.Color]::FromArgb(239, 159, 39))
$painelPct.Controls.Add($lblMarca50)

# ============================================================
#  CARDS (STATUS + MONITORAMENTO) - lado a lado
# ============================================================

$cardStatus = New-Object System.Windows.Forms.Panel
$cardStatus.Height      = 72
$cardStatus.BackColor   = [System.Drawing.Color]::White
$cardStatus.BorderStyle = "FixedSingle"
$container.Controls.Add($cardStatus)

$lblStatusTitulo = New-Label -Text "STATUS" -FontSize 8 `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblStatusTitulo.Location = New-Object System.Drawing.Point(10, 8)
$cardStatus.Controls.Add($lblStatusTitulo)

$lblStatusValor = New-Label -Text "--" -FontSize 11 -Style Bold
$lblStatusValor.Location = New-Object System.Drawing.Point(10, 32)
$cardStatus.Controls.Add($lblStatusValor)

$cardMonitor = New-Object System.Windows.Forms.Panel
$cardMonitor.Height      = 72
$cardMonitor.BackColor   = [System.Drawing.Color]::White
$cardMonitor.BorderStyle = "FixedSingle"
$container.Controls.Add($cardMonitor)

$lblMonitorTitulo = New-Label -Text "MONITORAMENTO" -FontSize 8 `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblMonitorTitulo.Location = New-Object System.Drawing.Point(10, 8)
$cardMonitor.Controls.Add($lblMonitorTitulo)

$lblMonitorValor = New-Label -Text "Parado" -FontSize 11 -Style Bold `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblMonitorValor.Location = New-Object System.Drawing.Point(10, 32)
$cardMonitor.Controls.Add($lblMonitorValor)

# ============================================================
#  PAINEL DRENO
# ============================================================

$painelDreno = New-Object System.Windows.Forms.Panel
$painelDreno.Height      = 52
$painelDreno.BackColor   = [System.Drawing.Color]::FromArgb(241, 239, 232)
$painelDreno.BorderStyle = "FixedSingle"
$painelDreno.Anchor      = "Top,Left,Right"
$container.Controls.Add($painelDreno)

$lblDrenoTitulo = New-Label -Text "DRENO DE BATERIA" -FontSize 8 `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblDrenoTitulo.Location = New-Object System.Drawing.Point(10, 4)
$painelDreno.Controls.Add($lblDrenoTitulo)

$lblDrenoValor = New-Label -Text "Inativo" -FontSize 10 -Style Bold `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblDrenoValor.Location = New-Object System.Drawing.Point(10, 26)
$painelDreno.Controls.Add($lblDrenoValor)

$lblDrenoInfo = New-Label -Text "" -FontSize 8 `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblDrenoInfo.Location = New-Object System.Drawing.Point(150, 30)
$painelDreno.Controls.Add($lblDrenoInfo)

# ============================================================
#  PAINEL AVISO
# ============================================================

$painelAviso = New-Object System.Windows.Forms.Panel
$painelAviso.Height      = 62
$painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(241, 239, 232)
$painelAviso.BorderStyle = "FixedSingle"
$painelAviso.Anchor      = "Top,Left,Right"
$container.Controls.Add($painelAviso)

$lblAvisoPre = New-Label -Text "!" -FontSize 16 -Style Bold `
    -Color ([System.Drawing.Color]::FromArgb(136, 135, 128))
$lblAvisoPre.Location = New-Object System.Drawing.Point(10, 14)
$painelAviso.Controls.Add($lblAvisoPre)

$lblAviso = New-Object System.Windows.Forms.Label
$lblAviso.Text      = "Aguardando inicio do monitoramento..."
$lblAviso.Font      = New-Object System.Drawing.Font("Segoe UI", 10)
$lblAviso.ForeColor = [System.Drawing.Color]::FromArgb(95, 94, 90)
$lblAviso.Location  = New-Object System.Drawing.Point(38, 6)
$lblAviso.AutoSize  = $false
$lblAviso.Anchor    = "Top,Left,Right"
$painelAviso.Controls.Add($lblAviso)

# ============================================================
#  LEGENDA
# ============================================================

$painelLegenda = New-Object System.Windows.Forms.Panel
$painelLegenda.Height      = 36
$painelLegenda.BackColor   = [System.Drawing.Color]::White
$painelLegenda.BorderStyle = "FixedSingle"
$painelLegenda.Anchor      = "Top,Left,Right"
$container.Controls.Add($painelLegenda)

$legendaCores = @(
    [System.Drawing.Color]::FromArgb(226,75,74),
    [System.Drawing.Color]::FromArgb(239,159,39),
    [System.Drawing.Color]::FromArgb(29,158,117),
    [System.Drawing.Color]::FromArgb(24,95,165)
)
$legendaTextos = @("< 40%", "40-49%", ">= 50%", "Carregando")
$legendaDots   = @()
$legendaLabels = @()

for ($i = 0; $i -lt 4; $i++) {
    $dot = New-Object System.Windows.Forms.Panel
    $dot.Size      = New-Object System.Drawing.Size(10, 10)
    $dot.BackColor = $legendaCores[$i]
    $painelLegenda.Controls.Add($dot)
    $legendaDots += $dot

    $ll = New-Label -Text $legendaTextos[$i] -FontSize 8 `
        -Color ([System.Drawing.Color]::FromArgb(95, 94, 90))
    $painelLegenda.Controls.Add($ll)
    $legendaLabels += $ll
}

# ============================================================
#  BOTOES
# ============================================================

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text      = "Start"
$btnStart.Height    = 44
$btnStart.FlatStyle = "Flat"
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStart.FlatAppearance.BorderSize = 0
$btnStart.Cursor    = [System.Windows.Forms.Cursors]::Hand
$container.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text      = "Parar"
$btnStop.Height    = 44
$btnStop.FlatStyle = "Flat"
$btnStop.BackColor = [System.Drawing.Color]::FromArgb(209, 209, 199)
$btnStop.ForeColor = [System.Drawing.Color]::FromArgb(95, 94, 90)
$btnStop.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnStop.FlatAppearance.BorderSize = 0
$btnStop.Enabled   = $false
$btnStop.Cursor    = [System.Windows.Forms.Cursors]::Hand
$container.Controls.Add($btnStop)

# ============================================================
#  LAYOUT RESPONSIVO - funcao de recalculo
# ============================================================

function Recalcular-Layout {
    $cw  = $container.ClientSize.Width
    $gap = 10
    $y   = 66   # inicio apos titulo

    # --- Painel porcentagem ---
    $painelPct.Location = New-Object System.Drawing.Point(0, $y)
    $painelPct.Width    = $cw

    # Barra de progresso (ocupa metade direita do painel)
    $barraX = [int]($cw * 0.36)
    $barraW = $cw - $barraX - 20
    $barraPanel.Location = New-Object System.Drawing.Point($barraX, 24)
    $barraPanel.Width    = $barraW

    # Marcadores proporcionais
    $marca40.Location = New-Object System.Drawing.Point([int]($barraW * 0.40), -4)
    $marca50.Location = New-Object System.Drawing.Point([int]($barraW * 0.50), -4)
    $lblMarca40.Location = New-Object System.Drawing.Point(($barraX + [int]($barraW * 0.40) - 10), 44)
    $lblMarca50.Location = New-Object System.Drawing.Point(($barraX + [int]($barraW * 0.50) - 10), 44)

    # Info de intervalo
    $y = $y + $painelPct.Height + $gap

    # --- Cards lado a lado ---
    $cardW = [int](($cw - $gap) / 2)
    $cardStatus.Location = New-Object System.Drawing.Point(0, $y)
    $cardStatus.Width    = $cardW
    $cardMonitor.Location = New-Object System.Drawing.Point(($cardW + $gap), $y)
    $cardMonitor.Width    = $cw - $cardW - $gap

    $y = $y + $cardStatus.Height + $gap

    # --- Painel dreno ---
    $painelDreno.Location = New-Object System.Drawing.Point(0, $y)
    $painelDreno.Width    = $cw
    $y = $y + $painelDreno.Height + $gap

    # --- Painel aviso ---
    $painelAviso.Location = New-Object System.Drawing.Point(0, $y)
    $painelAviso.Width    = $cw
    $lblAviso.Size = New-Object System.Drawing.Size(($cw - 54), 50)
    $y = $y + $painelAviso.Height + $gap

    # --- Legenda ---
    $painelLegenda.Location = New-Object System.Drawing.Point(0, $y)
    $painelLegenda.Width    = $cw

    # Distribui itens da legenda igualmente
    $segW = [int]($cw / 4)
    for ($i = 0; $i -lt 4; $i++) {
        $lx = $segW * $i + 8
        $legendaDots[$i].Location  = New-Object System.Drawing.Point($lx, 13)
        $legendaLabels[$i].Location = New-Object System.Drawing.Point(($lx + 14), 12)
    }

    $y = $y + $painelLegenda.Height + $gap

    # --- Botoes lado a lado ---
    $btnW = [int](($cw - $gap) / 2)
    $btnStart.Location = New-Object System.Drawing.Point(0, $y)
    $btnStart.Width    = $btnW
    $btnStop.Location  = New-Object System.Drawing.Point(($btnW + $gap), $y)
    $btnStop.Width     = $cw - $btnW - $gap
}

# Conecta o resize
$container.Add_Resize({ Recalcular-Layout })
$form.Add_Shown({ Recalcular-Layout })

# ============================================================
#  LOGICA PRINCIPAL
# ============================================================

function Atualizar-PainelDreno {
    if ($script:drenoAtivo) {
        $painelDreno.BackColor   = [System.Drawing.Color]::FromArgb(252, 235, 235)
        $lblDrenoValor.Text      = "ATIVO - Drenando"
        $lblDrenoValor.ForeColor = [System.Drawing.Color]::FromArgb(163, 45, 45)
        $lblDrenoInfo.Text       = "$NUM_THREADS_CPU threads + brilho 100%"
        $lblDrenoInfo.ForeColor  = [System.Drawing.Color]::FromArgb(163, 45, 45)
    } else {
        $painelDreno.BackColor   = [System.Drawing.Color]::FromArgb(241, 239, 232)
        $lblDrenoValor.Text      = "Inativo"
        $lblDrenoValor.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
        $lblDrenoInfo.Text       = ""
    }
}

function Atualizar-Barra {
    param([int]$Pct)
    $barraW = $barraPanel.Width
    $barraFill.Width     = [int]($barraW * $Pct / 100)
    $barraFill.BackColor = Get-CorBarra -Pct $Pct
}

function Aplicar-Logica {
    param([int]$Pct, [bool]$Carregando)

    $lblPct.Text      = "$Pct%"
    $lblPct.ForeColor = Get-CorBarra -Pct $Pct
    Atualizar-Barra -Pct $Pct

    if ($Carregando) {
        $lblStatusValor.Text      = "Carregando"
        $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(24, 95, 165)

        if ($script:drenoAtivo) { Parar-EstresseCPU }
        Atualizar-PainelDreno

        if ($Pct -lt 40) {
            $aviso = "Bateria em $Pct%, carregando ate 40%..."
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(230, 241, 251)
            $lblAvisoPre.ForeColor   = [System.Drawing.Color]::FromArgb(24, 95, 165)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(24, 95, 165)
        } else {
            $aviso = "Bateria em $Pct%! Desligue da tomada!"
            $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(234, 243, 222)
            $lblAvisoPre.ForeColor   = [System.Drawing.Color]::FromArgb(59, 109, 17)
            $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(59, 109, 17)
            if ($script:rodando) { Emitir-Bip }
        }

    } else {
        $lblStatusValor.Text      = "Descarregando"
        $lblStatusValor.ForeColor = [System.Drawing.Color]::FromArgb(226, 75, 74)

        if ($Pct -gt 50) {
            if (-not $script:drenoAtivo -and $script:rodando) {
                Iniciar-EstresseCPU
            }
            Atualizar-PainelDreno
            $aviso = "Drenando bateria... Aguarde, $Pct% ainda."
            $painelAviso.BackColor = [System.Drawing.Color]::FromArgb(252, 243, 226)
            $lblAvisoPre.ForeColor = [System.Drawing.Color]::FromArgb(150, 100, 20)
            $lblAviso.ForeColor    = [System.Drawing.Color]::FromArgb(150, 100, 20)

        } elseif ($Pct -eq 50) {
            if ($script:drenoAtivo) { Parar-EstresseCPU }
            Atualizar-PainelDreno
            $aviso = "Bateria em 50%! Dreno encerrado. Aguardando..."
            $painelAviso.BackColor = [System.Drawing.Color]::FromArgb(241, 239, 232)
            $lblAvisoPre.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)
            $lblAviso.ForeColor    = [System.Drawing.Color]::FromArgb(95, 94, 90)

        } elseif ($Pct -ge 40) {
            if ($script:drenoAtivo) { Parar-EstresseCPU }
            Atualizar-PainelDreno
            $aviso = "Bateria em $Pct%! Desligando agora..."
            $painelAviso.BackColor = [System.Drawing.Color]::FromArgb(252, 235, 235)
            $lblAvisoPre.ForeColor = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $lblAviso.ForeColor    = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $lblAviso.Text         = $aviso
            $form.Refresh()
            Start-Sleep -Seconds 3
            Stop-Computer -Force
            return

        } else {
            if ($script:drenoAtivo) { Parar-EstresseCPU }
            Atualizar-PainelDreno
            $aviso = "Bateria em $Pct%! Carregue ate 40%."
            $painelAviso.BackColor = [System.Drawing.Color]::FromArgb(252, 235, 235)
            $lblAvisoPre.ForeColor = [System.Drawing.Color]::FromArgb(163, 45, 45)
            $lblAviso.ForeColor    = [System.Drawing.Color]::FromArgb(163, 45, 45)
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
#  BOTOES
# ============================================================

$btnStart.Add_Click({
    $script:rodando = $true
    $timer.Start()
    [PowerState]::PreventSleep()

    $btnStart.Enabled   = $false
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(15, 110, 86)
    $btnStop.Enabled    = $true
    $btnStop.BackColor  = [System.Drawing.Color]::FromArgb(226, 75, 74)
    $btnStop.ForeColor  = [System.Drawing.Color]::White

    $lblMonitorValor.Text      = "Ativo"
    $lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(29, 158, 117)

    $info = Get-BateriaInfo
    if ($info) {
        Aplicar-Logica -Pct $info.Percentual -Carregando $info.Carregando
    }
})

$btnStop.Add_Click({
    $script:rodando = $false
    $timer.Stop()
    Parar-EstresseCPU
    Atualizar-PainelDreno
    [PowerState]::AllowSleep()

    $btnStart.Enabled   = $true
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(29, 158, 117)
    $btnStop.Enabled    = $false
    $btnStop.BackColor  = [System.Drawing.Color]::FromArgb(209, 209, 199)
    $btnStop.ForeColor  = [System.Drawing.Color]::FromArgb(95, 94, 90)

    $lblMonitorValor.Text      = "Parado"
    $lblMonitorValor.ForeColor = [System.Drawing.Color]::FromArgb(136, 135, 128)

    $painelAviso.BackColor   = [System.Drawing.Color]::FromArgb(241, 239, 232)
    $lblAvisoPre.ForeColor   = [System.Drawing.Color]::FromArgb(136, 135, 128)
    $lblAviso.ForeColor      = [System.Drawing.Color]::FromArgb(95, 94, 90)
    $lblAviso.Text           = "Monitoramento pausado."
})

# ============================================================
#  INICIA A JANELA
# ============================================================

[System.Windows.Forms.Application]::Run($form)