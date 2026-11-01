//+------------------------------------------------------------------+
//|                                       SMC_Sniper_Scanner.mq5     |
//|  Indicador de scan multi-timeframe (HTF -> LTF) para a estrategia|
//|  SMC do SMC_Sniper.mq5: tendencia H1, Order Block H1, sweep no   |
//|  timeframe de gatilho, displacement + RSI, projeta SL/TP.        |
//|                                                                    |
//|  NAO executa ordens. Apenas desenha a zona/sweep/SL/TP no grafico|
//|  e dispara Alert()/popup/som quando o setup fica pronto para     |
//|  decisao manual. Use junto com o EA SMC_Sniper_Manual.mq5 para   |
//|  ter botoes de compra/venda com lote ja calculado.                |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper Scanner"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property indicator_buffers 1

#include <SMC\SniperSignalEngine.mqh>

//--- Timeframes: rode o indicador no grafico do timeframe de ENTRADA (ex.: M5)
//--- e ele usa o timeframe de ESTRUTURA (ex.: H1) para tendencia + Order Block.
input ENUM_TIMEFRAMES  TF_Estrutura        = PERIOD_H1;   // Timeframe maior: tendencia + Order Block
input ENUM_TIMEFRAMES  TF_Gatilho          = PERIOD_M1;   // Timeframe menor: sweep + displacement + confirmacao
input ENUM_TIMEFRAMES  TF_RSI              = PERIOD_M30;  // Timeframe do RSI de momentum (perfil validado)

input group "=== Risco / Alvo (apenas para desenhar SL/TP projetados) ==="
input double  RR_Ratio               = 2.0;   // Relacao risco:retorno padrao
input double  RR_Sniper_Forte        = 2.8;   // RR quando o candle de confirmacao for muito forte
input bool    Usar_RR_Dinamico       = true;
input double  ATR_Stop_Min           = 0.15;  // Stop minimo em multiplos de ATR H1
input double  ATR_Stop_Max           = 5.0;   // Stop maximo em multiplos de ATR H1
input double  RSI_Min_Entrada        = 52.0;  // Momentum minimo apos o sweep (perfil v2.7)

input group "=== Risco em dinheiro (so para o texto do painel, nao executa nada) ==="
input double  Risco_Euros            = 25.0;  // Usado so para mostrar o lote sugerido no painel

input group "=== Visual / Alerta ==="
input bool    Alert_Popup            = true;
input bool    Alert_Sound            = true;
input string  Alert_Sound_File       = "alert2.wav";
input bool    Mostrar_Painel         = true;
input color   Cor_OB_Compra          = clrDodgerBlue;
input color   Cor_OB_Venda           = clrCrimson;
input color   Cor_SL                 = clrRed;
input color   Cor_TP                 = clrLimeGreen;
input color   Cor_Entrada            = clrWhite;

string g_prefix = "SMCScan_";
CSniperSignalEngine *g_engine = NULL;
datetime g_ultimo_alerta = 0;
ENUM_SNIPER_ESTADO g_ultimo_estado_desenhado = SNIPER_SCANNING;

double g_buf_dummy[];

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, g_buf_dummy, INDICATOR_DATA);

   g_engine = new CSniperSignalEngine(_Symbol);
   g_engine.SetTimeframes(TF_Estrutura, TF_Gatilho, TF_RSI);
   g_engine.SetRiscoRR(RR_Ratio, RR_Sniper_Forte, Usar_RR_Dinamico);
   g_engine.SetStopLimites(ATR_Stop_Min, ATR_Stop_Max);
   g_engine.SetRSI(RSI_Min_Entrada);

   if(!g_engine.Init())
   {
      Print("SMC Sniper Scanner: falha ao criar indicadores (ATR/EMA/RSI).");
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("SMC Sniper Scanner [%s -> %s]", EnumToString(TF_Estrutura), EnumToString(TF_Gatilho)));

   Print("SMC Sniper Scanner iniciado | Estrutura: ", EnumToString(TF_Estrutura),
         " | Gatilho: ", EnumToString(TF_Gatilho),
         " | RSI: ", EnumToString(TF_RSI));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
   if(CheckPointer(g_engine) != POINTER_INVALID)
   {
      g_engine.Deinit();
      delete g_engine;
      g_engine = NULL;
   }
}

//+------------------------------------------------------------------+
double LotesSugeridos(double entrada, double sl)
{
   double dist = MathAbs(entrada - sl);
   if(dist <= 0) return 0;

   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0 || tv <= 0) return 0;

   double lote = NormalizeDouble(Risco_Euros / ((dist / ts) * tv), 2);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   return MathMax(min_lot, MathMin(MathMin(max_lot, 2.0), lote));
}

//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontsize = 10)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
}

