📄 README — Descrição longa

# 🔋 Battery Alert Shutdown — PowerShell

Lógica implementada
🔌 Carregando e chegou a 50%

Entra em loop emitindo 2 bips a cada 5 segundos
Para quando o usuário retirar o carregador (detectado automaticamente) ou pressionar ENTER no terminal
Após encerrar o alerta, retoma o monitoramento normalmente

🪫 Descarregando e chegou a 50%

Emite 4 bips
Contagem regressiva de 1 minuto visível no terminal
Desliga o computador automaticamente

Funciona tanto durante o **carregamento** quanto durante o
**consumo** da bateria.

---

## ⚙️ Como usar

```powershell
# 1. Liberar execução de scripts (uma vez, como Administrador)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# 2. Executar o script
.\Monitor-Bateria50.ps1
```

---

## 🛠️ Configurações

As variáveis no topo do script permitem personalização fácil:

| Variável         | Padrão | Descrição                        |
|------------------|--------|----------------------------------|
| `$LIMITE_BATERIA` | `50`  | % que dispara o alerta           |
| `$INTERVALO_SEG`  | `30`  | Intervalo de verificação (seg)   |
| `$MINUTOS_ESPERA` | `1`   | Minutos antes de desligar        |
| `$QTDE_BIPS`      | `4`   | Número de bips                   |
| `$FREQ_BIP`       | `1000`| Frequência do bip (Hz)           |

---

## 📋 Requisitos

- Windows 11
- PowerShell 5.1+
- Notebook com bateria detectável via WMI

---

## ⚠️ Cancelar o desligamento

Pressione `Ctrl+C` durante a contagem regressiva.
    
