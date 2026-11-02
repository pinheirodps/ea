//+------------------------------------------------------------------+
//|                                            SMC_Sniper_v4.mq5     |
//|            Baseline minimalista - 7 inputs, 1 otimizavel         |
//|                                                                  |
//|  OBJETIVO: medir se a estrategia SMC base tem expectativa        |
//|  positiva, SEM filtros de excecao. Nao adicionar parametros      |
//|  sem evidencia estatistica (ver OnTester: t-stat, n>=100).       |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper v4.2"
#property version   "4.20"
#property strict

#include <Trade\Trade.mqh>

//==================================================================
// CONSTANTES DE ESTRATEGIA
//
// NAO sao inputs por desenho. Cada uma destas e um grau de
// liberdade; mante-las fora da janela de inputs torna inviavel
// afina-las contra o backtest sem recompilar. Durante a fase de
// validacao, NAO TOCAR.
//==================================================================
#define FRACTAL_LARGURA       2      // barras de cada lado do swing LTF
#define SWING_LOOKBACK_LTF   40      // ate onde procurar o swing de referencia (barras LTF)
#define SL_PADDING_ATR_LTF    0.15   // folga do SL alem do extremo do sweep (x ATR LTF)
#define STOP_MIN_ATR_HTF      0.30   // stop minimo aceite (x ATR do HTF)
#define STOP_MAX_ATR_HTF      1.50   // stop maximo aceite (x ATR do HTF)
#define TIMEOUT_BARRAS_LTF   30      // barras LTF a aguardar confirmacao CHoCH
#define ATR_PERIODO          14
#define OB_LOOKBACK_HTF      40      // barras HTF para procurar BOS/OB
#define MIN_TRADES_VALIDO   100      // abaixo disto, OnTester devolve 0

// Janelas de sessao
// - Asia: ancorada em UTC fixo (centros asiaticos sem DST sazonal)
// - Londres: ancorada em horario local de Londres (08:00 as 12:00 local)
#define ASIA_INI_UTC          0      // 00:00 UTC (fixo)
#define ASIA_FIM_UTC          6      // 06:00 UTC (fixo)
#define LONDON_INI_LOCAL      8      // 08:00 local de Londres (abertura oficial)
#define LONDON_FIM_LOCAL     12      // 12:00 local de Londres
#define LIQ_SESSION_FIM_LOCAL 16     // 16:00 local de Londres (fecho da sessao liquida para OB)

//==================================================================
// INPUTS (7 inputs, 1 otimizavel)
//==================================================================
enum ENUM_SETUP
  {
   SETUP_ASIA_SWEEP,    // Sweep do range do dia anterior na sessao asiatica
   SETUP_LONDON_SWEEP,  // Sweep do range asiatico na abertura de Londres
   SETUP_H1_OB          // Retorno a Order Block apos BOS no HTF
  };

enum ENUM_DST
  {
   DST_NENHUM,          // Sem mudanca sazonal de horario
   DST_US,              // Regra EUA (2o dom marco a 1o dom novembro)
   DST_EU               // Regra Europa (ultimo dom marco a ultimo dom outubro)
  };

// --- Estrategia ---
input ENUM_SETUP      InpSetup           = SETUP_LONDON_SWEEP; // Setup (seletor, nao afinar)
input ENUM_TIMEFRAMES InpHTF             = PERIOD_H1;          // Timeframe de estrutura
input ENUM_TIMEFRAMES InpLTF             = PERIOD_M5;          // Timeframe de gatilho (H1 prereg: M5)
input double          InpRR              = 2.0;                // Risk/Reward (UNICO otimizavel)

// --- Operacionais ---
input int             InpOffsetInverno   = 1;      // Offset-base do servidor vs GMT (inverno)
input ENUM_DST        InpDST             = DST_EU; // Regra sazonal do servidor (EU/US/Nenhum)
input double          InpRiscoPct        = 0.50;   // Risco por trade (% equity)
input int             InpMaxSpreadPts    = 20;     // Spread maximo (pontos)
input double          InpComissaoPorLote = 0.0;    // Comissao round-turn/lote (0 em conta spread-only)
input long            InpMagic           = 440001; // Magic number

//==================================================================
// ESTADO
//==================================================================
enum ENUM_ESTADO
  {
   EST_SCAN,      // a procurar sweep / entrada em OB
   EST_ARMADO,    // sweep detectado, a aguardar CHoCH
   EST_EM_TRADE
  };