void DesenharPainel(SniperSetup &s)
{
   if(!Mostrar_Painel) return;

   string pfx = g_prefix + "Painel_";
   int y = 20;

   string estado_txt = "SCANNING";
   color estado_clr = clrGray;
   if(s.estado == SNIPER_EM_ZONA) { estado_txt = "EM ZONA (aguardando sweep)"; estado_clr = clrOrange; }
   else if(s.estado == SNIPER_SWEEP_OK) { estado_txt = "SWEEP OK (aguardando confirmacao)"; estado_clr = clrYellow; }
   else if(s.estado == SNIPER_PRONTO) { estado_txt = "PRONTO PARA DECISAO"; estado_clr = clrLime; }

   CreateLabel(pfx + "Title", 20, y, "=== SMC SNIPER SCANNER ===", clrWhite, 12); y += 22;
   CreateLabel(pfx + "Estado", 20, y, "Estado: " + estado_txt, estado_clr, 10); y += 18;

   if(s.estado == SNIPER_PRONTO)
   {
      double lote = LotesSugeridos(s.entrada, s.sl);
      string dir_txt = (s.direcao == 1 ? "COMPRA" : "VENDA");
      color dir_clr = (s.direcao == 1 ? clrDodgerBlue : clrCrimson);

      ObjectDelete(0, pfx + "Tendencia");
      ObjectDelete(0, pfx + "ATR");
      ObjectDelete(0, pfx + "Timeout");

      CreateLabel(pfx + "Dir", 20, y, "Direcao: " + dir_txt + " | Zona: " + s.ob_tf, dir_clr, 10); y += 18;
      CreateLabel(pfx + "Entrada", 20, y, StringFormat("Entrada: %s", DoubleToString(s.entrada, _Digits)), Cor_Entrada, 10); y += 18;
      CreateLabel(pfx + "SL", 20, y, StringFormat("Stop:    %s  (%.1f pts)", DoubleToString(s.sl, _Digits), s.stop_pts), Cor_SL, 10); y += 18;
      CreateLabel(pfx + "TP", 20, y, StringFormat("Alvo:    %s  (RR %.2f)", DoubleToString(s.tp, _Digits), s.rr_efetivo), Cor_TP, 10); y += 18;
      CreateLabel(pfx + "RSI", 20, y, StringFormat("RSI(%s): %.1f", EnumToString(TF_RSI), s.rsi), clrSilver, 9); y += 16;
      CreateLabel(pfx + "Lote", 20, y, StringFormat("Lote sugerido p/ risco de %s: %.2f", DoubleToString(Risco_Euros, 2), lote), clrSilver, 9); y += 16;
      CreateLabel(pfx + "Aviso", 20, y, "Confirme no grafico e envie a ordem manualmente.", clrGray, 9);
   }
   else
   {
      ObjectDelete(0, pfx + "Dir");
      ObjectDelete(0, pfx + "Entrada");
      ObjectDelete(0, pfx + "SL");
      ObjectDelete(0, pfx + "TP");
      ObjectDelete(0, pfx + "RSI");
      ObjectDelete(0, pfx + "Lote");
      CreateLabel(pfx + "Aviso", 20, y, "Analisando " + _Symbol + "...", clrGray, 9); y += 16;
      CreateLabel(pfx + "Tendencia", 20, y, "Tendencia H1: " + g_engine.DiagnosticoTendencia(), clrSilver, 9); y += 16;
      CreateLabel(pfx + "ATR", 20, y,
         StringFormat("ATR estrutura/gatilho: %s / %s",
            DoubleToString(g_engine.DiagnosticoATR_Estrutura() / _Point, 1),
            DoubleToString(g_engine.DiagnosticoATR_Gatilho() / _Point, 1)),
         clrSilver, 9); y += 16;

      if(s.estado == SNIPER_EM_ZONA || s.estado == SNIPER_SWEEP_OK)
         CreateLabel(pfx + "Timeout", 20, y,
            StringFormat("Velas na zona: %d / %d (timeout)", g_engine.DiagnosticoVelasNaZona(), g_engine.DiagnosticoTimeoutVelas()),
            clrSilver, 9);
      else
         ObjectDelete(0, pfx + "Timeout");
   }

   ChartRedraw();
}

void DesenharZona(SniperSetup &s)
{
   if(s.ob_time <= 0) return;

   string base = g_prefix + "OB_" + TimeToString(s.ob_time);
   color cor = (s.direcao == 1 ? Cor_OB_Compra : Cor_OB_Venda);

   if(ObjectFind(0, base) < 0)
      ObjectCreate(0, base, OBJ_RECTANGLE, 0, s.ob_time, s.ob_high, TimeCurrent(), s.ob_low);

   ObjectSetInteger(0, base, OBJPROP_TIME, 1, TimeCurrent() + PeriodSeconds(TF_Gatilho) * 20);
   ObjectSetInteger(0, base, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, base, OBJPROP_FILL, true);
   ObjectSetInteger(0, base, OBJPROP_BACK, true);
   ObjectSetInteger(0, base, OBJPROP_WIDTH, 1);

   string label = base + "_Label";
   if(ObjectFind(0, label) < 0)
      ObjectCreate(0, label, OBJ_TEXT, 0, s.ob_time, s.ob_high);
   ObjectSetString(0, label, OBJPROP_TEXT, "  OB " + s.ob_tf + (s.direcao == 1 ? " (compra)" : " (venda)"));
   ObjectSetInteger(0, label, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
}

void DesenharSweep(SniperSetup &s)
{
   double preco_sweep = (s.direcao == 1 ? s.sweep_low : s.sweep_high);
   if(preco_sweep <= 0) return;

   string name = g_prefix + "Sweep_" + TimeToString(s.ob_time);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), preco_sweep);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // ponto
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrMagenta);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, TimeCurrent());
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, preco_sweep);
}

