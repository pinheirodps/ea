# EA SMC Multi-Profile v1.01

> Expert Advisor baseado em Smart Money Concepts (SMC) para MetaTrader 5

[![Version](https://img.shields.io/badge/version-1.01-blue.svg)](https://github.com)
[![MQL5](https://img.shields.io/badge/MQL5-Compatible-green.svg)](https://www.mql5.com)
[![License](https://img.shields.io/badge/license-MIT-orange.svg)](LICENSE)

---

## 📖 Visão Geral

Este Expert Advisor implementa uma estratégia completa de **Smart Money Concepts (SMC)**, detectando automaticamente:

- ✅ **Order Blocks (OB)** - Zonas de interesse institucional
- ✅ **Fair Value Gaps (FVG)** - Imbalances para scaling
- ✅ **Market Structure** - BOS e CHOCH
- ✅ **Inducement** - Liquidity sweeps
- ✅ **Premium/Discount Zones** - Preço relativo

### Características Principais

- 🤖 **Modo Auto/Manual** - Opere automaticamente ou receba apenas sinais
- 📊 **Visualização Completa** - Todos os conceitos SMC desenhados no gráfico
- 🔔 **Alertas Inteligentes** - Som e popup ao detectar setups
- 🛡️ **Gestão de Risco** - Killswitch de perda diária, cálculo automático de lote
- 📈 **Multi-Perfil** - Configurações para Scalper, Swing e Intraday
- 🎯 **Prevenção de Duplicatas** - Sistema anti-sinais repetidos (v1.01)

---

## 🎯 Estratégia de Trading

### Lógica de Entrada

1. **Detecta estrutura de mercado** no timeframe maior (ex: H1)
   - Identifica BOS (Break of Structure) ou CHOCH
   
2. **Localiza Order Block** que causou a quebra
   - Última vela de impulso antes do movimento
   
3. **Valida filtros obrigatórios**:
   - ✅ Preço em zona correta (Premium=SELL, Discount=BUY)
   - ✅ Inducement presente (liquidity sweep)
   - ✅ Horário de negociação (sessões Londres/NY)
   
4. **Abre posição** quando preço retorna ao Order Block
   - Entry: Na borda ou no meio do OB
   - SL: Além do OB + padding
   - TP: Calculado por Risk/Reward ratio

### Gestão de Posição

- **Scaling**: Entradas adicionais em Fair Value Gaps
- **Trailing**: Gerenciamento via FVG
- **Expiração**: Ordens pendentes expiram após N barras

---

## ⚙️ Instalação

### Pré-requisitos

- MetaTrader 5 (build 3802+)
- Conta demo ou real com permissão para AutoTrading

### Passo a Passo

1. **Copie os arquivos** para a pasta de dados do MT5:
   ```
   MQL5/
   ├── Experts/
   │   └── EA_SMC_MultiProfile.mq5
   └── Include/
       └── SMC/
           ├── Enums.mqh
           ├── Structures.mqh
           ├── Inputs.mqh
           ├── TradeUtils.mqh
           ├── SMC_Analyzer.mqh
           ├── Filters.mqh
           ├── TradingEngine.mqh
           └── Visualizer.mqh
   ```

2. **Compile o EA**:
   - Abra MetaEditor (F4)
   - Navegue até `Experts/EA_SMC_MultiProfile.mq5`
   - Pressione F7 (Compile)
   - Verifique: `0 errors, 0 warnings` ✅

3. **Anexe ao gráfico**:
   - Arraste o EA do Navigator para o gráfico desejado
   - Configure os parâmetros (veja seção abaixo)
   - Marque "Allow live trading" e "Allow DLL imports"

---

## 🔧 Parâmetros de Configuração

### Perfil de Operação

| Parâmetro | Opções | Descrição |
|-----------|--------|-----------|
| `Profile_Type` | SCALPER / SWING / INTRADAY | Define timeframes base |

**Pré-configurações:**
- **SCALPER**: H1/M5 - Trades rápidos, múltiplas operações/dia
- **SWING**: W1/D1 - Trades longos, algumas por semana
- **INTRADAY**: H4/M15 - Trades médios, 1-3 por dia

### Timeframes

| Parâmetro | Padrão | Função |
|-----------|---------|---------|
| `Timeframe_Structure` | H1 | Detecta estrutura e Order Blocks |
| `Timeframe_Entry` | M5 | Detecta FVGs para scaling |

### Estratégia SMC

| Parâmetro | Padrão | Descrição |
|-----------|---------|-----------|
| `Use_Premium_Discount_Filter` | ✅ true | SELL apenas em Premium, BUY em Discount |
| `Inducement_Required` | ✅ true | Exige liquidity sweep antes do trade |
| `Use_Time_Filter` | ✅ true | Opera apenas em horários específicos |
| `Entry_Mode` | TOUCH | TOUCH=borda OB / MEAN=meio OB |

> ⚠️ **Recomendação**: Mantenha `Inducement_Required = true` para seguir princípios SMC reais

### Filtro de Horário

| Parâmetro | Padrão | Descrição |
|-----------|---------|-----------|
| `Trading_Start_Time` | 09:00 | Início (abertura Londres) |
| `Trading_End_Time` | 17:00 | Fim (fechamento NY) |
| `Trade_Monday...Friday` | true | Dias da semana ativos |

### Gestão de Risco

| Parâmetro | Padrão | Range | Descrição |
|-----------|---------|-------|-----------|
| `Risk_Per_Trade_Percent` | 1.0% | 0.1-5.0 | Risco por operação |
| `Max_Daily_Drawdown_Percent` | 3.0% | 1.0-10.0 | Perda máxima diária (killswitch) |
| `SL_Padding_Points` | 15 | 5-50 | Points além do OB para SL |
| `Risk_Reward_Ratio` | 2.0 | 1.0-5.0 | Relação Risco/Recompensa |

### Scaling (Entradas Adicionais)

| Parâmetro | Padrão | Descrição |
|-----------|---------|-----------|
| `Max_Scaling_Orders` | 3 | Máximo de entradas via FVG |
| `Scaling_Expiration_Bars` | 12 | Barras até expirar ordens pendentes |

### Modo de Operação

| Parâmetro | Padrão | Descrição |
|-----------|---------|-----------|
| `Auto_Trade_Mode` | ✅ true | true=Auto / false=Manual |
| `Show_Visuals` | ✅ true | Desenha elementos no gráfico |
| `Alert_Sound` | ✅ true | Toca som ao detectar sinal |
| `Alert_Popup` | ✅ true | Mostra popup ao detectar sinal |

---

## 🎮 Modos de Operação

### Modo AUTO (`Auto_Trade_Mode = true`)

O EA opera de forma **totalmente automatizada**:

✅ **Abre trades automaticamente**  
✅ Mostra setas grandes (sinais) + pequenas (entradas)  
✅ Emite alertas sonoros e popups  
✅ Logs detalhados no terminal  
✅ Gerencia SL/TP automaticamente  

**Use quando:** Confiar na estratégia, quiser operar 24/7

### Modo MANUAL (`Auto_Trade_Mode = false`)

O EA **apenas sinaliza**, você opera manualmente:

✅ Mostra sinais visuais (setas grandes)  
✅ Emite alertas (som + popup)  
✅ Logs detalhados de cada setup  
❌ **NÃO abre trades** (decisão sua)

**Use quando:** 
- Validar estratégia em demo
- Aplicar filtros adicionais próprios
- Aprender SMC na prática

---

## 🎨 Elementos Visuais

Quando `Show_Visuals = true`, o EA desenha:

| Elemento | Cor | Descrição |
|----------|-----|-----------|
| **BEARISH OB ↓** | 🔴 Vermelho | Order Block de baixa |
| **BULLISH OB ↑** | 🔵 Azul | Order Block de alta |
| **PREMIUM (SELL)** | 🟥 Vermelho claro | Zona de venda (50-100%) |
| **DISCOUNT (BUY)** | 🟢 Verde escuro | Zona de compra (0-50%) |
| **EQ 50%** | 🟡 Dourado | Linha de equilíbrio |
| **BOS ↑/↓** | Linha tracejada | Break of Structure |
| **INDUCEMENT** | 🟣 X Magenta | Ponto de liquidity sweep |
| **Seta Grande** | Verde/Vermelha | Sinal de entrada |
| **Seta Pequena** | Azul/Vermelha | Marcador de execução |

### Dashboard (Canto Superior Esquerdo)

```
=== SMC EA DASHBOARD ===
Mode: AUTO / MANUAL          # Modo atual
Status: SCANNING             # Estado do EA
Msg: Monitoring...           # Mensagem
PnL: 0.00                    # Lucro/prejuízo flutuante
Positions: 0                 # Número de posições
```

---

## 🚀 Configuração Rápida

### Para Iniciantes (SEGURO)

```
Profile_Type = PROFILE_SCALPER
Timeframe_Structure = H1
Timeframe_Entry = M5

Use_Premium_Discount_Filter = true
Inducement_Required = true
Use_Time_Filter = true
Trading_Start_Time = 09:00
Trading_End_Time = 17:00

Risk_Per_Trade_Percent = 0.5     ← BAIXO!
Max_Daily_Drawdown_Percent = 2.0
SL_Padding_Points = 20

Auto_Trade_Mode = FALSE          ← MANUAL!
Show_Visuals = true
Alert_Sound = true
Alert_Popup = true
```

### Scalper Agressivo

```
Profile_Type = PROFILE_SCALPER
Timeframe_Structure = H1
Timeframe_Entry = M5
Risk_Per_Trade_Percent = 1.0
Max_Scaling_Orders = 3
Auto_Trade_Mode = true
```

### Swing Trader

```
Profile_Type = PROFILE_SWING
Timeframe_Structure = W1
Timeframe_Entry = D1
Use_Time_Filter = false
Risk_Per_Trade_Percent = 1.5
Max_Scaling_Orders = 2
Auto_Trade_Mode = true
```

---

## 📊 Como Usar

### Primeiro Uso (Recomendado)

1. **Inicie em MODO MANUAL** (`Auto_Trade_Mode = false`)
2. **Configure risco baixo** (`Risk_Per_Trade_Percent = 0.5%`)
3. **Aguarde sinais** (2-8 horas para Scalper)
4. **Analise cada sinal**:
   - OB está em zona correta? (Premium/Discount)
   - Inducement presente? (X magenta)
   - BOS desenhado?
5. **Opere manualmente** se concordar
6. **Após 1 semana** de testes e resultados positivos:
   - Mude para `Auto_Trade_Mode = true`
   - Aumente risco se desejar (máx 2%)

### Logs Importantes

No terminal MT5 (Ctrl+T), aba "Experts":

- `[AUTO SIGNAL]` - Sinal detectado (modo auto)
- `[MANUAL SIGNAL]` - Sinal detectado (modo manual)
- `[AUTO TRADE]` - Trade executado
- `[DUPLICATE BLOCKED]` - Sinal duplicado bloqueado ✅

---

## 🐛 Troubleshooting

### EA não abre trades

**Verificações:**
1. ✅ `Auto_Trade_Mode = true`?
2. ✅ Botão "AutoTrading" ativo no MT5? (verde)
3. ✅ "Allow live trading" marcado nas propriedades?
4. ✅ Verifique logs - filtros podem estar bloqueando

**Solução temporária:** `Inducement_Required = false`

### Erro "Invalid Stops"

**Causa:** SL/TP muito próximo do preço atual  
**Solução:** Aumente `SL_Padding_Points` para 25-30

### Sinais duplicados

**Status:** ✅ **Corrigido na v1.01**  
EA agora rastreia último OB processado e bloqueia duplicatas

### Muitos trades/scaling

**Solução:** Reduza `Max_Scaling_Orders` para 1-2

### Perda diária atingida

**Comportamento:** EA para automaticamente  
**Dashboard mostra:** `Status: TRADING STOPPED | Msg: Daily Limit Hit`  
**Solução:** Reinicie EA no dia seguinte ou ajuste parâmetro

---

## 📝 Changelog

### v1.01 (2025-11-26)
- ✅ **FIXED**: Sinais duplicados do mesmo Order Block
- ✅ **ADDED**: Rastreamento de OB processados via `g_last_ob_time`
- ✅ **IMPROVED**: Logs mais detalhados
- ✅ **ENHANCED**: Dashboard mostra modo AUTO/MANUAL

### v1.00 (2025-11-25)
- 🎉 Release inicial
- ✅ Implementação completa de SMC
- ✅ Modo Auto/Manual
- ✅ Visualização completa
- ✅ Sistema de alertas

---

## ⚠️ Avisos Importantes

1. ❌ **NUNCA** opere em conta real sem testar extensivamente em demo
2. ❌ **NUNCA** ultrapasse 2% de risco por trade
3. ❌ **NÃO** desative `Inducement_Required` sem entender as consequências
4. ✅ **SEMPRE** monitore os logs do EA
5. ✅ **SEMPRE** respeite o `Max_Daily_Drawdown_Percent`
6. ✅ **SEMPRE** use stop loss

---

## 🎓 Conceitos SMC

Glossário rápido:

- **Order Block (OB)**: Última vela antes de movimento impulsivo. Zona onde instituições acumularam posições.
- **Fair Value Gap (FVG)**: Gap de 3 velas não preenchido. Indica imbalance de liquidez.
- **BOS (Break of Structure)**: Quebra de estrutura. Confirmação de tendência.
- **CHOCH (Change of Character)**: Mudança de caráter. Possível reversão.
- **Inducement**: Liquidity sweep. "Armadilha" para retail traders antes do movimento real.
- **Premium/Discount**: Preço relativo ao range. Premium = caro (vender), Discount = barato (comprar).

---

## 📞 Suporte

**Antes de reportar problemas:**
1. Verifique a seção Troubleshooting
2. Compile novamente o EA
3. Teste em conta demo primeiro

**Ao reportar:**
- Screenshot do gráfico com visuais
- Logs do terminal (aba Experts)
- Parâmetros utilizados
- Símbolo e timeframe

---

## 📄 Licença

MIT License - Use livremente, modifique, distribua.

---

## 🙏 Agradecimentos

Baseado nos conceitos de:
- ICT (Inner Circle Trader)
- Smart Money Concepts
- Institutional Order Flow

---

**Desenvolvido com ❤️ para traders que buscam entender o mercado institucional**

*Trading envolve risco. Opere com responsabilidade.*