CTrade        trade;
ENUM_ESTADO   g_estado           = EST_SCAN;
datetime      g_ultima_barra_ltf = 0;
int           g_direcao          = 0;      // +1 compra, -1 venda
double        g_sweep_extremo    = 0.0;    // preco do extremo varrido
double        g_nivel_choch      = 0.0;    // nivel cujo rompimento confirma
int           g_barras_armado    = 0;
datetime      g_armado_em        = 0;

int           g_atr_htf_handle   = INVALID_HANDLE;
int           g_atr_ltf_handle   = INVALID_HANDLE;

// contadores de diagnostico (apenas Print no final)
int           g_cnt_sweep        = 0;
int           g_cnt_timeout      = 0;
int           g_cnt_stop_fora    = 0;
int           g_cnt_spread       = 0;
int           g_cnt_stops_level  = 0;
int           g_cnt_entradas     = 0;

//==================================================================
// INICIALIZACAO
//==================================================================
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(10);

   if(PeriodSeconds(InpLTF) >= PeriodSeconds(InpHTF))
     {
      Print("ERRO: InpLTF deve ser estritamente inferior a InpHTF.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_atr_htf_handle = iATR(_Symbol, InpHTF, ATR_PERIODO);
   g_atr_ltf_handle = iATR(_Symbol, InpLTF, ATR_PERIODO);

   if(g_atr_htf_handle == INVALID_HANDLE || g_atr_ltf_handle == INVALID_HANDLE)
     {
      Print("ERRO: falha ao criar handles ATR.");
      return(INIT_FAILED);
     }

   PrintFormat("SMC Sniper v4.2 | setup=%s | HTF=%s | LTF=%s | RR=%.2f | risco=%.2f%% | comm=%.2f | offset_base=GMT+%d | DST=%s",
               EnumToString(InpSetup), EnumToString(InpHTF), EnumToString(InpLTF),
               InpRR, InpRiscoPct, InpComissaoPorLote, InpOffsetInverno, EnumToString(InpDST));
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_atr_htf_handle != INVALID_HANDLE) IndicatorRelease(g_atr_htf_handle);
   if(g_atr_ltf_handle != INVALID_HANDLE) IndicatorRelease(g_atr_ltf_handle);

   PrintFormat("DIAG | sweeps=%d entradas=%d | rejeicoes: timeout=%d stop_fora=%d spread=%d stops_level=%d",
               g_cnt_sweep, g_cnt_entradas, g_cnt_timeout,
               g_cnt_stop_fora, g_cnt_spread, g_cnt_stops_level);
  }

//==================================================================
// UTILITARIOS
//==================================================================

// ATR do timeframe pedido, sempre da barra FECHADA (shift 1).
double ATR(const int handle)
  {
   double buf[1];
   if(CopyBuffer(handle, 0, 1, 1, buf) <= 0) return(0.0);
   return(buf[0]);
  }

datetime InicioDoDia(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   d.hour = 0; d.min = 0; d.sec = 0;
   return(StructToTime(d));
  }

