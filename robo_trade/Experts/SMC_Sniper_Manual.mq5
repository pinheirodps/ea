//+------------------------------------------------------------------+
//|                                        SMC_Sniper_Manual.mq5     |
//|  EA "semi-automatico": usa o mesmo motor de sinal SMC do          |
//|  SMC_Sniper.mq5 (tendencia H1, Order Block H1, sweep no timeframe |
//|  de gatilho, displacement + RSI) para montar o setup completo     |
//|  (entrada, SL, TP, lote pela % de risco) e mostra botoes          |
//|  BUY/SELL na tela.                                                |
//|                                                                    |
//|  O EA NUNCA abre ordem sozinho. Ele so calcula e desenha; voce    |
//|  decide olhando o grafico e clica no botao para enviar a ordem.   |
//+------------------------------------------------------------------+
#property copyright "SMC Sniper Manual"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <SMC\SniperSignalEngine.mqh>

CTrade trade;
CSniperSignalEngine *g_engine = NULL;

input group "=== Timeframes (HTF -> LTF) ==="
input ENUM_TIMEFRAMES  TF_Estrutura        = PERIOD_H1;   // Timeframe maior: tendencia + Order Block
input ENUM_TIMEFRAMES  TF_Gatilho          = PERIOD_M1;   // Timeframe menor: sweep + displacement + confirmacao
input ENUM_TIMEFRAMES  TF_RSI              = PERIOD_M30;  // Timeframe do RSI de momentum

input group "=== Risco / Alvo ==="
input double  RR_Ratio               = 2.0;
input double  RR_Sniper_Forte        = 2.8;
input bool    Usar_RR_Dinamico       = true;
input double  ATR_Stop_Min           = 0.15;
input double  ATR_Stop_Max           = 5.0;
input double  RSI_Min_Entrada        = 52.0;

input group "=== Dimensionamento da ordem ==="
input double  Risco_Euros            = 25.0;   // Risco monetario por trade usado para calcular o lote
input int     Magic                  = 20260301;
input string  Comentario_Ordem       = "SMC_Sniper_Manual";

input group "=== Alerta / Visual ==="
input bool    Alert_Popup            = true;
input bool    Alert_Sound            = true;
input string  Alert_Sound_File       = "alert2.wav";
input bool    Mostrar_Zona_Grafico   = true;    // Desenha o retangulo do Order Block e o sweep no grafico
input color   Cor_OB_Compra          = clrDodgerBlue;
input color   Cor_OB_Venda           = clrCrimson;
input color   Cor_SL                 = clrRed;
input color   Cor_TP                 = clrLimeGreen;
input color   Cor_Entrada            = clrWhite;

string   g_prefix = "SMCManual_";
string   g_btn_buy = "SMCManual_BtnBuy";
string   g_btn_sell = "SMCManual_BtnSell";
string   g_btn_cancel = "SMCManual_BtnCancel";
datetime g_ultimo_alerta = 0;
SniperSetup g_setup_exibido;
bool     g_tem_setup_exibido = false;
ENUM_SNIPER_ESTADO g_ultimo_estado_desenhado = SNIPER_SCANNING;

//+------------------------------------------------------------------+
double LotesPorRisco(double entrada, double sl)
{
   double dist = MathAbs(entrada - sl);
   if(dist <= 0) return 0;

   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0 || tv <= 0) return 0;

   double lote = NormalizeDouble(Risco_Euros / ((dist / ts) * tv), 2);
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lote = MathFloor(lote / step) * step;
   return MathMax(min_lot, MathMin(max_lot, lote));
}

bool TemPosicaoAberta()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == Magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
   }
   return false;
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

void CreateButton(string name, int x, int y, int w, int h, string text, color bg, color txt_color)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
}

void RemoverBotoes()
{
   ObjectDelete(0, g_btn_buy);
   ObjectDelete(0, g_btn_sell);
   ObjectDelete(0, g_btn_cancel);
}

