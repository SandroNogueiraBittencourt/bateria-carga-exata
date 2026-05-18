# 🔋 Battery Alert Shutdown — PowerShell

Script PowerShell para Windows 11 que monitora continuamente o nível da bateria do notebook com **interface gráfica** e comportamento inteligente conforme o estado da bateria.


## 🖥️ Interface gráfica

A janela exibe em tempo real:

- Porcentagem atual da bateria com cor dinâmica (verde → amarelo → vermelho)

- Barra de progresso proporcional à carga

- Status da bateria (Carregando / Descarregando)

- Estado do monitoramento (Ativo / Parado)

- Caixa de alerta ao atingir o limite configurado

- Botões **Start** e **Parar**


## ⚡ Comportamento ao atingir 50%

O script age de forma diferente dependendo do estado da bateria:

| Estado | Ação ao atingir 50% |
| - | - |
| 🔌 **Carregando** | Emite bips em loop até o carregador ser retirado ou o usuário clicar em **Parar** |
| 🪫 **Descarregando** | Emite 4 bips, exibe contagem regressiva de 1 minuto e **desliga o computador** |



## ⚙️ Como usar

```
\# 1. Liberar execução de scripts (uma vez, como Administrador)  
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned  
  
\# 2. Executar o script (com interface gráfica, sem terminal visível)  
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\\carregamentoBateria.ps1"  
  
\# 3. Ou executar com terminal visível (para debug)  
.\\carregamentoBateria.ps1
```


## 🛠️ Configurações

As variáveis no topo do script permitem personalização fácil:

| Variável | Padrão | Descrição |
| - | - | - |
| `$LIMITE\_BATERIA` | `50` | % que dispara o alerta |
| `$INTERVALO\_MS` | `5000` | Intervalo de verificação (ms) |
| `$MINUTOS\_ESPERA` | `1` | Minutos antes de desligar (modo descarga) |
| `$FREQ\_BIP\_CARGA` | `1200` | Frequência do bip ao carregar (Hz) |
| `$FREQ\_BIP\_DESC` | `800` | Frequência do bip ao descarregar (Hz) |



## 📋 Requisitos

- Windows 11

- PowerShell 5.1+

- .NET Framework (nativo no Windows 11 — necessário para a interface gráfica)

- Notebook com bateria detectável via WMI


## ⚠️ Cancelar o desligamento

Clique no botão **Parar** na interface durante a contagem regressiva.