//+------------------------------------------------------------------+
//| Offset do servidor vs GMT com suporte a DST dos brokers Forex    |
//| Quase a totalidade dos servidores Forex (ActivTrades, IC, etc.)  |
//| sincroniza com o fecho de Nova Iorque (US DST):                 |
//| - Inverno (novembro a marco): GMT+2                              |
//| - Verao (2o domingo marco a 1o domingo novembro): GMT+3         |
//+------------------------------------------------------------------+
int OffsetServidorGMT(const datetime t)
  {
   if(InpDST == DST_NENHUM)
      return(InpOffsetInverno);

   MqlDateTime dt;
   TimeToStruct(t, dt);
   int ano = dt.year;

   datetime dst_ini = 0;
   datetime dst_fim = 0;

   if(InpDST == DST_US)
     {
      // 2o domingo de marco as 02:00
      MqlDateTime d_mar;
      d_mar.year = ano; d_mar.mon = 3; d_mar.day = 1; d_mar.hour = 2; d_mar.min = 0; d_mar.sec = 0;
      datetime t_mar1 = StructToTime(d_mar);
      TimeToStruct(t_mar1, d_mar);
      int dom_mar = (d_mar.day_of_week == 0) ? 8 : (15 - d_mar.day_of_week);
      d_mar.day = dom_mar;
      dst_ini = StructToTime(d_mar);

      // 1o domingo de novembro as 02:00
      MqlDateTime d_nov;
      d_nov.year = ano; d_nov.mon = 11; d_nov.day = 1; d_nov.hour = 2; d_nov.min = 0; d_nov.sec = 0;
      datetime t_nov1 = StructToTime(d_nov);
      TimeToStruct(t_nov1, d_nov);
      int dom_nov = (d_nov.day_of_week == 0) ? 1 : (8 - d_nov.day_of_week);
      d_nov.day = dom_nov;
      dst_fim = StructToTime(d_nov);
     }
   else if(InpDST == DST_EU)
     {
      // Ultimo domingo de marco as 02:00 servidor
      MqlDateTime d_mar;
      d_mar.year = ano; d_mar.mon = 3; d_mar.day = 31; d_mar.hour = 2; d_mar.min = 0; d_mar.sec = 0;
      datetime t_mar31 = StructToTime(d_mar);
      TimeToStruct(t_mar31, d_mar);
      int dom_mar = 31 - d_mar.day_of_week;
      d_mar.day = dom_mar;
      dst_ini = StructToTime(d_mar);

      // Ultimo domingo de outubro as 02:00 servidor
      MqlDateTime d_out;
      d_out.year = ano; d_out.mon = 10; d_out.day = 31; d_out.hour = 2; d_out.min = 0; d_out.sec = 0;
      datetime t_out31 = StructToTime(d_out);
      TimeToStruct(t_out31, d_out);
      int dom_out = 31 - d_out.day_of_week;
      d_out.day = dom_out;
      dst_fim = StructToTime(d_out);
     }

   if(t >= dst_ini && t < dst_fim)
      return(InpOffsetInverno + 1); // Horario de verao (+1h)

   return(InpOffsetInverno);        // Horario de inverno
  }

//+------------------------------------------------------------------+
//| Regra de DST de Londres (Reino Unido / BST)                      |
//| Ultimo domingo de marco 01:00 UTC ate ultimo domingo outubro     |
//+------------------------------------------------------------------+
bool EmDST_Londres(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int ano = dt.year;

   // Ultimo domingo de marco as 01:00 UTC
   MqlDateTime d_mar;
   d_mar.year = ano; d_mar.mon = 3; d_mar.day = 31; d_mar.hour = 1; d_mar.min = 0; d_mar.sec = 0;
   datetime t_mar31 = StructToTime(d_mar);
   TimeToStruct(t_mar31, d_mar);
   int dom_mar = 31 - d_mar.day_of_week;
   d_mar.day = dom_mar;
   datetime dst_ini = StructToTime(d_mar);

   // Ultimo domingo de outubro as 01:00 UTC
   MqlDateTime d_out;
   d_out.year = ano; d_out.mon = 10; d_out.day = 31; d_out.hour = 1; d_out.min = 0; d_out.sec = 0;
   datetime t_out31 = StructToTime(d_out);
   TimeToStruct(t_out31, d_out);
   int dom_out = 31 - d_out.day_of_week;
   d_out.day = dom_out;
   datetime dst_fim = StructToTime(d_out);

   return(t >= dst_ini && t < dst_fim);
  }

int OffsetLondresGMT(const datetime t)
  {
   return(EmDST_Londres(t) ? 1 : 0); // 0 no inverno (GMT), +1 no verao (BST)
  }

int HoraServidorDeLondres(const datetime agora, const int hora_londres)
  {
   int gmt = hora_londres - OffsetLondresGMT(agora);
   int h   = gmt + OffsetServidorGMT(agora);
   while(h < 0)   h += 24;
   while(h >= 24) h -= 24;
   return(h);
  }

int HoraServidorDeUTC(const datetime agora, const int hora_utc)
  {
   int h = hora_utc + OffsetServidorGMT(agora);
   while(h < 0)   h += 24;
   while(h >= 24) h -= 24;
   return(h);
  }

bool DentroDaJanelaServidor(const datetime agora, const int ini_srv, const int fim_srv)
  {
   MqlDateTime d;
   TimeToStruct(agora, d);
   if(ini_srv <= fim_srv) return(d.hour >= ini_srv && d.hour < fim_srv);
   return(d.hour >= ini_srv || d.hour < fim_srv);
  }

bool DentroJanelaLondres(const datetime agora)
  {
   int ini = HoraServidorDeLondres(agora, LONDON_INI_LOCAL);
   int fim = HoraServidorDeLondres(agora, LONDON_FIM_LOCAL);
   return(DentroDaJanelaServidor(agora, ini, fim));
  }

