# 🔋 Battery Alert Shutdown — PowerShell

Script PowerShell para Windows 11 que monitora continuamente o nível da bateria do notebook com **interface gráfica**, emitindo alertas visuais e sonoros conforme o estado e a porcentagem da bateria.

---

## 🖥️ Interface gráfica

A janela exibe em tempo real:

- Porcentagem atual da bateria com cor dinâmica (verde → amarelo → vermelho)
- Barra de progresso com marcação visual no limite de 40%
- Status da bateria (Carregando / Descarregando)
- Estado do monitoramento (Ativo / Parado)
- Caixa de aviso com mensagem e cor correspondente ao estado atual
- Legenda dos limites de porcentagem
- Botões **Start** e **Parar**

---

## ⚡ Lógica de monitoramento

O comportamento varia conforme o estado e a porcentagem da bateria:

| Estado | Porcentagem | Ação |
|---|---|---|
| 🔌 Carregando | < 40% | Avisa que ainda está carregando até 40% |
| 🔌 Carregando | ≥ 40% | Avisa para desligar da tomada + emite bip |
| 🪫 Descarregando | < 40% | Avisa para conectar o carregador |
| 🪫 Descarregando | 40% a 49% | Exibe aviso e **desliga o computador** |
| 🪫 Descarregando | ≥ 50% | Exibe "Aguarde, X% ainda..." |

---

## ⚙️ Como usar

```powershell
# 1. Liberar execução de scripts (uma vez, como Administrador)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 2. Executar o script (sem terminal visível — recomendado)
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\carregamentoBateria.ps1"

# 3. Ou executar com terminal visível (para debug)
.\carregamentoBateria.ps1
```

---

## 🛠️ Configurações

As variáveis no topo do script permitem personalização fácil:

| Variável | Padrão | Descrição |
|---|---|---|
| `$INTERVALO_MS` | `3000` | Intervalo de verificação em milissegundos |
| `$FREQ_BIP` | `1000` | Frequência do bip sonoro (Hz) |
| `$DUR_BIP` | `400` | Duração do bip (ms) |

---

## 📋 Requisitos

- Windows 11
- PowerShell 5.1+
- .NET Framework (nativo no Windows 11 — necessário para a interface gráfica)
- Notebook com bateria detectável via WMI

---

## ⚠️ Cancelar o desligamento

Clique no botão **Parar** na interface antes que a bateria atinja a faixa de 40–49% em modo descarregando.