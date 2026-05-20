# :battery: Battery Alert Shutdown

**Monitoramento inteligente de bateria para Windows 11**

Controle automatico de carga com interface grafica, dreno de bateria e desligamento programado.

`PowerShell` `Windows Forms` `.NET Nativo` `Windows 11`


## :mag: Sobre

Script PowerShell com interface grafica que monitora a bateria do notebook em tempo real. Ele garante que sua bateria opere dentro de uma faixa saudavel (40%-50%), drenando automaticamente quando acima de 50% e desligando o computador quando abaixo de 40% em uso.


## :desktop\_computer: Funcionalidades

```
+------------------------------------------+  
|          Monitor de Bateria              |  
|                                          |  
|   72%  \[==============------\]            |  
|         de carga        |40%  |50%       |  
|                                          |  
|   STATUS          MONITORAMENTO          |  
|   Descarregando   Ativo                  |  
|                                          |  
|   DRENO DE BATERIA                       |  
|   ATIVO - 8 threads + brilho 100%       |  
|                                          |  
|   ! Drenando bateria... Aguarde          |  
|                                          |  
|   \[   Start   \]  \[   Parar   \]           |  
+------------------------------------------+
```

> **Interface grafica nativa** construida com Windows Forms - sem dependencias externas.


## :zap: Como funciona

### :electric\_plug: Descarregando (fora da tomada)

| Bateria | Acao | Indicador |
| :-: | - | :-: |
| **\> 50%** | Ativa dreno automatico (CPU stress + brilho maximo) | :yellow\_circle: |
| **= 50%** | Desativa o dreno e restaura o brilho | :white\_circle: |
| **40-49%** | Desliga o computador automaticamente | :red\_circle: |
| **\< 40%** | Alerta para conectar o carregador | :red\_circle: |


### :plug: Carregando (na tomada)

| Bateria | Acao | Indicador |
| :-: | - | :-: |
| **\< 40%** | Informa que esta carregando ate 40% | :large\_blue\_circle: |
| **\>= 40%** | Alerta sonoro para desligar da tomada | :green\_circle: |



## :fire: Dreno automatico

Quando a bateria esta **acima de 50%** e **descarregando**, o script acelera o consumo de energia de duas formas:

**:computer: Estresse de CPU**

> Cria uma thread por nucleo do processador executando calculos matematicos em loop continuo, maximizando o consumo de energia do processador.

**:high\_brightness: Brilho maximo**

> Aumenta automaticamente o brilho da tela para 100%, contribuindo para o consumo da bateria.

O dreno e desativado automaticamente quando:

- A bateria atinge 50%

- O carregador e conectado

- O usuario clica em **Parar**

- A janela e fechada

> O brilho original e salvo e restaurado ao encerrar o dreno.


## :rocket: Instalacao

**1. Liberar execucao de scripts** (uma unica vez, como Administrador)

```
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

**2. Clonar o repositorio**

```
git clone https://github.com/SandroNogueiraBittencourt/bateria-carga-exata.git  
cd bateria-carga-exata
```

**3. Executar**

```
\# Modo recomendado (sem terminal visivel)  
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File ".\\carregamentoBateria.ps1"  
  
\# Modo debug (com terminal)  
.\\carregamentoBateria.ps1
```


## :wrench: Configuracoes

Personalize as variaveis no topo do arquivo `carregamentoBateria.ps1`:

```
$INTERVALO\_MS     = 3000    \# Verificacao a cada 3 segundos  
$FREQ\_BIP         = 1000    \# Frequencia do bip (Hz)  
$DUR\_BIP          = 400     \# Duracao do bip (ms)  
$NUM\_THREADS\_CPU  = auto    \# Threads de estresse (padrao: todos os nucleos)
```


## :clipboard: Requisitos

| Requisito | Detalhe |
| - | - |
| Sistema | Windows 11 |
| PowerShell | 5.1 ou superior |
| .NET Framework | Nativo no Windows 11 |
| Permissao | Administrador (para controle de brilho) |
| Hardware | Notebook com bateria detectavel via WMI |



## :arrows\_counterclockwise: Fluxo de uso

```
Inicio  
  |  
  v  
\[Start\] --\> Leitura da bateria  
              |  
              +-- Carregando?  
              |     +-- \< 40% ----\> "Carregando ate 40%..."  
              |     +-- \>= 40% ---\> "Desligue da tomada!" + bip  
              |  
              +-- Descarregando?  
                    +-- \> 50% ----\> Ativa dreno (CPU + brilho)  
                    +-- = 50% ----\> Para o dreno  
                    +-- 40-49% ---\> DESLIGA O PC  
                    +-- \< 40% ----\> "Carregue ate 40%!"
```


## :stop\_sign: Cancelamento

Clique no botao **Parar** na interface a qualquer momento para:

- Interromper o monitoramento

- Encerrar o dreno de bateria

- Restaurar o brilho original

- Cancelar o desligamento (antes de atingir 40-49%)


Feito com :heart: em PowerShell para Windows 11