bool DentroJanelaAsia(const datetime agora)
  {
   int ini = HoraServidorDeUTC(agora, ASIA_INI_UTC);
   int fim = HoraServidorDeUTC(agora, ASIA_FIM_UTC);
   return(DentroDaJanelaServidor(agora, ini, fim));
  }

bool DentroJanelaLiquida(const datetime agora)
  {
   int ini = HoraServidorDeLondres(agora, LONDON_INI_LOCAL);
   int fim = HoraServidorDeLondres(agora, LIQ_SESSION_FIM_LOCAL);
   return(DentroDaJanelaServidor(agora, ini, fim));
  }

// Range de M1 entre dois instantes. Nunca le o indice 0 (barra aberta).
bool RangeEntre(const datetime t_ini, const datetime t_fim, double &hi, double &lo)
  {
   int i_ini = iBarShift(_Symbol, PERIOD_M1, t_ini, false);
   int i_fim = iBarShift(_Symbol, PERIOD_M1, t_fim, false);
   if(i_ini < 0 || i_fim < 0 || i_ini < i_fim) return(false);

   int inicio = i_ini;
   int fim    = MathMax(i_fim, 1);
   if(inicio < fim) return(false);

   hi = -DBL_MAX;
   lo =  DBL_MAX;
   for(int i = inicio; i >= fim; i--)
     {
      double h = iHigh(_Symbol, PERIOD_M1, i);
      double l = iLow (_Symbol, PERIOD_M1, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
     }
   return(hi > lo);
  }

// Swing low fractal mais recente em InpLTF (ignora a barra 0).
bool SwingLowRecente(double &nivel)
  {
   for(int i = 1 + FRACTAL_LARGURA; i <= SWING_LOOKBACK_LTF; i++)
     {
      double c = iLow(_Symbol, InpLTF, i);
      bool ok = true;
      for(int k = 1; k <= FRACTAL_LARGURA && ok; k++)
        {
         if(iLow(_Symbol, InpLTF, i - k) <= c) ok = false;
         if(iLow(_Symbol, InpLTF, i + k) <= c) ok = false;
        }
      if(ok) { nivel = c; return(true); }
     }
   return(false);
  }

// Swing high fractal mais recente em InpLTF (ignora a barra 0).
bool SwingHighRecente(double &nivel)
  {
   for(int i = 1 + FRACTAL_LARGURA; i <= SWING_LOOKBACK_LTF; i++)
     {
      double c = iHigh(_Symbol, InpLTF, i);
      bool ok = true;
      for(int k = 1; k <= FRACTAL_LARGURA && ok; k++)
        {
         if(iHigh(_Symbol, InpLTF, i - k) >= c) ok = false;
         if(iHigh(_Symbol, InpLTF, i + k) >= c) ok = false;
        }
      if(ok) { nivel = c; return(true); }
     }
   return(false);
  }

bool TemPosicaoAberta()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)  continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)   continue;
      return(true);
     }
   return(false);
  }

void ResetEstado()
  {
   g_estado        = EST_SCAN;
   g_direcao       = 0;
   g_sweep_extremo = 0.0;
   g_nivel_choch   = 0.0;
   g_barras_armado = 0;
   g_armado_em     = 0;
  }