void DesenharNiveis(SniperSetup &s)
{
   if(s.estado != SNIPER_PRONTO) return;

   string base = g_prefix + "Niveis_" + TimeToString(s.hora_pronto);
   datetime t1 = TimeCurrent();
   datetime t2 = TimeCurrent() + PeriodSeconds(TF_Gatilho) * 30;

   string entrada_name = base + "_Entrada";
   if(ObjectFind(0, entrada_name) < 0)
      ObjectCreate(0, entrada_name, OBJ_TREND, 0, t1, s.entrada, t2, s.entrada);
   ObjectSetInteger(0, entrada_name, OBJPROP_COLOR, Cor_Entrada);
   ObjectSetInteger(0, entrada_name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, entrada_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, entrada_name, OBJPROP_RAY_RIGHT, false);

   string sl_name = base + "_SL";
   if(ObjectFind(0, sl_name) < 0)
      ObjectCreate(0, sl_name, OBJ_TREND, 0, t1, s.sl, t2, s.sl);
   ObjectSetInteger(0, sl_name, OBJPROP_COLOR, Cor_SL);
   ObjectSetInteger(0, sl_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, sl_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, sl_name, OBJPROP_RAY_RIGHT, false);

   string tp_name = base + "_TP";
   if(ObjectFind(0, tp_name) < 0)
      ObjectCreate(0, tp_name, OBJ_TREND, 0, t1, s.tp, t2, s.tp);
   ObjectSetInteger(0, tp_name, OBJPROP_COLOR, Cor_TP);
   ObjectSetInteger(0, tp_name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, tp_name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, tp_name, OBJPROP_RAY_RIGHT, false);

   string label_name = base + "_Label";
   if(ObjectFind(0, label_name) < 0)
      ObjectCreate(0, label_name, OBJ_TEXT, 0, t2, s.entrada);
   string txt = StringFormat(" %s | Entrada %s | SL %s | TP %s (RR %.2f)",
                              (s.direcao == 1 ? "COMPRA" : "VENDA"),
                              DoubleToString(s.entrada, _Digits),
                              DoubleToString(s.sl, _Digits),
                              DoubleToString(s.tp, _Digits),
                              s.rr_efetivo);
   ObjectSetString(0, label_name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, label_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void DispararAlerta(SniperSetup &s)
{
   if(s.hora_pronto == g_ultimo_alerta) return;
   g_ultimo_alerta = s.hora_pronto;

   double lote = LotesSugeridos(s.entrada, s.sl);
   string msg = StringFormat("%s %s | Entrada %s | SL %s | TP %s | RR %.2f | Lote sugerido %.2f%s",
                              _Symbol,
                              (s.direcao == 1 ? "COMPRA" : "VENDA"),
                              DoubleToString(s.entrada, _Digits),
                              DoubleToString(s.sl, _Digits),
                              DoubleToString(s.tp, _Digits),
                              s.rr_efetivo,
                              lote,
                              (s.confirmacao_rastro ? " | confirmacao: rastro sniper" : " | confirmacao: candle classico"));

   Print(">>> SETUP PRONTO | ", msg);
   if(Alert_Popup) Alert(msg);
   if(Alert_Sound) PlaySound(Alert_Sound_File);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                 const double &open[], const double &high[], const double &low[], const double &close[],
                 const long &tick_volume[], const long &volume[], const int &spread[])
{
   if(CheckPointer(g_engine) == POINTER_INVALID) return 0;

   g_engine.Update();
   SniperSetup s = g_engine.GetSetup();

   if(s.estado != g_ultimo_estado_desenhado)
   {
      g_ultimo_estado_desenhado = s.estado;
      if(s.estado == SNIPER_SCANNING)
         ObjectsDeleteAll(0, g_prefix + "Niveis_");
   }

   if(s.estado == SNIPER_EM_ZONA || s.estado == SNIPER_SWEEP_OK || s.estado == SNIPER_PRONTO)
      DesenharZona(s);

   if(s.estado == SNIPER_SWEEP_OK || s.estado == SNIPER_PRONTO)
      DesenharSweep(s);

   if(s.estado == SNIPER_PRONTO)
   {
      DesenharNiveis(s);
      DispararAlerta(s);
   }

   DesenharPainel(s);

   return rates_total;
}
