# Pré-Registo Experimental — `v4.2` (`EURUSD`)

**Data do registo:** 2026-11-02  
**Baseline de referência congelada:** tag `v4.10-baseline` (commit `4b68cf4` na branch `v4.0-baseline`)  
**Script e dados de auditoria da baseline:** [`tools/auditar_logs_eurusd.py`](../tools/auditar_logs_eurusd.py) | [`files_in_progressing/auditoria_trades_eurusd_v410.csv`](../files_in_progressing/auditoria_trades_eurusd_v410.csv) (4.217 trades)

---

## 1. Linha de Base Medida (`v4.10-baseline` — `EURUSD` M1, 2022–2025)

A auditoria linha a linha dos logs brutos dos agentes do Strategy Tester separou o custo de execução ($\mathbb{E}[R_0]$ de passeio aleatório sem deriva com os mesmos pares observados $(\text{Spread}_i, \text{Stop}_i)$) da informação direcional bruta do sinal ($\alpha = \mathbb{E}[R_{\text{real}}] - \mathbb{E}[R_0]$):

| Setup | $n$ | Spread mediano (médio) | Stop mediano (médio) | $S/D$ médio | WR Obs. | WR Aleatório ($p_0$) | $z$ (Sinal vs $p_0$) | $\mathbb{E}[R_{\text{real}}]$ (só spread) | $t_R$ (só spread) | $\mathbb{E}[R_0]$ (aleatório) | **$\alpha$ bruto** |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `SETUP_LONDON_SWEEP` | 1.156 | 9,0 pts (9,85) | 56,1 pts (64,2) | 19,20% | 24,91% | 26,93% | $-1,55$ | $-0,2675R$ | $-6,89$ | $-0,2072R$ | **$-0,0603R$** |
| `SETUP_H1_OB` | 2.805 | 9,0 pts (9,93) | 92,2 pts (106,6) | 12,78% | 29,52% | 29,07% | $+0,52$ | $-0,1256R$ | $-4,78$ | $-0,1390R$ | **$+0,0134R$** |
| `SETUP_ASIA_SWEEP` | 256 | 9,0 pts (9,70) | 50,0 pts (57,4) | 20,87% | 28,91% | 26,38% | $+0,92$ | $-0,1426R$ | $-1,65$ | $-0,2178R$ | **$+0,0752R$** |

**Constatações fechadas na auditoria:**
1. Nenhum setup em `M1` possui $\alpha$ estatisticamente diferente de zero ($|z| < 1,6$).
2. No `H1_OB`, a expectativa das reentradas pós-loss no mesmo dia ($-0,0935R$, $n=1.635$) foi superior à do 1.º trade do dia ($-0,1567R$, $n=950$); **a trava de 1 trade/dia está descartada**.
3. O símbolo `EURUSD` standard da ActivTrades é *spread-only* (`DEAL_COMMISSION = 0`). Em todas as execuções nesta conta, `InpComissaoPorLote` deve ser `0.0` para evitar dupla cobrança no `OnTester()` e subdimensionamento no `OrderCalcProfit()`.

---

## 2. Partição Estrita de Dados (Proteção contra Sobreajuste)

| Conjunto | Ativo(s) | Período | Regra de Uso |
|---|---|---|---|
| **In-Sample (Desenvolvimento)** | `EURUSD` | `2022.01.01` – `2025.12.31` | Único período permitido para testar hipóteses iterativas (1 variável por vez). |
| **OOS Temporal (Cofre 1)** | `EURUSD` | `2026.01.01` – `2026.10.30` | **Intocado durante o desenvolvimento.** Proibido correr backtests ou scripts de inspeção. Execução única apenas se um candidato aprovar todos os gates em `2022–2025`. |
| **OOS Transversal (Cofre 2)** | `GBPUSD`, `USDJPY` | `2022.01.01` – `2026.10.30` | **Intocados** até existir candidato aprovado em `EURUSD` (IS + OOS 2026). |

---

## 3. Hipótese Pré-Registada `H1` (`v4.2-m5`): Gatilho Estrutural em `M5`