//==================================================================
// DETECCAO DE SWEEP (setups de sessao)
//
// Um sweep e: a barra fechada varreu um extremo de referencia e
// FECHOU de volta para dentro do range. O fecho de volta e o que
// distingue sweep de rompimento.
//==================================================================
bool DetectarSweepSessao()
  {
   datetime agora  = iTime(_Symbol, InpLTF, 1);
   datetime dia    = InicioDoDia(agora);
   double   ref_hi = 0.0, ref_lo = 0.0;

   if(InpSetup == SETUP_LONDON_SWEEP)
     {
      if(!DentroJanelaLondres(agora)) return(false);
      datetime t_ini = dia + HoraServidorDeUTC(agora, ASIA_INI_UTC) * 3600;
      datetime t_fim = dia + HoraServidorDeUTC(agora, ASIA_FIM_UTC) * 3600;
      if(!RangeEntre(t_ini, t_fim, ref_hi, ref_lo)) return(false);
     }
   else if(InpSetup == SETUP_ASIA_SWEEP)
     {
      if(!DentroJanelaAsia(agora)) return(false);
      ref_hi = iHigh(_Symbol, PERIOD_D1, 1);
      ref_lo = iLow (_Symbol, PERIOD_D1, 1);
      if(ref_hi <= 0.0 || ref_lo <= 0.0 || ref_hi <= ref_lo) return(false);
     }
   else
      return(false);

   double h = iHigh (_Symbol, InpLTF, 1);
   double l = iLow  (_Symbol, InpLTF, 1);
   double c = iClose(_Symbol, InpLTF, 1);

   // Sweep do topo -> procura venda
   if(h > ref_hi && c < ref_hi)
     {
      double nivel;
      if(!SwingLowRecente(nivel)) return(false);
      g_direcao       = -1;
      g_sweep_extremo = h;
      g_nivel_choch   = nivel;
      return(true);
     }

   // Sweep do fundo -> procura compra
   if(l < ref_lo && c > ref_lo)
     {
      double nivel;
      if(!SwingHighRecente(nivel)) return(false);
      g_direcao       = 1;
      g_sweep_extremo = l;
      g_nivel_choch   = nivel;
      return(true);
     }

   return(false);
  }

//==================================================================
// DETECCAO DE ORDER BLOCK (setup estrutural)
//
// BOS no HTF -> identifica a ultima vela oposta antes do impulso
// -> arma quando o preco regressa a zona do OB.
//==================================================================
bool DetectarRetornoOB()
  {
   datetime agora = iTime(_Symbol, InpLTF, 1);
   // apenas sessoes liquidas
   if(!DentroJanelaLiquida(agora)) return(false);

   double h_ltf = iHigh(_Symbol, InpLTF, 1);
   double l_ltf = iLow (_Symbol, InpLTF, 1);

   for(int i = 2; i <= OB_LOOKBACK_HTF; i++)
     {
      // --- BUY OB: vela de baixa no HTF que gerou BOS de alta posterior ---
      if(iClose(_Symbol, InpHTF, i) < iOpen(_Symbol, InpHTF, i))
        {
         double ob_hi = iHigh(_Symbol, InpHTF, i);
         double ob_lo = iLow (_Symbol, InpHTF, i);

         // BOS posterior: alguma barra entre i-1 e 1 fechou acima do topo do OB
         bool bos = false;
         for(int j = i - 1; j >= 1; j--)
           {
            if(iClose(_Symbol, InpHTF, j) > ob_hi) { bos = true; break; }
           }

         if(bos)
           {
            // Retorno da vela M1 a zona do OB
            if(l_ltf <= ob_hi && h_ltf >= ob_lo)
              {
               double nivel;
               if(SwingHighRecente(nivel))
                 {
                  g_direcao       = 1;
                  g_sweep_extremo = ob_lo;
                  g_nivel_choch   = nivel;
                  return(true);
                 }
              }
           }
        }

      // --- SELL OB: vela de alta no HTF que gerou BOS de baixa posterior ---
      if(iClose(_Symbol, InpHTF, i) > iOpen(_Symbol, InpHTF, i))
        {
         double ob_hi = iHigh(_Symbol, InpHTF, i);
         double ob_lo = iLow (_Symbol, InpHTF, i);

         // BOS posterior: alguma barra entre i-1 e 1 fechou abaixo do fundo do OB
         bool bos = false;
         for(int j = i - 1; j >= 1; j--)
           {
            if(iClose(_Symbol, InpHTF, j) < ob_lo) { bos = true; break; }
           }

         if(bos)
           {
            // Retorno da vela M1 a zona do OB
            if(h_ltf >= ob_lo && l_ltf <= ob_hi)
              {
               double nivel;
               if(SwingLowRecente(nivel))
                 {
                  g_direcao       = -1;
                  g_sweep_extremo = ob_hi;
                  g_nivel_choch   = nivel;
                  return(true);
                 }
              }
           }
        }
     }
   return(false);
  }

//==================================================================
// CONFIRMACAO CHoCH
//
// Apos o sweep, so entra se a barra InpLTF FECHADA romper o swing de
// referencia na direcao do trade.
//==================================================================
bool ConfirmouCHoCH()
  {
   double c = iClose(_Symbol, InpLTF, 1);
   if(g_direcao ==  1) return(c > g_nivel_choch);
   if(g_direcao == -1) return(c < g_nivel_choch);
   return(false);
  }

