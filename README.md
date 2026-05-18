📄 README — Descrição longa

# 🔋 Battery Alert Shutdown — PowerShell

Script PowerShell para Windows 11 que monitora continuamente
o nível da bateria do notebook e executa as seguintes ações
ao atingir 50% de carga:

1. Emite **4 bips** sonoros de alerta
2. Inicia uma contagem regressiva de **1 minuto**
3. **Desliga o computador** automaticamente

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
    