### 3.1 Mecanismo Direcional Postulado
Reduzir apenas a razão custo/stop ($S/D$) é insuficiente quando $\alpha \approx 0$ (demonstrado no quartil `Q4 > 136 pts` do `H1_OB`, onde $S/D = 5,50\%$ e $\mathbb{E}[R] = -0,0352R$). A hipótese `H1` postula duas coisas em conjunto:
1. **Filtro estrutural real ($\alpha_{\text{M5}} > \alpha_{\text{M1}}$):** Em `M1`, um fractal de largura 2 (`5 min`) forma-se dentro do ruído de microestrutura (3–5 pips), gerando falsos rompimentos de CHoCH sem fluxo institucional ($\alpha \approx 0$). Em `M5`, um fractal de largura 2 exige `25 minutos` (5 barras M5 fechadas) para consolidar o swing de referência e um fecho de barra M5 além desse nível para confirmar o CHoCH, capturando reversões/absorções intradiárias genuínas.
2. **Compressão aritmética do custo relativo:** A elevação do stop típico reduz $S/D$ para a faixa de `5%–9%`, permitindo que um $\alpha$ bruto moderado ($\ge +0,08R$) se converta em expectativa líquida positiva.

### 3.2 O que muda exatamente face à `v4.10-baseline`
1. Introdução de `input ENUM_TIMEFRAMES InpLTF = PERIOD_M5;` (seletor estrutural, não otimizável) substituindo `PERIOD_M1` no loop de barra fechada, cálculo de ATR de padding, fractais `SwingHighRecente` / `SwingLowRecente`, deteção de vela de sweep/retorno ao OB e `ConfirmouCHoCH()`. *(Nota: `RangeEntre` do range asiático mantém leitura exata dos limites horários).*
2. Configuração operacional nos `.set` para a conta standard ActivTrades: `InpComissaoPorLote = 0.0`.

### 3.3 O que permanece estritamente fixo (Zero afinação)
- `InpRR = 2.0`
- `InpHTF = PERIOD_H1`
- Constantes `#define`: `FRACTAL_LARGURA = 2`, `SWING_LOOKBACK = 40` (barras de `InpLTF`), `SL_PADDING_ATR = 0.15` (x ATR de `InpLTF`), `STOP_MIN_ATR_HTF = 0.30`, `STOP_MAX_ATR_HTF = 1.50`, `TIMEOUT_BARRAS = 30` (barras de `InpLTF`), `OB_LOOKBACK_HTF = 40`.
- Janelas horárias: Londres `08:00–12:00` local (`09:00–13:00` servidor), Ásia `00:00–06:00` UTC, Sessão líquida OB `08:00–16:00` local.
- Sem breakeven, sem trailing stop, sem trava de 1 trade/dia.

---

## 4. Critérios Objetivos de Aceite e Descarte (em `EURUSD 2022–2025`)

Para qualquer setup (`London`, `H1_OB`, `Asia`) ser aprovado no In-Sample e ganhar o direito à rodada única em `2026`:

1. **Amostra mínima:** $n \ge 100$ trades em `2022–2025`.
2. **Gate de Sinal Bruto ($\alpha$):**
   - $\alpha = \mathbb{E}[R_{\text{real}}] - \mathbb{E}[R_0] \ge +0,06R$ por trade; **e**
   - $z_{\text{sinal}} \ge +2,4$ contra o benchmark de passeio aleatório $p_0$ (e contra o controle empírico de entradas aleatórias nos ticks de `2022–2025`).
3. **Gate de Expectativa Líquida:**
   - $\mathbb{E}[R_{\text{líquido}}] > +0,05R$ por trade; **e**
   - $t_{\text{líquido}} \ge +2,4$ (com `InpComissaoPorLote = 0.0` na conta spread-only).

**Regra de descarte:** Se um setup falhar os gates acima em `2022–2025`, a hipótese `H1` para esse setup é registada como **rejeitada**, sem ajustar `FRACTAL_LARGURA`, `TIMEOUT`, `ATR` ou `InpRR` para tentar forçar aprovação.

---

## 5. Nota Técnica Separada: Hipótese `H2` (Integridade da Máquina de Estados)

Para não misturar variáveis com `H1` (`M5`), ficam registados separadamente 3 defeitos de máquina de estados identificados na inspeção do código `v4.10`, a avaliar apenas em iteração própria (`H2`) sem combinar às cegas:
1. Em `EST_ARMADO`, `g_sweep_extremo` não é atualizado caso o preço marque novo extremo antes do fecho de confirmação do CHoCH.
2. Em `DetectarSweepSessao()`, `ref_hi`/`ref_lo` não são marcados como consumidos após rompimento/execução na sessão.
3. Em `DetectarRetornoOB()`, não há verificação de invalidação prévia do OB (`close < ob_lo` em compra / `close > ob_hi` em venda entre a criação do OB e o presente) nem marcação de mitigação.