//==================================================================
// EXECUCAO
//==================================================================
void ExecutarEntrada()
  {
   //--- guarda de spread
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPts)
     {
      g_cnt_spread++;
      ResetEstado();
      return;
     }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr_ltf = ATR(g_atr_ltf_handle);
   double atr_htf = ATR(g_atr_htf_handle);
   if(atr_htf <= 0.0 || atr_ltf <= 0.0) { ResetEstado(); return; }

   double padding = atr_ltf * SL_PADDING_ATR_LTF;

   // Entrada no lado correto do spread; SL e TP medidos a partir dela,
   // por isso o spread fica DENTRO do R e nao por fora.
   double entrada = (g_direcao == 1 ? ask : bid);
   double sl      = (g_direcao == 1 ? g_sweep_extremo - padding
                                    : g_sweep_extremo + padding);
   double dist    = (g_direcao == 1 ? entrada - sl : sl - entrada);

   if(dist <= 0.0) { ResetEstado(); return; }

   //--- limites de stop derivados do ATR (constantes, nao inputs)
   if(dist < atr_htf * STOP_MIN_ATR_HTF || dist > atr_htf * STOP_MAX_ATR_HTF)
     {
      g_cnt_stop_fora++;
      ResetEstado();
      return;
     }

   //--- CORRECAO 1: respeitar o stops level da corretora.
   // Sem isto o backtest aceita SL colado ao extremo e o live
   // devolve retcode 10016, criando divergencia silenciosa.
   // No MT5 o SL da compra fecha ao Bid (distancia = bid - sl) e da venda fecha ao Ask (distancia = sl - ask).
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze      = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double min_dist  = (double)MathMax(stops_level, freeze) * _Point;

   bool sl_invalido = (g_direcao == 1) ? ((bid - sl) <= min_dist) : ((sl - ask) <= min_dist);
   double tp = (g_direcao == 1 ? entrada + dist * InpRR
                               : entrada - dist * InpRR);
   bool tp_invalido = (g_direcao == 1) ? ((tp - bid) <= min_dist) : ((ask - tp) <= min_dist);

   if(min_dist > 0.0 && (sl_invalido || tp_invalido))
     {
      g_cnt_stops_level++;
      PrintFormat("Entrada abortada: SL/TP proximo demais do preco (stops level=%d pts)",
                  (int)MathMax(stops_level, freeze));
      ResetEstado();
      return;
     }

   //--- CORRECAO 2: calculo exato de perda por lote na moeda da conta via OrderCalcProfit.
   // Elimina o vies cambial em pares cruzados (USDJPY, GBPUSD com conta EUR/USD)
   // e inclui a comissao round-turn dentro do risco projetado.
   ENUM_ORDER_TYPE order_type = (g_direcao == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double perda_calc = 0.0;
   if(!OrderCalcProfit(order_type, _Symbol, 1.0, entrada, sl, perda_calc))
     {
      ResetEstado();
      return;
     }

   double perda_por_lote = MathAbs(perda_calc) + InpComissaoPorLote;
   if(perda_por_lote <= 0.0) { ResetEstado(); return; }

   double risco_moeda = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiscoPct / 100.0;
   double lote = risco_moeda / perda_por_lote;

   double lote_min  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lote_max  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lote_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lote_step > 0.0)
     {
      lote = MathFloor((lote / lote_step) + 1e-7) * lote_step;
      int lote_dig = (lote_step < 0.01) ? 3 : ((lote_step < 0.1) ? 2 : 1);
      lote = NormalizeDouble(lote, lote_dig);
     }
   lote = MathMax(lote_min, MathMin(lote_max, lote));

   // Guard de risco estrito a 1.0x: se o lote minimo exceder o risco alvo, aborta.
   if(lote * perda_por_lote > risco_moeda)
     {
      PrintFormat("Entrada abortada: lote minimo (%.2f) excede o risco alvo de %.2f (perda projetada: %.2f)",
                  lote, risco_moeda, lote * perda_por_lote);
      ResetEstado();
      return;
     }

   int    dig = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   entrada = NormalizeDouble(entrada, dig);
   sl      = NormalizeDouble(sl,      dig);
   tp      = NormalizeDouble(tp,      dig);

   bool ok = (g_direcao == 1)
             ? trade.Buy (lote, _Symbol, entrada, sl, tp, "SMCv4")
             : trade.Sell(lote, _Symbol, entrada, sl, tp, "SMCv4");

   if(ok)
     {
      g_cnt_entradas++;
      g_estado = EST_EM_TRADE;
      PrintFormat("ENTRADA %s | %.5f | SL %.5f (%.1f pts) | TP %.5f | lote %.2f | spread %d | risco %.2f",
                  (g_direcao == 1 ? "BUY" : "SELL"), entrada, sl,
                  dist / _Point, tp, lote, (int)spread, risco_moeda);
     }
   else
     {
      PrintFormat("Ordem rejeitada: %d - %s",
                  trade.ResultRetcode(), trade.ResultRetcodeDescription());
      ResetEstado();
     }
  }