void DesenharZona(SniperSetup &s)
{
   if(!Mostrar_Zona_Grafico || s.ob_time <= 0) return;

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
   if(!Mostrar_Zona_Grafico) return;
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
   if(!Mostrar_Zona_Grafico || s.estado != SNIPER_PRONTO) return;

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

void LimparZonaGrafico()
{
   ObjectsDeleteAll(0, g_prefix + "OB_");
   ObjectsDeleteAll(0, g_prefix + "Sweep_");
   ObjectsDeleteAll(0, g_prefix + "Niveis_");
}

void RemoverDiagnostico()
{
   string pfx = g_prefix + "Dash_";
   ObjectDelete(0, pfx + "Tendencia");
   ObjectDelete(0, pfx + "ATR");
   ObjectDelete(0, pfx + "Timeout");
}

//+------------------------------------------------------------------+
void AtualizarPainel()
{
   string pfx = g_prefix + "Dash_";
   int y = 20;

   ENUM_SNIPER_ESTADO estado = g_engine.GetEstado();
   string estado_txt = "SCANNING";
   color estado_clr = clrGray;
   if(estado == SNIPER_EM_ZONA) { estado_txt = "EM ZONA"; estado_clr = clrOrange; }
   else if(estado == SNIPER_SWEEP_OK) { estado_txt = "SWEEP OK"; estado_clr = clrYellow; }
   else if(estado == SNIPER_PRONTO) { estado_txt = "PRONTO - DECIDA"; estado_clr = clrLime; }

   CreateLabel(pfx + "Title", 20, y, "=== SMC SNIPER MANUAL ===", clrWhite, 12); y += 22;
   CreateLabel(pfx + "Modo", 20, y, "Modo: MANUAL (voce clica p/ entrar)", clrOrange, 10); y += 18;
   CreateLabel(pfx + "Risco", 20, y, StringFormat("Risco configurado: %s por trade", DoubleToString(Risco_Euros, 2)), clrOrange, 9); y += 16;
   CreateLabel(pfx + "Estado", 20, y, "Estado: " + estado_txt, estado_clr, 10); y += 18;

   bool tem_posicao = TemPosicaoAberta();

   if(tem_posicao)
   {
      RemoverBotoes();
      RemoverDiagnostico();
      CreateLabel(pfx + "Info", 20, y, "Posicao aberta. Gerencie pelo terminal.", clrSilver, 9);
      return;
   }

   if(estado == SNIPER_PRONTO && g_tem_setup_exibido)
   {
      RemoverDiagnostico();
      SniperSetup s = g_setup_exibido;
      double lote = LotesPorRisco(s.entrada, s.sl);
      string dir_txt = (s.direcao == 1 ? "COMPRA" : "VENDA");
      color dir_clr = (s.direcao == 1 ? clrDodgerBlue : clrCrimson);

      CreateLabel(pfx + "Dir", 20, y, "Direcao: " + dir_txt + " | Zona: " + s.ob_tf, dir_clr, 10); y += 18;
      CreateLabel(pfx + "Entrada", 20, y, StringFormat("Entrada: %s", DoubleToString(s.entrada, _Digits)), clrWhite, 10); y += 18;
      CreateLabel(pfx + "SL", 20, y, StringFormat("Stop:    %s  (%.1f pts)", DoubleToString(s.sl, _Digits), s.stop_pts), clrRed, 10); y += 18;
      CreateLabel(pfx + "TP", 20, y, StringFormat("Alvo:    %s  (RR %.2f)", DoubleToString(s.tp, _Digits), s.rr_efetivo), clrLimeGreen, 10); y += 18;
      CreateLabel(pfx + "Lote", 20, y, StringFormat("Lote (risco %s): %.2f", DoubleToString(Risco_Euros, 2), lote), clrSilver, 9); y += 22;

      if(s.direcao == 1)
      {
         CreateButton(g_btn_buy, 20, y, 160, 34, StringFormat("COMPRAR %.2f lote", lote), clrDodgerBlue, clrWhite);
         ObjectDelete(0, g_btn_sell);
      }
      else
      {
         CreateButton(g_btn_sell, 20, y, 160, 34, StringFormat("VENDER %.2f lote", lote), clrCrimson, clrWhite);
         ObjectDelete(0, g_btn_buy);
      }
      CreateButton(g_btn_cancel, 190, y, 100, 34, "Ignorar", clrGray, clrWhite);
   }
   else
   {
      RemoverBotoes();
      CreateLabel(pfx + "Info", 20, y, "Aguardando setup em " + _Symbol + "...", clrGray, 9); y += 16;
      CreateLabel(pfx + "Tendencia", 20, y, "Tendencia H1: " + g_engine.DiagnosticoTendencia(), clrSilver, 9); y += 16;
      CreateLabel(pfx + "ATR", 20, y,
         StringFormat("ATR estrutura/gatilho: %s / %s",
            DoubleToString(g_engine.DiagnosticoATR_Estrutura() / _Point, 1),
            DoubleToString(g_engine.DiagnosticoATR_Gatilho() / _Point, 1)),
         clrSilver, 9); y += 16;

      if(estado == SNIPER_EM_ZONA || estado == SNIPER_SWEEP_OK)
         CreateLabel(pfx + "Timeout", 20, y,
            StringFormat("Velas na zona: %d / %d (timeout)", g_engine.DiagnosticoVelasNaZona(), g_engine.DiagnosticoTimeoutVelas()),
            clrSilver, 9);
      else
         ObjectDelete(0, pfx + "Timeout");
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
void EnviarOrdem(int direcao)
{
   if(!g_tem_setup_exibido) return;
   SniperSetup s = g_setup_exibido;
   if(s.direcao != direcao) return;

   double lote = LotesPorRisco(s.entrada, s.sl);
   if(lote <= 0)
   {
      Alert("Lote invalido, ordem nao enviada. Confira risco/stop.");
      return;
   }

   trade.SetExpertMagicNumber(Magic);
   trade.SetDeviationInPoints(10);

   bool ok = false;
   double preco_atual = (direcao == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));

   if(direcao == 1)
      ok = trade.Buy(lote, _Symbol, preco_atual, s.sl, s.tp, Comentario_Ordem);
   else
      ok = trade.Sell(lote, _Symbol, preco_atual, s.sl, s.tp, Comentario_Ordem);

   if(ok)
   {
      Print(">>> ORDEM MANUAL ENVIADA | ", (direcao == 1 ? "BUY" : "SELL"),
            " | lote: ", lote, " | SL: ", s.sl, " | TP: ", s.tp);
      g_engine.Reset();
      g_tem_setup_exibido = false;
      RemoverBotoes();
      LimparZonaGrafico();
   }
   else
   {
      Print("Erro ao enviar ordem manual: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      Alert("Erro ao enviar ordem: " + trade.ResultRetcodeDescription());
   }
}

void CancelarSetup()
{
   g_engine.Reset();
   g_tem_setup_exibido = false;
   RemoverBotoes();
   LimparZonaGrafico();
   Print("Setup ignorado pelo usuario.");
}

//+------------------------------------------------------------------+
void DispararAlerta(SniperSetup &s)
{
   if(s.hora_pronto == g_ultimo_alerta) return;
   g_ultimo_alerta = s.hora_pronto;

   double lote = LotesPorRisco(s.entrada, s.sl);
   string msg = StringFormat("%s %s | Entrada %s | SL %s | TP %s | RR %.2f | Lote sugerido %.2f",
                              _Symbol,
                              (s.direcao == 1 ? "COMPRA" : "VENDA"),
                              DoubleToString(s.entrada, _Digits),
                              DoubleToString(s.sl, _Digits),
                              DoubleToString(s.tp, _Digits),
                              s.rr_efetivo,
                              lote);

   Print(">>> SETUP PRONTO (decisao manual) | ", msg);
   if(Alert_Popup) Alert(msg);
   if(Alert_Sound) PlaySound(Alert_Sound_File);
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_engine = new CSniperSignalEngine(_Symbol);
   g_engine.SetTimeframes(TF_Estrutura, TF_Gatilho, TF_RSI);
   g_engine.SetRiscoRR(RR_Ratio, RR_Sniper_Forte, Usar_RR_Dinamico);
   g_engine.SetStopLimites(ATR_Stop_Min, ATR_Stop_Max);
   g_engine.SetRSI(RSI_Min_Entrada);

   if(!g_engine.Init())
   {
      Print("SMC Sniper Manual: falha ao criar indicadores (ATR/EMA/RSI).");
      return INIT_FAILED;
   }

   Print("SMC Sniper Manual iniciado | Estrutura: ", EnumToString(TF_Estrutura),
         " | Gatilho: ", EnumToString(TF_Gatilho),
         " | RSI: ", EnumToString(TF_RSI),
         " | Risco/trade: ", DoubleToString(Risco_Euros, 2));
   Print("MODO MANUAL: o EA nunca abre ordem sozinho. Use os botoes na tela para confirmar.");

   AtualizarPainel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, g_prefix);
   RemoverBotoes();
   if(CheckPointer(g_engine) != POINTER_INVALID)
   {
      g_engine.Deinit();
      delete g_engine;
      g_engine = NULL;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(CheckPointer(g_engine) == POINTER_INVALID) return;

   if(TemPosicaoAberta())
   {
      AtualizarPainel();
      return;
   }

   g_engine.Update();
   SniperSetup s = g_engine.GetSetup();

   if(s.estado != g_ultimo_estado_desenhado)
   {
      g_ultimo_estado_desenhado = s.estado;
      if(s.estado == SNIPER_SCANNING) LimparZonaGrafico();
   }

   if(s.estado == SNIPER_EM_ZONA || s.estado == SNIPER_SWEEP_OK || s.estado == SNIPER_PRONTO)
      DesenharZona(s);

   if(s.estado == SNIPER_SWEEP_OK || s.estado == SNIPER_PRONTO)
      DesenharSweep(s);

   if(g_engine.EstaPronto())
   {
      g_setup_exibido = s;
      g_tem_setup_exibido = true;
      DesenharNiveis(s);
      DispararAlerta(s);
   }

   AtualizarPainel();
   ChartRedraw();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   if(sparam == g_btn_buy)
   {
      ObjectSetInteger(0, g_btn_buy, OBJPROP_STATE, false);
      EnviarOrdem(1);
   }
   else if(sparam == g_btn_sell)
   {
      ObjectSetInteger(0, g_btn_sell, OBJPROP_STATE, false);
      EnviarOrdem(-1);
   }
   else if(sparam == g_btn_cancel)
   {
      ObjectSetInteger(0, g_btn_cancel, OBJPROP_STATE, false);
      CancelarSetup();
   }
}