//==================================================================
// LOOP PRINCIPAL
//==================================================================
void OnTick()
  {
   //--- posicao aberta: sem gestao ativa nesta baseline.
   // Breakeven e trailing alteram a distribuicao de RR e sao
   // precisamente o que queremos medir depois, isoladamente.
   if(g_estado == EST_EM_TRADE)
     {
      if(!TemPosicaoAberta()) ResetEstado();
      return;
     }

   //--- CORRECAO 3 (implicita): toda a logica corre uma vez por
   // barra InpLTF FECHADA. Nenhuma leitura usa o indice 0.
   datetime barra = iTime(_Symbol, InpLTF, 0);
   if(barra == g_ultima_barra_ltf) return;
   g_ultima_barra_ltf = barra;

   if(TemPosicaoAberta()) { g_estado = EST_EM_TRADE; return; }

   if(g_estado == EST_SCAN)
     {
      bool armou = (InpSetup == SETUP_H1_OB) ? DetectarRetornoOB()
                                             : DetectarSweepSessao();
      if(armou)
        {
         g_estado        = EST_ARMADO;
         g_barras_armado = 0;
         g_armado_em     = barra;
         g_cnt_sweep++;
        }
      return;
     }

   if(g_estado == EST_ARMADO)
     {
      g_barras_armado++;

      if(ConfirmouCHoCH())
        {
         ExecutarEntrada();
         return;
        }

      if(g_barras_armado >= TIMEOUT_BARRAS_LTF)
        {
         g_cnt_timeout++;
         ResetEstado();
        }
     }
  }

//==================================================================
// CRITERIO DE OTIMIZACAO
//
// Devolve a estatistica t da expectativa por trade: media / desvio
// padrao * raiz(n). Responde a pergunta certa -- "esta expectativa
// distingue-se de zero?" -- em vez de "qual o maior lucro?", que e
// o que premeia sobreajuste.
//
// Devolve 0 abaixo de MIN_TRADES_VALIDO: uma amostra pequena nao
// e um resultado, e um ruido.
//
// Referencia: t >= 2.0 e a barra minima convencional (~95%).
//==================================================================
double OnTester()
  {
   if(!HistorySelect(0, TimeCurrent())) return(0.0);

   double r[];
   int    n = 0;
   int    total = HistoryDealsTotal();

   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)       continue;
      if(HistoryDealGetString (ticket, DEAL_SYMBOL) != _Symbol)       continue;

      double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double vol  = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      // Fallback: se o Strategy Tester nao modelar comissao da corretora (vem a 0),
      // deduz InpComissaoPorLote manualmente para que o t-stat seja sempre liquido.
      if(comm == 0.0 && InpComissaoPorLote > 0.0 && vol > 0.0)
         comm = -InpComissaoPorLote * vol;

      double p = HistoryDealGetDouble(ticket, DEAL_PROFIT)
               + comm
               + HistoryDealGetDouble(ticket, DEAL_SWAP);

      ArrayResize(r, n + 1, 1000);
      r[n] = p;
      n++;
     }

   if(n < MIN_TRADES_VALIDO)
     {
      PrintFormat("OnTester: %d trades (< %d). Amostra insuficiente -> 0.",
                  n, MIN_TRADES_VALIDO);
      return(0.0);
     }

   double soma = 0.0;
   for(int i = 0; i < n; i++) soma += r[i];
   double media = soma / n;

   double var = 0.0;
   for(int i = 0; i < n; i++) var += (r[i] - media) * (r[i] - media);
   var /= (n - 1);

   double sd = MathSqrt(var);
   if(sd <= 0.0) return(0.0);

   double t = (media / sd) * MathSqrt((double)n);

   PrintFormat("OnTester: n=%d | media=%.2f | sd=%.2f | t=%.2f", n, media, sd, t);
   return(t);
  }
//+------------------------------------------------------------------+